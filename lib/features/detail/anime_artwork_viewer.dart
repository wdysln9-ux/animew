import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:html/parser.dart' as html_parser;

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

final Map<String, Future<List<({String label, String url})>>> _malPicturesCache = {};

Future<List<({String label, String url})>> _loadMyAnimeListArtwork(int? malId) {
  if (malId == null || malId <= 0) return Future.value(const []);
  return _malPicturesCache.putIfAbsent('mal:$malId', () async {
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 12),
        receiveTimeout: const Duration(seconds: 20),
        responseType: ResponseType.json,
        headers: const {'Accept': 'application/json'},
      ),
    );
    try {
      final response = await dio.get<dynamic>(
        'https://api.jikan.moe/v4/anime/$malId/pictures',
      );
      final body = response.data;
      final rawPictures = body is Map ? body['data'] : null;
      if (rawPictures is! List) return const [];
      final result = <({String label, String url})>[];
      final seen = <String>{};
      for (final raw in rawPictures) {
        if (raw is! Map) continue;
        final jpg = raw['jpg'];
        final webp = raw['webp'];
        final url = (jpg is Map
                ? jpg['large_image_url'] ?? jpg['image_url']
                : null) ??
            (webp is Map
                ? webp['large_image_url'] ?? webp['image_url']
                : null);
        final value = url?.toString().trim() ?? '';
        final uri = Uri.tryParse(value);
        if (uri == null ||
            (uri.scheme != 'https' && uri.scheme != 'http') ||
            !seen.add(value)) {
          continue;
        }
        result.add((label: 'Artwork · MyAnimeList', url: value));
      }
      return result;
    } catch (_) {
      _malPicturesCache.remove('mal:$malId');
      return const [];
    } finally {
      dio.close();
    }
  });
}


final Map<String, Future<List<({String label, String url})>>> _liveChartArtworkCache = {};

Future<List<({String label, String url})>> _loadLiveChartArtwork(String title) {
  final normalizedTitle = title.trim();
  if (normalizedTitle.isEmpty) return Future.value(const []);
  final cacheKey = normalizedTitle.toLowerCase();
  return _liveChartArtworkCache.putIfAbsent(cacheKey, () async {
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 25),
        responseType: ResponseType.plain,
        headers: const {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Accept-Language': 'en-US,en;q=0.9',
        },
      ),
    );
    try {
      final searchResponse = await dio.get<String>(
        'https://www.livechart.me/search',
        queryParameters: {'q': normalizedTitle},
      );
      if (searchResponse.statusCode != 200 || searchResponse.data == null) {
        return const [];
      }
      final searchDocument = html_parser.parse(searchResponse.data);
      final cards = searchDocument.querySelectorAll('.anime-item');
      String? animePath;
      if (cards.isNotEmpty) {
        final query = normalizedTitle.toLowerCase().replaceAll(
          RegExp(r'[^a-z0-9]+'),
          '',
        );
        var selected = cards.first;
        for (final card in cards) {
          final candidate = (card.attributes['data-title'] ??
                  card.querySelector('.anime-item__body__title a')?.text ??
                  '')
              .toLowerCase()
              .replaceAll(RegExp(r'[^a-z0-9]+'), '');
          if (candidate == query ||
              (candidate.isNotEmpty &&
                  query.isNotEmpty &&
                  (candidate.contains(query) || query.contains(candidate)))) {
            selected = card;
            break;
          }
        }
        animePath = selected
            .querySelector('.anime-item__body__title a')
            ?.attributes['href'];
      }
      animePath ??= searchDocument
          .querySelector('.callout .media-body a')
          ?.attributes['href'];
      if (animePath == null || animePath.trim().isEmpty) return const [];

      final animeUri = Uri.parse(animePath);
      final absoluteAnimeUri = animeUri.hasScheme
          ? animeUri
          : Uri.parse('https://www.livechart.me').resolveUri(animeUri);
      final basePath = absoluteAnimeUri.path.replaceFirst(RegExp(r'/$'), '');
      final visualsUri = absoluteAnimeUri.replace(
        path: '$basePath/visuals',
        query: null,
        fragment: null,
      );
      final visualsResponse = await dio.get<String>(visualsUri.toString());
      if (visualsResponse.statusCode != 200 || visualsResponse.data == null) {
        return const [];
      }
      final visualsDocument = html_parser.parse(visualsResponse.data);
      final result = <({String label, String url})>[];
      final seen = <String>{};
      for (final element
          in visualsDocument.querySelectorAll('[data-anime-visual-url-value]')) {
        var value =
            element.attributes['data-anime-visual-url-value']?.trim() ?? '';
        if (value.isEmpty) continue;
        final uri = Uri.tryParse(value);
        if (uri == null) continue;
        if (!uri.hasScheme) {
          value = Uri.parse('https://www.livechart.me').resolveUri(uri).toString();
        } else if (uri.scheme != 'https' && uri.scheme != 'http') {
          continue;
        }
        if (seen.add(value)) {
          result.add((label: 'Artwork · LiveChart', url: value));
        }
      }
      return result;
    } catch (_) {
      _liveChartArtworkCache.remove(cacheKey);
      return const [];
    } finally {
      dio.close();
    }
  });
}

Future<List<({String label, String url})>> _loadAniZipArtwork({
  int? anilistId,
  int? malId,
}) {
  final cacheKey = 'a:${anilistId ?? 0}:m:${malId ?? 0}';
  return _aniZipArtworkCache.putIfAbsent(cacheKey, () async {
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 12),
        receiveTimeout: const Duration(seconds: 20),
        responseType: ResponseType.json,
        headers: const {'Accept': 'application/json'},
      ),
    );
    try {
      var resolvedAniListId = anilistId;
      if ((resolvedAniListId == null || resolvedAniListId <= 0) &&
          malId != null && malId > 0) {
        final mapping = await dio.get<dynamic>(
          'https://api.ani.zip/v1/mappings',
          queryParameters: {'mal_id': malId},
        );
        final mappingData = mapping.data;
        if (mappingData is Map) {
          final rawId = mappingData['anilist_id'] ??
              (mappingData['mappings'] is Map
                  ? mappingData['mappings']['anilist_id']
                  : null);
          resolvedAniListId = int.tryParse(rawId?.toString() ?? '');
        }
      }
      if (resolvedAniListId == null || resolvedAniListId <= 0) {
        return const [];
      }

      dynamic data;
      for (final host in ['https://api.ani.zip', 'https://hayase.ani.zip']) {
        try {
          final response = await dio.get<dynamic>(
            '$host/v1/episodes',
            queryParameters: {'anilist_id': resolvedAniListId},
          );
          data = response.data;
          if (data is Map && data['images'] is List) break;
        } catch (_) {
          // Try the compatible AniZip endpoint host.
        }
      }
      if (data is! Map) return const [];
      final rawImages = data['images'] ??
          (data['data'] is Map ? data['data']['images'] : null);
      if (rawImages is! List) return const [];
      const labels = {
        'Poster': 'Poster · AniZip',
        'Banner': 'Banner · AniZip',
        'Fanart': 'Fanart · AniZip',
        'Clearlogo': 'Clearlogo · AniZip',
      };
      final result = <({String label, String url})>[];
      final seen = <String>{};
      for (final raw in rawImages) {
        if (raw is! Map) continue;
        final type = raw['coverType']?.toString();
        final url = raw['url']?.toString().trim() ?? '';
        final uri = Uri.tryParse(url);
        if (!labels.containsKey(type) ||
            uri == null ||
            (uri.scheme != 'https' && uri.scheme != 'http') ||
            !seen.add(url)) {
          continue;
        }
        result.add((label: labels[type]!, url: url));
      }
      return result;
    } catch (_) {
      _aniZipArtworkCache.remove(cacheKey);
      return const [];
    } finally {
      dio.close();
    }
  });
}

Future<void> showAnimeArtworkViewer(
  BuildContext context, {
  required String posterUrl,
  String? bannerUrl,
  int? anilistId,
  int? malId,
  required String title,
  Map<String, String>? headers,
}) async {
  final images = <({String label, String url})>[
    if (posterUrl.trim().isNotEmpty) (label: 'Poster · AniList', url: posterUrl.trim()),
    if (bannerUrl?.trim().isNotEmpty == true &&
        bannerUrl!.trim() != posterUrl.trim())
      (label: 'Banner · AniList', url: bannerUrl.trim()),
  ];
  if (images.isEmpty) return;

  await showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.50),
    builder: (dialogContext) => _AnimeArtworkViewer(
      images: images,
      title: title,
      headers: headers,
      anilistId: anilistId,
      malId: malId,
    ),
  );
}

class _AnimeArtworkViewer extends StatefulWidget {
  const _AnimeArtworkViewer({
    required this.images,
    required this.title,
    required this.headers,
    this.anilistId,
    this.malId,
  });

  final List<({String label, String url})> images;
  final String title;
  final Map<String, String>? headers;
  final int? anilistId;
  final int? malId;

  @override
  State<_AnimeArtworkViewer> createState() => _AnimeArtworkViewerState();
}

class _AnimeArtworkViewerState extends State<_AnimeArtworkViewer> {
  late final PageController _pages = PageController();
  int _index = 0;
  bool _saving = false;
  bool _loadingAdditionalArtwork = false;

  @override
  void initState() {
    super.initState();
    _loadAdditionalArtwork();
  }

  Future<void> _loadAdditionalArtwork() async {
    if ((widget.anilistId == null || widget.anilistId! <= 0) &&
        (widget.malId == null || widget.malId! <= 0)) return;
    setState(() => _loadingAdditionalArtwork = true);
    // Combine AniZip's typed artwork, MAL's additional pictures, and
    // LiveChart's public anime visuals page. Each source fails independently.
    final results = await Future.wait([
      _loadAniZipArtwork(
        anilistId: widget.anilistId,
        malId: widget.malId,
      ),
      _loadMyAnimeListArtwork(widget.malId),
      _loadLiveChartArtwork(widget.title),
    ]);
    if (!mounted) return;
    final existing = widget.images.map((image) => image.url).toSet();
    final additions = results
        .expand((images) => images)
        .where((image) => existing.add(image.url))
        .toList();
    setState(() {
      widget.images.addAll(additions);
      _loadingAdditionalArtwork = false;
    });
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
              onPageChanged: (index) {
                setState(() => _index = index);
                // Warm the pages on either side so a quick swipe back and
                // forth can reuse the image cache instead of showing a blank
                // placeholder while the same artwork is fetched again.
                for (final adjacent in [index - 1, index + 1]) {
                  if (adjacent < 0 || adjacent >= widget.images.length) {
                    continue;
                  }
                  final adjacentImage = widget.images[adjacent];
                  precacheImage(
                    CachedNetworkImageProvider(
                      adjacentImage.url,
                      headers: widget.headers,
                    ),
                    context,
                  ).catchError((_) {});
                }
              },
              itemBuilder: (context, index) {
                final image = widget.images[index];
                // Keep every page mounted as an image page. CachedNetworkImage
                // reuses its disk/memory cache when the user returns to it.
                return Center(
                  child: InteractiveViewer(
                    key: ValueKey(image.url),
                    minScale: 1,
                    maxScale: 4,
                    child: CachedNetworkImage(
                      imageUrl: image.url,
                      httpHeaders: widget.headers,
                      fit: BoxFit.contain,
                      fadeInDuration: Duration.zero,
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
            if (_loadingAdditionalArtwork)
              Positioned(
                bottom: 14,
                left: 0,
                right: 0,
                child: Center(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.58),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      child: Text(
                        'Memuat artwork AniZip, MyAnimeList & LiveChart…',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
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
