import 'dart:math';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../core/anilist/anilist_service.dart';
import '../../core/di/injector.dart';
import '../../core/hive/safe_box.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';

const _boxName = 'menu_tools_data';

Future<Box> _openMenuToolsBox() async {
  return Hive.isBoxOpen(_boxName) ? Hive.box(_boxName) : openBoxSafely(_boxName);
}

class MenuToolsScreen extends StatelessWidget {
  const MenuToolsScreen({super.key, required this.featureId});
  final String featureId;

  @override
  Widget build(BuildContext context) {
    return switch (featureId) {
      'journal' => const _JournalScreen(),
      'challenge' => const _ChallengeScreen(),
      'games' => const _TicTacToeScreen(),
      'roulette' => const _AnimeRouletteScreen(),
      'random-character' => const _RandomCharacterScreen(),
      _ => const _UnavailableMenuToolScreen(),
    };
  }
}

class _BasePage extends StatelessWidget {
  const _BasePage({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          backgroundColor: AppColors.bg,
          foregroundColor: AppColors.textPrimary,
          title: Text(title, style: AppText.title.copyWith(color: AppColors.textPrimary)),
        ),
        body: SafeArea(child: child),
      );
}

class _JournalScreen extends StatefulWidget {
  const _JournalScreen();
  @override
  State<_JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<_JournalScreen> {
  List<Map<String, dynamic>> _entries = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final box = await _openMenuToolsBox();
    final raw = box.get('journal');
    if (!mounted) return;
    setState(() {
      _entries = raw is List
          ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
          : [];
      _loading = false;
    });
  }

  Future<void> _save() async {
    final box = await _openMenuToolsBox();
    await box.put('journal', _entries);
  }

  Future<void> _edit({int? index}) async {
    final old = index == null ? null : _entries[index];
    final title = TextEditingController(text: old?['title'] as String? ?? '');
    final note = TextEditingController(text: old?['note'] as String? ?? '');
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(index == null ? 'Catatan baru' : 'Edit catatan', style: AppText.title.copyWith(color: AppColors.textPrimary)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: title, decoration: const InputDecoration(labelText: 'Judul anime')),
          const SizedBox(height: 10),
          TextField(controller: note, minLines: 3, maxLines: 6, decoration: const InputDecoration(labelText: 'Catatan / kesan')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(context, {'title': title.text.trim(), 'note': note.text.trim()}), child: const Text('Simpan')),
        ],
      ),
    );
    title.dispose();
    note.dispose();
    if (result == null || result['title']!.isEmpty || result['note']!.isEmpty) return;
    setState(() {
      final entry = {'title': result['title'], 'note': result['note'], 'updatedAt': DateTime.now().millisecondsSinceEpoch};
      if (index == null) {
        _entries.insert(0, entry);
      } else {
        _entries[index] = entry;
      }
    });
    await _save();
  }

  Future<void> _delete(int index) async {
    setState(() => _entries.removeAt(index));
    await _save();
  }

  @override
  Widget build(BuildContext context) => _BasePage(
        title: 'Personal Journal',
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _entries.isEmpty
                ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.edit_note_rounded, size: 54, color: AppColors.textTertiary),
                    const SizedBox(height: 12),
                    Text('Belum ada catatan anime.', style: AppText.body.copyWith(color: AppColors.textSecondary)),
                    const SizedBox(height: 12),
                    FilledButton.icon(onPressed: () => _edit(), icon: const Icon(Icons.add), label: const Text('Buat catatan')),
                  ]))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _entries.length,
                    itemBuilder: (context, index) {
                      final e = _entries[index];
                      return Card(
                        color: AppColors.surface,
                        child: ListTile(
                          title: Text(e['title'] as String? ?? '', style: AppText.body.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
                          subtitle: Padding(padding: const EdgeInsets.only(top: 6), child: Text(e['note'] as String? ?? '', maxLines: 5, overflow: TextOverflow.ellipsis, style: AppText.caption.copyWith(color: AppColors.textSecondary))),
                          onTap: () => _edit(index: index),
                          trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _delete(index)),
                        ),
                      );
                    },
                  ),
        ),
      );
}

class _ChallengeScreen extends StatefulWidget {
  const _ChallengeScreen();
  @override
  State<_ChallengeScreen> createState() => _ChallengeScreenState();
}

class _ChallengeScreenState extends State<_ChallengeScreen> {
  int _goal = 12;
  int _progress = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final box = await _openMenuToolsBox();
    if (!mounted) return;
    setState(() {
      _goal = (box.get('challenge_goal') as int?) ?? 12;
      _progress = (box.get('challenge_progress') as int?) ?? 0;
      _loading = false;
    });
  }

  Future<void> _set(int goal, int progress) async {
    final box = await _openMenuToolsBox();
    await box.put('challenge_goal', goal);
    final safeProgress = progress.clamp(0, goal).toInt();
    await box.put('challenge_progress', safeProgress);
    if (mounted) setState(() { _goal = goal; _progress = safeProgress; });
  }

  @override
  Widget build(BuildContext context) => _BasePage(
        title: 'Anime Challenge',
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(padding: const EdgeInsets.all(20), children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Target menonton', style: AppText.title.copyWith(color: AppColors.textPrimary)),
                    const SizedBox(height: 8),
                    Text('Tentukan target anime yang ingin kamu selesaikan. Progres tersimpan di perangkat ini.', style: AppText.caption.copyWith(color: AppColors.textSecondary)),
                    const SizedBox(height: 22),
                    Center(child: Text('$_progress / $_goal anime', style: AppText.headline.copyWith(color: AppColors.accent, fontSize: 28))),
                    const SizedBox(height: 12),
                    ClipRRect(borderRadius: BorderRadius.circular(20), child: LinearProgressIndicator(value: _goal == 0 ? 0 : _progress / _goal, minHeight: 10, backgroundColor: AppColors.surface2, color: AppColors.accent)),
                    const SizedBox(height: 20),
                    Row(children: [
                      Expanded(child: OutlinedButton(onPressed: _progress > 0 ? () => _set(_goal, _progress - 1) : null, child: const Text('Kurangi'))),
                      const SizedBox(width: 10),
                      Expanded(child: FilledButton(onPressed: _progress < _goal ? () => _set(_goal, _progress + 1) : null, child: const Text('Tambah progres'))),
                    ]),
                  ]),
                ),
                const SizedBox(height: 16),
                ListTile(
                  tileColor: AppColors.surface,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  title: Text('Ubah target', style: AppText.body.copyWith(color: AppColors.textPrimary)),
                  subtitle: Text('Target saat ini: $_goal anime', style: AppText.caption.copyWith(color: AppColors.textSecondary)),
                  trailing: const Icon(Icons.edit_outlined),
                  onTap: () async {
                    final controller = TextEditingController(text: '$_goal');
                    final value = await showDialog<int>(context: context, builder: (context) => AlertDialog(
                      title: const Text('Target anime'),
                      content: TextField(controller: controller, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: 'Contoh: 24')),
                      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')), FilledButton(onPressed: () => Navigator.pop(context, int.tryParse(controller.text)), child: const Text('Simpan'))],
                    ));
                    controller.dispose();
                    if (value != null && value > 0 && value <= 999) await _set(value, _progress);
                  },
                ),
                const SizedBox(height: 10),
                TextButton(onPressed: () => _set(_goal, 0), child: const Text('Reset progres')),
              ]),
      );
}

class _TicTacToeScreen extends StatefulWidget {
  const _TicTacToeScreen();
  @override
  State<_TicTacToeScreen> createState() => _TicTacToeScreenState();
}

class _TicTacToeScreenState extends State<_TicTacToeScreen> {
  List<String> _cells = List.filled(9, '');
  String _turn = 'X';
  String? _winner;

  void _play(int i) {
    if (_cells[i].isNotEmpty || _winner != null) return;
    setState(() {
      _cells[i] = _turn;
      const wins = [[0,1,2],[3,4,5],[6,7,8],[0,3,6],[1,4,7],[2,5,8],[0,4,8],[2,4,6]];
      for (final line in wins) {
        if (_cells[line[0]].isNotEmpty && _cells[line[0]] == _cells[line[1]] && _cells[line[1]] == _cells[line[2]]) {
          _winner = _turn;
          break;
        }
      }
      if (_winner == null && _cells.every((c) => c.isNotEmpty)) _winner = 'Seri';
      if (_winner == null) _turn = _turn == 'X' ? 'O' : 'X';
    });
  }

  void _reset() => setState(() { _cells = List.filled(9, ''); _turn = 'X'; _winner = null; });

  @override
  Widget build(BuildContext context) => _BasePage(
        title: 'Mini Games · Tic-tac-toe',
        child: Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_winner == null ? 'Giliran: $_turn' : (_winner == 'Seri' ? 'Permainan seri!' : 'Pemenang: $_winner'), style: AppText.title.copyWith(color: AppColors.textPrimary)),
          const SizedBox(height: 20),
          SizedBox(width: 300, child: GridView.builder(
            shrinkWrap: true,
            itemCount: 9,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8),
            itemBuilder: (context, i) => InkWell(
              onTap: () => _play(i),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14)),
                child: Center(child: Text(_cells[i], style: TextStyle(fontSize: 42, fontWeight: FontWeight.w800, color: _cells[i] == 'X' ? AppColors.accent : AppColors.textPrimary))),
              ),
            ),
          )),
          const SizedBox(height: 20),
          FilledButton.icon(onPressed: _reset, icon: const Icon(Icons.refresh), label: const Text('Main lagi')),
        ]))),
      );
}

class _AnimeRouletteScreen extends StatefulWidget {
  const _AnimeRouletteScreen();
  @override
  State<_AnimeRouletteScreen> createState() => _AnimeRouletteScreenState();
}

class _AnimeRouletteScreenState extends State<_AnimeRouletteScreen> {
  final _query = TextEditingController(text: 'anime');
  Map<String, dynamic>? _picked;
  bool _loading = false;
  String? _error;

  Future<void> _spin() async {
    setState(() { _loading = true; _error = null; _picked = null; });
    try {
      final rows = await sl<AniListService>().api.searchMedia(_query.text.trim().isEmpty ? 'anime' : _query.text.trim(), perPage: 50);
      if (rows.isEmpty) throw StateError('Tidak ada hasil dari AniList.');
      final valid = rows.where((e) => e['id'] is num).toList();
      if (valid.isEmpty) throw StateError('Data anime tidak lengkap.');
      if (mounted) setState(() => _picked = valid[Random().nextInt(valid.length)]);
    } catch (e) {
      if (mounted) setState(() => _error = 'Gagal mengambil anime. Periksa koneksi lalu coba lagi.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() { _query.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => _BasePage(
        title: 'Anime Roulette',
        child: ListView(padding: const EdgeInsets.all(20), children: [
          Text('Cari anime secara acak dari katalog AniList.', style: AppText.body.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 14),
          TextField(controller: _query, decoration: const InputDecoration(labelText: 'Kata kunci / genre', prefixIcon: Icon(Icons.search))),
          const SizedBox(height: 14),
          FilledButton.icon(onPressed: _loading ? null : _spin, icon: const Icon(Icons.casino), label: Text(_loading ? 'Mengacak...' : 'Putar roulette')),
          if (_loading) const Padding(padding: EdgeInsets.all(28), child: Center(child: CircularProgressIndicator())),
          if (_error != null) Padding(padding: const EdgeInsets.all(16), child: Text(_error!, style: TextStyle(color: AppColors.textSecondary))),
          if (_picked != null) _AnimeResultCard(media: _picked!),
        ]),
      );
}

class _RandomCharacterScreen extends StatefulWidget {
  const _RandomCharacterScreen();
  @override
  State<_RandomCharacterScreen> createState() => _RandomCharacterScreenState();
}

class _RandomCharacterScreenState extends State<_RandomCharacterScreen> {
  Map<String, dynamic>? _media;
  Map<String, dynamic>? _character;
  bool _loading = false;
  String? _error;

  Future<void> _randomize() async {
    setState(() { _loading = true; _error = null; _character = null; });
    try {
      final api = sl<AniListService>().api;
      final titles = await api.searchMedia('anime', perPage: 50);
      final candidates = titles.where((e) => e['id'] is num).toList();
      if (candidates.isEmpty) throw StateError('Tidak ada anime.');
      candidates.shuffle();
      for (final media in candidates.take(8)) {
        final result = await api.mediaCharacters((media['id'] as num).toInt());
        if (result.cast.isEmpty) continue;
        final cast = result.cast;
        final chosen = cast[Random().nextInt(cast.length)];
        if (!mounted) return;
        setState(() {
          _media = media;
          _character = {'name': chosen.name, 'photo': chosen.photo, 'role': chosen.role};
        });
        return;
      }
      throw StateError('Karakter belum tersedia.');
    } catch (_) {
      if (mounted) setState(() => _error = 'Karakter belum bisa dimuat. Coba lagi nanti.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => _BasePage(
        title: 'Random Character',
        child: ListView(padding: const EdgeInsets.all(20), children: [
          Text('Temukan karakter acak dari data karakter AniList.', style: AppText.body.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 14),
          FilledButton.icon(onPressed: _loading ? null : _randomize, icon: const Icon(Icons.shuffle), label: Text(_loading ? 'Mencari karakter...' : 'Acak karakter')),
          if (_loading) const Padding(padding: EdgeInsets.all(28), child: Center(child: CircularProgressIndicator())),
          if (_error != null) Padding(padding: const EdgeInsets.all(16), child: Text(_error!, style: TextStyle(color: AppColors.textSecondary))),
          if (_character != null) _CharacterResultCard(character: _character!, media: _media!),
        ]),
      );
}

class _AnimeResultCard extends StatelessWidget {
  const _AnimeResultCard({required this.media});
  final Map<String, dynamic> media;

  @override
  Widget build(BuildContext context) {
    final title = media['title'] is Map ? media['title'] as Map : const {};
    final name = title['romaji'] ?? title['english'] ?? 'Anime';
    final cover = media['coverImage'] is Map ? (media['coverImage'] as Map)['large'] as String? : null;
    return Card(color: AppColors.surface, margin: const EdgeInsets.only(top: 22), child: Padding(padding: const EdgeInsets.all(14), child: Row(children: [
      if (cover != null) ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.network(cover, width: 92, height: 130, fit: BoxFit.cover, errorBuilder: (_,__,___) => const SizedBox(width: 92, height: 130))),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(name.toString(), style: AppText.title.copyWith(color: AppColors.textPrimary)),
        const SizedBox(height: 8),
        Text('${media['format'] ?? 'Anime'} · ${media['seasonYear'] ?? '-'}', style: AppText.caption.copyWith(color: AppColors.textSecondary)),
        Text('Popularitas: ${media['popularity'] ?? '-'}', style: AppText.caption.copyWith(color: AppColors.textSecondary)),
      ])),
    ])));
  }
}

class _CharacterResultCard extends StatelessWidget {
  const _CharacterResultCard({required this.character, required this.media});
  final Map<String, dynamic> character;
  final Map<String, dynamic> media;

  @override
  Widget build(BuildContext context) {
    final title = media['title'] is Map ? media['title'] as Map : const {};
    final anime = title['romaji'] ?? title['english'] ?? 'Anime';
    final photo = character['photo'] as String?;
    return Card(color: AppColors.surface, margin: const EdgeInsets.only(top: 22), child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (photo != null) Center(child: ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.network(photo, height: 240, fit: BoxFit.contain, errorBuilder: (_,__,___) => const SizedBox(height: 100)))),
      const SizedBox(height: 14),
      Text(character['name'] as String? ?? 'Karakter', style: AppText.title.copyWith(color: AppColors.textPrimary)),
      Text('${character['role'] ?? 'Karakter'} · $anime', style: AppText.caption.copyWith(color: AppColors.textSecondary)),
    ])));
  }
}

class _UnavailableMenuToolScreen extends StatelessWidget {
  const _UnavailableMenuToolScreen();
  @override
  Widget build(BuildContext context) => const _BasePage(title: 'Fitur', child: Center(child: Text('Fitur ini belum tersedia.')));
}
