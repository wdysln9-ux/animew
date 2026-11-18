import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/di/injector.dart';
import '../../core/supabase/supabase_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';

class MenuMessagesScreen extends StatefulWidget {
  const MenuMessagesScreen({super.key});
  @override State<MenuMessagesScreen> createState() => _MenuMessagesScreenState();
}

class _MenuMessagesScreenState extends State<MenuMessagesScreen> {
  final _sb = sl<SupabaseService>();
  List<Map<String, dynamic>> _conversations = [];
  bool _loading = true;
  String? _error;
  String? get _uid => _sb.currentUserId();

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final uid = _uid;
    if (uid == null) {
      setState(() { _loading = false; _error = 'Login diperlukan untuk menggunakan pesan pribadi.'; });
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final rows = await _sb.client.from('community_messages').select('id,sender_id,recipient_id,body,created_at,read_at').or('sender_id.eq.$uid,recipient_id.eq.$uid').order('created_at', ascending: false).limit(500);
      final messages = List<Map<String, dynamic>>.from(rows);
      final latest = <String, Map<String, dynamic>>{};
      for (final m in messages) {
        final other = m['sender_id'] == uid ? m['recipient_id'].toString() : m['sender_id'].toString();
        latest.putIfAbsent(other, () => {...m, 'other_id': other});
      }
      final ids = latest.keys.toList();
      if (ids.isNotEmpty) {
        final profiles = await _sb.client.from('public_profiles').select('id,display_name,avatar_path').inFilter('id', ids);
        for (final p in profiles) {
          final id = p['id']?.toString();
          if (id != null && latest.containsKey(id)) latest[id]!['profile'] = p;
        }
      }
      if (mounted) setState(() => _conversations = latest.values.toList());
    } catch (_) {
      if (mounted) setState(() => _error = 'Pesan belum tersedia. Pastikan migrasi Supabase komunitas sudah diterapkan.');
    } finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _newMessage() async {
    final uid = _uid;
    if (uid == null) return;
    final query = TextEditingController();
    List<Map<String, dynamic>> users = [];
    bool searching = false;
    final selected = await showDialog<Map<String, dynamic>>(context: context, builder: (dialogContext) => StatefulBuilder(builder: (context, setDialog) => AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text('Pesan baru'),
      content: SizedBox(width: 420, height: 360, child: Column(children: [
        TextField(controller: query, decoration: InputDecoration(hintText: 'Cari nama pengguna', suffixIcon: IconButton(onPressed: () async {
          if (query.text.trim().isEmpty) return;
          setDialog(() => searching = true);
          try {
            final rows = await _sb.client.from('public_profiles').select('id,display_name,avatar_path').ilike('display_name', '%${query.text.trim()}%').neq('id', uid).limit(30);
            users = List<Map<String, dynamic>>.from(rows);
          } catch (_) { users = []; }
          setDialog(() => searching = false);
        }, icon: const Icon(Icons.search)))),
        const SizedBox(height: 10),
        Expanded(child: searching ? const Center(child: CircularProgressIndicator()) : ListView.builder(itemCount: users.length, itemBuilder: (_, i) {
          final user = users[i];
          return ListTile(title: Text(user['display_name']?.toString() ?? 'Pengguna'), leading: const CircleAvatar(child: Icon(Icons.person)), onTap: () => Navigator.pop(dialogContext, user));
        })),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Tutup'))],
    )));
    query.dispose();
    if (selected == null || !mounted) return;
    await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => _ConversationScreen(profile: selected)));
    _load();
  }

  @override Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.bg,
    appBar: AppBar(backgroundColor: AppColors.bg, foregroundColor: AppColors.textPrimary, title: Text('Pesan', style: AppText.title.copyWith(color: AppColors.textPrimary)), actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))]),
    floatingActionButton: FloatingActionButton(onPressed: _newMessage, backgroundColor: AppColors.accent, foregroundColor: Colors.white, child: const Icon(Icons.edit)),
    body: RefreshIndicator(onRefresh: _load, child: _loading ? const ListView(children: [SizedBox(height: 280, child: Center(child: CircularProgressIndicator()))]) : _error != null ? ListView(children: [Padding(padding: const EdgeInsets.all(24), child: Text(_error!, style: AppText.body.copyWith(color: AppColors.textSecondary)))]) : _conversations.isEmpty ? ListView(children: [Padding(padding: const EdgeInsets.all(24), child: Text('Belum ada percakapan. Tekan tombol pesan baru untuk memulai.', style: AppText.body.copyWith(color: AppColors.textSecondary)))]) : ListView.separated(padding: const EdgeInsets.all(12), itemCount: _conversations.length, separatorBuilder: (_, __) => const SizedBox(height: 8), itemBuilder: (_, i) {
      final c = _conversations[i]; final p = c['profile'] is Map ? c['profile'] as Map : const {};
      return ListTile(
        tileColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        leading: const CircleAvatar(child: Icon(Icons.person)),
        title: Text(p['display_name']?.toString() ?? 'Pengguna', style: AppText.body.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
        subtitle: Text(c['body']?.toString() ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.caption.copyWith(color: AppColors.textSecondary)),
        onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => _ConversationScreen(profile: {'id': c['other_id'], 'display_name': p['display_name'] ?? 'Pengguna'}))).then((_) => _load()),
      );
    })),
  );
}

class _ConversationScreen extends StatefulWidget {
  const _ConversationScreen({required this.profile});
  final Map<String, dynamic> profile;
  @override State<_ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<_ConversationScreen> {
  final _sb = sl<SupabaseService>();
  final _input = TextEditingController();
  final _scroll = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true, _sending = false;
  RealtimeChannel? _channel;
  String? get _uid => _sb.currentUserId();
  String get _other => widget.profile['id'].toString();

  @override void initState() {
    super.initState();
    _load();
    final uid = _uid ?? 'unknown';
    _channel = _sb.client.channel('dm:$uid:$_other')
      ..onPostgresChanges(event: PostgresChangeEvent.insert, schema: 'public', table: 'community_messages', callback: (_) => _load())
      ..subscribe();
  }

  Future<void> _load() async {
    final uid = _uid;
    if (uid == null) return;
    try {
      final sent = await _sb.client.from('community_messages').select('id,sender_id,recipient_id,body,created_at').eq('sender_id', uid).eq('recipient_id', _other);
      final received = await _sb.client.from('community_messages').select('id,sender_id,recipient_id,body,created_at').eq('sender_id', _other).eq('recipient_id', uid);
      final all = [...List<Map<String, dynamic>>.from(sent), ...List<Map<String, dynamic>>.from(received)];
      all.sort((a,b) => DateTime.parse(a['created_at'].toString()).compareTo(DateTime.parse(b['created_at'].toString())));
      if (mounted) setState(() { _messages = all; _loading = false; });
      await _sb.client.from('community_messages').update({'read_at': DateTime.now().toUtc().toIso8601String()}).eq('sender_id', _other).eq('recipient_id', uid).isFilter('read_at', null);
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _send() async {
    final uid = _uid;
    final body = _input.text.trim();
    if (uid == null || body.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await _sb.client.from('community_messages').insert({'sender_id': uid, 'recipient_id': _other, 'body': body});
      _input.clear();
      await _load();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pesan gagal dikirim.')));
    } finally { if (mounted) setState(() => _sending = false); }
  }

  @override void dispose() {
    _input.dispose(); _scroll.dispose();
    final channel = _channel;
    if (channel != null) _sb.client.removeChannel(channel);
    super.dispose();
  }

  @override Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.bg,
    appBar: AppBar(backgroundColor: AppColors.bg, foregroundColor: AppColors.textPrimary, title: Text(widget.profile['display_name']?.toString() ?? 'Percakapan')),
    body: Column(children: [
      Expanded(child: _loading ? const Center(child: CircularProgressIndicator()) : ListView.builder(controller: _scroll, padding: const EdgeInsets.all(12), itemCount: _messages.length, itemBuilder: (_, i) {
        final m = _messages[i]; final mine = m['sender_id'] == _uid;
        return Align(alignment: mine ? Alignment.centerRight : Alignment.centerLeft, child: Container(margin: const EdgeInsets.symmetric(vertical: 4), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9), constraints: const BoxConstraints(maxWidth: 300), decoration: BoxDecoration(color: mine ? AppColors.accent.withValues(alpha: .2) : AppColors.surface, borderRadius: BorderRadius.circular(14)), child: Text(m['body']?.toString() ?? '', style: AppText.body.copyWith(color: AppColors.textPrimary))));
      })),
      SafeArea(top: false, child: Padding(padding: const EdgeInsets.all(10), child: Row(children: [
        Expanded(child: TextField(controller: _input, minLines: 1, maxLines: 4, decoration: const InputDecoration(hintText: 'Tulis pesan...'))),
        const SizedBox(width: 8),
        IconButton.filled(onPressed: _sending ? null : _send, icon: _sending ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send)),
      ]))),
    ]),
  );
}
