import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/anilist/anilist_service.dart';
import '../../core/di/injector.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/ui/settings_widgets.dart';
import '../../l10n/l10n.dart';

enum _NotificationTab { all, airing, activity, forum, following, media, submissions }

const _tabs = <(_NotificationTab, String)>[
  (_NotificationTab.all, 'Semua'),
  (_NotificationTab.airing, 'Episode'),
  (_NotificationTab.activity, 'Aktivitas'),
  (_NotificationTab.forum, 'Forum'),
  (_NotificationTab.following, 'Pengikut'),
  (_NotificationTab.media, 'Media'),
  (_NotificationTab.submissions, 'Submissions'),
];
const _activity = <String>{'ACTIVITY_MESSAGE','ACTIVITY_MENTION','ACTIVITY_REPLY','ACTIVITY_REPLY_SUBSCRIBED','ACTIVITY_LIKE','ACTIVITY_REPLY_LIKE'};
const _forum = <String>{'THREAD_COMMENT_MENTION','THREAD_COMMENT_REPLY','THREAD_SUBSCRIBED','THREAD_COMMENT_LIKE','THREAD_LIKE'};
const _media = <String>{'RELATED_MEDIA_ADDITION','MEDIA_DATA_CHANGE','MEDIA_MERGE','MEDIA_DELETION'};
const _submissions = <String>{'MEDIA_SUBMISSION_UPDATE','STAFF_SUBMISSION_UPDATE','CHARACTER_SUBMISSION_UPDATE'};

class SubscriptionsScreen extends StatefulWidget {
  const SubscriptionsScreen({super.key});
  @override
  State<SubscriptionsScreen> createState() => _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends State<SubscriptionsScreen> {
  _NotificationTab _selected = _NotificationTab.all;
  List<Map<String, dynamic>> _items = const [];
  bool _loading = true;
  bool _failed = false;
  AniListService get _aniList => sl<AniListService>();

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    if (!_aniList.isConnected) {
      if (mounted) setState(() { _loading = false; _failed = false; _items = const []; });
      return;
    }
    if (mounted) setState(() { _loading = true; _failed = false; });
    try {
      final rows = await _aniList.api.notifications();
      if (mounted) setState(() { _items = rows; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _loading = false; _failed = true; });
    }
  }

  bool _matches(Map<String, dynamic> n) {
    final type = (n['type'] ?? '').toString();
    switch (_selected) {
      case _NotificationTab.all: return true;
      case _NotificationTab.airing: return type == 'AIRING';
      case _NotificationTab.activity: return _activity.contains(type);
      case _NotificationTab.forum: return _forum.contains(type);
      case _NotificationTab.following: return type == 'FOLLOWING';
      case _NotificationTab.media: return _media.contains(type);
      case _NotificationTab.submissions: return _submissions.contains(type);
    }
  }

  String _title(Map<String, dynamic> n) {
    final type = (n['type'] ?? '').toString();
    final user = n['user'] is Map ? n['user'] as Map : null;
    final name = (user?['name'] ?? 'AniList').toString();
    final media = n['media'] is Map ? n['media'] as Map : null;
    final titles = media?['title'] is Map ? media!['title'] as Map : null;
    final mediaTitle = (titles?['romaji'] ?? titles?['english'] ?? 'Anime').toString();
    switch (type) {
      case 'AIRING': return mediaTitle + ' — Episode ' + (n['episode'] ?? '').toString() + ' sudah tayang';
      case 'FOLLOWING': return name + ' mulai mengikutimu';
      case 'ACTIVITY_MESSAGE': return name + ' mengirim pesan';
      case 'ACTIVITY_MENTION': return name + ' menyebutmu di aktivitas';
      case 'ACTIVITY_REPLY':
      case 'ACTIVITY_REPLY_SUBSCRIBED': return name + ' membalas aktivitas';
      case 'ACTIVITY_LIKE':
      case 'ACTIVITY_REPLY_LIKE': return name + ' menyukai aktivitasmu';
      case 'THREAD_COMMENT_MENTION': return name + ' menyebutmu di forum';
      case 'THREAD_COMMENT_REPLY': return name + ' membalas komentarmu di forum';
      case 'THREAD_SUBSCRIBED': return name + ' berkomentar di forum yang kamu ikuti';
      case 'THREAD_COMMENT_LIKE':
      case 'THREAD_LIKE': return name + ' menyukai postingan forum';
      case 'RELATED_MEDIA_ADDITION': return 'Media terkait baru ditambahkan';
      case 'MEDIA_DATA_CHANGE': return 'Informasi media diperbarui';
      case 'MEDIA_MERGE': return 'Media digabungkan';
      case 'MEDIA_DELETION': return 'Media dihapus dari AniList';
      default: return 'Pembaruan submission AniList';
    }
  }

  String _time(Map<String, dynamic> n) {
    final raw = n['createdAt'];
    if (raw is! num) return '';
    final date = DateTime.fromMillisecondsSinceEpoch(raw.toInt() * 1000).toLocal();
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'Baru saja';
    if (diff.inHours < 1) return diff.inMinutes.toString() + ' menit lalu';
    if (diff.inDays < 1) return diff.inHours.toString() + ' jam lalu';
    if (diff.inDays < 7) return diff.inDays.toString() + ' hari lalu';
    return date.day.toString() + '/' + date.month.toString() + '/' + date.year.toString();
  }

  @override
  Widget build(BuildContext context) {
    final connected = _aniList.isConnected;
    final rows = _items.where(_matches).toList();
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: settingsAppBar(context.l10n.notifications),
      body: Column(children: [
        SizedBox(
          height: 54,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            scrollDirection: Axis.horizontal,
            itemCount: _tabs.length,
            separatorBuilder: (_, _) => const SizedBox(width: 7),
            itemBuilder: (context, index) {
              final tab = _tabs[index];
              final selected = _selected == tab.$1;
              return ChoiceChip(
                label: Text(tab.$2),
                selected: selected,
                onSelected: (_) => setState(() => _selected = tab.$1),
                showCheckmark: false,
                labelStyle: AppText.caption.copyWith(
                  color: selected ? AppColors.bg : AppColors.textPrimary,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
                selectedColor: AppColors.accent,
                backgroundColor: AppColors.surface2,
                side: BorderSide.none,
                shape: const StadiumBorder(),
                visualDensity: VisualDensity.compact,
              );
            },
          ),
        ),
        Expanded(
          child: !connected
              ? _message(Icons.link_off_rounded, 'Hubungkan akun AniList untuk melihat notifikasi.')
              : _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _failed
                      ? _message(Icons.cloud_off_rounded, 'Notifikasi AniList gagal dimuat.', retry: true)
                      : rows.isEmpty
                          ? _message(Icons.notifications_none_rounded, 'Belum ada notifikasi di kategori ini.')
                          : RefreshIndicator(
                              onRefresh: _load,
                              child: ListView.separated(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                itemCount: rows.length,
                                separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
                                itemBuilder: (context, index) => _tile(rows[index]),
                              ),
                            ),
        ),
      ]),
    );
  }

  Widget _message(IconData icon, String message, {bool retry = false}) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 38, color: AppColors.textSecondary),
        const SizedBox(height: 12),
        Text(message, textAlign: TextAlign.center, style: AppText.body.copyWith(color: AppColors.textSecondary)),
        if (retry) TextButton(onPressed: _load, child: const Text('Coba lagi')),
      ]),
    ),
  );

  Widget _tile(Map<String, dynamic> n) {
    final user = n['user'] is Map ? n['user'] as Map : null;
    final media = n['media'] is Map ? n['media'] as Map : null;
    final avatar = user?['avatar'] is Map ? (user!['avatar'] as Map)['large']?.toString() : null;
    final cover = media?['coverImage'] is Map ? (media!['coverImage'] as Map)['large']?.toString() : null;
    final image = avatar ?? cover;
    final contextText = n['context']?.toString();
    final contexts = n['contexts'] is List ? (n['contexts'] as List).whereType<String>().join(' · ') : '';
    final detail = contextText?.isNotEmpty == true ? contextText! : contexts;
    final type = (n['type'] ?? '').toString();
    final icon = type == 'AIRING' ? Icons.play_circle_outline_rounded
        : type == 'FOLLOWING' ? Icons.person_add_alt_1_rounded
        : _forum.contains(type) ? Icons.forum_outlined : Icons.notifications_none_rounded;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: SizedBox(
          width: 44, height: 44,
          child: image != null && image.isNotEmpty
              ? CachedNetworkImage(imageUrl: image, fit: BoxFit.cover,
                  errorWidget: (_, _, _) => _fallback(icon))
              : _fallback(icon),
        ),
      ),
      title: Text(_title(n), maxLines: 2, overflow: TextOverflow.ellipsis,
        style: AppText.body.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (detail.isNotEmpty) Text(detail, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.caption),
        const SizedBox(height: 3),
        Text(_time(n), style: AppText.caption.copyWith(color: AppColors.textSecondary)),
      ]),
    );
  }

  Widget _fallback(IconData icon) => ColoredBox(
    color: AppColors.surface2,
    child: Icon(icon, color: AppColors.textSecondary, size: 22),
  );
}
