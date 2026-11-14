import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';


const _galleryChannel = MethodChannel('animew/image_gallery');

Future<void> showAnimeArtworkViewer(
  BuildContext context, {
  required String posterUrl,
  String? bannerUrl,
  required String title,
  Map<String, String>? headers,
  int? malId,
}) async {
  final images = <({String label, String url})>[
    if (posterUrl.trim().isNotEmpty) (label: 'Poster', url: posterUrl.trim()),
    if (bannerUrl?.trim().isNotEmpty == true &&
        bannerUrl!.trim() != posterUrl.trim())
      (label: 'Banner', url: bannerUrl.trim()),
  ];
  if (images.isEmpty) return;

  await showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.50),
    builder: (dialogContext) => _AnimeArtworkViewer(
      images: images,
      title: title,
      headers: headers,
      malId: malId,
    ),
  );
}

class _AnimeArtworkViewer extends StatefulWidget {
  const _AnimeArtworkViewer({
    required this.images,
    required this.title,
    required this.headers,
    required this.malId,
  });

  final List<({String label, String url})> images;
  final String title;
  final Map<String, String>? headers;
  final int? malId;

  @override
  State<_AnimeArtworkViewer> createState() => _AnimeArtworkViewerState();
}

class _AnimeArtworkViewerState extends State<_AnimeArtworkViewer> {
  late final PageController _pages = PageController();
  int _index = 0;
  bool _saving = false;
  bool _loadingMalPictures = false;

  @override
  void initState() {
    super.initState();
    _loadMalPictures();
  }

  Future<void> _loadMalPictures() async {
    final id = widget.malId;
    if (id == null || id <= 0) return;
    if (mounted) setState(() => _loadingMalPictures = true);
    try {
      final response = await Dio().get<Map<String, dynamic>>(
        'https://api.jikan.moe/v4/anime/$id/pictures',
        options: Options(
          receiveTimeout: const Duration(seconds: 20),
          headers: const {'Accept': 'application/json'},
        ),
      );
      final data = response.data?['data'];
      if (data is! List) return;
      final existing = widget.images.map((image) => image.url).toSet();
      final additions = <({String label, String url})>[];
      for (final item in data) {
        if (item is! Map) continue;
        final jpg = item['jpg'];
        final webp = item['webp'];
        final url = (jpg is Map ? jpg['large_image_url'] : null) as String? ??
            (webp is Map ? webp['large_image_url'] : null) as String? ??
            (jpg is Map ? jpg['image_url'] : null) as String? ??
            (webp is Map ? webp['image_url'] : null) as String?;
        if (url == null || url.isEmpty || !existing.add(url)) continue;
        additions.add((label: 'MAL ${additions.length + 1}', url: url));
      }
      if (!mounted || additions.isEmpty) return;
      setState(() => widget.images.addAll(additions));
    } catch (_) {
      // MAL pictures are optional; keep the AniList poster and banner usable.
    } finally {
      if (mounted) setState(() => _loadingMalPictures = false);
    }
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _saveCurrent() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final image = widget.images[_index];
      final requestHeaders = Map<String, String>.from(widget.headers ?? {})
        ..remove('x-ani-src')
        ..remove('x-mihon-src');
      final response = await Dio().get<List<int>>(
        image.url,
        options: Options(
          responseType: ResponseType.bytes,
          headers: requestHeaders.isEmpty ? null : requestHeaders,
          receiveTimeout: const Duration(seconds: 30),
        ),
      );
      final bytes = response.data;
      if (bytes == null || bytes.isEmpty) {
        throw StateError('Gambar kosong');
      }
      final uri = await _galleryChannel.invokeMethod<String>('saveImage', {
        'bytes': Uint8List.fromList(bytes),
        'fileName': _fileName(image.label),
        'mimeType': _mimeType(response.headers.value('content-type'), image.url),
      });
      if (!mounted) return;
      if (uri == null || uri.isEmpty) throw StateError('Gagal menyimpan gambar');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${image.label} berhasil disimpan ke Galeri')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengunduh gambar: $error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _fileName(String label) {
    final safe = widget.title
        .replaceAll(RegExp(r'[^a-zA-Z0-9 _-]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '_');
    final stamp = DateTime.now().millisecondsSinceEpoch;
    return '${safe.isEmpty ? 'Anime' : safe}_${label.toLowerCase()}_$stamp';
  }

  String _mimeType(String? contentType, String url) {
    final type = contentType?.split(';').first.trim().toLowerCase();
    if (type == 'image/png' || type == 'image/webp' || type == 'image/jpeg') {
      return type!;
    }
    final path = Uri.tryParse(url)?.path.toLowerCase() ?? '';
    if (path.endsWith('.png')) return 'image/png';
    if (path.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  @override
  Widget build(BuildContext context) {
    final current = widget.images[_index];
    return Material(
      color: Colors.black.withValues(alpha: 0.50),
      child: SafeArea(
        child: Stack(
          children: [
            PageView.builder(
              controller: _pages,
              itemCount: widget.images.length,
              onPageChanged: (index) => setState(() => _index = index),
              itemBuilder: (context, index) {
                final image = widget.images[index];
                return Center(
                  child: InteractiveViewer(
                    minScale: 1,
                    maxScale: 4,
                    child: CachedNetworkImage(
                      imageUrl: image.url,
                      httpHeaders: widget.headers,
                      fit: BoxFit.contain,
                      placeholder: (_, _) => const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                      errorWidget: (_, _, _) => const Icon(
                        Icons.broken_image_outlined,
                        color: Colors.white70,
                        size: 42,
                      ),
                    ),
                  ),
                );
              },
            ),
            Positioned(
              top: 8,
              left: 8,
              child: IconButton(
                tooltip: 'Tutup',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded, color: Colors.white),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                tooltip: 'Unduh ${current.label}',
                onPressed: _saving ? null : _saveCurrent,
                icon: _saving
                    ? const SizedBox(
                        width: 21,
                        height: 21,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.download_rounded, color: Colors.white),
              ),
            ),
            if (_loadingMalPictures)\n              Positioned(\n                bottom: 18,\n                left: 0,\n                right: 0,\n                child: Center(\n                  child: DecoratedBox(\n                    decoration: BoxDecoration(\n                      color: Colors.black.withValues(alpha: 0.58),\n                      borderRadius: BorderRadius.circular(18),\n                    ),\n                    child: const Padding(\n                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 7),\n                      child: Row(\n                        mainAxisSize: MainAxisSize.min,\n                        children: [\n                          SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.8, color: Colors.white)),\n                          SizedBox(width: 8),\n                          Text('Memuat gambar MAL...', style: TextStyle(color: Colors.white, fontSize: 12)),\n                        ],\n                      ),\n                    ),\n                  ),\n                ),\n              ),\n            if (widget.images.length > 1)\n              Positioned(
                left: 0,
                right: 0,
                bottom: 18,
                child: Center(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.58),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (var i = 0; i < widget.images.length; i++) ...[
                            if (i > 0) const SizedBox(width: 12),
                            GestureDetector(
                              onTap: () => _pages.animateToPage(
                                i,
                                duration: const Duration(milliseconds: 220),
                                curve: Curves.easeOut,
                              ),
                              child: Text(
                                widget.images[i].label,
                                style: TextStyle(
                                  color: i == _index ? Colors.white : Colors.white60,
                                  fontSize: 12,
                                  fontWeight: i == _index ? FontWeight.w700 : FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
