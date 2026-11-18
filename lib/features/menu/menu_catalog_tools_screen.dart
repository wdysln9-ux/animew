import 'package:flutter/material.dart';
import '../../core/anilist/anilist_service.dart';
import '../../core/di/injector.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';

class MenuCatalogToolsScreen extends StatelessWidget {
  const MenuCatalogToolsScreen({super.key, required this.featureId});
  final String featureId;
  @override Widget build(BuildContext context) => switch (featureId) {
    'characters' => const _CharacterDatabaseScreen(),
    'stats' => const _AnimeStatsScreen(),
    _ => const _CompareAnimeScreen(),
  };
}

class _CharacterDatabaseScreen extends StatefulWidget {
  const _CharacterDatabaseScreen();
  @override State<_CharacterDatabaseScreen> createState() => _CharacterDatabaseScreenState();
}

class _CharacterDatabaseScreenState extends State<_CharacterDatabaseScreen> {
  final _query = TextEditingController();
  List<Map<String, dynamic>> _anime = [];
  List<dynamic> _characters = [];
  Map<String, dynamic>? _selected;
  bool _loading = false;
  String? _error;

  Future<void> _search() async {
    if (_query.text.trim().isEmpty) return;
    setState(() { _loading = true; _error = null; _selected = null; _characters = []; });
    try {
      final rows = await sl<AniListService>().api.searchMedia(_query.text, perPage: 15);
      if (mounted) setState(() => _anime = rows.where((e) => e['isAdult'] != true).toList());
      if (rows.isEmpty && mounted) setState(() => _error = 'Anime tidak ditemukan.');
    } catch (_) {
      if (mounted) setState(() => _error = 'Pencarian AniList gagal.');
    } finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _loadCharacters(Map<String, dynamic> anime) async {
    setState(() { _loading = true; _selected = anime; _characters = []; _error = null; });
    try {
      final result = await sl<AniListService>().api.mediaCharacters((anime['id'] as num).toInt());
      if (mounted) setState(() => _characters = result.cast);
    } catch (_) {
      if (mounted) setState(() => _error = 'Database karakter untuk anime ini tidak tersedia.');
    } finally { if (mounted) setState(() => _loading = false); }
  }

  @override void dispose() { _query.dispose(); super.dispose(); }

  @override Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.bg,
    appBar: AppBar(backgroundColor: AppColors.bg, foregroundColor: AppColors.textPrimary, title: const Text('Database Karakter')),
    body: Column(children: [
      Padding(padding: const EdgeInsets.all(14), child: TextField(controller: _query, onSubmitted: (_) => _search(), decoration: InputDecoration(hintText: 'Cari judul anime', prefixIcon: const Icon(Icons.search), suffixIcon: IconButton(onPressed: _search, icon: const Icon(Icons.arrow_forward))))),
      if (_selected == null) Expanded(child: _loading ? const Center(child: CircularProgressIndicator()) : _error != null ? Center(child: Text(_error!, style: AppText.body.copyWith(color: AppColors.textSecondary))) : ListView.builder(padding: const EdgeInsets.symmetric(horizontal: 14), itemCount: _anime.length, itemBuilder: (_, i) {
        final item = _anime[i]; final title = item['title'] is Map ? item['title'] as Map : const {}; final cover = item['coverImage'] is Map ? (item['coverImage'] as Map)['large'] as String? : null;
        return ListTile(onTap: () => _loadCharacters(item), leading: cover == null ? const SizedBox(width: 44) : ClipRRect(borderRadius: BorderRadius.circular(6), child: Image.network(cover, width: 44, height: 60, fit: BoxFit.cover)), title: Text((title['romaji'] ?? title['english'] ?? 'Anime').toString(), style: AppText.body.copyWith(color: AppColors.textPrimary)), trailing: const Icon(Icons.chevron_right));
      }))
      else Expanded(child: Column(children: [
        ListTile(leading: const Icon(Icons.arrow_back), title: Text((_selected!['title'] as Map?)?['romaji']?.toString() ?? 'Anime', style: AppText.body.copyWith(color: AppColors.textPrimary)), onTap: () => setState(() => _selected = null)),
        Expanded(child: _loading ? const Center(child: CircularProgressIndicator()) : _error != null ? Center(child: Text(_error!, style: AppText.caption.copyWith(color: AppColors.textSecondary))) : GridView.builder(padding: const EdgeInsets.all(12), itemCount: _characters.length, gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, childAspectRatio: .72, crossAxisSpacing: 9, mainAxisSpacing: 9), itemBuilder: (_, i) {
          final ch = _characters[i]; final photo = ch.photo as String?;
          return Container(decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)), clipBehavior: Clip.antiAlias, child: Column(children: [
            Expanded(child: photo == null ? const Center(child: Icon(Icons.person)) : Image.network(photo, width: double.infinity, fit: BoxFit.cover, errorBuilder: (_,__,___) => const Center(child: Icon(Icons.person)))),
            Padding(padding: const EdgeInsets.all(7), child: Column(children: [Text(ch.name as String, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: AppText.caption.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w700)), Text(ch.role?.toString() ?? '', style: AppText.caption.copyWith(color: AppColors.textTertiary, fontSize: 10))])),
          ]));
        })),
      ])),
    ]),
  );
}

class _AnimeStatsScreen extends StatefulWidget {
  const _AnimeStatsScreen();
  @override State<_AnimeStatsScreen> createState() => _AnimeStatsScreenState();
}

class _AnimeStatsScreenState extends State<_AnimeStatsScreen> {
  Map<String, int> _genres = {};
  bool _loading = true;
  String? _error;
  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    final service = sl<AniListService>();
    try {
      if (!service.isConnected && !await service.connect()) throw StateError('AniList belum terhubung.');
      final data = await service.api.viewerAnimeGenreCounts();
      if (mounted) setState(() => _genres = data);
    } catch (_) {
      if (mounted) setState(() => _error = 'Hubungkan akun AniList untuk melihat statistik genre.');
    } finally { if (mounted) setState(() => _loading = false); }
  }

  @override Widget build(BuildContext context) {
    final sorted = _genres.entries.toList()..sort((a,b) => b.value.compareTo(a.value));
    final maxValue = sorted.isEmpty ? 1 : sorted.first.value;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(backgroundColor: AppColors.bg, foregroundColor: AppColors.textPrimary, title: const Text('Statistik Anime'), actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))]),
      body: _loading ? const Center(child: CircularProgressIndicator()) : _error != null ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, textAlign: TextAlign.center, style: AppText.body.copyWith(color: AppColors.textSecondary)))) : sorted.isEmpty ? Center(child: Text('Belum ada data genre.', style: AppText.body.copyWith(color: AppColors.textSecondary))) : ListView(padding: const EdgeInsets.all(18), children: [
        Text('Genre yang paling sering kamu tonton', style: AppText.title.copyWith(color: AppColors.textPrimary)),
        const SizedBox(height: 6),
        Text('Berdasarkan statistik akun AniList.', style: AppText.caption.copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: 18),
        for (final e in sorted) Padding(padding: const EdgeInsets.only(bottom: 16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Expanded(child: Text(e.key, style: AppText.body.copyWith(color: AppColors.textPrimary))), Text('${e.value}', style: AppText.caption.copyWith(color: AppColors.textSecondary))]),
          const SizedBox(height: 6),
          ClipRRect(borderRadius: BorderRadius.circular(10), child: LinearProgressIndicator(value: e.value / maxValue, minHeight: 8, color: AppColors.accent, backgroundColor: AppColors.surface2)),
        ])),
      ]),
    );
  }
}

class _CompareAnimeScreen extends StatefulWidget {
  const _CompareAnimeScreen();
  @override State<_CompareAnimeScreen> createState() => _CompareAnimeScreenState();
}

class _CompareAnimeScreenState extends State<_CompareAnimeScreen> {
  final _a = TextEditingController();
  final _b = TextEditingController();
  Map<String, dynamic>? _left, _right;
  bool _loading = false;
  String? _error;

  Future<Map<String, dynamic>?> _find(String q) async {
    if (q.trim().isEmpty) return null;
    final rows = await sl<AniListService>().api.searchMedia(q, perPage: 1);
    final safe = rows.where((e) => e['isAdult'] != true).toList();
    return safe.isEmpty ? null : safe.first;
  }

  Future<void> _compare() async {
    setState(() { _loading = true; _error = null; });
    try {
      final values = await Future.wait([_find(_a.text), _find(_b.text)]);
      if (values[0] == null || values[1] == null) throw StateError('Anime tidak ditemukan.');
      if (mounted) setState(() { _left = values[0]; _right = values[1]; });
    } catch (_) {
      if (mounted) setState(() => _error = 'Pastikan kedua judul ditemukan di AniList.');
    } finally { if (mounted) setState(() => _loading = false); }
  }

  @override void dispose() { _a.dispose(); _b.dispose(); super.dispose(); }

  @override Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.bg,
    appBar: AppBar(backgroundColor: AppColors.bg, foregroundColor: AppColors.textPrimary, title: const Text('Perbandingan Anime')),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      TextField(controller: _a, decoration: const InputDecoration(labelText: 'Anime pertama')),
      const SizedBox(height: 10),
      TextField(controller: _b, decoration: const InputDecoration(labelText: 'Anime kedua')),
      const SizedBox(height: 14),
      FilledButton(onPressed: _loading ? null : _compare, child: Text(_loading ? 'Membandingkan...' : 'Bandingkan')),
      if (_error != null) Padding(padding: const EdgeInsets.all(12), child: Text(_error!, style: AppText.caption.copyWith(color: AppColors.textSecondary))),
      if (_left != null && _right != null) Padding(padding: const EdgeInsets.only(top: 20), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: _CompareCard(media: _left!)),
        const SizedBox(width: 10),
        Expanded(child: _CompareCard(media: _right!)),
      ])),
    ]),
  );
}

class _CompareCard extends StatelessWidget {
  const _CompareCard({required this.media});
  final Map<String, dynamic> media;
  @override Widget build(BuildContext context) {
    final title = media['title'] is Map ? media['title'] as Map : const {};
    final cover = media['coverImage'] is Map ? (media['coverImage'] as Map)['large'] as String? : null;
    final studios = media['studios'] is Map && (media['studios'] as Map)['nodes'] is List ? ((media['studios'] as Map)['nodes'] as List).map((e) => (e as Map)['name']).join(', ') : '-';
    final genres = media['genres'] is List ? (media['genres'] as List).join(', ') : '-';
    Widget value(String label, Object? data) => Padding(padding: const EdgeInsets.only(top: 9), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: AppText.caption.copyWith(color: AppColors.textTertiary)), Text(data?.toString() ?? '-', style: AppText.caption.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600))]));
    return Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (cover != null) ClipRRect(borderRadius: BorderRadius.circular(9), child: Image.network(cover, height: 150, width: double.infinity, fit: BoxFit.cover)),
      const SizedBox(height: 8),
      Text((title['romaji'] ?? title['english'] ?? 'Anime').toString(), maxLines: 3, overflow: TextOverflow.ellipsis, style: AppText.caption.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w800)),
      value('Skor', media['averageScore'] == null ? '-' : '${media['averageScore']}/100'),
      value('Popularitas', media['popularity']),
      value('Episode', media['episodes']),
      value('Tahun', media['seasonYear']),
      value('Status', media['status']),
      value('Studio', studios),
      value('Genre', genres),
    ]));
  }
}
