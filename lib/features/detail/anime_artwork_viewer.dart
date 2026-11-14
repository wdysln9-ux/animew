import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/metadata/jikan_api.dart';

const _galleryChannel = MethodChannel('animew/image_gallery');

/// Shared in-flight/result cache so the detail page can warm MAL artwork before
/// the viewer is opened. Opening the gallery joins this same request.
final Map<int, Future<List<String>>> _malPictureRequests = {};

Future<List<String>> preloadAnimeMalPictures(int malId) {
  if (malId <= 0) return Future.value(const <String>[]);
  return _malPictureRequests.putIfAbsent(malId, () async {
    try {
      // Use the app-wide Jikan scheduler instead of a raw Dio request.
      // Other detail sections also call Jikan; sharing its rate limit and
      // retry handling prevents the Pictures request from being rejected
      // when several Jikan endpoints are loading together.
      final response = await JikanApi.get(
        Dio(),
        'https://api.jikan.moe/v4/anime/$malId/pictures',
        headers: const {'Accept': 'application/json'},
      );
      final data = response is Map ? response['data'] : null;
      if (data is! List) return const <String>[];
      final urls = <String>[];
      final seen = <String>{};
      for (final item in data) {
        if (item is! Map) continue;
        final jpg = item['jpg'];
        final webp = item['webp'];
        final url = (jpg is Map ? jpg['large_image_url'] : null) as String? ??
            (webp is Map ? webp['large_image_url'] : null) as String? ??
            (jpg is Map ? jpg['image_url'] : null) as String? ??
            (webp is Map ? webp['image_url'] : null) as String?;
        if (url != null && url.isNotEmpty && seen.add(url)) urls.add(url);
      }
      return urls;
    } catch (_) {
      // Do not cache a failed request. The viewer can show the failure and a
      // later attempt can retry instead of silently looking like success.
      _malPictureRequests.remove(malId);
      rethrow;
    }
  });
}

/// Also warms the actual image bytes (not just the Jikan URL list), so opening
/// the gallery can paint from CachedNetworkImage's disk cache.
final Map<int, Future<void>> _malImagePreloads = {};

Future<void> preloadAnimeMalArtwork(int malId, BuildContext context) {
  return _malImagePreloads.putIfAbsent(malId, () async {
    try {
      final urls = await preloadAnimeMalPictures(malId);
      for (final url in urls.take(8)) {
        if (!context.mounted) {
          _malImagePreloads.remove(malId);
          return;
        }
        try {
          await precacheImage(CachedNetworkImageProvider(url), context);
        } catch (_) {
          // One failed image should not block the rest of the gallery.
        }
      }
    } catch (_) {
      // Keep this best-effort: the viewer owns the visible error state.
      _malImagePreloads.remove(malId);
    }
  });
}

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
  String? _malLoadMessage;
  bool _hideMalSuccessMessage = false;

  @override
  void initState() {
    super.initState();
    _loadMalPictures();
  }

  Future<void> _loadMalPictures() async {
    final id = widget.malId;
    if (id == null || id <= 0) {
      if (mounted) {
        setState(() {
          _loadingMalPictures = false;
          _malLoadMessage = 'ID MAL tidak diterima oleh galeri';
        });
      }
      return;
    }
    if (mounted) {
      setState(() {
        _loadingMalPictures = true;
        _malLoadMessage = null;
        _hideMalSuccessMessage = false;
      });
    }
    try {
      // Usually this future has already completed while the detail page was
      // visible; if not, the viewer joins the same request.
      final urls = await preloadAnimeMalPictures(id);
      if (!mounted) return;
      final existing = widget.images.map((image) => image.url).toSet();
      final additions = <({String label, String url})>[];
      for (final url in urls) {
        if (!existing.add(url)) continue;
        additions.add((label: 'MAL ${additions.length + 1}', url: url));
      }
      setState(() {
        if (additions.isNotEmpty) widget.images.addAll(additions);
        _malLoadMessage = additions.isEmpty
            ? 'MAL tidak mengembalikan gambar tambahan'
            : '${additions.length} gambar MAL ditemukan · geser ke samping';
        _hideMalSuccessMessage = false;
      });
      if (additions.isNotEmpty) {
        // Start fading as soon as the success message has been painted.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _hideMalSuccessMessage = true);
        });
      }
    } catch (error) {
      if (!mounted) return;
      final detail = error is DioException
          ? [
              if (error.response?.statusCode != null)
                'HTTP ${error.response!.statusCode}'
              else
                error.type.name,
              if (error.message?.trim().isNotEmpty == true)
                error.message!.trim(),
            ].join(' · ')
          : error.toString();
      setState(() {
        _malLoadMessage = 'Gagal memuat gambar MAL: $detail';
      });
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
            if (_loadingMalPictures || _malLoadMessage != null)
              Positioned(
                bottom: 18,
                left: 16,
                right: 16,
                child: AnimatedOpacity(
                  opacity: _hideMalSuccessMessage ? 0 : 1,
                  duration: const Duration(seconds: 1),
                  curve: Curves.easeOut,
                  child: Center(
                    child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.68),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 9,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_loadingMalPictures) ...[
                            const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.8,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 8),
                          ] else ...[
                            Icon(
                              _malLoadMessage?.startsWith('Gagal') == true ||
                                      _malLoadMessage?.startsWith('ID MAL') == true
                                  ? Icons.error_outline_rounded
                                  : Icons.photo_library_outlined,
                              color: Colors.white,
                              size: 15,
                            ),
                            const SizedBox(width: 7),
                          ],
                          Flexible(
                            child: Text(
                              _loadingMalPictures
                                  ? 'Memuat gambar MAL...'
                                  : _malLoadMessage!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    ),
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
