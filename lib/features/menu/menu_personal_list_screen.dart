import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../core/anilist/anilist_service.dart';
import '../../core/di/injector.dart';
import '../../core/hive/safe_box.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';

const _personalBox = 'menu_tools_data';

class MenuPersonalListScreen extends StatelessWidget {
  const MenuPersonalListScreen({super.key, required this.featureId});
  final String featureId;
  @override Widget build(BuildContext context) => _PersonalListBody(ranking: featureId == 'ranking');
}

class _PersonalListBody extends StatefulWidget {
  const _PersonalListBody({required this.ranking});
  final bool ranking;
  @override State<_PersonalListBody> createState() => _PersonalListBodyState();
}

class _PersonalListBodyState extends State<_PersonalListBody> {
  final _query = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  List<Map<String, dynamic>> _saved = [];
  bool _loading = false;
  bool _saving = false;
  String get _key => widget.ranking ? 'custom_ranking' : 'anime_collection';
  String get _title => widget.ranking ? 'Ranking Builder' : 'Koleksi Anime';

  @override void initState() { super.initState(); _loadSaved(); }

  Future<Box> _box() async => Hive.isBoxOpen(_personalBox) ? Hive.box(_personalBox) : openBoxSafely(_personalBox);

  Future<void> _loadSaved() async {
    final box = await _box();
    final raw = box.get(_key);
    if (!mounted) return;
    setState(() => _saved = raw is List ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : []);
  }

  Future<void> _search() async {
    if (_query.text.trim().isEmpty) return;
    setState(() => _loading = true);
    try {
      final rows = await sl<AniListService>().api.searchMedia(_query.text, perPage: 15);
      if (mounted) setState(() => _results = rows);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pencarian AniList gagal.')));
    } finally { if (mounted) setState(() => _loading = false); }
  }

  Map<String, dynamic> _compact(Map<String, dynamic> media) {
    final title = media['title'] is Map ? media['title'] as Map : const {};
    final cover = media['coverImage'] is Map ? (media['coverImage'] as Map)['large'] : null;
    return {'id': media['id'], 'title': title['romaji'] ?? title['english'] ?? 'Anime', 'cover': cover};
  }

  Future<void> _add(Map<String, dynamic> media) async {
    final item = _compact(media);
    if (_saved.any((e) => e['id'] == item['id'])) return;
    setState(() => _saved.add(item));
    await _persist();
  }

  Future<void> _remove(int index) async {
    setState(() => _saved.removeAt(index));
    await _persist();
  }

  Future<void> _persist() async {
    setState(() => _saving = true);
    try { await (await _box()).put(_key, _saved); }
    finally { if (mounted) setState(() => _saving = false); }
  }

  Future<void> _reorder(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex--;
    final item = _saved.removeAt(oldIndex);
    _saved.insert(newIndex, item);
    setState(() {});
    await _persist();
  }

  @override void dispose() { _query.dispose(); super.dispose(); }

  @override Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.bg,
    appBar: AppBar(backgroundColor: AppColors.bg, foregroundColor: AppColors.textPrimary, title: Text(_title, style: AppText.title.copyWith(color: AppColors.textPrimary)), actions: [if (_saving) const Padding(padding: EdgeInsets.all(16), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)))]),
    body: Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(14, 12, 14, 6), child: TextField(controller: _query, onSubmitted: (_) => _search(), decoration: InputDecoration(hintText: 'Cari anime di AniList', prefixIcon: const Icon(Icons.search), suffixIcon: IconButton(onPressed: _search, icon: const Icon(Icons.arrow_forward))))),
      if (_loading) const LinearProgressIndicator(),
      if (_results.isNotEmpty) SizedBox(height: 190, child: ListView.builder(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 10), itemCount: _results.length, itemBuilder: (_, i) {
        final m = _results[i]; final title = m['title'] is Map ? m['title'] as Map : const {}; final cover = m['coverImage'] is Map ? (m['coverImage'] as Map)['large'] as String? : null;
        return SizedBox(width: 118, child: InkWell(onTap: () => _add(m), child: Padding(padding: const EdgeInsets.all(5), child: Column(children: [
          Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(8), child: cover == null ? Container(color: AppColors.surface, child: const Icon(Icons.movie)) : Image.network(cover, width: 108, fit: BoxFit.cover))),
          const SizedBox(height: 5),
          Text((title['romaji'] ?? title['english'] ?? 'Anime').toString(), maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: AppText.caption.copyWith(color: AppColors.textPrimary)),
          const Icon(Icons.add_circle_outline, size: 17),
        ]))));
      })),
      Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 6), child: Row(children: [Expanded(child: Text(widget.ranking ? 'Urutan ranking kamu' : 'Anime yang disimpan', style: AppText.title.copyWith(color: AppColors.textPrimary))), Text('${_saved.length}', style: AppText.caption.copyWith(color: AppColors.textSecondary))])),
      Expanded(child: _saved.isEmpty ? Center(child: Text(widget.ranking ? 'Cari anime lalu tambahkan untuk menyusun ranking.' : 'Cari anime lalu tambahkan ke koleksi.', textAlign: TextAlign.center, style: AppText.body.copyWith(color: AppColors.textSecondary))) : widget.ranking
        ? ReorderableListView.builder(padding: const EdgeInsets.fromLTRB(12, 4, 12, 20), itemCount: _saved.length, onReorder: _reorder, itemBuilder: (_, i) => _SavedAnimeTile(key: ValueKey(_saved[i]['id']), item: _saved[i], index: i + 1, onRemove: () => _remove(i), ranking: true))
        : ListView.builder(padding: const EdgeInsets.fromLTRB(12, 4, 12, 20), itemCount: _saved.length, itemBuilder: (_, i) => _SavedAnimeTile(item: _saved[i], index: i + 1, onRemove: () => _remove(i), ranking: false)),
      ),
    ]),
  );
}

class _SavedAnimeTile extends StatelessWidget {
  const _SavedAnimeTile({super.key, required this.item, required this.index, required this.onRemove, required this.ranking});
  final Map<String, dynamic> item;
  final int index;
  final VoidCallback onRemove;
  final bool ranking;
  @override Widget build(BuildContext context) {
    final cover = item['cover'] as String?;
    return Card(color: AppColors.surface, child: ListTile(
      leading: Text(ranking ? '#$index' : '★', style: AppText.title.copyWith(color: AppColors.accent)),
      title: Text(item['title']?.toString() ?? 'Anime', maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.body.copyWith(color: AppColors.textPrimary)),
      subtitle: Text(ranking ? 'Tahan lalu geser untuk mengubah urutan' : 'Tersimpan di koleksi lokal', style: AppText.caption.copyWith(color: AppColors.textTertiary)),
      trailing: IconButton(onPressed: onRemove, icon: const Icon(Icons.remove_circle_outline)),
    ));
  }
}
