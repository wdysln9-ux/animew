import 'package:flutter/material.dart';

import '../../core/zmode/metadata_filters.dart';
import '../../core/zmode/metadata_repository.dart';
import '../../core/zmode/zmode_ids.dart';
import '../../core/di/injector.dart';
import 'meta_filter_dialog_tv.dart';

Future<MetaFilters?> showMetaFilterSheet(
  BuildContext context,
  ZKind kind,
  MetaFilters current, {
  bool showStatus = true,
  bool hideMyAnime = false,
  ValueChanged<bool>? onHideMyAnimeChanged,
}) => showModalBottomSheet<MetaFilters>(
  context: context,
  backgroundColor: Colors.transparent,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => _MetaFilterSheet(
    kind: kind,
    initial: current,
    showStatus: showStatus,
    hideMyAnime: hideMyAnime,
    onHideMyAnimeChanged: onHideMyAnimeChanged,
  ),
);

Future<MetaFilters?> showMetaFilterDialog(
  BuildContext context,
  ZKind kind,
  MetaFilters current, {
  bool showStatus = true,
}) => showMetaFilterDialogTv(context, kind, current, showStatus: showStatus);

class _MetaFilterSheet extends StatefulWidget {
  const _MetaFilterSheet({
    required this.kind,
    required this.initial,
    required this.showStatus,
    required this.hideMyAnime,
    required this.onHideMyAnimeChanged,
  });

  final ZKind kind;
  final MetaFilters initial;
  final bool showStatus;
  final bool hideMyAnime;
  final ValueChanged<bool>? onHideMyAnimeChanged;

  @override
  State<_MetaFilterSheet> createState() => _MetaFilterSheetState();
}

class _MetaFilterSheetState extends State<_MetaFilterSheet> {
  late MetaFilters f = widget.initial;
  late bool hideMyAnime = widget.hideMyAnime;
  bool showAllYears = false;
  bool showAllTags = false;
  late Future<List<String>> genresFuture;
  late Future<List<String>> tagsFuture;

  bool get isAniList => widget.kind == ZKind.anime ||
      widget.kind == ZKind.manga || widget.kind == ZKind.novel;
  int get count =>
      f.genres.length + f.tags.length + f.years.length +
      f.seasons.length + f.formats.length + f.statuses.length +
      (f.minEpisodes > 0 || f.maxEpisodes < 200 ? 1 : 0) +
      (f.sort != MetaSort.popularity ? 1 : 0);

  @override
  void initState() {
    super.initState();
    genresFuture = _loadGenres();
    tagsFuture = _loadTags();
  }

  Future<List<String>> _loadGenres() async {
    if (!isAniList || !sl.isRegistered<MetadataRepository>()) {
      return metaGenresFor(widget.kind, adult: f.adult);
    }
    try {
      final values = await sl<MetadataRepository>().filterGenres();
      return values.where((v) => f.adult || v.toLowerCase() != 'hentai').toList();
    } catch (_) {
      return metaGenresFor(widget.kind, adult: f.adult);
    }
  }

  Future<List<String>> _loadTags() async {
    if (!isAniList || !sl.isRegistered<MetadataRepository>()) return const [];
    try {
      return await sl<MetadataRepository>().filterTags();
    } catch (_) {
      return const [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final now = DateTime.now().year;
    final years = [for (var y = now; y >= 1960; y--) y];
    final visibleYears = showAllYears
        ? years.where((y) => y >= 1980 && y <= 2011).toList()
        : years.where((y) => y >= 2012 || y < 1980).toList();
    final formats = _formats();
    final sortLabels = <MetaSort, String>{
      MetaSort.popularity: 'Popularitas',
      MetaSort.score: 'Rating',
      MetaSort.newest: 'Terbaru',
      MetaSort.trending: 'Trending',
      MetaSort.title: 'Judul',
    };

    return DraggableScrollableSheet(
      initialChildSize: .78,
      minChildSize: .48,
      maxChildSize: .96,
      expand: false,
      builder: (context, scroll) => Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 42, height: 5,
              decoration: BoxDecoration(color: cs.onSurface.withValues(alpha: .22),
                borderRadius: BorderRadius.circular(8))),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 22, 18, 14),
              child: Row(children: [
                Expanded(child: Text('Filter', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700))),
                TextButton(onPressed: _reset, child: const Text('Atur Ulang')),
              ]),
            ),
            Expanded(
              child: ListView(
                controller: scroll,
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                children: [
                  if (widget.onHideMyAnimeChanged != null)
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Hide My Anime'),
                      value: hideMyAnime,
                      onChanged: (v) { setState(() => hideMyAnime = v); widget.onHideMyAnimeChanged?.call(v); },
                    ),
                  _heading('Urutkan', theme),
                  Align(alignment: Alignment.centerRight, child: TextButton.icon(
                    onPressed: () => setState(() => f = f.copyWith(sortAscending: !f.sortAscending)),
                    icon: Icon(f.sortAscending ? Icons.north : Icons.south, color: cs.primary),
                    label: Text(f.sortAscending ? 'Naik' : 'Turun'),
                  )),
                  _chips(sortLabels.keys.map((v) => _ChipData(sortLabels[v]!, f.sort == v,
                    () => setState(() => f = f.copyWith(sort: v)))).toList(), cs),
                  const SizedBox(height: 22),
                  _heading('Tipe', theme),
                  _chips(formats.map((v) => _ChipData(_formatLabel(v), f.formats.contains(v),
                    () => _toggle<MetaFormat>(f.formats, v, (xs) => f = f.copyWith(formats: xs)))).toList(), cs),
                  if (widget.showStatus) ...[
                    const SizedBox(height: 22),
                    _heading('Status', theme),
                    _chips(MetaStatus.values.where((v) => v != MetaStatus.cancelled).map((v) =>
                      _ChipData(_statusLabel(v), f.statuses.contains(v),
                        () => _toggle<MetaStatus>(f.statuses, v, (xs) => f = f.copyWith(statuses: xs)))).toList(), cs),
                  ],
                  const SizedBox(height: 22),
                  _heading('Tahun', theme),
                  _chips(visibleYears.map((y) => _ChipData('$y', f.years.contains(y),
                    () => _toggle<int>(f.years, y, (xs) => f = f.copyWith(years: xs)))).toList(), cs),
                  if (!showAllYears)
                    _moreButton('Tampilkan Semua Tahun', years.where((y) => y >= 1980 && y <= 2011).length, () => setState(() => showAllYears = true), cs),
                  if (showAllYears)
                    _moreButton('Sembunyikan Tahun Lama', 0, () => setState(() => showAllYears = false), cs),
                  if (isAniList) ...[
                    const SizedBox(height: 22),
                    _heading('Musim', theme),
                    _chips(MetaSeason.values.map((v) => _ChipData(_seasonLabel(v), f.seasons.contains(v),
                      () => _toggle<MetaSeason>(f.seasons, v, (xs) => f = f.copyWith(seasons: xs)))).toList(), cs),
                    const SizedBox(height: 22),
                    _heading('Genre', theme),
                    FutureBuilder<List<String>>(
                      future: genresFuture,
                      builder: (context, snap) => snap.hasData
                        ? _chips(snap.data!.map((g) => _ChipData(g, f.genres.contains(g),
                            () => _toggle<String>(f.genres, g, (xs) => f = f.copyWith(genres: xs)))).toList(), cs)
                        : const Padding(padding: EdgeInsets.all(12), child: LinearProgressIndicator()),
                    ),
                    const SizedBox(height: 22),
                    _heading('Tags', theme),
                    FutureBuilder<List<String>>(
                      future: tagsFuture,
                      builder: (context, snap) {
                        if (!snap.hasData) return const LinearProgressIndicator();
                        final all = snap.data!;
                        final visible = showAllTags ? all : all.take(11).toList();
                        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          _chips(visible.map((t) => _ChipData(t, f.tags.contains(t),
                            () => _toggle<String>(f.tags, t, (xs) => f = f.copyWith(tags: xs)))).toList(), cs),
                          if (all.length > 11)
                            _moreButton(showAllTags ? 'Tampilkan Lebih Sedikit' : 'Tampilkan Semua', showAllTags ? 0 : all.length - 11,
                              () => setState(() => showAllTags = !showAllTags), cs),
                        ]);
                      },
                    ),
                  ],
                  const SizedBox(height: 22),
                  _heading('Jumlah Episode', theme),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('${f.minEpisodes}', style: theme.textTheme.titleMedium),
                    Text('${f.maxEpisodes}', style: theme.textTheme.titleMedium),
                  ]),
                  RangeSlider(
                    min: 0, max: 200, divisions: 200,
                    values: RangeValues(f.minEpisodes.toDouble(), f.maxEpisodes.toDouble()),
                    onChanged: (v) => setState(() => f = f.copyWith(
                      minEpisodes: v.start.round(), maxEpisodes: v.end.round())),
                  ),
                ],
              ),
            ),
            SafeArea(top: false, child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
              child: SizedBox(width: double.infinity, height: 50,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(f),
                  child: Text(count == 0 ? 'Simpan' : 'Simpan ($count)'),
                ),
              ),
            )),
          ],
        ),
      ),
    );
  }

  void _reset() => setState(() {
    f = const MetaFilters();
  });

  void _toggle<T>(List<T> current, T value, void Function(List<T>) update) {
    final next = [...current];
    next.contains(value) ? next.remove(value) : next.add(value);
    setState(() => update(next));
  }

  List<MetaFormat> _formats() {
    if (widget.kind == ZKind.anime) return const [MetaFormat.tv, MetaFormat.movie, MetaFormat.ova, MetaFormat.special];
    if (widget.kind == ZKind.manga) return const [MetaFormat.manga];
    if (widget.kind == ZKind.novel) return const [MetaFormat.novel];
    return const [MetaFormat.tv, MetaFormat.movie];
  }

  String _formatLabel(MetaFormat v) => switch (v) {
    MetaFormat.tv => 'TV', MetaFormat.movie => 'Movie', MetaFormat.ova => 'OVA',
    MetaFormat.special => 'Special', MetaFormat.manga => 'Manga',
    MetaFormat.novel => 'Novel', MetaFormat.oneShot => 'One Shot',
  };
  String _statusLabel(MetaStatus v) => switch (v) {
    MetaStatus.releasing => 'Tayang', MetaStatus.finished => 'Selesai',
    MetaStatus.notYetReleased => 'Segera', MetaStatus.cancelled => 'Dibatalkan',
  };
  String _seasonLabel(MetaSeason v) => switch (v) {
    MetaSeason.winter => 'Winter', MetaSeason.spring => 'Spring',
    MetaSeason.summer => 'Summer', MetaSeason.fall => 'Fall',
  };

  Widget _heading(String title, ThemeData theme) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
  );

  Widget _chips(List<_ChipData> data, ColorScheme cs) => Wrap(
    spacing: 9, runSpacing: 9,
    children: data.map((d) => ChoiceChip(
      label: Text(d.label),
      selected: d.selected,
      onSelected: (_) => d.onTap(),
      showCheckmark: false,
      selectedColor: cs.primary,
      backgroundColor: Colors.transparent,
      side: BorderSide(color: d.selected ? cs.primary : cs.outline.withValues(alpha: .55)),
      labelStyle: TextStyle(color: d.selected ? cs.onPrimary : cs.onSurfaceVariant),
      shape: const StadiumBorder(),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    )).toList(),
  );

  Widget _moreButton(String label, int count, VoidCallback onTap, ColorScheme cs) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: OutlinedButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.expand_more),
      label: Text(count > 0 ? '$label (+$count)' : label),
      style: OutlinedButton.styleFrom(foregroundColor: cs.primary, side: BorderSide(color: cs.primary)),
    ),
  );
}

class _ChipData {
  const _ChipData(this.label, this.selected, this.onTap);
  final String label;
  final bool selected;
  final VoidCallback onTap;
}
