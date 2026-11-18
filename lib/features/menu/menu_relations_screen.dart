import 'package:flutter/material.dart';
import '../../core/anilist/anilist_service.dart';
import '../../core/di/injector.dart';
import '../../core/models/media_extras.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';

class MenuRelationsScreen extends StatefulWidget {
  const MenuRelationsScreen({super.key, required this.timeline});
  final bool timeline;
  @override State<MenuRelationsScreen> createState() => _MenuRelationsScreenState();
}

class _MenuRelationsScreenState extends State<MenuRelationsScreen> {
  final _query = TextEditingController();
  List<MediaRelation> _relations = [];
  bool _loading = false;
  String? _error;

  Future<void> _search() async {
    if (_query.text.trim().isEmpty) return;
    setState(() { _loading = true; _error = null; _relations = []; });
    try {
      final result = await sl<AniListService>().api.mediaExtrasBySearch(_query.text.trim());
      final rows = result.relations.toList();
      if (widget.timeline) {
        rows.sort((a, b) => (a.year ?? 9999).compareTo(b.year ?? 9999));
      }
      if (mounted) {
        setState(() {
          _relations = rows;
          if (rows.isEmpty) _error = 'Belum ada hubungan franchise yang ditemukan untuk judul ini.';
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Data relasi AniList gagal dimuat.');
    } finally { if (mounted) setState(() => _loading = false); }
  }

  @override void dispose() { _query.dispose(); super.dispose(); }

  @override Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.bg,
    appBar: AppBar(backgroundColor: AppColors.bg, foregroundColor: AppColors.textPrimary, title: Text(widget.timeline ? 'Timeline Anime' : 'Anime Map', style: AppText.title.copyWith(color: AppColors.textPrimary))),
    body: Column(children: [
      Padding(padding: const EdgeInsets.all(14), child: TextField(controller: _query, onSubmitted: (_) => _search(), decoration: InputDecoration(hintText: 'Cari judul anime / franchise', prefixIcon: const Icon(Icons.search), suffixIcon: IconButton(onPressed: _search, icon: const Icon(Icons.arrow_forward))))),
      if (_loading) const LinearProgressIndicator(),
      Expanded(child: _error != null ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, textAlign: TextAlign.center, style: AppText.body.copyWith(color: AppColors.textSecondary)))) : _relations.isEmpty ? Center(child: Text(widget.timeline ? 'Cari anime untuk menyusun linimasanya.' : 'Cari anime untuk melihat hubungan prekuel dan sekuelnya.', style: AppText.body.copyWith(color: AppColors.textSecondary), textAlign: TextAlign.center)) : ListView.builder(padding: const EdgeInsets.fromLTRB(14, 8, 14, 24), itemCount: _relations.length, itemBuilder: (_, i) {
        final r = _relations[i];
        final year = r.year?.toString() ?? 'Tahun tidak diketahui';
        return Padding(padding: const EdgeInsets.only(bottom: 9), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 58, child: Padding(padding: const EdgeInsets.only(top: 14), child: Text(widget.timeline ? year : '${i + 1}', style: AppText.caption.copyWith(color: AppColors.accent, fontWeight: FontWeight.w800)))),
          if (widget.timeline) Container(width: 2, height: 92, margin: const EdgeInsets.only(right: 10), color: AppColors.accent.withValues(alpha: .45)),
          Expanded(child: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(13)), child: Row(children: [
            if (r.cover != null) ClipRRect(borderRadius: BorderRadius.circular(7), child: Image.network(r.cover!, width: 54, height: 76, fit: BoxFit.cover, errorBuilder: (_,__,___) => const SizedBox(width: 54, height: 76))),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r.title, maxLines: 3, overflow: TextOverflow.ellipsis, style: AppText.body.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
              const SizedBox(height: 5),
              Text('${r.relation ?? 'Terkait'} · ${r.format ?? 'Anime'} · $year', style: AppText.caption.copyWith(color: AppColors.textSecondary)),
            ])),
          ]))),
        ]));
      })),
    ]),
  );
}
