import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/anilist/anilist_service.dart';
import '../../core/di/injector.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/ui/settings_widgets.dart';
import '../../l10n/l10n.dart';

enum _NotificationTab { all, airing, activity, forum, following, media, submissions }

final _tabs = <(_NotificationTab, String, IconData, Color)>[
  (_NotificationTab.all, 'Semua', Icons.notifications_active_rounded, AppColors.accent),
  (_NotificationTab.airing, 'Episode', Icons.play_circle_rounded, Color(0xFF35B7E8)),
  (_NotificationTab.activity, 'Aktivitas', Icons.bolt_rounded, Color(0xFFFFB547)),
  (_NotificationTab.forum, 'Forum', Icons.forum_rounded, Color(0xFF9B83F6)),
  (_NotificationTab.following, 'Pengikut', Icons.people_alt_rounded, Color(0xFF42C99A)),
  (_NotificationTab.media, 'Media', Icons.movie_creation_rounded, Color(0xFFFF7C91)),
  (_NotificationTab.submissions, 'Pengajuan', Icons.fact_check_rounded, Color(0xFFB0A0FF)),
];
const _activity = <String>{'ACTIVITY_MESSAGE','ACTIVITY_MENTION','ACTIVITY_REPLY','ACTIVITY_REPLY_SUBSCRIBED','ACTIVITY_LIKE','ACTIVITY_REPLY_LIKE'};
const _forum = <String>{'THREAD_COMMENT_MENTION','THREAD_COMMENT_REPLY','THREAD_SUBSCRIBED','THREAD_COMMENT_LIKE','THREAD_LIKE'};
const _media = <String>{'RELATED_MEDIA_ADDITION','MEDIA_DATA_CHANGE','MEDIA_MERGE','MEDIA_DELETION'};
const _submissions = <String>{'MEDIA_SUBMISSION_UPDATE','STAFF_SUBMISSION_UPDATE','CHARACTER_SUBMISSION_UPDATE'};
const _allNotificationTypes = <String>{
  'AIRING',
  'FOLLOWING',
  ..._activity,
  ..._forum,
  ..._media,
  ..._submissions,
};

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  _NotificationTab _selected = _NotificationTab.all;
  List<Map<String, dynamic>> _items = const [];
  bool _loading = true;
  bool _failed = false;
  String? _errorMessage;
  bool _loadingMore = false;
  bool _loadMoreFailed = false;
  bool _hasMore = true;
  int _page = 1;
  int _loadGeneration = 0;
  final ScrollController _scroll = ScrollController();

  AniListService get _aniList => sl<AniListService>();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _aniList.addListener(_onAniListChanged);
    _load();
  }

  @override
  void dispose() {
    _scroll
      ..removeListener(_onScroll)
      ..dispose();
    _aniList.removeListener(_onAniListChanged);
    super.dispose();
  }

  void _onAniListChanged() {
    if (_aniList.isConnected && !_loading) _load();
    if (mounted) setState(() {});
  }

  void _onScroll() {
    if (!_scroll.hasClients || _loading || _loadingMore || !_hasMore) return;
    if (_scroll.position.extentAfter < 480) _loadMore();
  }

  List<String>? _typesFor(_NotificationTab tab) => switch (tab) {
    _NotificationTab.all => _allNotificationTypes.toList(),
    _NotificationTab.airing => const ['AIRING'],
    _NotificationTab.activity => _activity.toList(),
    _NotificationTab.forum => _forum.toList(),
    _NotificationTab.following => const ['FOLLOWING'],
    _NotificationTab.media => _media.toList(),
    _NotificationTab.submissions => _submissions.toList(),
  };

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    final types = _typesFor(_selected);
    if (!_aniList.isConnected) {
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = false;
          _items = const [];
          _page = 1;
          _hasMore = false;
        });
      }
      return;
    }
    if (mounted) setState(() {
      _loading = true;
      _failed = false;
      _errorMessage = null;
      _loadMoreFailed = false;
      _page = 1;
      _hasMore = true;
    });
    try {
      final rows = await _aniList.api.notifications(page: 1, types: types);
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _items = rows;
        _page = 1;
        _hasMore = rows.length >= 50;
        _loading = false;
      });
    } catch (error) {
      if (mounted && generation == _loadGeneration) setState(() {
        _loading = false;
        _failed = true;
        _errorMessage = error.toString().replaceFirst('Bad state: ', '');
      });
    }
  }

  Future<void> _loadMore() async {
    if (!_aniList.isConnected || _loading || _loadingMore || !_hasMore) return;
    setState(() {
      _loadingMore = true;
      _loadMoreFailed = false;
    });
    final nextPage = _page + 1;
    final generation = _loadGeneration;
    final types = _typesFor(_selected);
    try {
      final rows = await _aniList.api.notifications(page: nextPage, types: types);
      if (!mounted || generation != _loadGeneration) return;
      final ids = _items.map((n) => n['id']?.toString()).whereType<String>().toSet();
      setState(() {
        _items = [
          ..._items,
          ...rows.where((n) => n['id'] == null || ids.add(n['id'].toString())),
        ];
        _page = nextPage;
        _hasMore = rows.length >= 50;
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted && generation == _loadGeneration) setState(() {
        _loadingMore = false;
        _loadMoreFailed = true;
      });
    }
  }
  String _mediaTitle(Map? media) {
    final titles = media?['title'] is Map ? media!['title'] as Map : null;
    return (titles?['romaji'] ?? titles?['english'] ?? 'Media AniList').toString();
  }

  String _mediaKind(Map? media) {
    if (media?['type'] == 'ANIME') return 'Anime';
    if (media?['format'] == 'NOVEL') return 'Light novel';
    if (media?['type'] == 'MANGA') return 'Manga';
    return 'Media';
  }

  String _submissionStatus(Map n) {
    switch ((n['status'] ?? '').toString().toUpperCase()) {
      case 'ACCEPTED': return 'Diterima';
      case 'REJECTED': return 'Ditolak';
      case 'PENDING': return 'Menunggu';
      default: return 'Diperbarui';
    }
  }

  Color? _submissionColor(Map n) {
    switch ((n['status'] ?? '').toString().toUpperCase()) {
      case 'ACCEPTED': return const Color(0xFF35C978);
      case 'REJECTED': return const Color(0xFFE34D59);
      case 'PENDING': return const Color(0xFFFFB547);
      default: return null;
    }
  }

  String _detail(Map<String, dynamic> n) {
    final type = (n['type'] ?? '').toString();
    final media = n['media'] is Map ? n['media'] as Map : null;
    switch (type) {
      case 'AIRING': return 'Episode ' + (n['episode'] ?? '').toString();
      case 'RELATED_MEDIA_ADDITION': return _mediaKind(media);
      case 'MEDIA_DATA_CHANGE': return 'Informasi ' + _mediaKind(media).toLowerCase() + ' diperbarui';
      case 'MEDIA_SUBMISSION_UPDATE':
      case 'STAFF_SUBMISSION_UPDATE':
      case 'CHARACTER_SUBMISSION_UPDATE': return _submissionStatus(n);
      case 'THREAD_COMMENT_REPLY': return 'Membalas komentarmu dalam utas';
      case 'THREAD_SUBSCRIBED': return '';
      case 'THREAD_COMMENT_MENTION': return 'Menyebutmu dalam utas';
      case 'ACTIVITY_MENTION': return 'Menyebutmu dalam aktivitas';
      case 'ACTIVITY_REPLY':
      case 'ACTIVITY_REPLY_SUBSCRIBED': return 'Membalas aktivitasmu';
      default: return '';
    }
  }

  String _activityDescription(Map<String, dynamic> n) {
    final activity = n['activity'] is Map ? n['activity'] as Map : null;
    final media = activity?['media'] is Map ? activity!['media'] as Map : null;
    final status = (activity?['status'] ?? '').toString().toLowerCase();
    final progress = (activity?['progress'] ?? '').toString();
    if (status.contains('watch')) return 'Menonton episode ' + progress + ' ' + _mediaTitle(media);
    if (status.contains('read')) return 'Membaca bab ' + progress + ' ' + _mediaTitle(media);
    return 'Aktivitas AniList';
  }


  String _title(Map<String, dynamic> n) {
    final type = (n['type'] ?? '').toString();
    final user = n['user'] is Map ? n['user'] as Map : null;
    final name = (user?['name'] ?? 'AniList').toString();
    final media = n['media'] is Map ? n['media'] as Map : null;
    final mediaTitle = _mediaTitle(media);
    final thread = n['thread'] is Map ? n['thread'] as Map : null;
    switch (type) {
      case 'AIRING': return mediaTitle;
      case 'FOLLOWING': return name + ' mulai mengikutimu';
      case 'ACTIVITY_MESSAGE': return name + ' mengirim pesan';
      case 'ACTIVITY_MENTION': return name + ' menyebutmu di aktivitas';
      case 'ACTIVITY_REPLY':
      case 'ACTIVITY_REPLY_SUBSCRIBED': return name + ' membalas aktivitasmu';
      case 'ACTIVITY_LIKE':
      case 'ACTIVITY_REPLY_LIKE': return name + ' menyukai aktivitasmu';
      case 'THREAD_COMMENT_MENTION': return name + ' menyebutmu di utas: ' + (thread?['title'] ?? 'Forum').toString();
      case 'THREAD_COMMENT_REPLY': return name + ' membalas di utas: ' + (thread?['title'] ?? 'Forum').toString();
      case 'THREAD_SUBSCRIBED': return name + ' berkomentar di utas: ' + (thread?['title'] ?? 'Forum').toString();
      case 'THREAD_COMMENT_LIKE': return name + ' menyukai komentarmu di utas: ' + (thread?['title'] ?? 'Forum').toString();
      case 'THREAD_LIKE': return name + ' menyukai utas: ' + (thread?['title'] ?? 'Forum').toString();
      case 'RELATED_MEDIA_ADDITION': return mediaTitle + ' ditambahkan ke database';
      case 'MEDIA_DATA_CHANGE': return mediaTitle + ' diperbarui';
      case 'MEDIA_MERGE': return mediaTitle + ' digabungkan';
      case 'MEDIA_DELETION': return 'Media dihapus';
      case 'MEDIA_SUBMISSION_UPDATE': return mediaTitle;
      case 'STAFF_SUBMISSION_UPDATE': return 'Pengajuan staf — ' + _submissionStatus(n);
      case 'CHARACTER_SUBMISSION_UPDATE': return 'Pengajuan karakter — ' + _submissionStatus(n);
      default: return 'Pembaruan AniList';
    }
  }

  Widget _notificationTitle(Map<String, dynamic> n) {
    final type = (n['type'] ?? '').toString();
    final thread = n['thread'] is Map ? n['thread'] as Map : null;
    String? prefix;
    String? subject;
    String suffix = '';
    if (type == 'AIRING') {
      subject = _mediaTitle(n['media'] is Map ? n['media'] as Map : null);
    } else if (type == 'RELATED_MEDIA_ADDITION' || type == 'MEDIA_DATA_CHANGE' || type == 'MEDIA_MERGE' || type == 'MEDIA_SUBMISSION_UPDATE') {
      subject = _mediaTitle(n['media'] is Map ? n['media'] as Map : null);
      suffix = type == 'RELATED_MEDIA_ADDITION' ? ' ditambahkan ke database'
          : type == 'MEDIA_DATA_CHANGE' ? ' diperbarui'
          : type == 'MEDIA_MERGE' ? ' digabungkan' : '';
    } else if (_forum.contains(type)) {
      final user = n['user'] is Map ? n['user'] as Map : const {};
      final action = switch (type) {
        'THREAD_COMMENT_MENTION' => ' menyebutmu di utas: ',
        'THREAD_COMMENT_REPLY' => ' membalas di utas: ',
        'THREAD_SUBSCRIBED' => ' berkomentar di utas: ',
        'THREAD_COMMENT_LIKE' => ' menyukai komentarmu di utas: ',
        _ => ' menyukai utas: ',
      };
      prefix = (user['name'] ?? 'AniList').toString() + action;
      subject = (thread?['title'] ?? 'Forum').toString();
    }
    if (subject == null) {
      return Text(_title(n), maxLines: 2, overflow: TextOverflow.ellipsis,
        style: AppText.body.copyWith(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w600));
    }
    return Text.rich(TextSpan(children: [
      if (prefix != null) TextSpan(text: prefix, style: const TextStyle(color: AppColors.textPrimary)),
      TextSpan(text: subject, style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700)),
      if (suffix.isNotEmpty) TextSpan(text: suffix, style: const TextStyle(color: AppColors.textPrimary)),
    ]), maxLines: 2, overflow: TextOverflow.ellipsis,
      style: AppText.body.copyWith(fontSize: 13, fontWeight: FontWeight.w600));
  }

  static const _weekdays = [
    'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu',
  ];
  static const _months = [
    'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
  ];

  String _time(Map<String, dynamic> n) {
    final raw = n['createdAt'];
    if (raw is! num) return '';
    final date = DateTime.fromMillisecondsSinceEpoch(raw.toInt() * 1000).toLocal();
    final day = _weekdays[date.weekday - 1];
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return '$day, Baru saja';
    if (diff.inHours < 1) return '$day, ${diff.inMinutes} menit lalu';
    if (diff.inDays < 1) return '$day, ${diff.inHours} jam lalu';
    if (diff.inDays == 1) return '$day, Kemarin';
    if (diff.inDays < 7) return '$day, ${diff.inDays} hari lalu';
    return '$day, ${date.day} ${_months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final connected = _aniList.isConnected;
    final rows = _items;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: settingsAppBar(context.l10n.notifications),
      body: Column(children: [
        SizedBox(
          height: 56,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            scrollDirection: Axis.horizontal,
            itemCount: _tabs.length,
            separatorBuilder: (_, _) => const SizedBox(width: 7),
            itemBuilder: (context, index) {
              final tab = _tabs[index];
              final selected = _selected == tab.$1;
              final tabColor = tab.$4;
              return Material(
                color: selected ? tabColor : tabColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    if (_selected == tab.$1) return;
                    setState(() => _selected = tab.$1);
                    if (_scroll.hasClients) _scroll.jumpTo(0);
                    _load();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: tabColor.withOpacity(selected ? 0 : 0.28))),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(tab.$3, size: 17, color: selected ? AppColors.bg : tabColor),
                      const SizedBox(width: 5),
                      Text(tab.$2, style: AppText.caption.copyWith(fontSize: 12.5,
                        color: selected ? AppColors.bg : AppColors.textPrimary,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w600)),
                    ]),
                  ),
                ),
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
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(28),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.notifications_none_rounded, size: 38, color: AppColors.textSecondary),
                                    const SizedBox(height: 12),
                                    Text(
                                      _hasMore
                                          ? 'Belum ada notifikasi di kategori ini pada halaman terbaru.'
                                          : 'Belum ada notifikasi di kategori ini.',
                                      textAlign: TextAlign.center,
                                      style: AppText.body.copyWith(color: AppColors.textSecondary),
                                    ),
                                    if (_hasMore)
                                      TextButton(
                                        onPressed: _loadMore,
                                        child: const Text('Cari notifikasi lebih lama'),
                                      ),
                                  ],
                                ),
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: _load,
                              child: ListView.separated(
                                controller: _scroll,
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                itemCount: rows.length + (_hasMore || _loadMoreFailed ? 1 : 0),
                                separatorBuilder: (_, index) => Divider(
                                  height: 1,
                                  indent: 72,
                                  color: index == rows.length - 1 ? Colors.transparent : AppColors.hairline,
                                ),
                                itemBuilder: (context, index) {
                                  if (index < rows.length) return _tile(rows[index]);
                                  if (_loadingMore) {
                                    return const Padding(
                                      padding: EdgeInsets.all(18),
                                      child: Center(
                                        child: SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        ),
                                      ),
                                    );
                                  }
                                  return Center(
                                    child: TextButton(
                                      onPressed: _loadMore,
                                      child: Text(_loadMoreFailed ? 'Gagal memuat. Coba lagi' : 'Muat notifikasi lebih lama'),
                                    ),
                                  );
                                },
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
    final staff = n['staff'] is Map ? n['staff'] as Map : null;
    final character = n['character'] is Map ? n['character'] as Map : null;
    final avatar = user?['avatar'] is Map ? (user!['avatar'] as Map)['large']?.toString() : null;
    final staffImage = staff?['image'] is Map ? (staff!['image'] as Map)['large']?.toString() : null;
    final characterImage = character?['image'] is Map ? (character!['image'] as Map)['large']?.toString() : null;
    final cover = media?['coverImage'] is Map ? (media!['coverImage'] as Map)['large']?.toString() : null;
    final type = (n['type'] ?? '').toString();
    final socialNotification = _activity.contains(type) || _forum.contains(type);
    final mediaPoster = !socialNotification && cover?.isNotEmpty == true;
    final image = mediaPoster
        ? cover
        : (avatar ?? staffImage ?? characterImage ?? cover);
    final detail = _detail(n);
    final icon = type == 'AIRING' ? Icons.play_circle_outline_rounded
        : type == 'FOLLOWING' ? Icons.person_add_alt_1_rounded
        : _forum.contains(type) ? Icons.forum_outlined : Icons.notifications_none_rounded;
    return ListTile(
      onTap: () => _openNotification(n),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(mediaPoster ? 8 : 22),
        child: SizedBox(
          width: 44,
          height: mediaPoster ? 58 : 44,
          child: image != null && image.isNotEmpty
              ? CachedNetworkImage(imageUrl: image, fit: BoxFit.cover,
                  errorWidget: (_, _, _) => _fallback(icon))
              : _fallback(icon),
        ),
      ),
      title: _notificationTitle(n),
      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (detail.isNotEmpty)
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (_submissions.contains(type) && _submissionColor(n) != null)
              Padding(
                padding: const EdgeInsets.only(top: 4, right: 6),
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: _submissionColor(n),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            Expanded(child: Text(detail, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: AppText.caption.copyWith(fontSize: 11.5, color: AppColors.textSecondary))),
          ]),
        const SizedBox(height: 3),
        Text(_time(n), style: AppText.caption.copyWith(fontSize: 11, color: AppColors.textSecondary)),
      ]),
    );
  }

  Future<void> _openNotification(Map<String, dynamic> n) async {
    final type = (n['type'] ?? '').toString();
    final user = n['user'] is Map ? n['user'] as Map : null;
    final media = n['media'] is Map ? n['media'] as Map : null;
    final thread = n['thread'] is Map ? n['thread'] as Map : null;
    final staff = n['staff'] is Map ? n['staff'] as Map : null;
    final character = n['character'] is Map ? n['character'] as Map : null;

    String? target;
    if (type == 'MEDIA_DELETION') {
      final id = n['mediaId'];
      if (id != null) target = 'https://anilist.co/anime/$id';
    } else if (type == 'AIRING' || _media.contains(type) ||
        type == 'MEDIA_SUBMISSION_UPDATE') {
      target = media?['siteUrl']?.toString();
      if ((target == null || target.isEmpty) && media?['id'] != null) {
        target = 'https://anilist.co/anime/${media!['id']}';
      }
    } else if (type == 'FOLLOWING') {
      target = user?['siteUrl']?.toString();
      if ((target == null || target.isEmpty) && user?['name'] != null) {
        target = 'https://anilist.co/user/${user!['name']}';
      }
    } else if (_activity.contains(type)) {
      final id = n['activityId'];
      if (id != null) target = 'https://anilist.co/activity/$id';
    } else if (_forum.contains(type)) {
      target = thread?['siteUrl']?.toString();
      if ((target == null || target.isEmpty) && thread?['id'] != null) {
        target = 'https://anilist.co/forum/thread/${thread!['id']}';
      }
    } else if (type == 'STAFF_SUBMISSION_UPDATE') {
      target = staff?['siteUrl']?.toString();
    } else if (type == 'CHARACTER_SUBMISSION_UPDATE') {
      target = character?['siteUrl']?.toString();
    }

    final uri = Uri.tryParse(target ?? '');
    if (uri != null && (uri.scheme == 'https' || uri.scheme == 'http')) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Widget _fallback(IconData icon) => ColoredBox(
    color: AppColors.surface2,
    child: Icon(icon, color: AppColors.textSecondary, size: 22),
  );
}
