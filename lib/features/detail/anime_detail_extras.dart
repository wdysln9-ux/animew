// External anime promo and theme data for the AniList-backed detail page.
part of 'detail_screen.dart';

class _AnimeExternalApi {
  static final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
    sendTimeout: const Duration(seconds: 10),
    headers: const {'Accept': 'application/json'},
  ));
  static const _anilist = 'https://graphql.anilist.co';
  static const _themes = 'https://graphql.animethemes.moe/';
  static const _jikan = 'https://api.jikan.moe/v4';
  static final Map<int, Future<int?>> _malIds = {};
  static final Map<String, Future<List<_AnimePromo>>> _promoCache = {};
  static final Map<int, Future<List<_AnimeTheme>>> _themeCache = {};

  static Map<String, dynamic> _map(dynamic value) => value is Map
      ? value.map((k, v) => MapEntry(k.toString(), v))
      : <String, dynamic>{};
  static List<dynamic> _list(dynamic value) => value is List ? value : const [];
  static String _str(dynamic value) => value?.toString().trim() ?? '';

  static Future<int?> _resolveMalId(int? anilistId, int? suppliedMalId) {
    if (suppliedMalId != null && suppliedMalId > 0) {
      return Future.value(suppliedMalId);
    }
    if (anilistId == null || anilistId <= 0) return Future.value(null);
    return _malIds.putIfAbsent(anilistId, () async {
      try {
        const query = r'query($id:Int!){Media(id:$id,type:ANIME){idMal}}';
        final response = await _dio.post(_anilist, data: {
          'query': query,
          'variables': {'id': anilistId},
        });
        final media = _map(_map(response.data)['data'])['Media'];
        final value = _map(media)['idMal'];
        return value is num ? value.toInt() : int.tryParse(_str(value));
      } catch (_) {
        _malIds.remove(anilistId);
        return null;
      }
    });
  }

  static Future<List<_AnimePromo>> promos(int? anilistId, int? malId) async {
    final key = 'a:${anilistId ?? 0}:m:${malId ?? 0}';
    return _promoCache.putIfAbsent(key, () async {
      final mal = await _resolveMalId(anilistId, malId);
      if (mal == null) return const [];
      try {
        final payload = await JikanApi.get(_dio, '$_jikan/anime/$mal/videos');
        final data = _map(_map(payload)['data']);
        final result = <_AnimePromo>[];
        for (final raw in [..._list(data['promo']), ..._list(data['music_videos'])]) {
          final row = _map(raw);
          final trailer = _map(row['trailer']);
          final videoId = _str(trailer['youtube_id']);
          if (videoId.isEmpty) continue;
          final jpg = _map(_map(trailer['images'])['jpg']);
          final image = _str(jpg['maximum_image_url']).isNotEmpty
              ? _str(jpg['maximum_image_url'])
              : _str(jpg['large_image_url']).isNotEmpty
                  ? _str(jpg['large_image_url'])
                  : 'https://img.youtube.com/vi/$videoId/hqdefault.jpg';
          result.add(_AnimePromo(
            title: _str(row['title']).isEmpty ? 'Video promosi' : _str(row['title']),
            youtubeId: videoId,
            thumbnail: image,
          ));
        }
        return result;
      } catch (_) {
        _promoCache.remove(key);
        return const [];
      }
    });
  }

  static Future<List<_AnimeTheme>> themes(int? anilistId, int? malId) async {
    if (anilistId == null || anilistId <= 0) return const [];
    return _themeCache.putIfAbsent(anilistId, () async {
      try {
        const query = r'''
          query($id:[Int!]) {
            findAnimeByExternalSite(site:ANILIST,id:$id) {
              slug resources(site:ANILIST){nodes{externalId}}
              animethemes {
                type sequence
                song { title { romaji } performances { alias artist { name { main } } } }
                animethemeentries { videos { nodes { link resolution } } }
              }
            }
          }
        ''';
        final response = await _dio.post(_themes, data: {
          'query': query,
          'variables': {'id': [anilistId]},
        });
        final root = _map(response.data);
        if (_list(root['errors']).isNotEmpty) throw StateError('AnimeThemes GraphQL error');
        final animeRows = _list(_map(root['data'])['findAnimeByExternalSite']);
        final result = <_AnimeTheme>[];
        for (final rawAnime in animeRows) {
          final anime = _map(rawAnime);
          final ids = _list(_map(anime['resources'])['nodes'])
              .map((e) => _map(e)['externalId']).whereType<num>().map((e) => e.toInt());
          if (!ids.contains(anilistId)) continue;
          for (final rawTheme in _list(anime['animethemes'])) {
            final theme = _map(rawTheme);
            final kind = _str(theme['type']).toUpperCase();
            if (kind != 'OP' && kind != 'ED' && kind != 'IN') continue;
            final song = _map(theme['song']);
            final songTitle = _str(_map(song['title'])['romaji']);
            if (songTitle.isEmpty) continue;
            final artists = _list(song['performances']).map((p) {
              final performance = _map(p);
              return _str(performance['alias']).isNotEmpty
                  ? _str(performance['alias'])
                  : _str(_map(_map(performance['artist'])['name'])['main']);
            }).where((v) => v.isNotEmpty).toList();
            String? videoUrl;
            for (final entry in _list(theme['animethemeentries'])) {
              final videos = _list(_map(entry)['videos'] is Map
                  ? _map(_map(entry)['videos'])['nodes']
                  : null);
              if (videos.isEmpty) continue;
              final link = _str(_map(videos.first)['link']);
              if (link.startsWith('https://')) { videoUrl = link; break; }
            }
            final sequenceValue = theme['sequence'];
            final sequence = sequenceValue is num ? sequenceValue.toInt() : int.tryParse(_str(sequenceValue)) ?? 1;
            result.add(_AnimeTheme(kind: kind, sequence: sequence,
                title: songTitle, artists: artists, videoUrl: videoUrl));
          }
        }
        result.sort((a, b) {
          final type = a.kind.compareTo(b.kind);
          return type != 0 ? type : a.sequence.compareTo(b.sequence);
        });
        return result;
      } catch (_) {
        _themeCache.remove(anilistId);
        return const [];
      }
    });
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
  const _ExternalTrailerSection({required this.anilistId, required this.malId, required this.title});
  final int? anilistId;
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
      if (_expanded) _future ??= _AnimeExternalApi.promos(widget.anilistId, widget.malId);
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
  const _AnimeMusicSection({required this.anilistId, required this.malId, required this.title});
  final int? anilistId;
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
      if (_expanded) _future ??= _AnimeExternalApi.themes(widget.anilistId, widget.malId);
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
