import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/anilist/anilist_service.dart';
import '../../core/di/injector.dart';
import '../../core/models/home_section.dart';
import '../../core/models/media_item.dart';
import '../../core/playback/watch_history.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/zmode/metadata_filters.dart';
import '../../core/zmode/metadata_repository.dart';
import '../detail/detail_screen.dart';
import 'search_screen.dart';
import 'genres_screen.dart';
import '../studio/studio_page.dart';
import '../../core/ui/poster_card.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});
  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  List<HomeSection> _rows = const [];
  List<String> _genres = const [];
  List<HistoryEntry> _history = const [];
  List<MediaItem> _becauseCarousel = const [];
  List<MediaItem> _becauseList = const [];
  Map<int, int> _becauseRatings = const {};
  bool _becauseLoading = false;
  String _selected = 'Untukmu';
  int _heroIndex = 0;
  Map<String, int> _viewerGenreCounts = const {};
  bool _viewerGenreStatsLoaded = false;
  final PageController _heroController = PageController(viewportFraction: .96);
  final PageController _recommendationController = PageController(viewportFraction: .34);

  @override
  void initState() { super.initState(); _load(); }
  @override
  void dispose() { _heroController.dispose(); _recommendationController.dispose(); super.dispose(); }

  Future<void> _load() async {
    try {
      final rows = await sl<MetadataRepository>().home();
      final all = rows.expand((r) => r.items).where((m) => !m.isAdult);
      final genres = <String>{for (final m in all) ...m.genres};
      final history = sl.isRegistered<WatchHistory>()
          ? sl<WatchHistory>().all().take(30).toList() : <HistoryEntry>[];
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _genres = genres.where((g) => g.toLowerCase() != 'hentai').toList()..sort();
        _history = history;
      });
      _loadViewerGenreStats();
      _loadBecauseRecommendations();
    } catch (_) {}
  }

  Future<void> _loadBecauseRecommendations() async {
    if (_becauseLoading || _history.isEmpty) return;
    _becauseLoading = true;
    try {
      final watched = _history.first;
      final match = _all.where((m) =>
        (watched.malId != null && m.malId == watched.malId) ||
        m.title.toLowerCase() == watched.showTitle.toLowerCase()
      ).firstOrNull;
      var anilistId = match?.anilistId;
      if (anilistId == null && watched.malId != null) {
        final resolved = await sl<AniListService>().api.mediaByMalId(watched.malId!);
        anilistId = resolved?.id;
      }
      if (anilistId == null) return;
      final api = sl<AniListService>().api;
      final items = <MediaItem>[];
      final seen = <int>{};
      final ratings = <int, int>{};
      var page = 1;
      var hasNextPage = true;
      while (items.length < 15 && hasNextPage) {
        final result = await api.mediaRecommendations(anilistId, page: page);
        for (final r in result.recommendations) {
          if (r.isReading || r.isAdult || r.anilistId == null || !seen.add(r.anilistId!)) continue;
          ratings[r.anilistId!] = r.recommendationRating ?? 0;
          items.add(MediaItem(
            id: 'anilist:${r.anilistId}',
            title: r.title,
            englishTitle: r.romaji,
            cover: r.cover,
            coverColor: r.coverColor,
            url: 'https://anilist.co/anime/${r.anilistId}',
            type: ProviderType.anime,
            sourceId: 'anilist',
            malId: r.malId,
            anilistId: r.anilistId,
            genres: r.genres,
            score: r.score,
            popularity: r.popularity,
            format: r.format,
            totalEpisodes: r.episodes,
            year: r.year?.toString(),
          ));
          if (items.length == 15) break;
        }
        hasNextPage = result.hasNextPage;
        page++;
      }
      if (mounted) setState(() {
        _becauseCarousel = items.take(5).toList();
        _becauseList = items.skip(5).take(10).toList();
        _becauseRatings = ratings;
      });
    } catch (_) {
      // Leave this section empty if AniList cannot provide title-specific recommendations.
    } finally {
      _becauseLoading = false;
    }
  }

  Future<void> _loadViewerGenreStats() async {
    final service = sl<AniListService>();
    if (!service.isConnected) {
      if (mounted) setState(() {
        _viewerGenreCounts = const {};
        _viewerGenreStatsLoaded = true;
      });
      return;
    }
    try {
      final counts = await service.api.viewerAnimeGenreCounts();
      if (mounted) setState(() {
        _viewerGenreCounts = counts;
        _viewerGenreStatsLoaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => _viewerGenreStatsLoaded = true);
    }
  }

  List<MediaItem> get _all => _rows.expand((r) => r.items).where((m) => !m.isAdult).toList();
  List<String> get _tasteGenres {
    final ids = _history.map((e) => e.malId).whereType<int>().toSet();
    final titles = _history.map((e) => e.showTitle.toLowerCase()).toSet();
    final counts = <String, int>{};
    for (final m in _all) {
      if ((m.malId != null && ids.contains(m.malId)) || titles.contains(m.title.toLowerCase())) {
        for (final g in m.genres) { counts.update(g, (n) => n + 1, ifAbsent: () => 1); }
      }
    }
    final sorted = counts.keys.toList()..sort((a, b) => counts[b]!.compareTo(counts[a]!));
    return sorted.isEmpty ? _genres.take(4).toList() : sorted.take(4).toList();
  }

  List<MediaItem> get _personalized {
    final tastes = _tasteGenres.map((g) => g.toLowerCase()).toSet();
    final watched = _history.map((e) => e.malId).whereType<int>().toSet();
    final seen = <String>{};
    return _all.where((m) {
      if ((m.malId != null && watched.contains(m.malId)) || !seen.add(m.id)) return false;
      return m.genres.any((g) => tastes.contains(g.toLowerCase()));
    }).toList();
  }

  List<MediaItem> _row(String name) {
    for (final r in _rows) {
      if (r.title.toLowerCase() == name.toLowerCase()) return r.items.where((m) => !m.isAdult).toList();
    }
    return const [];
  }
  List<MediaItem> get _trending => _row('Trending').isNotEmpty ? _row('Trending') : _row('Populer');
  // Reuse the exact catalogue row shown as "Rekomendasi Anime" on Home.
  // Do not synthesize a second recommendation list from genres/history here.
  List<MediaItem> get _recommendations => _row('Rekomendasi Anime');
  List<MediaItem> get _heroes {
    final unique = <String, MediaItem>{};
    for (final m in [..._recommendations, ..._trending, ..._row('Populer')]) {
      if (m.banner != null || m.cover != null) unique.putIfAbsent(m.id, () => m);
    }
    return unique.values.take(5).toList();
  }

  void _search({String query = '', MetaFilters? filters}) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) =>
      SearchScreen(initialQuery: query.isEmpty ? null : query, initialFilters: filters)));
  }
  void _open(MediaItem m) => Navigator.of(context).push(DetailScreen.route(m));
  TextStyle _txt(double size, {FontWeight weight = FontWeight.w500, Color? color, double height = 1.1}) =>
      AppText.body.copyWith(fontSize: size, height: height, fontWeight: weight, color: color ?? AppColors.textPrimary);

  Widget _heading(String title, {String? action, String? subtitle, VoidCallback? onAction, bool marked = false}) =>
    Padding(padding: const EdgeInsets.fromLTRB(16, 23, 16, 11), child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      if (marked) Container(width: 3, height: 30, margin: const EdgeInsets.only(right: 9), decoration: BoxDecoration(color: AppColors.textPrimary, borderRadius: BorderRadius.circular(3))),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: _txt(14, weight: FontWeight.w800)),
        if (subtitle != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text(subtitle, style: _txt(9, color: AppColors.textTertiary))),
      ])),
      if (action != null) GestureDetector(onTap: onAction, child: Text(action, style: _txt(10.5, weight: FontWeight.w800, color: AppColors.accent))),
    ]));

  Widget _searchBar() => Padding(padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
    child: Material(color: AppColors.surface, borderRadius: BorderRadius.circular(24),
      child: InkWell(borderRadius: BorderRadius.circular(24), onTap: () => _search(),
        child: SizedBox(height: 46, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 15),
          child: Row(children: [
            Icon(Icons.search_rounded, size: 18, color: AppColors.textTertiary),
            const SizedBox(width: 8),
            Text('Cari anime, genre, studio...', style: _txt(11, color: AppColors.textTertiary)),
          ]))))));

  Widget _pill(String label, VoidCallback tap, {bool selected = false, bool compact = false, Widget? icon, String? suffix}) =>
    Material(color: selected ? AppColors.accent : AppColors.surface,
      borderRadius: BorderRadius.circular(compact ? 18 : 10),
      child: InkWell(borderRadius: BorderRadius.circular(compact ? 18 : 10), onTap: tap,
        child: Padding(padding: EdgeInsets.symmetric(horizontal: compact ? 14 : 12, vertical: compact ? 9 : 10),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[icon, const SizedBox(width: 5)],
            Text(label, style: _txt(compact ? 10 : 10.5, weight: FontWeight.w700,
              color: selected ? Colors.white : AppColors.textSecondary)),
            if (suffix != null) ...[const SizedBox(width: 5), Text(suffix, style: _txt(7.5, weight: FontWeight.w900, color: AppColors.accent))],
          ]))));

  Widget _sorts() {
    const names = ['Untukmu', 'Populer', 'Nilai Tertinggi', 'Sedang Tayang'];
    return SizedBox(height: 40, child: ListView(scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16), children: [
        for (var i = 0; i < names.length; i++)
          Padding(padding: const EdgeInsets.only(right: 8), child: _pill(names[i], () {
            setState(() => _selected = names[i]);
            if (i == 1) _search(filters: const MetaFilters(sort: MetaSort.popularity));
            if (i == 2) _search(filters: const MetaFilters(sort: MetaSort.score));
            if (i == 3) _search(filters: const MetaFilters(statuses: [MetaStatus.releasing]));
          }, selected: _selected == names[i], compact: true)),
      ]));
  }

  Widget _hero({List<MediaItem>? sourceItems}) {
    if (sourceItems != null) return _recommendationCarousel(sourceItems);
    
    final items = _heroes;
    if (items.isEmpty) return const SizedBox(height: 8);
    return Column(children: [
      SizedBox(height: 178, child: PageView.builder(controller: _heroController, itemCount: items.length,
        onPageChanged: (i) => setState(() => _heroIndex = i),
        itemBuilder: (_, i) {
          final m = items[i];
          return Padding(padding: const EdgeInsets.only(left: 16, right: 5),
            child: GestureDetector(onTap: () => _open(m), child: ClipRRect(
              borderRadius: BorderRadius.circular(16), child: Stack(fit: StackFit.expand, children: [
                if (m.banner != null || m.cover != null)
                  Image.network(m.banner ?? m.cover!, fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => ColoredBox(color: AppColors.surface2)),
                DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [Colors.black.withValues(alpha: .02), Colors.black.withValues(alpha: .1), Colors.black.withValues(alpha: .9)],
                  stops: const [0, .35, 1]))),
                Positioned(left: 14, right: 13, bottom: 13, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(4)),
                    child: Text('SOROTAN', style: _txt(8, weight: FontWeight.w900, color: Colors.white))),
                  const SizedBox(height: 5),
                  Text(m.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: _txt(14, weight: FontWeight.w900, color: Colors.white, height: 1.05)),
                  const SizedBox(height: 3),
                  Row(children: [
                    const Icon(Icons.star_rounded, size: 11, color: Color(0xFF8BE16B)),
                    const SizedBox(width: 2),
                    Text(m.score == null ? '—' : (m.score! / 10).toStringAsFixed(1), style: _txt(9, weight: FontWeight.w900, color: const Color(0xFF8BE16B))),
                    const SizedBox(width: 6),
                    Expanded(child: Text('Karena kamu menonton ${_history.isEmpty ? 'anime favoritmu' : _history.first.showTitle}',
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: _txt(9, color: Colors.white.withValues(alpha: .9)))),
                  ]),
                ])),
              ]))));
        })),
      if (items.length > 1) Padding(padding: const EdgeInsets.only(top: 9),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (var i = 0; i < items.length; i++) AnimatedContainer(duration: const Duration(milliseconds: 180),
            margin: const EdgeInsets.symmetric(horizontal: 2), width: _heroIndex == i ? 12 : 5, height: 4,
            decoration: BoxDecoration(color: _heroIndex == i ? AppColors.accent : AppColors.textTertiary.withValues(alpha: .55),
              borderRadius: BorderRadius.circular(5))),
        ])),
    ]);
  }

  Widget _recommendationCarousel(List<MediaItem> items) {
    if (items.isEmpty) return const SizedBox(height: 8);
    final width = posterRowWidth(context);
    final height = posterRowHeight(context);
    return SizedBox(
      height: height,
      child: PageView.builder(
        controller: _recommendationController,
        itemCount: items.length,
        itemBuilder: (_, index) {
          final item = items[index];
          return SizedBox(
            width: width,
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: PosterCard(
                title: item.title,
                imageUrl: item.cover,
                imageColor: item.coverColor,
                wideImageUrl: item.banner,
                headers: item.coverHeaders,
                logoItem: item,
                cellWidth: width,
                onTap: () => _open(item),
                scoreBadge: item.score,
                recommendationRatingBadge: _becauseRatings[item.anilistId],
                viewsBadge: item.popularity,
                statusBadge: item.status?.name,
                qualityBadge: item.quality,
                dubBadge: item.dubBadge,
                genres: item.genres,
                isAdult: item.isAdult,
                metaFormat: item.format,
                metaEpisodes: item.totalEpisodes,
                metaYear: item.year,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _posterRail(List<MediaItem> items, {bool hidden = false, bool recommendationMode = false}) {
    if (items.isEmpty) return const SizedBox(height: 184);
    final list = items.take(18).toList();
    final width = posterRowWidth(context);
    final height = posterRowHeight(context);
    return SizedBox(
      height: height,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        scrollDirection: Axis.horizontal,
        itemCount: list.length,
        separatorBuilder: (_, _) => const SizedBox(width: 9),
        itemBuilder: (_, i) {
          final m = list[i];
          return SizedBox(
            width: width,
            height: height,
            child: PosterCard(
              title: m.title,
              imageUrl: m.cover,
              imageColor: m.coverColor,
              wideImageUrl: m.banner,
              headers: m.coverHeaders,
              logoItem: m,
              cellWidth: width,
              onTap: () => _open(m),
              scoreBadge: m.score,
              recommendationRatingBadge: recommendationMode ? _becauseRatings[m.anilistId] : null,
              viewsBadge: m.popularity,
              statusBadge: m.status?.name,
              qualityBadge: m.quality,
              dubBadge: m.dubBadge,
              genres: m.genres,
              isAdult: m.isAdult,
              metaFormat: m.format,
              metaEpisodes: m.totalEpisodes,
              metaYear: m.year,
            ),
          );
        },
      ),
    );
  }

  Widget _taste() {
    final stats = _viewerGenreCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final genres = stats.isNotEmpty
        ? stats.take(4).map((entry) => entry.key).toList()
        : (_history.isEmpty ? const ['Comedy', 'Fantasy', 'Action', 'Adventure'] : _tasteGenres);
    final total = stats.fold<int>(0, (sum, entry) => sum + entry.value);
    return SizedBox(height: 36, child: ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      children: [for (final g in genres)
        Padding(padding: const EdgeInsets.only(right: 8), child: _pill(
          g,
          () => _search(filters: MetaFilters(genres: [g])),
          suffix: _viewerGenreStatsLoaded && total > 0 && _viewerGenreCounts.containsKey(g)
              ? '${(_viewerGenreCounts[g]! * 100 / total).round()}%'
              : null,
        ))],
    ));
  }

  Widget _quickPicks() {
    final choices = [
      ('Tonton Singkat', Icons.bolt_rounded, const MetaFilters(maxEpisodes: 13)),
      ('Film', Icons.movie_rounded, const MetaFilters(formats: [MetaFormat.movie])),
      ('Siap Maraton', Icons.playlist_play_rounded, const MetaFilters(minEpisodes: 24)),
      ('Anime Baru', Icons.fiber_new_rounded, const MetaFilters(sort: MetaSort.newest)),
    ];
    return SizedBox(height: 40, child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [for (final c in choices) Padding(padding: const EdgeInsets.only(right: 7),
        child: _pill(c.$1, () => _search(filters: c.$3), icon: Icon(c.$2, size: 12, color: AppColors.accent)))]));
  }

  Widget _seasons() {
    final now = DateTime.now();
    final current = (now.month - 1) ~/ 3;
    const names = ['Winter', 'Spring', 'Summer', 'Fall'];
    final order = [for (var i = 0; i < 4; i++) (current - i + 4) % 4];
    return SizedBox(height: 34, child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12),
      children: [for (final i in order) Padding(padding: const EdgeInsets.only(right: 7),
        child: _pill('${names[i]} ${i > current ? now.year - 1 : now.year}', () => _search(filters: MetaFilters(
          years: [i > current ? now.year - 1 : now.year], seasons: [MetaSeason.values[i]]))))]));
  }

  Widget _genreGrid() {
    const genres = ['Comedy', 'Kids', 'Fantasy', 'Action', 'Adventure', 'Sci-Fi', 'Drama', 'Shounen'];
    const colors = [Color(0xFF9B742C), Color(0xFF7140A5), Color(0xFF7041A1), Color(0xFF98413F),
      Color(0xFF267D70), Color(0xFF276C78), Color(0xFF365F91), Color(0xFF8B3E57)];
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: GridView.builder(
      shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: math.min(8, genres.length),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 9, crossAxisSpacing: 9, childAspectRatio: 2.35),
      itemBuilder: (_, i) {
        final g = genres[i];
        final c = colors[i % colors.length];
        return Material(color: c.withValues(alpha: .34), borderRadius: BorderRadius.circular(11),
          child: InkWell(borderRadius: BorderRadius.circular(11), onTap: () => _search(filters: MetaFilters(genres: [g])),
            child: Container(padding: const EdgeInsets.fromLTRB(13, 10, 11, 9),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(11), border: Border.all(color: c.withValues(alpha: .65), width: .8),
                gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [c.withValues(alpha: .48), c.withValues(alpha: .20)])),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(g, maxLines: 1, overflow: TextOverflow.ellipsis, style: _txt(12, weight: FontWeight.w800)),
              ]))));
      }));
  }

  Widget _years() {
    final y = DateTime.now().year;
    return SizedBox(height: 34, child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12),
      children: [for (var i = 0; i < 12; i++) Padding(padding: const EdgeInsets.only(right: 7),
        child: _pill('${y - i}', () => _search(filters: MetaFilters(years: [y - i]))))]));
  }

  Widget _studios() {
    const names = ['Toei Animation', 'Sunrise', 'J.C.Staff', 'TMS Entertainment', 'Madhouse', 'Shanghai Animation Film Studio', 'Production I.G'];
    const initials = ['TO', 'SU', 'J', 'TM', 'MA', 'SH', 'PR'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          for (var i = 0; i < names.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => Navigator.of(context).push(StudioPage.route(names[i])),
                  child: SizedBox(
                    height: 48,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 34,
                            child: Center(
                              child: Text(
                                initials[i],
                                style: _txt(9, weight: FontWeight.w900, color: AppColors.textSecondary),
                              ),
                            ),
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  names[i],
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: _txt(11, weight: FontWeight.w800),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right_rounded, size: 17, color: AppColors.textTertiary),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final watched = _history.isEmpty ? 'anime favoritmu' : _history.first.showTitle;
    final hidden = _all.where((m) => m.popularity != null && m.popularity! < 50000).toList()
      ..sort((a, b) => (a.popularity ?? 0).compareTo(b.popularity ?? 0));
    return Scaffold(backgroundColor: AppColors.bg, body: RefreshIndicator(
      color: AppColors.accent, backgroundColor: AppColors.surface, onRefresh: _load,
      child: CustomScrollView(physics: const AlwaysScrollableScrollPhysics(), slivers: [
        SliverToBoxAdapter(child: SafeArea(bottom: false, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 2), child: Text('Jelajahi', style: _txt(20, weight: FontWeight.w900))),
          _searchBar(), _sorts(), const SizedBox(height: 10), _hero(),
          _heading('Selera Kamu', marked: true), _taste(),
          _heading('Karena kamu menonton $watched'), _hero(sourceItems: _becauseCarousel), _posterRail(_becauseList, recommendationMode: true),
          _heading('Permata Tersembunyi', subtitle: 'Skor tinggi, jarang dilirik'), _posterRail(hidden.isEmpty ? _recommendations : hidden, hidden: true),
          _heading('Lagi pengen apa?', marked: true), _quickPicks(),
          _heading('Telusuri Musim'), _seasons(),
          _heading('Genre', action: 'Lihat Semua →', onAction: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const GenresScreen()))), _genreGrid(),
          _heading('Telusuri Tahun'), _years(),
          _heading('Studio Populer', marked: true), _studios(),
          const SizedBox(height: 100),
        ]))),
      ]),
    ));
  }
}
