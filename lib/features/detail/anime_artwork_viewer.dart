import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/ui/app_toast.dart';

const _galleryChannel = MethodChannel('animew/image_gallery');

Future<void> showAnimeArtworkViewer(
  BuildContext context, {
  required String posterUrl,
  String? bannerUrl,
  required String title,
  Map<String, String>? headers,
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
    barrierColor: Colors.black,
    builder: (dialogContext) => _AnimeArtworkViewer(
      images: images,
      title: title,
      headers: headers,
    ),
  );
}

class _AnimeArtworkViewer extends StatefulWidget {
  const _AnimeArtworkViewer({
    required this.images,
    required this.title,
    required this.headers,
  });

  final List<({String label, String url})> images;
  final String title;
  final Map<String, String>? headers;

  @override
  State<_AnimeArtworkViewer> createState() => _AnimeArtworkViewerState();
}

class _AnimeArtworkViewerState extends State<_AnimeArtworkViewer> {
  late final PageController _pages = PageController();
  int _index = 0;
  bool _saving = false;

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
      color: Colors.black,
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
            if (widget.images.length > 1)
              Positioned(
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
