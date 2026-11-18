import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/anilist/anilist_service.dart';
import '../../core/di/injector.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';

class MenuRecommendationMatchScreen extends StatefulWidget {
  const MenuRecommendationMatchScreen({super.key});
  @override State<MenuRecommendationMatchScreen> createState() => _MenuRecommendationMatchScreenState();
}

class _MenuRecommendationMatchScreenState extends State<MenuRecommendationMatchScreen> {
  final _username = TextEditingController();
  Map<String, int> _mine = {};
  Map<String, int> _theirs = {};
  bool _loading = false;
  String? _error;
  double _similarity = 0;

  double _cosine(Map<String, int> a, Map<String, int> b) {
    final keys = {...a.keys, ...b.keys};
    double dot = 0, aa = 0, bb = 0;
    for (final k in keys) {
      final x = (a[k] ?? 0).toDouble();
      final y = (b[k] ?? 0).toDouble();
      dot += x * y; aa += x * x; bb += y * y;
    }
    if (aa == 0 || bb == 0) return 0;
    return dot / (sqrt(aa) * sqrt(bb));
  }

  Future<void> _match() async {
    if (_username.text.trim().isEmpty) return;
    setState(() { _loading = true; _error = null; });
    try {
      final service = sl<AniListService>();
      if (!service.isConnected && !await service.connect()) throw StateError('Login AniList diperlukan.');
      final values = await Future.wait([
        service.api.viewerAnimeGenreCounts(),
        service.api.userAnimeGenreCounts(_username.text.trim()),
      ]);
      if (values[0].isEmpty || values[1].isEmpty) throw StateError('Statistik genre tidak ditemukan.');
      if (mounted) setState(() { _mine = values[0]; _theirs = values[1]; _similarity = _cosine(values[0], values[1]); });
    } catch (_) {
      if (mounted) setState(() => _error = 'Tidak bisa menghitung kecocokan. Pastikan username AniList benar dan akunmu terhubung.');
    } finally { if (mounted) setState(() => _loading = false); }
  }

  @override void dispose() { _username.dispose(); super.dispose(); }

  @override Widget build(BuildContext context) {
    final common = _mine.keys.where(_theirs.containsKey).toList()..sort((a,b) => ((_mine[b] ?? 0) + (_theirs[b] ?? 0)).compareTo((_mine[a] ?? 0) + (_theirs[a] ?? 0)));
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(backgroundColor: AppColors.bg, foregroundColor: AppColors.textPrimary, title: const Text('Recommendation Match')),
      body: ListView(padding: const EdgeInsets.all(18), children: [
        Text('Bandingkan selera anime berdasarkan statistik genre AniList.', style: AppText.body.copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: 14),
        TextField(controller: _username, textInputAction: TextInputAction.search, onSubmitted: (_) => _match(), decoration: const InputDecoration(labelText: 'Username AniList', prefixIcon: Icon(Icons.person_search))),
        const SizedBox(height: 12),
        FilledButton(onPressed: _loading ? null : _match, child: Text(_loading ? 'Menghitung...' : 'Cari kecocokan')),
        if (_loading) const Padding(padding: EdgeInsets.all(22), child: Center(child: CircularProgressIndicator())),
        if (_error != null) Padding(padding: const EdgeInsets.only(top: 16), child: Text(_error!, style: AppText.caption.copyWith(color: AppColors.textSecondary))),
        if (_mine.isNotEmpty && _theirs.isNotEmpty) ...[
          const SizedBox(height: 24),
          Center(child: Text('${(_similarity * 100).round()}%', style: AppText.headline.copyWith(color: AppColors.accent, fontSize: 42))),
          Center(child: Text('Kemiripan selera genre', style: AppText.caption.copyWith(color: AppColors.textSecondary))),
          const SizedBox(height: 20),
          Text('Genre yang sama-sama disukai', style: AppText.title.copyWith(color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          if (common.isEmpty) Text('Belum ada genre yang sama di statistik.', style: AppText.caption.copyWith(color: AppColors.textSecondary)),
          for (final genre in common.take(12)) ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(genre, style: AppText.body.copyWith(color: AppColors.textPrimary)),
            subtitle: Text('Kamu: ${_mine[genre]} · ${_username.text}: ${_theirs[genre]}', style: AppText.caption.copyWith(color: AppColors.textSecondary)),
          ),
          Text('Persentase ini dihitung dari kemiripan distribusi genre, bukan jaminan rekomendasi akan cocok.', style: AppText.caption.copyWith(color: AppColors.textTertiary)),
        ],
      ]),
    );
  }
}
