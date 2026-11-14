import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const _galleryChannel = MethodChannel('animew/image_gallery');

final Map<String, Future<Uint8List>> _malArtworkBytes = {};

Future<Uint8List> _loadMalArtworkBytes(String url) {
  return _malArtworkBytes.putIfAbsent(url, () async {
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 60),
        sendTimeout: const Duration(seconds: 20),
        responseType: ResponseType.bytes,
      ),
    );
    try {
      final response = await dio.get<List<int>>(url);
      final bytes = response.data;
      if (bytes == null || bytes.isEmpty) {
        throw StateError('Gambar kosong');
      }
      // Keep only a small in-memory cache so swiping back does not redownload
      // the same artwork, without retaining an unlimited number of images.
      if (_malArtworkBytes.length > 12) {
        _malArtworkBytes.remove(_malArtworkBytes.keys.first);
      }
      return Uint8List.fromList(bytes);
    } catch (_) {
      _malArtworkBytes.remove(url);
      rethrow;
    } finally {
      dio.close();
    }
  });
}

class _MalArtworkImage extends StatefulWidget {
  const _MalArtworkImage({required this.url});

  final String url;

  @override
  State<_MalArtworkImage> createState() => _MalArtworkImageState();
}

class _MalArtworkImageState extends State<_MalArtworkImage> {
  late Future<Uint8List> _image;

  @override
  void initState() {
    super.initState();
    _image = _loadMalArtworkBytes(widget.url);
  }

  void _retry() {
    setState(() => _image = _loadMalArtworkBytes(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: _image,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return Image.memory(snapshot.data!, fit: BoxFit.contain);
        }
        if (snapshot.hasError) {
          return GestureDetector(
            onTap: _retry,
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.refresh_rounded, color: Colors.white70, size: 42),
                SizedBox(height: 8),
                Text(
                  'Gagal memuat · ketuk untuk coba lagi',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          );
        }
        return const Center(
          child: CircularProgressIndicator(color: Colors.white),
        );
      },
    );
  }
}

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
    barrierColor: Colors.black.withValues(alpha: 0.50),
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
  void initState() {
    super.initState();
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
          headers: requestHeaders == null || requestHeaders.isEmpty ? null : requestHeaders,
          connectTimeout: const Duration(seconds: 20),
          receiveTimeout: const Duration(seconds: 60),
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
                // PageView may build neighbouring pages before the user
                // reaches them. Keep those pages inert: fetch image bytes only
                // for the page currently selected by a swipe.
                if (index != _index) {
                  return const Center(
                    child: Icon(
                      Icons.photo_outlined,
                      color: Colors.white38,
                      size: 34,
                    ),
                  );
                }
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
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.42),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  tooltip: 'Tutup',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.42),
                  shape: BoxShape.circle,
                ),
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
            ),
            Positioned(
              top: 14,
              left: 0,
              right: 0,
              child: Center(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.58),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 9,
                    ),
                    child: Text(
                      '${_index + 1}/${widget.images.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
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
