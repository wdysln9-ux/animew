import 'dart:convert';
import 'package:flutter/material.dart';
import '../../core/anilist/anilist_service.dart';
import '../../core/di/injector.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';

class MenuForumScreen extends StatefulWidget {
  const MenuForumScreen({super.key});
  @override State<MenuForumScreen> createState() => _MenuForumScreenState();
}

class _MenuForumScreenState extends State<MenuForumScreen> {
  final _api = sl<AniListService>().api;
  List<Map<String, dynamic>> _threads = [];
  bool _loading = true;
  String? _error;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final rows = await _api.fetchGlobalThreads();
      if (mounted) setState(() => _threads = rows);
    } catch (_) {
      if (mounted) setState(() => _error = 'Forum AniList tidak bisa dimuat. Coba lagi nanti.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _create() async {
    final service = sl<AniListService>();
    if (!service.isConnected && !await service.connect()) return;
    final title = TextEditingController();
    final body = TextEditingController();
    final data = await showDialog<(String, String)>(context: context, builder: (context) => AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text('Buat thread'),
      content: SizedBox(width: 420, child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: title, maxLength: 100, decoration: const InputDecoration(labelText: 'Judul diskusi')),
        const SizedBox(height: 10),
        TextField(controller: body, minLines: 4, maxLines: 8, decoration: const InputDecoration(labelText: 'Isi diskusi')),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
        FilledButton(onPressed: () => Navigator.pop(context, (title.text.trim(), body.text.trim())), child: const Text('Terbitkan')),
      ],
    ));
    title.dispose(); body.dispose();
    if (data == null) return;
    if (data.$1.length < 6 || data.$2.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Judul minimal 6 karakter dan isi diskusi tidak boleh kosong.')));
      return;
    }
    try {
      final id = await _api.createThread(title: data.$1, body: data.$2);
      if (id == null) throw StateError('CreateThread failed');
      await _load();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal menerbitkan thread.')));
    }
  }

  @override Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.bg,
    appBar: AppBar(backgroundColor: AppColors.bg, foregroundColor: AppColors.textPrimary, title: Text('Forum AniList', style: AppText.title.copyWith(color: AppColors.textPrimary)), actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))]),
    floatingActionButton: FloatingActionButton.extended(onPressed: _create, backgroundColor: AppColors.accent, foregroundColor: Colors.white, icon: const Icon(Icons.add_comment), label: const Text('Buat thread')),
    body: RefreshIndicator(onRefresh: _load, child: _loading
      ? const ListView(children: [SizedBox(height: 300, child: Center(child: CircularProgressIndicator()))])
      : _error != null
        ? ListView(children: [Padding(padding: const EdgeInsets.all(24), child: Text(_error!, style: AppText.body.copyWith(color: AppColors.textSecondary)))])
        : _threads.isEmpty
          ? ListView(children: [Padding(padding: const EdgeInsets.all(24), child: Text('Belum ada diskusi.', style: AppText.body.copyWith(color: AppColors.textSecondary)))])
          : ListView.separated(padding: const EdgeInsets.fromLTRB(14, 12, 14, 90), itemCount: _threads.length, separatorBuilder: (_, __) => const SizedBox(height: 10), itemBuilder: (context, i) {
              final thread = _threads[i];
              return _ThreadCard(thread: thread, onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => _ThreadDetailScreen(thread: thread))));
            }),
    ),
  );
}

String _plain(String? s) => (s ?? '').replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n').replaceAll(RegExp(r'</p>', caseSensitive: false), '\n').replaceAll(RegExp(r'<[^>]*>'), '').replaceAll('&amp;', '&').replaceAll('&quot;', '"').trim();

class _ThreadCard extends StatelessWidget {
  const _ThreadCard({required this.thread, required this.onTap});
  final Map<String, dynamic> thread;
  final VoidCallback onTap;
  @override Widget build(BuildContext context) {
    final user = thread['user'] is Map ? thread['user'] as Map : const {};
    final avatar = user['avatar'] is Map ? (user['avatar'] as Map)['large'] as String? : null;
    return Material(color: AppColors.surface, borderRadius: BorderRadius.circular(16), child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(16), child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [CircleAvatar(radius: 15, backgroundImage: avatar == null ? null : NetworkImage(avatar), child: avatar == null ? const Icon(Icons.person, size: 16) : null), const SizedBox(width: 8), Expanded(child: Text(user['name']?.toString() ?? 'AniList user', style: AppText.caption.copyWith(color: AppColors.textSecondary))), Text('${thread['replyCount'] ?? 0} balasan', style: AppText.caption.copyWith(color: AppColors.textTertiary))]),
      const SizedBox(height: 10),
      Text(thread['title']?.toString() ?? 'Tanpa judul', style: AppText.body.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w800)),
      const SizedBox(height: 6),
      Text(_plain(thread['body']?.toString()), maxLines: 3, overflow: TextOverflow.ellipsis, style: AppText.caption.copyWith(color: AppColors.textSecondary, height: 1.4)),
      const SizedBox(height: 8),
      Text('♥ ${thread['likeCount'] ?? 0}    •    ${thread['viewCount'] ?? 0} dilihat', style: AppText.caption.copyWith(color: AppColors.textTertiary)),
    ]))));
  }
}

class _ThreadDetailScreen extends StatefulWidget {
  const _ThreadDetailScreen({required this.thread});
  final Map<String, dynamic> thread;
  @override State<_ThreadDetailScreen> createState() => _ThreadDetailScreenState();
}

class _ThreadDetailScreenState extends State<_ThreadDetailScreen> {
  final _api = sl<AniListService>().api;
  final _input = TextEditingController();
  List<Map<String, dynamic>> _comments = [];
  bool _loading = true, _sending = false;
  late bool _liked;
  late int _likes;

  @override void initState() {
    super.initState();
    _liked = widget.thread['isLiked'] == true;
    _likes = (widget.thread['likeCount'] as num?)?.toInt() ?? 0;
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await _api.fetchThreadComments((widget.thread['id'] as num).toInt());
      if (mounted) setState(() => _comments = rows);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _like() async {
    final service = sl<AniListService>();
    if (!service.isConnected && !await service.connect()) return;
    final ok = await _api.toggleThreadLike((widget.thread['id'] as num).toInt());
    if (ok && mounted) setState(() { _liked = !_liked; _likes += _liked ? 1 : -1; });
  }

  Future<void> _send() async {
    if (_input.text.trim().isEmpty || _sending) return;
    final service = sl<AniListService>();
    if (!service.isConnected && !await service.connect()) return;
    setState(() => _sending = true);
    try {
      final id = await _api.createThreadComment(threadId: (widget.thread['id'] as num).toInt(), comment: _input.text);
      if (id == null) throw StateError('Comment failed');
      _input.clear();
      await _load();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Komentar gagal dikirim.')));
    } finally { if (mounted) setState(() => _sending = false); }
  }

  Future<void> _reply(Map<String, dynamic> parent) async {
    final service = sl<AniListService>();
    if (!service.isConnected && !await service.connect()) return;
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Balas komentar'),
        content: TextField(controller: controller, autofocus: true, minLines: 2, maxLines: 5, maxLength: 12000, decoration: const InputDecoration(hintText: 'Tulis balasan...')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Kirim')),
        ],
      ),
    );
    controller.dispose();
    if (text == null || text.trim().isEmpty) return;
    try {
      final id = await _api.createThreadComment(
        threadId: (widget.thread['id'] as num).toInt(),
        parentCommentId: (parent['id'] as num).toInt(),
        comment: text,
      );
      if (id == null) throw StateError('Reply failed');
      await _load();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Balasan gagal dikirim.')));
    }
  }

  @override void dispose() { _input.dispose(); super.dispose(); }

  @override Widget build(BuildContext context) {
    final user = widget.thread['user'] is Map ? widget.thread['user'] as Map : const {};
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(backgroundColor: AppColors.bg, foregroundColor: AppColors.textPrimary, title: const Text('Diskusi')),
      body: Column(children: [
        Expanded(child: ListView(padding: const EdgeInsets.all(16), children: [
          Text(widget.thread['title']?.toString() ?? '', style: AppText.headline.copyWith(color: AppColors.textPrimary, fontSize: 22)),
          const SizedBox(height: 8),
          Text('Oleh ${user['name'] ?? 'AniList user'}', style: AppText.caption.copyWith(color: AppColors.textTertiary)),
          const SizedBox(height: 14),
          Text(_plain(widget.thread['body']?.toString()), style: AppText.body.copyWith(color: AppColors.textSecondary, height: 1.5)),
          Align(alignment: Alignment.centerLeft, child: TextButton.icon(onPressed: _like, icon: Icon(_liked ? Icons.favorite : Icons.favorite_border, color: AppColors.accent), label: Text('$_likes suka'))),
          const Divider(),
          Text('Komentar', style: AppText.title.copyWith(color: AppColors.textPrimary)),
          if (_loading) const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())),
          if (!_loading && _comments.isEmpty) Text('Belum ada komentar.', style: AppText.caption.copyWith(color: AppColors.textTertiary)),
          for (final c in _comments) _CommentCard(comment: c, onReply: () => _reply(c)),
        ])),
        SafeArea(top: false, child: Padding(padding: const EdgeInsets.all(10), child: Row(children: [
          Expanded(child: TextField(controller: _input, minLines: 1, maxLines: 4, decoration: const InputDecoration(hintText: 'Tulis komentar...'))),
          const SizedBox(width: 8),
          IconButton.filled(onPressed: _sending ? null : _send, icon: _sending ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send)),
        ]))),
      ]),
    );
  }
}

List<Map<String, dynamic>> _threadReplies(dynamic raw) {
  dynamic decoded = raw;
  if (raw is String && raw.trim().isNotEmpty) {
    try { decoded = jsonDecode(raw); } catch (_) { return const []; }
  }
  if (decoded is Map && decoded['nodes'] is List) decoded = decoded['nodes'];
  if (decoded is! List) return const [];
  return [for (final item in decoded) if (item is Map) Map<String, dynamic>.from(item)];
}

class _CommentCard extends StatelessWidget {
  const _CommentCard({required this.comment, required this.onReply});
  final Map<String, dynamic> comment;
  final VoidCallback onReply;
  @override Widget build(BuildContext context) {
    final user = comment['user'] is Map ? comment['user'] as Map : const {};
    final replies = _threadReplies(comment['childComments']);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(user['name']?.toString() ?? 'Pengguna', style: AppText.caption.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
            const SizedBox(height: 5),
            Text(_plain(comment['comment']?.toString()), style: AppText.caption.copyWith(color: AppColors.textSecondary, height: 1.4)),
            Align(alignment: Alignment.centerRight, child: TextButton.icon(onPressed: onReply, icon: const Icon(Icons.reply_rounded, size: 16), label: const Text('Balas'))),
          ]),
        ),
        for (final reply in replies)
          Padding(
            padding: const EdgeInsets.only(left: 20, top: 6),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(10)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(((reply['user'] as Map?)?['name'] ?? reply['name'] ?? 'Pengguna').toString(), style: AppText.caption.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(_plain((reply['comment'] ?? reply['text'])?.toString()), style: AppText.caption.copyWith(color: AppColors.textSecondary, height: 1.4)),
              ]),
            ),
          ),
      ]),
    );
  }
}
