import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/anilist/anilist_service.dart';
import '../../core/di/injector.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';

class MenuSocialScreen extends StatelessWidget {
  const MenuSocialScreen({super.key, required this.featureId});
  final String featureId;
  @override Widget build(BuildContext context) => featureId == 'feed' ? const _ActivityFeedScreen() : const _UserDirectoryScreen();
}

class _ActivityFeedScreen extends StatefulWidget {
  const _ActivityFeedScreen();
  @override State<_ActivityFeedScreen> createState() => _ActivityFeedScreenState();
}

class _ActivityFeedScreenState extends State<_ActivityFeedScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;
  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final rows = await sl<AniListService>().api.fetchGlobalActivities();
      if (mounted) setState(() => _items = rows);
    } catch (_) {
      if (mounted) setState(() => _error = 'Aktivitas AniList tidak bisa dimuat.');
    } finally { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.bg,
    appBar: AppBar(
      backgroundColor: AppColors.bg,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      title: Text('Feed', style: AppText.title.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w800)),
      actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded))],
    ),
    body: RefreshIndicator(
      onRefresh: _load,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        slivers: [
          SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.accent.withValues(alpha: .2), AppColors.surface, AppColors.surface2]),
                border: Border.all(color: AppColors.accent.withValues(alpha: .15)),
              ),
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('COMMUNITY PULSE', style: AppText.caption.copyWith(color: AppColors.accent, fontWeight: FontWeight.w900, letterSpacing: 1)),
                  const SizedBox(height: 7),
                  Text('Yang lagi ditonton komunitas.', style: AppText.title.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text('Aktivitas publik terbaru dari AniList.', style: AppText.caption.copyWith(color: AppColors.textSecondary)),
                ])),
                const SizedBox(width: 10),
                Icon(Icons.bubble_chart_rounded, color: AppColors.accent, size: 42),
              ]),
            ),
          )),
          if (_loading)
            const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
          else if (_error != null)
            SliverFillRemaining(child: Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, style: AppText.body.copyWith(color: AppColors.textSecondary)))))
          else if (_items.isEmpty)
            SliverFillRemaining(child: Center(child: Text('Belum ada aktivitas.', style: AppText.body.copyWith(color: AppColors.textSecondary))))
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 28),
              sliver: SliverList(delegate: SliverChildBuilderDelegate(
                (context, index) => Padding(
                  padding: const EdgeInsets.only(bottom: 11),
                  child: _ActivityCard(activity: _items[index]),
                ),
                childCount: _items.length,
              )),
            ),
        ],
      ),
    ),
  );
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.activity});
  final Map<String, dynamic> activity;

  @override
  Widget build(BuildContext context) {
    final user = activity['user'] is Map ? activity['user'] as Map : const {};
    final avatar = user['avatar'] is Map ? (user['avatar'] as Map)['large'] as String? : null;
    final media = activity['media'] is Map ? activity['media'] as Map : const {};
    final title = media['title'] is Map ? media['title'] as Map : const {};
    final mediaName = title['romaji'] ?? title['english'];
    final cover = media['coverImage'] is Map ? (media['coverImage'] as Map)['large'] as String? : null;
    final type = activity['type']?.toString() ?? '';
    String message;
    if (type == 'ANIME_LIST' || type == 'MANGA_LIST') {
      final rawStatus = activity['status']?.toString().replaceAll('_', ' ').toLowerCase() ?? 'memperbarui daftar';
      final progress = activity['progress'];
      message = '${rawStatus[0].toUpperCase()}${rawStatus.substring(1)}${progress == null ? '' : ' · episode/bab $progress'}';
    } else {
      message = (activity['text'] ?? activity['message'] ?? '').toString().replaceAll(RegExp(r'<[^>]*>'), '').trim();
      if (message.isEmpty) message = 'Membagikan aktivitas.';
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(19), border: Border.all(color: AppColors.hairline)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(radius: 18, backgroundColor: AppColors.surface2, backgroundImage: avatar == null ? null : NetworkImage(avatar), child: avatar == null ? const Icon(Icons.person_rounded, size: 18) : null),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(user['name']?.toString() ?? 'AniList user', style: AppText.body.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w800)),
            Text('Aktivitas AniList', style: AppText.caption.copyWith(color: AppColors.textTertiary, fontSize: 10)),
          ])),
          Icon(Icons.more_horiz_rounded, color: AppColors.textTertiary),
        ]),
        const SizedBox(height: 13),
        if (cover != null) Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ClipRRect(borderRadius: BorderRadius.circular(11), child: Image.network(cover, width: 72, height: 96, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox(width: 72, height: 96))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(message, style: AppText.body.copyWith(color: AppColors.textSecondary, height: 1.4)),
            if (mediaName != null) ...[
              const SizedBox(height: 7),
              Text(mediaName.toString(), maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.title.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w800)),
            ],
          ])),
        ]) else Text(message, style: AppText.body.copyWith(color: AppColors.textSecondary, height: 1.45)),
      ]),
    );
  }
}

class _UserDirectoryScreen extends StatefulWidget {
  const _UserDirectoryScreen();
  @override State<_UserDirectoryScreen> createState() => _UserDirectoryScreenState();
}

class _UserDirectoryScreenState extends State<_UserDirectoryScreen> {
  final _query = TextEditingController();
  List<Map<String, dynamic>> _users = [];
  bool _loading = false;
  String? _error;

  Future<void> _search() async {
    if (_query.text.trim().isEmpty) return;
    setState(() { _loading = true; _error = null; });
    try {
      final rows = await sl<AniListService>().api.searchUsers(_query.text);
      if (mounted) setState(() => _users = rows);
    } catch (_) {
      if (mounted) setState(() => _error = 'Pencarian pengguna gagal.');
    } finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _open(String? url) async {
    if (url == null) return;
    final uri = Uri.tryParse(url);
    if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override void dispose() { _query.dispose(); super.dispose(); }

  @override Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.bg,
    appBar: AppBar(backgroundColor: AppColors.bg, foregroundColor: AppColors.textPrimary, title: Text('Pengguna AniList', style: AppText.title.copyWith(color: AppColors.textPrimary))),
    body: Column(children: [
      Padding(padding: const EdgeInsets.all(14), child: TextField(controller: _query, textInputAction: TextInputAction.search, onSubmitted: (_) => _search(), decoration: InputDecoration(hintText: 'Cari username AniList', prefixIcon: const Icon(Icons.search), suffixIcon: IconButton(onPressed: _search, icon: const Icon(Icons.arrow_forward))))),
      Expanded(child: _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
          ? Center(child: Text(_error!, style: AppText.body.copyWith(color: AppColors.textSecondary)))
          : _users.isEmpty
            ? Center(child: Text('Cari pengguna berdasarkan username.', style: AppText.body.copyWith(color: AppColors.textSecondary)))
            : ListView.separated(padding: const EdgeInsets.symmetric(horizontal: 14), itemCount: _users.length, separatorBuilder: (_, __) => const SizedBox(height: 8), itemBuilder: (_, i) {
                final u = _users[i];
                final avatar = u['avatar'] is Map ? (u['avatar'] as Map)['large'] as String? : null;
                final stats = u['statistics'] is Map && (u['statistics'] as Map)['anime'] is Map ? (u['statistics'] as Map)['anime'] as Map : const {};
                return ListTile(
                  tileColor: AppColors.surface,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  leading: CircleAvatar(backgroundImage: avatar == null ? null : NetworkImage(avatar), child: avatar == null ? const Icon(Icons.person) : null),
                  title: Text(u['name']?.toString() ?? 'Pengguna', style: AppText.body.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
                  subtitle: Text('${stats['count'] ?? 0} anime · ${stats['minutesWatched'] ?? 0} menit ditonton', style: AppText.caption.copyWith(color: AppColors.textSecondary)),
                  trailing: const Icon(Icons.open_in_new, size: 18),
                  onTap: () => _open(u['siteUrl'] as String?),
                );
              }),
      ),
    ]),
  );
}
