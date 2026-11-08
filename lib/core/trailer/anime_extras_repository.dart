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
  });

  final int malId;
  final List<AnimeExtraVideo> videos;
  final List<String> openings;
  final List<String> endings;

  bool get isEmpty => videos.isEmpty && openings.isEmpty && endings.isEmpty;
}

/// Independent AniList -> MAL -> Jikan enrichment pipeline for the anime page.
/// AniList remains the catalogue identity; MAL/Jikan are used only for extras.
class AnimeExtrasRepository {
  AnimeExtrasRepository._();

  static final AnimeExtrasRepository instance = AnimeExtrasRepository._();

  static const _aniList = 'https://graphql.anilist.co';
  static const _jikan = 'https://api.jikan.moe/v4';
  static const _query = r'''
query ($id: Int, $search: String) {
  Media(id: $id, search: $search, type: ANIME) {
    idMal
    title { romaji english }
  }
}
''';

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 12),
    receiveTimeout: const Duration(seconds: 12),
    sendTimeout: const Duration(seconds: 12),
    headers: const {'Accept': 'application/json'},
  ));

  final Map<int, Future<AnimeExtras>> _cache = {};
  final Map<String, Future<int?>> _idCache = {};

  Future<AnimeExtras> load({
    int? malId,
    int? anilistId,
    required String title,
    String? englishTitle,
  }) async {
    final resolvedId = malId ?? await _resolveMalId(
      anilistId: anilistId,
      title: title,
      englishTitle: englishTitle,
    );
    if (resolvedId == null || resolvedId <= 0) {
      throw StateError('MAL ID untuk anime ini belum ditemukan.');
    }
    return _cache.putIfAbsent(resolvedId, () => _fetch(resolvedId));
  }

  Future<int?> _resolveMalId({
    int? anilistId,
    required String title,
    String? englishTitle,
  }) {
    final key = anilistId != null
        ? 'anilist:$anilistId'
        : 'title:${(englishTitle?.trim().isNotEmpty == true ? englishTitle : title).toLowerCase()}';
    return _idCache.putIfAbsent(key, () async {
      final search = (englishTitle?.trim().isNotEmpty == true
              ? englishTitle
              : title)
          ?.trim();
      try {
        final response = await _dio.post<dynamic>(
          _aniList,
          data: {
            'query': _query,
            'variables': {
              'id': anilistId,
              'search': anilistId == null ? search : null,
            },
          },
        );
        final root = _map(response.data);
        final media = _map(_map(root?['data'])?['Media']);
        final value = media?['idMal'];
        return value is int ? value : int.tryParse(value?.toString() ?? '');
      } catch (_) {
        _idCache.remove(key);
        rethrow;
      }
    });
  }

  Future<AnimeExtras> _fetch(int malId) async {
    // Jikan applies a strict request rate limit. Keep the two endpoints
    // sequential and retry a transient 429/5xx once instead of silently hiding
    // both sections.
    final videosResponse = await _getWithRetry('$_jikan/anime/$malId/videos');
    await Future<void>.delayed(const Duration(milliseconds: 450));
    final themesResponse = await _getWithRetry('$_jikan/anime/$malId/themes');

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
        imageUrl: image,
      ));
    }

    final themesRoot = _map(themesResponse);
    final themesData = _map(themesRoot?['data']);
    List<String> readSongs(String key) => (_list(themesData?[key]) ?? const [])
        .map((value) => value.toString().trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);

    final result = AnimeExtras(
      malId: malId,
      videos: List.unmodifiable(videos),
      openings: readSongs('openings'),
      endings: readSongs('endings'),
    );
    return result;
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
