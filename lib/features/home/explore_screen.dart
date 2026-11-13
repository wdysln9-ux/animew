import 'dart:math' as math;
import 'package:flutter/material.dart';
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

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});
  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  List<HomeSection> _rows = const [];
  List<String> _genres = const [];
  List<HistoryEntry> _history = const [];
  String _selected = 'Untukmu';
  int _heroIndex = 0;
  final PageController _heroController = PageController(viewportFraction: .96);

  @override
  void initState() { super.initState(); _load(); }
  @override
  void dispose() { _heroController.dispose(); super.dispose(); }

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
    } catch (_) {}
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
  List<MediaItem> get _recommendations {
    if (_personalized.isNotEmpty) return _personalized;
    return _row('Rekomendasi Anime').isNotEmpty ? _row('Rekomendasi Anime') : _trending;
  }
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
    Padding(padding: const EdgeInsets.fromLTRB(12, 19, 13, 9), child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      if (marked) Container(width: 2.5, height: 28, margin: const EdgeInsets.only(right: 8), decoration: BoxDecoration(color: AppColors.textPrimary, borderRadius: BorderRadius.circular(3))),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: _txt(12, weight: FontWeight.w800)),
        if (subtitle != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text(subtitle, style: _txt(8, color: AppColors.textTertiary))),
      ])),
      if (action != null) GestureDetector(onTap: onAction, child: Text(action, style: _txt(9.5, weight: FontWeight.w800, color: AppColors.accent))),
    ]));

  Widget _searchBar() => Padding(padding: const EdgeInsets.fromLTRB(12, 11, 12, 8),
    child: Material(color: AppColors.surface, borderRadius: BorderRadius.circular(24),
      child: InkWell(borderRadius: BorderRadius.circular(24), onTap: () => _search(),
        child: SizedBox(height: 40, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 13),
          child: Row(children: [
            Icon(Icons.search_rounded, size: 16, color: AppColors.textTertiary),
            const SizedBox(width: 8),
            Text('Cari anime, genre, studio...', style: _txt(10, color: AppColors.textTertiary)),
          ]))))));

  Widget _pill(String label, VoidCallback tap, {bool selected = false, bool compact = false, Widget? icon, String? suffix}) =>
    Material(color: selected ? AppColors.accent : AppColors.surface,
      borderRadius: BorderRadius.circular(compact ? 18 : 10),
      child: InkWell(borderRadius: BorderRadius.circular(compact ? 18 : 10), onTap: tap,
        child: Padding(padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 10, vertical: 8),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[icon, const SizedBox(width: 5)],
            Text(label, style: _txt(compact ? 9 : 9.5, weight: FontWeight.w700,
              color: selected ? Colors.white : AppColors.textSecondary)),
            if (suffix != null) ...[const SizedBox(width: 5), Text(suffix, style: _txt(7.5, weight: FontWeight.w900, color: AppColors.accent))],
          ]))));

  Widget _sorts() {
    const names = ['Untukmu', 'Populer', 'Nilai Tertinggi', 'Sedang Tayang'];
    return SizedBox(height: 36, child: ListView(scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 11), children: [
        for (var i = 0; i < names.length; i++)
          Padding(padding: const EdgeInsets.only(right: 6), child: _pill(names[i], () {
            setState(() => _selected = names[i]);
            if (i == 1) _search(filters: const MetaFilters(sort: MetaSort.popularity));
            if (i == 2) _search(filters: const MetaFilters(sort: MetaSort.score));
            if (i == 3) _search(filters: const MetaFilters(statuses: [MetaStatus.releasing]));
          }, selected: _selected == names[i], compact: true)),
      ]));
  }

  Widget _hero() {
    final items = _heroes;
    if (items.isEmpty) return const SizedBox(height: 8);
    return Column(children: [
      SizedBox(height: 145, child: PageView.builder(controller: _heroController, itemCount: items.length,
        onPageChanged: (i) => setState(() => _heroIndex = i),
        itemBuilder: (_, i) {
          final m = items[i];
          return Padding(padding: const EdgeInsets.only(left: 12, right: 3),
            child: GestureDetector(onTap: () => _open(m), child: ClipRRect(
              borderRadius: BorderRadius.circular(13), child: Stack(fit: StackFit.expand, children: [
                if (m.banner != null || m.cover != null)
                  Image.network(m.banner ?? m.cover!, fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => ColoredBox(color: AppColors.surface2)),
                DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [Colors.black.withValues(alpha: .02), Colors.black.withValues(alpha: .1), Colors.black.withValues(alpha: .9)],
                  stops: const [0, .35, 1]))),
                Positioned(left: 11, right: 10, bottom: 10, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(4)),
                    child: Text('SOROTAN', style: _txt(7, weight: FontWeight.w900, color: Colors.white))),
                  const SizedBox(height: 5),
                  Text(m.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: _txt(11.5, weight: FontWeight.w900, color: Colors.white, height: 1.05)),
                  const SizedBox(height: 3),
                  Row(children: [
                    const Icon(Icons.star_rounded, size: 11, color: Color(0xFF8BE16B)),
                    const SizedBox(width: 2),
                    Text(m.score == null ? '—' : (m.score! / 10).toStringAsFixed(1), style: _txt(8, weight: FontWeight.w900, color: const Color(0xFF8BE16B))),
                    const SizedBox(width: 6),
                    Expanded(child: Text('Karena kamu menonton ${_history.isEmpty ? 'anime favoritmu' : _history.first.showTitle}',
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: _txt(8, color: Colors.white.withValues(alpha: .9)))),
                  ]),
                ])),
              ]))));
        })),
      if (items.length > 1) Padding(padding: const EdgeInsets.only(top: 7),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (var i = 0; i < items.length; i++) AnimatedContainer(duration: const Duration(milliseconds: 180),
            margin: const EdgeInsets.symmetric(horizontal: 2), width: _heroIndex == i ? 12 : 5, height: 4,
            decoration: BoxDecoration(color: _heroIndex == i ? AppColors.accent : AppColors.textTertiary.withValues(alpha: .55),
              borderRadius: BorderRadius.circular(5))),
        ])),
    ]);
  }

  String _compact(int? n) {
    if (n == null || n <= 0) return '—';
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(n >= 10000000 ? 0 : 1).replaceAll('.0', '')}jt';
    if (n >= 10000) return '${(n / 1000).toStringAsFixed(0)}rb';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1).replaceAll('.0', '')}rb';
    return '$n';
  }

  Widget _posterRail(List<MediaItem> items, {bool hidden = false}) {
    if (items.isEmpty) return const SizedBox(height: 184);
    final list = items.take(18).toList();
    return SizedBox(height: 235, child: ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 12), scrollDirection: Axis.horizontal,
      itemCount: list.length, separatorBuilder: (_, _) => const SizedBox(width: 9),
      itemBuilder: (_, i) {
        final m = list[i];
        const width = 104.0;
        final meta = [if (m.format?.isNotEmpty == true) m.format!, if (m.totalEpisodes != null) '${m.totalEpisodes} Eps',
          if (m.year?.isNotEmpty == true) m.year!].join(' · ');
        return SizedBox(width: width, child: GestureDetector(onTap: () => _open(m),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ClipRRect(borderRadius: BorderRadius.circular(8), child: SizedBox(width: width, height: 156,
              child: Stack(fit: StackFit.expand, children: [
                if (m.cover != null) Image.network(m.cover!, fit: BoxFit.cover, headers: m.coverHeaders,
                  errorBuilder: (_, _, _) => ColoredBox(color: AppColors.surface2))
                else const ColoredBox(color: Colors.black12),
                Positioned(left: 5, top: 5, child: Container(padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                  decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(5)),
                  child: Text(hidden ? 'Pilihan' : 'Selesai', style: _txt(6.5, weight: FontWeight.w900, color: Colors.white)))),
                if (m.score != null) Positioned(right: 4, top: 5, child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: .68), borderRadius: BorderRadius.circular(5)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.star_rounded, size: 9, color: Color(0xFF8BE16B)),
                    Text((m.score! / 10).toStringAsFixed(1), style: _txt(7, weight: FontWeight.w900, color: Colors.white)),
                  ]))),
                if (m.popularity != null) Positioned(left: 5, bottom: 5, child: Row(children: [
                  const Icon(Icons.visibility_rounded, size: 9, color: Colors.white),
                  const SizedBox(width: 2), Text(_compact(m.popularity), style: _txt(7, weight: FontWeight.w800, color: Colors.white)),
                ])),
              ]))),
            const SizedBox(height: 5),
            Text(m.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: _txt(9, weight: FontWeight.w800, height: 1.03)),
            if (meta.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 2),
              child: Text(meta, maxLines: 1, overflow: TextOverflow.ellipsis, style: _txt(7.5, color: AppColors.textTertiary))),
          ])));
      }));
  }

  Widget _taste() {
    final genres = _history.isEmpty ? const ['Comedy', 'Fantasy', 'Action', 'Adventure'] : _tasteGenres;
    return SizedBox(height: 28, child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12),
      children: [for (final g in genres)
        Padding(padding: const EdgeInsets.only(right: 6), child: _pill(g,
          () => _search(filters: MetaFilters(genres: [g])),
          suffix: '${_all.where((m) => m.genres.any((x) => x.toLowerCase() == g.toLowerCase())).length}'))]));
  }

  Widget _quickPicks() {
    final choices = [
      ('Tonton Singkat', Icons.bolt_rounded, const MetaFilters(maxEpisodes: 13)),
      ('Film', Icons.movie_rounded, const MetaFilters(formats: [MetaFormat.movie])),
      ('Siap Maraton', Icons.playlist_play_rounded, const MetaFilters(minEpisodes: 24)),
      ('Anime Baru', Icons.fiber_new_rounded, const MetaFilters(sort: MetaSort.newest)),
    ];
    return SizedBox(height: 34, child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12),
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
    final genres = _genres.isEmpty ? const ['Comedy', 'Kids', 'Fantasy', 'Action', 'Adventure', 'Sci-Fi', 'Drama', 'Shounen'] : _genres.take(8).toList();
    const colors = [Color(0xFF9B742C), Color(0xFF7140A5), Color(0xFF7041A1), Color(0xFF98413F),
      Color(0xFF267D70), Color(0xFF276C78), Color(0xFF365F91), Color(0xFF8B3E57)];
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: GridView.builder(
      shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: math.min(8, genres.length),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 6, crossAxisSpacing: 7, childAspectRatio: 2.55),
      itemBuilder: (_, i) {
        final g = genres[i];
        final count = _all.where((m) => m.genres.any((x) => x.toLowerCase() == g.toLowerCase())).length;
        final c = colors[i % colors.length];
        return Material(color: c.withValues(alpha: .34), borderRadius: BorderRadius.circular(11),
          child: InkWell(borderRadius: BorderRadius.circular(11), onTap: () => _search(filters: MetaFilters(genres: [g])),
            child: Container(padding: const EdgeInsets.fromLTRB(10, 8, 8, 7),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(11), border: Border.all(color: c.withValues(alpha: .65), width: .8),
                gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [c.withValues(alpha: .48), c.withValues(alpha: .20)])),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(g, maxLines: 1, overflow: TextOverflow.ellipsis, style: _txt(10, weight: FontWeight.w800)),
                const SizedBox(height: 2), Text('$count anime', style: _txt(7.5, color: Colors.white.withValues(alpha: .82))),
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
    const counts = [912, 564, 446, 415, 369, 351, 347];
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Column(children: [
      for (var i = 0; i < names.length; i++)
        Padding(padding: const EdgeInsets.only(bottom: 6), child: Material(
          color: AppColors.surface, borderRadius: BorderRadius.circular(10),
          child: InkWell(borderRadius: BorderRadius.circular(10), onTap: () => _search(query: names[i]),
            child: SizedBox(height: 48, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(children: [
                SizedBox(width: 34, child: Center(child: Text(initials[i], style: _txt(8, weight: FontWeight.w900, color: AppColors.textSecondary)))),
                const SizedBox(width: 9),
                Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(names[i], maxLines: 1, overflow: TextOverflow.ellipsis, style: _txt(9.5, weight: FontWeight.w800)),
                  Text('${counts[i]} anime', style: _txt(7, color: AppColors.textTertiary)),
                ])),
                Icon(Icons.chevron_right_rounded, size: 17, color: AppColors.textTertiary),
              ]))),
        )),
    ]));
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
          Padding(padding: const EdgeInsets.fromLTRB(12, 5, 12, 0), child: Text('Jelajahi', style: _txt(16, weight: FontWeight.w900))),
          _searchBar(), _sorts(), const SizedBox(height: 5), _hero(),
          _heading('Selera Kamu', marked: true), _taste(),
          _heading('Karena kamu menonton $watched'), _posterRail(_recommendations),
          _heading('Permata Tersembunyi', subtitle: 'Skor tinggi, jarang dilirik'), _posterRail(hidden.isEmpty ? _recommendations : hidden, hidden: true),
          _heading('Lagi pengen apa?', marked: true), _quickPicks(),
          _heading('Telusuri Musim'), _seasons(),
          _heading('Genre', action: 'Lihat Semua →', onAction: () => _search()), _genreGrid(),
          _heading('Telusuri Tahun'), _years(),
          _heading('Studio Populer', marked: true, action: 'Lihat Semua →', onAction: () => _search()), _studios(),
          const SizedBox(height: 100),
        ]))),
      ]),
    ));
  }
}
