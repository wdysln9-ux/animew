// External anime promo and theme data for the AniList-backed detail page.
part of 'detail_screen.dart';

class _AnimeExternalApi {
  static final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 12),
    receiveTimeout: const Duration(seconds: 18),
  ));
  static final Map<String, Future<List<_AnimePromo>>> _promoCache = {};
  static final Map<String, Future<List<_AnimeTheme>>> _themeCache = {};

  static Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return value.map((k, v) => MapEntry(k.toString(), v));
    return <String, dynamic>{};
  }

  static List<dynamic> _list(dynamic value) => value is List ? value : const [];
  static String _str(dynamic value) => value?.toString().trim() ?? '';
  static String _norm(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();

  static Future<int?> _malId(int? id, String title) async {
    if (id != null && id > 0) return id;
    try {
      final response = await _dio.get('https://api.jikan.moe/v4/anime',
          queryParameters: {'q': title, 'limit': 5});
      final rows = _list(_map(response.data)['data']);
      if (rows.isEmpty) return null;
      final wanted = _norm(title);
      final exact = rows.where((raw) {
        final row = _map(raw);
        return [_str(row['title']), _str(row['title_english']), _str(row['title_japanese'])]
            .any((v) => _norm(v) == wanted);
      }).firstOrNull;
      final value = _map(exact ?? rows.first)['mal_id'];
      return value is num ? value.toInt() : int.tryParse('$value');
    } catch (_) {
      return null;
    }
  }

  static Future<List<_AnimePromo>> promos(int? id, String title) {
    final key = id?.toString() ?? _norm(title);
    return _promoCache.putIfAbsent(key, () async {
      final mal = await _malId(id, title);
      if (mal == null) return const [];
      try {
        final response = await _dio.get('https://api.jikan.moe/v4/anime/$mal/videos');
        final data = _map(_map(response.data)['data']);
        final result = <_AnimePromo>[];
        for (final raw in _list(data['promo'])) {
          final row = _map(raw);
          final trailer = _map(row['trailer']);
          final videoId = _str(trailer['youtube_id']);
          if (videoId.isEmpty) continue;
          final jpg = _map(_map(trailer['images'])['jpg']);
          final image = _str(jpg['maximum_image_url']).isNotEmpty
              ? _str(jpg['maximum_image_url']) : _str(jpg['image_url']);
          result.add(_AnimePromo(
            title: _str(row['title']).isEmpty ? 'Video promosi' : _str(row['title']),
            youtubeId: videoId,
            thumbnail: image,
          ));
        }
        return result;
      } catch (_) {
        return const [];
      }
    });
  }

  static Future<List<_AnimeTheme>> themes(int? id, String title) {
    final key = id?.toString() ?? _norm(title);
    return _themeCache.putIfAbsent(key, () async {
      try {
        final response = await _dio.get('https://api.animethemes.moe/anime',
          queryParameters: {
            'q': title,
            'page[limit]': 5,
            'include': 'animethemes.song.artists,animethemes.animethemeentries.videos',
          });
        final root = _map(response.data);
        final candidates = _list(root['anime']).isNotEmpty
            ? _list(root['anime']) : _list(_map(root['search'])['anime']);
        if (candidates.isNotEmpty) {
          final wanted = _norm(title);
          final anime = _map(candidates.where((raw) =>
              _norm(_str(_map(raw)['name'])) == wanted).firstOrNull ?? candidates.first);
          final parsed = <_AnimeTheme>[];
          for (final raw in _list(anime['animethemes'])) {
            final theme = _map(raw);
            final song = _map(theme['song']);
            final songTitle = _str(song['title']);
            final artists = _list(song['artists']).map((a) => _str(_map(a)['name']))
                .where((v) => v.isNotEmpty).toList();
            String? videoUrl;
            for (final entry in _list(theme['animethemeentries'])) {
              final videos = _list(_map(entry)['videos']);
              if (videos.isEmpty) continue;
              final video = _map(videos.first);
              final link = _str(video['link']).isNotEmpty ? _str(video['link']) : _str(video['url']);
              if (link.startsWith('https://')) { videoUrl = link; break; }
            }
            final kind = _str(theme['type']).toUpperCase();
            final rawSequence = theme['sequence'];
            final sequence = rawSequence is num ? rawSequence.toInt() : int.tryParse('$rawSequence') ?? 1;
            if ((kind == 'OP' || kind == 'ED') && songTitle.isNotEmpty) {
              parsed.add(_AnimeTheme(kind: kind, sequence: sequence,
                  title: songTitle, artists: artists, videoUrl: videoUrl));
            }
          }
          if (parsed.isNotEmpty) {
            parsed.sort((a, b) {
              final byType = a.kind.compareTo(b.kind);
              return byType != 0 ? byType : a.sequence.compareTo(b.sequence);
            });
            return parsed;
          }
        }
      } catch (_) {}
      return _jikanThemes(id, title);
    });
  }

  static Future<List<_AnimeTheme>> _jikanThemes(int? id, String title) async {
    final mal = await _malId(id, title);
    if (mal == null) return const [];
    try {
      final response = await _dio.get('https://api.jikan.moe/v4/anime/$mal/themes');
      final data = _map(_map(response.data)['data']);
      final result = <_AnimeTheme>[];
      for (final group in [('OP', _list(data['openings'])), ('ED', _list(data['endings']))]) {
        for (var i = 0; i < group.$2.length; i++) {
          final value = _str(group.$2[i]);
          if (value.isNotEmpty) {
            result.add(_AnimeTheme(kind: group.$1, sequence: i + 1,
                title: value, artists: const []));
          }
        }
      }
      return result;
    } catch (_) {
      return const [];
    }
  }
}

class _AnimePromo {
  const _AnimePromo({required this.title, required this.youtubeId, required this.thumbnail});
  final String title;
  final String youtubeId;
  final String thumbnail;
}

class _AnimeTheme {
  const _AnimeTheme({required this.kind, required this.sequence,
    required this.title, required this.artists, this.videoUrl});
  final String kind;
  final int sequence;
  final String title;
  final List<String> artists;
  final String? videoUrl;
}

class _ExternalTrailerSection extends StatefulWidget {
  const _ExternalTrailerSection({required this.malId, required this.title});
  final int? malId;
  final String title;
  @override
  State<_ExternalTrailerSection> createState() => _ExternalTrailerSectionState();
}

class _ExternalTrailerSectionState extends State<_ExternalTrailerSection> {
  late bool _expanded = sl<PlaybackPrefs>().detailSectionExpanded('trailer');
  Future<List<_AnimePromo>>? _future;

  void _toggle() {
    setState(() {
      _expanded = !_expanded;
      if (_expanded) _future ??= _AnimeExternalApi.promos(widget.malId, widget.title);
      unawaited(sl<PlaybackPrefs>().setDetailSectionExpanded('trailer', _expanded));
    });
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
    child: AnimatedSize(
      duration: const Duration(milliseconds: 240), curve: Curves.easeInOutCubic,
      alignment: Alignment.topCenter,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque, onTap: _toggle,
          child: Row(children: [
            Text('Trailer & PV', style: AppText.headline.copyWith(fontSize: 16)),
            const Spacer(),
            AnimatedRotation(turns: _expanded ? 0.25 : 0,
              duration: const Duration(milliseconds: 220),
              child: Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary, size: 21)),
          ]),
        ),
        if (_expanded) ...[
          const SizedBox(height: 9),
          FutureBuilder<List<_AnimePromo>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Padding(padding: EdgeInsets.symmetric(vertical: 14),
                  child: Center(child: SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 1.8))));
              }
              final rows = snapshot.data ?? const [];
              if (rows.isEmpty) return Text('Belum ada trailer atau PV yang tersedia.',
                style: AppText.caption.copyWith(color: AppColors.textSecondary));
              return SizedBox(height: 142, child: ListView.separated(
                scrollDirection: Axis.horizontal, padding: EdgeInsets.zero,
                itemCount: rows.length, separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final promo = rows[index];
                  return SizedBox(width: 190, child: GestureDetector(
                    onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => TrailerScreen(videoId: promo.youtubeId))),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      ClipRRect(borderRadius: BorderRadius.circular(10),
                        child: AspectRatio(aspectRatio: 16 / 9,
                          child: Stack(fit: StackFit.expand, children: [
                            if (promo.thumbnail.isNotEmpty)
                              CachedNetworkImage(imageUrl: promo.thumbnail, fit: BoxFit.cover,
                                errorWidget: (_, _, _) => ColoredBox(color: AppColors.surface2))
                            else
                              ColoredBox(color: AppColors.surface2),
                            const Center(child: Icon(Icons.play_circle_fill_rounded,
                              color: Colors.white, size: 36)),
                          ]))),
                      const SizedBox(height: 6),
                      Text(promo.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: AppText.caption.copyWith(color: AppColors.textPrimary)),
                    ]),
                  ));
                },
              ));
            },
          ),
        ],
      ]),
    ),
  );
}

class _AnimeMusicSection extends StatefulWidget {
  const _AnimeMusicSection({required this.malId, required this.title});
  final int? malId;
  final String title;
  @override
  State<_AnimeMusicSection> createState() => _AnimeMusicSectionState();
}

class _AnimeMusicSectionState extends State<_AnimeMusicSection> {
  late bool _expanded = sl<PlaybackPrefs>().detailSectionExpanded('music');
  Future<List<_AnimeTheme>>? _future;

  void _toggle() {
    setState(() {
      _expanded = !_expanded;
      if (_expanded) _future ??= _AnimeExternalApi.themes(widget.malId, widget.title);
      unawaited(sl<PlaybackPrefs>().setDetailSectionExpanded('music', _expanded));
    });
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
    child: AnimatedSize(
      duration: const Duration(milliseconds: 240), curve: Curves.easeInOutCubic,
      alignment: Alignment.topCenter,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque, onTap: _toggle,
          child: Row(children: [
            Text('Musik', style: AppText.headline.copyWith(fontSize: 16)),
            const Spacer(),
            AnimatedRotation(turns: _expanded ? 0.25 : 0,
              duration: const Duration(milliseconds: 220),
              child: Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary, size: 21)),
          ]),
        ),
        if (_expanded) ...[
          const SizedBox(height: 9),
          FutureBuilder<List<_AnimeTheme>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Padding(padding: EdgeInsets.symmetric(vertical: 14),
                  child: Center(child: SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 1.8))));
              }
              final rows = snapshot.data ?? const [];
              if (rows.isEmpty) return Text('Data OP/ED belum tersedia untuk anime ini.',
                style: AppText.caption.copyWith(color: AppColors.textSecondary));
              return Column(children: [
                for (final theme in rows)
                  Padding(padding: const EdgeInsets.only(bottom: 10),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                      Container(width: 43, height: 43, alignment: Alignment.center,
                        decoration: BoxDecoration(color: AppColors.surface2,
                          borderRadius: BorderRadius.circular(9)),
                        child: Text(theme.kind + '\n' + theme.sequence.toString(),
                          textAlign: TextAlign.center,
                          style: AppText.caption.copyWith(color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700, fontSize: 11))),
                      const SizedBox(width: 10),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(theme.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                          style: AppText.caption.copyWith(color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600)),
                        if (theme.artists.isNotEmpty)
                          Text(theme.artists.join(', '), maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: AppText.caption.copyWith(color: AppColors.textSecondary, fontSize: 11)),
                      ])),
                      if (theme.videoUrl != null)
                        IconButton(tooltip: 'Buka video musik', visualDensity: VisualDensity.compact,
                          onPressed: () => launchUrl(Uri.parse(theme.videoUrl!),
                            mode: LaunchMode.externalApplication),
                          icon: Icon(Icons.play_circle_outline_rounded, color: AppColors.textSecondary)),
                    ])),
                Text('Sumber ini terutama menyediakan opening dan ending; OST album atau insert song belum tentu tercatat.',
                  style: AppText.caption.copyWith(color: AppColors.textSecondary, fontSize: 10.5)),
              ]);
            },
          ),
        ],
      ]),
    ),
  );
}
