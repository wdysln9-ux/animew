import 'dart:async';

import 'package:dio/dio.dart';

class AnimeExtraVideo {
  const AnimeExtraVideo({
    required this.title,
    required this.youtubeId,
    this.imageUrl,
  });

  final String title;
  final String youtubeId;
  final String? imageUrl;
}

class AnimeExtras {
  const AnimeExtras({
    required this.malId,
    this.videos = const [],
    this.openings = const [],
    this.endings = const [],
    this.videoError,
    this.themeError,
  });

  final int malId;
  final List<AnimeExtraVideo> videos;
  final List<String> openings;
  final List<String> endings;
  final String? videoError;
  final String? themeError;

  bool get isEmpty => videos.isEmpty && openings.isEmpty && endings.isEmpty;
}

/// MAL/Jikan supplementary data for the anime page. AniList is not queried here.
class AnimeExtrasRepository {
  AnimeExtrasRepository._();

  static final AnimeExtrasRepository instance = AnimeExtrasRepository._();

  static const _jikan = 'https://api.jikan.moe/v4';

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 12),
    receiveTimeout: const Duration(seconds: 12),
    sendTimeout: const Duration(seconds: 12),
    headers: const {'Accept': 'application/json'},
  ));

  final Map<int, Future<AnimeExtras>> _cache = {};

  Future<AnimeExtras> load({
    int? malId,
    int? anilistId,
    required String title,
    String? englishTitle,
    bool forceRefresh = false,
  }) async {
    final resolvedId = malId ??
        await _searchJikanId(englishTitle?.trim().isNotEmpty == true
            ? englishTitle!.trim()
            : title.trim());
    if (resolvedId == null || resolvedId <= 0) {
      throw StateError('Data tambahan MAL belum bisa ditemukan.');
    }
    if (forceRefresh) _cache.remove(resolvedId);
    final existing = _cache[resolvedId];
    if (existing != null) return existing;
    final request = () async {
      final primary = await _fetch(resolvedId);
      if (primary.isEmpty) {
        final fallbackId = await _searchJikanId(
          englishTitle?.trim().isNotEmpty == true
              ? englishTitle!.trim()
              : title,
        );
        if (fallbackId != null && fallbackId > 0 && fallbackId != resolvedId) {
          final fallback = await _fetch(fallbackId);
          if (!fallback.isEmpty) return fallback;
        }
      }
      return primary;
    }();
    _cache[resolvedId] = request;
    try {
      return await request;
    } catch (_) {
      _cache.remove(resolvedId);
      rethrow;
    }
  }

  Future<int?> _searchJikanId(String title) async {
    final response = await _dio.get<dynamic>(
      '$_jikan/anime',
      queryParameters: {'q': title, 'limit': 10},
    );
    final root = _map(response.data);
    final entries = _list(root?['data']) ?? const [];
    String normalize(String value) =>
        value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final wanted = normalize(title);

    for (final raw in entries) {
      final entry = _map(raw);
      if (entry == null) continue;
      final candidates = <String>[
        entry['title']?.toString() ?? '',
        entry['title_english']?.toString() ?? '',
        entry['title_japanese']?.toString() ?? '',
        ...(_list(entry['title_synonyms']) ?? const []).map((e) => e.toString()),
      ];
      if (candidates.any((candidate) => normalize(candidate) == wanted)) {
        final id = entry['mal_id'];
        return id is int ? id : int.tryParse(id?.toString() ?? '');
      }
    }
    return null;
  }

  Future<AnimeExtras> _fetch(int malId) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    dynamic videosResponse;
    dynamic themesResponse;
    String? videoError;
    String? themeError;

    try {
      videosResponse = await _getWithRetry('$_jikan/anime/$malId/videos');
    } catch (error) {
      videoError = error.toString();
    }

    // Respect Jikan's request pacing even when the first endpoint failed.
    await Future<void>.delayed(const Duration(milliseconds: 500));

    try {
      themesResponse = await _getWithRetry('$_jikan/anime/$malId/themes');
    } catch (error) {
      themeError = error.toString();
    }

    final videosRoot = _map(videosResponse);
    final videoData = _map(videosRoot?['data']);
    final promo = _list(videoData?['promo']) ?? const [];
    final musicVideos = _list(videoData?['music_videos']) ?? const [];
    final videos = <AnimeExtraVideo>[];

    for (final raw in [...promo, ...musicVideos]) {
      final entry = _map(raw);
      final trailer = _map(entry?['trailer']);
      final id = trailer?['youtube_id']?.toString();
      if (id == null || id.isEmpty) continue;
      final images = _map(trailer?['images']);
      final jpg = _map(images?['jpg']);
      final image = (jpg?['maximum_image_url'] ??
              jpg?['large_image_url'] ??
              jpg?['image_url'])
          ?.toString();
      videos.add(AnimeExtraVideo(
        title: entry?['title']?.toString().trim().isNotEmpty == true
            ? entry!['title'].toString().trim()
            : 'Trailer / PV',
        youtubeId: id,
        imageUrl: image ?? 'https://img.youtube.com/vi/$id/hqdefault.jpg',
      ));
    }

    final themesRoot = _map(themesResponse);
    final themesData = _map(themesRoot?['data']);
    List<String> readSongs(String key) => (_list(themesData?[key]) ?? const [])
        .map((value) => value.toString().trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);

    return AnimeExtras(
      malId: malId,
      videos: List.unmodifiable(videos),
      openings: readSongs('openings'),
      endings: readSongs('endings'),
      videoError: videoError,
      themeError: themeError,
    );
  }

  Future<dynamic> _getWithRetry(String url) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final response = await _dio.get<dynamic>(url);
        return response.data;
      } on DioException catch (error) {
        final status = error.response?.statusCode;
        final retryable = status == 429 || (status != null && status >= 500);
        if (attempt == 0 && retryable) {
          await Future<void>.delayed(const Duration(milliseconds: 1400));
          continue;
        }
        rethrow;
      }
    }
    throw StateError('Jikan tidak merespons.');
  }

  static Map<String, dynamic>? _map(dynamic value) => value is Map
      ? Map<String, dynamic>.from(value)
      : null;

  static List<dynamic>? _list(dynamic value) =>
      value is List ? value : null;
}
