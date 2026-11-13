import 'package:equatable/equatable.dart';

import 'media_detail.dart';

/// One anime episode airing event (from AniList AiringSchedule).
class AiringEntry extends Equatable {
  const AiringEntry({
    required this.malId,
    required this.title,
    this.anilistId,
    required this.coverUrl,
    required this.episode,
    required this.airsAtLocal,
    required this.format,
    this.altTitle,
    this.bannerUrl,
    this.synopsis,
    this.coverColor,
    this.durationMinutes,
    this.score,
    this.popularity,
    this.totalEpisodes,
    this.genres = const [],
    this.status,
    this.isAdult = false,
  });

  final int? malId;
  final int? anilistId;
  final String title;

  /// The other title AniList had (romaji when [title] is the English one).
  ///
  /// Kept because the "My List" filter falls back to matching titles, and a
  /// list entry saved from a source is usually the romaji spelling while
  /// AniList hands back the English one. Null when they're the same.
  final String? altTitle;
  final String? coverUrl;
  /// AniList coverImage.color, used as the poster's loading background.
  final String? coverColor;
  /// Runtime of one episode in minutes, as reported by AniList.
  final int? durationMinutes;
  final int? score;
  final int? popularity;
  final int? totalEpisodes;
  final List<String> genres;
  final MediaStatus? status;
  final bool isAdult;
  final int episode;
  final DateTime airsAtLocal;
  final String format;

  /// Wide 16:9 art (AniList `bannerImage`), for the New&Hot backdrop cards.
  /// Often null — the UI falls back to [coverUrl].
  final String? bannerUrl;

  /// Plain-text synopsis (AniList `description`), or null.
  final String? synopsis;

  @override
  List<Object?> get props =>
      [malId, anilistId, title, altTitle, coverUrl, episode, airsAtLocal,
       format, bannerUrl, synopsis, coverColor, durationMinutes, score,
       popularity, totalEpisodes, genres, status, isAdult];
}

/// One upcoming movie/TV title (from TMDB upcoming / on_the_air).
class ComingSoonEntry extends Equatable {
  const ComingSoonEntry({
    required this.tmdbId,
    required this.isTv,
    required this.title,
    required this.posterUrl,
    required this.releaseDate,
    this.backdropUrl,
    this.synopsis,
    this.episodeLabel,
    this.rank,
  });

  final int tmdbId;
  final bool isTv;
  final String title;
  final String? posterUrl;
  final DateTime? releaseDate;

  /// Wide 16:9 art (TMDB `backdrop_path`); falls back to [posterUrl].
  final String? backdropUrl;

  /// Plain-text synopsis (TMDB `overview`), or null.
  final String? synopsis;

  /// `S2E7` for a dated TV airing, null for a movie release (or a TV entry
  /// from a source that only knows premieres). A per-episode calendar lists
  /// the same series on many days, so without this the rows read as the same
  /// title repeated with nothing to tell them apart.
  final String? episodeLabel;

  /// Simkl's popularity rank — LOWER is more popular (Formula 1 sits at 14,
  /// obscure regional shows in the tens of thousands). Null when the feed has
  /// none, which is most movies. Used only for ordering a day's rows.
  final int? rank;

  @override
  List<Object?> get props => [
    tmdbId, isTv, title, posterUrl, releaseDate, backdropUrl, synopsis,
    episodeLabel, rank,
  ];
}
