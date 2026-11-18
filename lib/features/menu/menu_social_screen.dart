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

  @override Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.bg,
    appBar: AppBar(backgroundColor: AppColors.bg, foregroundColor: AppColors.textPrimary, title: Text('Feed Komunitas', style: AppText.title.copyWith(color: AppColors.textPrimary)), actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))]),
    body: RefreshIndicator(onRefresh: _load, child: _loading
      ? ListView(children: const [SizedBox(height: 280, child: Center(child: CircularProgressIndicator()))])
      : _error != null
        ? ListView(children: [Padding(padding: const EdgeInsets.all(24), child: Text(_error!, style: AppText.body.copyWith(color: AppColors.textSecondary)))])
        : _items.isEmpty
          ? ListView(children: [Padding(padding: const EdgeInsets.all(24), child: Text('Belum ada aktivitas.', style: AppText.body.copyWith(color: AppColors.textSecondary)))])
          : ListView.separated(padding: const EdgeInsets.all(14), itemCount: _items.length, separatorBuilder: (_, __) => const SizedBox(height: 10), itemBuilder: (_, i) => _ActivityCard(activity: _items[i])),
    ),
  );
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.activity});
  final Map<String, dynamic> activity;
  @override Widget build(BuildContext context) {
    final user = activity['user'] is Map ? activity['user'] as Map : const {};
    final avatar = user['avatar'] is Map ? (user['avatar'] as Map)['large'] as String? : null;
    final media = activity['media'] is Map ? activity['media'] as Map : const {};
    final title = media['title'] is Map ? media['title'] as Map : const {};
    final mediaName = title['romaji'] ?? title['english'];
    final type = activity['type']?.toString() ?? '';
    String message;
    if (type == 'ANIME_LIST' || type == 'MANGA_LIST') {
      final status = activity['status']?.toString()?.replaceAll('_', ' ').toLowerCase() ?? 'memperbarui daftar';
      final progress = activity['progress'];
      message = '${status[0].toUpperCase()}${status.substring(1)}${progress == null ? '' : ' · episode/bab $progress'}${mediaName == null ? '' : ' · $mediaName'}';
    } else {
      message = (activity['text'] ?? activity['message'] ?? '').toString().replaceAll(RegExp(r'<[^>]*>'), '').trim();
      if (message.isEmpty) message = 'Membagikan aktivitas.';
    }
    return Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [CircleAvatar(radius: 17, backgroundImage: avatar == null ? null : NetworkImage(avatar), child: avatar == null ? const Icon(Icons.person, size: 18) : null), const SizedBox(width: 9), Expanded(child: Text(user['name']?.toString() ?? 'AniList user', style: AppText.body.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w700)))]),
      const SizedBox(height: 12),
      Text(message, style: AppText.body.copyWith(color: AppColors.textSecondary, height: 1.45)),
    ]));
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
