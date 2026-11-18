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

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.bg,
    appBar: AppBar(
      backgroundColor: AppColors.bg,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      title: Text('Forum', style: AppText.title.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w800)),
      actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded))],
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _create,
      backgroundColor: AppColors.accent,
      foregroundColor: Colors.white,
      icon: const Icon(Icons.edit_rounded),
      label: const Text('Mulai diskusi'),
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
                  Text('OPEN DISCUSSIONS', style: AppText.caption.copyWith(color: AppColors.accent, fontWeight: FontWeight.w900, letterSpacing: 1)),
                  const SizedBox(height: 7),
                  Text('Punya teori? Bahas di sini.', style: AppText.title.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text('Temukan sudut pandang dan rekomendasi baru.', style: AppText.caption.copyWith(color: AppColors.textSecondary)),
                ])),
                const SizedBox(width: 8),
                Icon(Icons.forum_rounded, color: AppColors.accent, size: 40),
              ]),
            ),
          )),
          if (_loading)
            const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
          else if (_error != null)
            SliverFillRemaining(child: Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, style: AppText.body.copyWith(color: AppColors.textSecondary)))))
          else if (_threads.isEmpty)
            SliverFillRemaining(child: Center(child: Text('Belum ada diskusi.', style: AppText.body.copyWith(color: AppColors.textSecondary))))
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 100),
              sliver: SliverList(delegate: SliverChildBuilderDelegate(
                (context, i) => Padding(
                  padding: const EdgeInsets.only(bottom: 11),
                  child: _ThreadCard(thread: _threads[i], onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => _ThreadDetailScreen(thread: _threads[i])))),
                ),
                childCount: _threads.length,
              )),
            ),
        ],
      ),
    ),
  );
}

String _plain(String? s) => (s ?? '').replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n').replaceAll(RegExp(r'</p>', caseSensitive: false), '\n').replaceAll(RegExp(r'<[^>]*>'), '').replaceAll('&amp;', '&').replaceAll('&quot;', '"').trim();

class _ThreadCard extends StatelessWidget {
  const _ThreadCard({required this.thread, required this.onTap});
  final Map<String, dynamic> thread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final user = thread['user'] is Map ? thread['user'] as Map : const {};
    final avatar = user['avatar'] is Map ? (user['avatar'] as Map)['large'] as String? : null;
    final categories = thread['categories'] is List ? (thread['categories'] as List).whereType<Map>().map((e) => e['name']?.toString() ?? '').where((e) => e.isNotEmpty).take(2).toList() : <String>[];
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(19),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: const EdgeInsets.all(15), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(radius: 16, backgroundColor: AppColors.surface2, backgroundImage: avatar == null ? null : NetworkImage(avatar), child: avatar == null ? const Icon(Icons.person_rounded, size: 16) : null),
            const SizedBox(width: 9),
            Expanded(child: Text(user['name']?.toString() ?? 'AniList user', style: AppText.caption.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w700))),
            Text('${thread['replyCount'] ?? 0} balasan', style: AppText.caption.copyWith(color: AppColors.textTertiary, fontSize: 10)),
          ]),
          const SizedBox(height: 12),
          Text(thread['title']?.toString() ?? 'Tanpa judul', style: AppText.title.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w800, height: 1.25)),
          const SizedBox(height: 7),
          Text(_plain(thread['body']?.toString()), maxLines: 3, overflow: TextOverflow.ellipsis, style: AppText.caption.copyWith(color: AppColors.textSecondary, height: 1.45)),
          if (categories.isNotEmpty) ...[
            const SizedBox(height: 11),
            Wrap(spacing: 6, runSpacing: 6, children: [for (final category in categories) Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5), decoration: BoxDecoration(color: AppColors.accentSoft, borderRadius: BorderRadius.circular(8)), child: Text(category, style: AppText.caption.copyWith(color: AppColors.accent, fontSize: 10, fontWeight: FontWeight.w700)))]),
          ],
          const SizedBox(height: 11),
          Row(children: [
            Icon(Icons.favorite_border_rounded, size: 15, color: AppColors.textTertiary),
            const SizedBox(width: 5),
            Text('${thread['likeCount'] ?? 0}', style: AppText.caption.copyWith(color: AppColors.textTertiary, fontSize: 10)),
            const SizedBox(width: 13),
            Icon(Icons.visibility_outlined, size: 15, color: AppColors.textTertiary),
            const SizedBox(width: 5),
            Text('${thread['viewCount'] ?? 0}', style: AppText.caption.copyWith(color: AppColors.textTertiary, fontSize: 10)),
            const Spacer(),
            Icon(Icons.arrow_forward_rounded, size: 17, color: AppColors.accent),
          ]),
        ])),
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    final user = widget.thread['user'] is Map ? widget.thread['user'] as Map : const {};
    final avatar = user['avatar'] is Map ? (user['avatar'] as Map)['large'] as String? : null;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(backgroundColor: AppColors.bg, foregroundColor: AppColors.textPrimary, elevation: 0, title: const Text('Diskusi')),
      body: Column(children: [
        Expanded(child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 18), children: [
          Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(22), border: Border.all(color: AppColors.hairline)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('FORUM THREAD', style: AppText.caption.copyWith(color: AppColors.accent, fontWeight: FontWeight.w900, letterSpacing: 1)),
            const SizedBox(height: 10),
            Text(widget.thread['title']?.toString() ?? '', style: AppText.headline.copyWith(color: AppColors.textPrimary, fontSize: 23, fontWeight: FontWeight.w900, height: 1.2)),
            const SizedBox(height: 14),
            Row(children: [
              CircleAvatar(radius: 17, backgroundColor: AppColors.surface2, backgroundImage: avatar == null ? null : NetworkImage(avatar), child: avatar == null ? const Icon(Icons.person_rounded, size: 17) : null),
              const SizedBox(width: 9),
              Expanded(child: Text(user['name']?.toString() ?? 'AniList user', style: AppText.caption.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w700))),
              Text('${widget.thread['replyCount'] ?? 0} balasan', style: AppText.caption.copyWith(color: AppColors.textTertiary, fontSize: 10)),
            ]),
            const SizedBox(height: 16),
            Text(_plain(widget.thread['body']?.toString()), style: AppText.body.copyWith(color: AppColors.textSecondary, height: 1.65)),
            const SizedBox(height: 12),
            Align(alignment: Alignment.centerLeft, child: FilledButton.tonalIcon(
              onPressed: _like,
              icon: Icon(_liked ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: AppColors.accent),
              label: Text('$_likes suka'),
              style: FilledButton.styleFrom(foregroundColor: AppColors.accent, backgroundColor: AppColors.accentSoft),
            )),
          ])),
          const SizedBox(height: 20),
          Row(children: [
            Text('Komentar', style: AppText.title.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w800)),
            const SizedBox(width: 8),
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(8)), child: Text('${_comments.length}', style: AppText.caption.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w800))),
          ]),
          const SizedBox(height: 10),
          if (_loading) const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())),
          if (!_loading && _comments.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 18), child: Text('Jadi yang pertama ikut berdiskusi.', style: AppText.caption.copyWith(color: AppColors.textTertiary))),
          for (final comment in _comments) _CommentCard(comment: comment, onReply: () => _reply(comment)),
        ])),
        SafeArea(top: false, child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(color: AppColors.bg, border: Border(top: BorderSide(color: AppColors.hairline))),
          child: Row(children: [
            Expanded(child: TextField(controller: _input, minLines: 1, maxLines: 4, decoration: InputDecoration(hintText: 'Tulis komentar...', filled: true, fillColor: AppColors.surface, contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12), border: OutlineInputBorder(borderRadius: BorderRadius.circular(17), borderSide: BorderSide.none)))),
            const SizedBox(width: 8),
            IconButton.filled(onPressed: _sending ? null : _send, style: IconButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.white), icon: _sending ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.arrow_upward_rounded)),
          ]),
        )),
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
