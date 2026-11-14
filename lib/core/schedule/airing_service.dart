import 'package:dio/dio.dart';

import '../anilist/anilist_graphql.dart';
import '../models/media_item.dart' show normalizeTitle;
import '../models/media_detail.dart' show MediaStatus;
import '../error/network_failure.dart';
import 'schedule_models.dart';

const String _kAniListEndpoint = AniListGraphql.endpoint;

/// UTC-epoch-seconds window: local midnight yesterday .. +7 days.
({int startSec, int endSec}) weekWindowUtc(DateTime nowLocal) {
  final today = DateTime(nowLocal.year, nowLocal.month, nowLocal.day);
  final startLocal = today.subtract(const Duration(days: 1));
  final endLocal = today.add(const Duration(days: 7));
  return (
    startSec: startLocal.toUtc().millisecondsSinceEpoch ~/ 1000,
    endSec: endLocal.toUtc().millisecondsSinceEpoch ~/ 1000,
  );
}

/// Maps `data['Page']['airingSchedules']` → entries (SFW, valid media only).
List<AiringEntry> parseAiringSchedules(Map<String, dynamic> data) {
  final page = data['Page'];
  final list = (page is Map) ? page['airingSchedules'] : null;
  if (list is! List) return const [];
  final out = <AiringEntry>[];
  for (final raw in list) {
    if (raw is! Map) continue;
    final media = raw['media'];
    if (media is! Map) continue;
    if (media['isAdult'] == true) continue;
    final format = (media['format'] as String?) ?? '';
    final titleMap = media['title'];
    final english = (titleMap is Map) ? titleMap['english'] as String? : null;
    final romaji = (titleMap is Map) ? titleMap['romaji'] as String? : null;
    // Home's Anime Tayang cards follow the app's Romaji title preference.
    // Keep English as the alternate title for matching and other fallbacks.
    final title = (romaji != null && romaji.isNotEmpty)
        ? romaji
        : (english ?? '');
    if (title.isEmpty) continue;
    final airingAt = raw['airingAt'];
    if (airingAt is! int) continue;
    final coverImage = media['coverImage'];
    final cover = coverImage is Map ? coverImage['large'] as String? : null;
    final coverColor = coverImage is Map ? coverImage['color'] as String? : null;
    final alt = (english != null && english.isNotEmpty && title != english)
        ? english
        : null;
    out.add(AiringEntry(
      altTitle: alt,
      malId: media['idMal'] as int?,
      anilistId: media['id'] as int?,
      title: title,
      coverUrl: cover,
      coverColor: coverColor,
      durationMinutes: (media['duration'] as num?)?.toInt(),
      episode: (raw['episode'] as int?) ?? 0,
      airsAtLocal:
          DateTime.fromMillisecondsSinceEpoch(airingAt * 1000).toLocal(),
      format: format,
      score: (media['averageScore'] as num?)?.toInt(),
      popularity: (media['popularity'] as num?)?.toInt(),
      totalEpisodes: (media['episodes'] as num?)?.toInt(),
      genres: [for (final g in (media['genres'] as List? ?? const [])) '$g'],
      status: switch (media['status']) {
        'RELEASING' => MediaStatus.ongoing,
        'FINISHED' => MediaStatus.completed,
        'HIATUS' => MediaStatus.hiatus,
        'CANCELLED' => MediaStatus.cancelled,
        _ => MediaStatus.unknown,
      },
      isAdult: media['isAdult'] == true,
      bannerUrl: media['bannerImage'] as String?,
      synopsis: _cleanDescription(media['description'] as String?),
    ));
  }
  return out;
}

/// AniList descriptions carry lightweight HTML (`<br>`, `<i>`, `<b>`). Strip
/// tags + collapse whitespace so it fits a two-line card synopsis. Null/empty → null.
String? _cleanDescription(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  final text = raw
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), ' ')
      .replaceAll(RegExp(r'<[^>]+>'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return text.isEmpty ? null : text;
}

/// Orders the Home "Anime Tayang" feed by the most recently released
/// episode first. Airings that have already happened are descending by time;
/// upcoming episodes follow in chronological order (nearest first).
List<AiringEntry> sortHomeAiringsByLatestRelease(
  List<AiringEntry> entries, {
  DateTime? now,
}) {
  final current = now ?? DateTime.now();
  // Home's "Anime Tayang" row is a list of episodes that have ALREADY
  // aired for series that are still RELEASING. The schedule window starts
  // yesterday, so yesterday's releases remain visible; future episodes and
  // FINISHED/NOT_YET_RELEASED titles do not belong in this row.
  // These presentation filters stay local to Home; the calendar keeps its
  // broader schedule, including TV_SHORT and short ONA.
  final sorted = entries.where((entry) {
    if (entry.status != MediaStatus.ongoing) return false;
    if (entry.airsAtLocal.isAfter(current)) return false;
    if (entry.format == 'TV_SHORT') return false;
    if (entry.format == 'ONA' &&
        entry.durationMinutes != null &&
        entry.durationMinutes! < 10) return false;
    return true;
  }).toList();
  sorted.sort((a, b) {
    final aReleased = !a.airsAtLocal.isAfter(current);
    final bReleased = !b.airsAtLocal.isAfter(current);
    if (aReleased != bReleased) return aReleased ? -1 : 1;
    return aReleased
        ? b.airsAtLocal.compareTo(a.airsAtLocal)
        : a.airsAtLocal.compareTo(b.airsAtLocal);
  });
  return sorted;
}

/// Groups entries by their local calendar day, each day's list time-sorted.
Map<DateTime, List<AiringEntry>> groupByLocalDay(List<AiringEntry> entries) {
  final map = <DateTime, List<AiringEntry>>{};
  for (final e in entries) {
    final day =
        DateTime(e.airsAtLocal.year, e.airsAtLocal.month, e.airsAtLocal.day);
    (map[day] ??= []).add(e);
  }
  for (final list in map.values) {
    list.sort((a, b) => a.airsAtLocal.compareTo(b.airsAtLocal));
  }
  return map;
}

List<AiringEntry> filterByMalIds(List<AiringEntry> entries, Set<int> malIds) =>
    entries.where((e) => e.malId != null && malIds.contains(e.malId)).toList();

/// The shows the "My List" filter should keep.
///
/// MAL ids alone were not enough. A list entry only carries a malId once
/// metadata enrichment has run, and an item added straight from a source
/// usually has none — so the set came out empty, nothing matched, and the
/// schedule claimed you follow nothing while the very same show sat in the
/// unfiltered list. (Verified against BLACK TORCH: AniList publishes
/// `idMal: 61169` for it, so the airing side was fine; the list side had no
/// id to match with.)
///
/// Titles are the fallback, normalized so case and punctuation can't break it.
class FollowedShows {
  const FollowedShows({this.malIds = const {}, this.titles = const {}});

  final Set<int> malIds;

  /// Already normalized via [normalizeTitle].
  final Set<String> titles;

  bool get isEmpty => malIds.isEmpty && titles.isEmpty;

  bool matches(AiringEntry e) {
    if (e.malId != null && malIds.contains(e.malId)) return true;
    if (titles.isEmpty) return false;
    if (titles.contains(normalizeTitle(e.title))) return true;
    final alt = e.altTitle;
    return alt != null && titles.contains(normalizeTitle(alt));
  }
}

List<AiringEntry> filterByFollowed(
  List<AiringEntry> entries,
  FollowedShows followed,
) =>
    entries.where(followed.matches).toList();

/// Fetches yesterday through the next six days of anime airing schedules from AniList (public, no auth).
class AiringService {
  AiringService(this._dio);
  final Dio _dio;

  static const String _query = r'''
query ($start: Int, $end: Int, $page: Int) {
  Page(page: $page, perPage: 50) {
    pageInfo { hasNextPage }
    airingSchedules(airingAt_greater: $start, airingAt_lesser: $end, sort: TIME) {
      episode
      airingAt
      media {
        id
        idMal
        title { romaji english }
        coverImage { large color }
        duration
        bannerImage
        description(asHtml: false)
        format
        averageScore
        popularity
        episodes
        status
        genres
        isAdult
      }
    }
  }
}''';

  /// Returns every SFW airing event from yesterday through the next 6 days, or `[]` on any error.
  /// Whether the LAST attempt failed because nothing could reach the network.
  ///
  /// This service returns `[]` for every failure so a bad response never
  /// breaks the screen — which also means the caller cannot tell "offline"
  /// from "genuinely nothing scheduled". Reset at the start of each attempt
  /// and read straight after, so the two can be told apart without changing
  /// the return type everything already depends on.
  bool lastFailureOffline = false;

  Future<List<AiringEntry>> weekAiring({DateTime? now}) {
    lastFailureOffline = false;
    final win = weekWindowUtc(now ?? DateTime.now());
    return _fetchRange(win.startSec, win.endSec, maxPages: 10);
  }

  /// Paginated AniList airingSchedules fetch for a UTC-epoch-seconds window.
  /// Fetches page 1 first (so an empty or single-page window bails cheaply),
  /// then the remaining pages in one parallel batch. AniList reports
  /// hasNextPage against a capped total, so the old page-by-page loop never
  /// broke early and always ran the full [maxPages] one after another — the
  /// parallel batch collapses that to ~2 round-trips instead of [maxPages].
  /// Never throws — returns `[]` on any error.
  Future<List<AiringEntry>> _fetchRange(
    int startSec,
    int endSec, {
    required int maxPages,
  }) async {
    try {
      final first = await _fetchPage(startSec, endSec, 1);
      if (maxPages <= 1 || !first.hasNext) return first.entries;
      final rest = await Future.wait([
        for (var page = 2; page <= maxPages; page++)
          _fetchPage(startSec, endSec, page),
      ]);
      return [
        ...first.entries,
        for (final r in rest) ...r.entries,
      ];
    } catch (e) {
      lastFailureOffline = await isOfflineErrorConfirmed(e);
      return const [];
    }
  }

  /// One AniList page → its entries plus whether AniList claims more pages.
  Future<({List<AiringEntry> entries, bool hasNext})> _fetchPage(
    int startSec,
    int endSec,
    int page,
  ) async {
    final res = await _dio.post<dynamic>(
      _kAniListEndpoint,
      data: {
        'query': _query,
        'variables': {'start': startSec, 'end': endSec, 'page': page},
      },
      options: Options(
        headers: AniListGraphql.headers,
        validateStatus: (s) => s != null && s < 500,
      ),
    );
    final data = res.data;
    final root = (data is Map && data['data'] is Map)
        ? Map<String, dynamic>.from(data['data'] as Map)
        : const <String, dynamic>{};
    final page0 = root['Page'];
    final hasNext = (page0 is Map && page0['pageInfo'] is Map)
        ? page0['pageInfo']['hasNextPage'] == true
        : false;
    return (entries: parseAiringSchedules(root), hasNext: hasNext);
  }
}
