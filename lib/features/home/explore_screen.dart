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
import '../../core/ui/poster_card.dart';
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

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final repo = sl<MetadataRepository>();
      final rows = await repo.home();
      final genreSet = <String>{for (final row in rows) for (final item in row.items) ...item.genres};
      final history = sl.isRegistered<WatchHistory>() ? sl<WatchHistory>().all().take(30).toList() : <HistoryEntry>[];
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _genres = genreSet.where((g) => g.toLowerCase() != 'hentai').toList()..sort();
        _history = history;
      });
    } catch (_) {}
  }

  List<MediaItem> _row(String name) {
    for (final row in _rows) { if (row.title.toLowerCase() == name.toLowerCase()) return row.items; }
    return const [];
  }

  void _search({String query = '', MetaFilters? filters}) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) =>
      SearchScreen(initialQuery: query.isEmpty ? null : query, initialFilters: filters)));
  }
  void _open(MediaItem item) => Navigator.of(context).push(DetailScreen.route(item));

  Widget _heading(String title, {String? action, VoidCallback? onAction}) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 18, 16, 9),
    child: Row(children: [
      Expanded(child: Text(title, style: AppText.body.copyWith(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w700))),
      if (action != null) GestureDetector(onTap: onAction, child: Text(action, style: AppText.caption.copyWith(color: AppColors.accent, fontSize: 11))),
    ]),
  );

  Widget _rail(List<MediaItem> items, {double width = 112}) {
    if (items.isEmpty) return const SizedBox(height: 178);
    return SizedBox(height: 204, child: ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 12), scrollDirection: Axis.horizontal,
      itemCount: math.min(items.length, 16), separatorBuilder: (_, _) => const SizedBox(width: 9),
      itemBuilder: (_, i) { final m = items[i]; return SizedBox(width: width, child: PosterCard(
        title: m.title, logoItem: m, imageUrl: m.cover, wideImageUrl: m.banner,
        imageColor: m.coverColor, headers: m.coverHeaders, genres: m.genres,
        scoreBadge: m.score, latestEpisodeBadge: m.latestEpisode, cellWidth: width,
        onTap: () => _open(m),
      )); },
    ));
  }

  Widget _chip(String label, VoidCallback onTap, {bool selected = false}) => ActionChip(
    label: Text(label, style: AppText.caption.copyWith(color: selected ? Colors.white : AppColors.textSecondary, fontSize: 10)),
    backgroundColor: selected ? AppColors.accent : AppColors.surface, side: BorderSide.none, onPressed: onTap);

  Widget _hero() {
    final recs = _row('Rekomendasi Anime');
    final m = recs.isNotEmpty ? recs.first : (_rows.isNotEmpty && _rows.first.items.isNotEmpty ? _rows.first.items.first : null);
    if (m == null) return const SizedBox.shrink();
    return Padding(padding: const EdgeInsets.fromLTRB(14, 12, 14, 0), child: GestureDetector(onTap: () => _open(m),
      child: ClipRRect(borderRadius: BorderRadius.circular(13), child: SizedBox(height: 145, width: double.infinity,
        child: Stack(fit: StackFit.expand, children: [
          if (m.banner != null || m.cover != null) Image.network(m.banner ?? m.cover!, fit: BoxFit.cover, errorBuilder: (_, _, _) => ColoredBox(color: AppColors.surface2)),
          DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black.withValues(alpha: .86)]))),
          Positioned(left: 13, right: 12, bottom: 12, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3), decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(4)), child: const Text('SOROTAN', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold))),
            const SizedBox(height: 6), Text(m.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
            Text('★ ${((m.score ?? 0) / 10).toStringAsFixed(1)}  Rekomendasi berdasarkan tontonanmu', style: const TextStyle(color: Colors.white, fontSize: 9)),
          ])),
        ]))));
  }

  Widget _searchBar() => Padding(padding: const EdgeInsets.fromLTRB(12, 12, 12, 8), child: InkWell(
    borderRadius: BorderRadius.circular(24), onTap: () => _search(),
    child: Container(height: 42, padding: const EdgeInsets.symmetric(horizontal: 13), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(24)),
      child: Row(children: [Icon(Icons.search_rounded, size: 18, color: AppColors.textTertiary), const SizedBox(width: 8), Text('Cari anime, genre, studio...', style: AppText.caption.copyWith(color: AppColors.textTertiary))]))));

  Widget _sorts() {
    const names = ['Untukmu', 'Populer', 'Nilai Tertinggi', 'Sedang Tayang'];
    return SizedBox(height: 39, child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 11), children: [
      for (var i = 0; i < names.length; i++) Padding(padding: const EdgeInsets.only(right: 6), child: _chip(names[i], () {
        setState(() => _selected = names[i]);
        if (i == 1) _search(filters: const MetaFilters(sort: MetaSort.popularity));
        if (i == 2) _search(filters: const MetaFilters(sort: MetaSort.score));
        if (i == 3) _search(filters: const MetaFilters(statuses: [MetaStatus.releasing]));
      }, selected: _selected == names[i])),
    ]));
  }

  Widget _genreGrid() {
    final genres = _genres.isEmpty ? const ['Comedy','Fantasy','Action','Adventure','Drama','Sci-Fi','Romance','Mystery'] : _genres;
    final colors = [AppColors.accent, const Color(0xFF7651B8), const Color(0xFF347D72), const Color(0xFF376B9A)];
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: GridView.builder(
      shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: math.min(8, genres.length),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 7, crossAxisSpacing: 7, childAspectRatio: 2.35),
      itemBuilder: (_, i) => InkWell(borderRadius: BorderRadius.circular(12), onTap: () => _search(filters: MetaFilters(genres: [genres[i]])),
        child: Container(padding: const EdgeInsets.all(11), decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), gradient: LinearGradient(colors: [colors[i % colors.length].withValues(alpha: .4), AppColors.surface]), border: Border.all(color: colors[i % colors.length].withValues(alpha: .35))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(genres[i], style: AppText.body.copyWith(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w700)),
            Text('Telusuri anime', style: AppText.caption.copyWith(color: AppColors.textSecondary, fontSize: 9)),
          ]))),
    ));
  }

  Widget _quickPicks() {
    final choices = [
      ('ϟ  Tonton Singkat', const MetaFilters(maxEpisodes: 13)),
      ('▣  Film', const MetaFilters(formats: [MetaFormat.movie])),
      ('▤  Siap Maraton', const MetaFilters(minEpisodes: 24)),
      ('◷  Anime Baru', const MetaFilters(sort: MetaSort.newest)),
    ];
    return SizedBox(height: 40, child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12), children: [
      for (final c in choices) Padding(padding: const EdgeInsets.only(right: 7), child: _chip(c.$1, () => _search(filters: c.$2))),
    ]));
  }

  Widget _years() {
    final year = DateTime.now().year;
    return SizedBox(height: 40, child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12), children: [
      for (var i = 0; i < 12; i++) Padding(padding: const EdgeInsets.only(right: 7), child: _chip('${year-i}', () => _search(filters: MetaFilters(years: [year-i])))),
    ]));
  }

  @override
  Widget build(BuildContext context) {
    final trending = _row('Trending').isNotEmpty ? _row('Trending') : _row('Populer');
    final recs = _row('Rekomendasi Anime').isNotEmpty ? _row('Rekomendasi Anime') : trending;
    final watched = _history.isEmpty ? 'anime yang kamu ikuti' : _history.first.showTitle;
    const studios = ['Toei Animation','Sunrise','J.C.Staff','TMS Entertainment','Madhouse','Production I.G'];
    return Scaffold(backgroundColor: AppColors.bg, body: RefreshIndicator(
      color: AppColors.accent, backgroundColor: AppColors.surface, onRefresh: _load,
      child: CustomScrollView(physics: const AlwaysScrollableScrollPhysics(), slivers: [
        SliverToBoxAdapter(child: SafeArea(bottom: false, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.fromLTRB(16, 7, 16, 0), child: Text('Jelajahi', style: AppText.body.copyWith(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w800))),
          _searchBar(), _sorts(), _hero(),
          _heading('Selera Kamu'),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Wrap(spacing: 6, children: [
            for (final g in (_history.isEmpty ? const ['Comedy','Fantasy','Action','Adventure'] : _genres.take(4))) _chip(g, () => _search(filters: MetaFilters(genres: [g]))),
          ])),
          _heading('Karena kamu menonton $watched'), _rail(recs),
          _heading('Permata Tersembunyi'), _rail(_rows.expand((r) => r.items).where((m) => (m.popularity ?? 999999) < 50000).take(12).toList()),
          _heading('Lagi pengen apa?'), _quickPicks(),
          _heading('Telusuri Musim'), SizedBox(height: 40, child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12), children: [
            for (var i = 0; i < MetaSeason.values.length; i++) Padding(padding: const EdgeInsets.only(right: 7), child: _chip('${['Winter','Spring','Summer','Fall'][i]} ${DateTime.now().year}', () => _search(filters: MetaFilters(years: [DateTime.now().year], seasons: [MetaSeason.values[i]])))),
          ])),
          _heading('Genre', action: 'Lihat Semua →', onAction: () => _search()), _genreGrid(),
          _heading('Telusuri Tahun'), _years(),
          _heading('Studio Populer', action: 'Lihat Semua →', onAction: () => _search()),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Column(children: [
            for (final studio in studios) Padding(padding: const EdgeInsets.only(bottom: 6), child: Material(color: AppColors.surface, borderRadius: BorderRadius.circular(11), child: InkWell(onTap: () => _search(query: studio), child: Padding(padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12), child: Row(children: [
              Expanded(child: Text(studio, style: AppText.body.copyWith(color: AppColors.textPrimary, fontSize: 11, fontWeight: FontWeight.w600))),
              Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary, size: 18),
            ]))))),
          ])),
          _heading('Populer'), _rail(trending),
          _heading('Nilai Tertinggi'), _rail(_row('Skor Tinggi')),
          const SizedBox(height: 105),
        ]))),
      ]),
    ));
  }
}
