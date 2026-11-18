import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/di/injector.dart';
import '../auth/auth_screens.dart';
import '../../core/supabase/supabase_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';

class MenuPollsScreen extends StatefulWidget {
  const MenuPollsScreen({super.key});
  @override State<MenuPollsScreen> createState() => _MenuPollsScreenState();
}

class _MenuPollsScreenState extends State<MenuPollsScreen> {
  SupabaseClient get _client => sl<SupabaseService>().client;
  List<Map<String, dynamic>> _polls = [];
  bool _loading = true;
  String? _error;
  String? get _userId => sl<SupabaseService>().currentUserId();

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    if (_userId == null) {
      if (mounted) setState(() { _error = 'Login diperlukan untuk melihat polling komunitas.'; _loading = false; });
      return;
    }
    try {
      final rows = await _client.from('community_polls').select('id,question,description,created_at,creator_id,community_poll_options(id,label,position),community_poll_votes(option_id,user_id)').order('created_at', ascending: false).limit(50);
      if (mounted) setState(() => _polls = List<Map<String, dynamic>>.from(rows));
    } catch (_) {
      if (mounted) setState(() => _error = 'Polling komunitas belum tersedia. Pastikan migrasi Supabase AnimeW sudah diterapkan dan kamu sudah login.');
    } finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _openLogin() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
    );
    if (mounted) await _load();
  }

  Future<void> _create() async {
    if (_userId == null) {
      requireLogin(context, action: 'membuat polling');
      return;
    }
    final question = TextEditingController();
    final options = List.generate(4, (_) => TextEditingController());
    final result = await showDialog<(String, List<String>)>(context: context, builder: (context) => AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text('Buat polling'),
      content: SizedBox(width: 440, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: question, maxLength: 180, decoration: const InputDecoration(labelText: 'Pertanyaan')),
        for (var i = 0; i < options.length; i++) Padding(padding: const EdgeInsets.only(top: 8), child: TextField(controller: options[i], maxLength: 90, decoration: InputDecoration(labelText: 'Pilihan ${i + 1}'))),
      ]))),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')), FilledButton(onPressed: () => Navigator.pop(context, (question.text.trim(), options.map((e) => e.text.trim()).where((e) => e.isNotEmpty).toList())), child: const Text('Terbitkan'))],
    ));
    question.dispose(); for (final c in options) { c.dispose(); }
    if (result == null || result.$1.length < 4 || result.$2.length < 2) {
      if (result != null && mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Isi pertanyaan dan minimal dua pilihan.')));
      return;
    }
    String? createdPollId;
    try {
      final inserted = await _client.from('community_polls').insert({'creator_id': _userId, 'question': result.$1}).select('id').single();
      final pollId = inserted['id'];
      createdPollId = pollId?.toString();
      await _client.from('community_poll_options').insert([
        for (var i = 0; i < result.$2.length; i++) {'poll_id': pollId, 'label': result.$2[i], 'position': i}
      ]);
      await _load();
    } catch (_) {
      if (createdPollId != null) {
        try { await _client.from('community_polls').delete().eq('id', createdPollId!); } catch (_) {}
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Polling gagal dibuat. Periksa koneksi dan migrasi backend.')));
    }
  }

  Future<void> _vote(Map<String, dynamic> poll, String optionId) async {
    final userId = _userId;
    if (userId == null) {
      requireLogin(context, action: 'memilih polling');
      return;
    }
    try {
      await _client.from('community_poll_votes').upsert({'poll_id': poll['id'], 'option_id': optionId, 'user_id': userId}, onConflict: 'poll_id,user_id');
      await _load();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Suara gagal disimpan.')));
    }
  }

  @override Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.bg,
    appBar: AppBar(backgroundColor: AppColors.bg, foregroundColor: AppColors.textPrimary, title: Text('Polling Komunitas', style: AppText.title.copyWith(color: AppColors.textPrimary)), actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))]),
    floatingActionButton: FloatingActionButton.extended(onPressed: _create, backgroundColor: AppColors.accent, foregroundColor: Colors.white, icon: const Icon(Icons.add), label: const Text('Buat polling')),
    body: RefreshIndicator(onRefresh: _load, child: _loading ? const ListView(children: [SizedBox(height: 280, child: Center(child: CircularProgressIndicator()))]) : _error != null ? ListView(children: [Padding(padding: const EdgeInsets.all(24), child: Column(children: [Text(_error!, textAlign: TextAlign.center, style: AppText.body.copyWith(color: AppColors.textSecondary)), if (_userId == null) Padding(padding: const EdgeInsets.only(top: 12), child: FilledButton(onPressed: _openLogin, child: const Text('Masuk')))]))]) : _polls.isEmpty ? ListView(children: [Padding(padding: const EdgeInsets.all(24), child: Text('Belum ada polling. Buat polling pertama!', style: AppText.body.copyWith(color: AppColors.textSecondary)))]) : ListView.separated(padding: const EdgeInsets.fromLTRB(14, 12, 14, 90), itemCount: _polls.length, separatorBuilder: (_, __) => const SizedBox(height: 10), itemBuilder: (_, i) => _PollCard(poll: _polls[i], userId: _userId, onVote: (id) => _vote(_polls[i], id)))),
  );
}

class _PollCard extends StatelessWidget {
  const _PollCard({required this.poll, required this.userId, required this.onVote});
  final Map<String, dynamic> poll;
  final String? userId;
  final ValueChanged<String> onVote;
  @override Widget build(BuildContext context) {
    final options = (poll['community_poll_options'] as List? ?? const []).whereType<Map>().toList()..sort((a,b) => ((a['position'] as num?)?.toInt() ?? 0).compareTo((b['position'] as num?)?.toInt() ?? 0));
    final votes = (poll['community_poll_votes'] as List? ?? const []).whereType<Map>().toList();
    final myVotes = votes.where((v) => v['user_id'] == userId).map((v) => v['option_id']?.toString()).toList();
    final selected = myVotes.isEmpty ? null : myVotes.first;
    final total = votes.length;
    return Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(poll['question']?.toString() ?? '', style: AppText.body.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w800)),
      const SizedBox(height: 12),
      for (final option in options) Builder(builder: (_) {
        final id = option['id'].toString();
        final count = votes.where((v) => v['option_id']?.toString() == id).length;
        final percent = total == 0 ? 0.0 : count / total;
        return Padding(padding: const EdgeInsets.only(bottom: 8), child: InkWell(onTap: selected == null ? () => onVote(id) : null, borderRadius: BorderRadius.circular(10), child: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(10), border: Border.all(color: selected == id ? AppColors.accent : Colors.transparent)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Expanded(child: Text(option['label']?.toString() ?? '', style: AppText.caption.copyWith(color: AppColors.textPrimary))), Text('${(percent * 100).round()}% · $count', style: AppText.caption.copyWith(color: AppColors.textSecondary))]),
          const SizedBox(height: 6),
          ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(value: percent, minHeight: 5, color: AppColors.accent, backgroundColor: AppColors.bg)),
        ]))));
      }),
      Text(total == 1 ? '1 suara' : '$total suara', style: AppText.caption.copyWith(color: AppColors.textTertiary)),
    ]));
  }
}
