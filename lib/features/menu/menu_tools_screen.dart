import 'dart:math';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

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
      'guess' => const _GuessCharacterScreen(),
      'quiz' => const _AnimeQuizScreen(),
      'screenshots' => const _ScreenshotGalleryScreen(),
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


class _GuessCharacterScreen extends StatefulWidget {
  const _GuessCharacterScreen();
  @override State<_GuessCharacterScreen> createState() => _GuessCharacterScreenState();
}

class _GuessCharacterScreenState extends State<_GuessCharacterScreen> {
  Map<String, dynamic>? _media;
  dynamic _character;
  final _answer = TextEditingController();
  bool _loading = false, _revealed = false;
  String? _result;

  Future<void> _next() async {
    setState(() { _loading = true; _revealed = false; _result = null; _answer.clear(); });
    try {
      final api = sl<AniListService>().api;
      final anime = await api.searchMedia('anime', perPage: 40);
      final candidates = anime.where((e) => e['id'] is num).toList()..shuffle();
      for (final m in candidates.take(10)) {
        final cast = (await api.mediaCharacters((m['id'] as num).toInt())).cast;
        if (cast.isEmpty) continue;
        if (!mounted) return;
        setState(() { _media = m; _character = cast[Random().nextInt(cast.length)]; });
        return;
      }
      throw StateError('No character');
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Soal belum bisa dimuat. Coba lagi.')));
    } finally { if (mounted) setState(() => _loading = false); }
  }

  void _check() {
    if (_character == null) return;
    final expected = (_character.name as String).toLowerCase().trim();
    final answer = _answer.text.toLowerCase().trim();
    setState(() { _revealed = true; _result = answer == expected ? 'Benar!' : 'Belum tepat. Jawabannya: ${_character.name}'; });
  }

  @override void dispose() { _answer.dispose(); super.dispose(); }

  @override Widget build(BuildContext context) => _BasePage(title: 'Tebak Karakter', child: ListView(padding: const EdgeInsets.all(20), children: [
    Text('Tebak nama karakter dari gambar yang ditampilkan.', style: AppText.body.copyWith(color: AppColors.textSecondary)),
    const SizedBox(height: 14),
    FilledButton.icon(onPressed: _loading ? null : _next, icon: const Icon(Icons.shuffle), label: Text(_loading ? 'Menyiapkan soal...' : 'Mulai / Soal berikutnya')),
    if (_loading) const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
    if (_character != null) ...[
      const SizedBox(height: 16),
      if (_character.photo != null) Center(child: Image.network(_character.photo, height: 280, fit: BoxFit.contain, errorBuilder: (_,__,___) => const SizedBox(height: 120, child: Icon(Icons.person, size: 60)))),
      const SizedBox(height: 12),
      TextField(controller: _answer, enabled: !_revealed, decoration: const InputDecoration(labelText: 'Nama karakter')),
      const SizedBox(height: 10),
      if (!_revealed) FilledButton(onPressed: _check, child: const Text('Periksa jawaban')),
      if (_result != null) Text(_result!, style: AppText.title.copyWith(color: AppColors.accent)),
      if (_revealed) Text('Anime: ${((_media?['title'] as Map?)?['romaji'] ?? (_media?['title'] as Map?)?['english'] ?? '-')}', style: AppText.caption.copyWith(color: AppColors.textSecondary)),
    ],
  ]));
}

class _AnimeQuizScreen extends StatefulWidget {
  const _AnimeQuizScreen();
  @override State<_AnimeQuizScreen> createState() => _AnimeQuizScreenState();
}

class _AnimeQuizScreenState extends State<_AnimeQuizScreen> {
  List<Map<String, dynamic>> _pool = [];
  Map<String, dynamic>? _question;
  List<String> _choices = [];
  String? _selected;
  int _score = 0, _answered = 0;
  bool _loading = false;

  String _title(Map<String, dynamic> m) {
    final t = m['title'] is Map ? m['title'] as Map : const {};
    return (t['romaji'] ?? t['english'] ?? 'Anime').toString();
  }

  Future<void> _next() async {
    setState(() => _loading = true);
    try {
      if (_pool.isEmpty) _pool = await sl<AniListService>().api.searchMedia('anime', perPage: 40);
      if (_pool.length < 4) throw StateError('Not enough anime');
      _pool.shuffle();
      final q = _pool.first;
      final correct = _title(q);
      final choices = <String>{correct};
      for (final m in _pool.skip(1)) {
        choices.add(_title(m));
        if (choices.length == 4) break;
      }
      if (mounted) setState(() { _question = q; _choices = choices.toList()..shuffle(); _selected = null; });
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kuis gagal dimuat.')));
    } finally { if (mounted) setState(() => _loading = false); }
  }

  void _choose(String value) {
    if (_selected != null || _question == null) return;
    final correct = value == _title(_question!);
    setState(() { _selected = value; _answered++; if (correct) _score++; });
  }

  @override Widget build(BuildContext context) {
    final cover = _question?['coverImage'] is Map ? (_question!['coverImage'] as Map)['large'] as String? : null;
    return _BasePage(title: 'Kuis Anime', child: ListView(padding: const EdgeInsets.all(20), children: [
      Text('Tebak judul anime dari poster.', style: AppText.body.copyWith(color: AppColors.textSecondary)),
      const SizedBox(height: 8),
      Text('Skor: $_score / $_answered', style: AppText.title.copyWith(color: AppColors.accent)),
      const SizedBox(height: 12),
      FilledButton.icon(onPressed: _loading ? null : _next, icon: const Icon(Icons.play_arrow), label: Text(_question == null ? 'Mulai kuis' : 'Soal berikutnya')),
      if (_loading) const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator())),
      if (_question != null) ...[
        const SizedBox(height: 14),
        if (cover != null) Center(child: ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.network(cover, height: 300, fit: BoxFit.contain))),
        const SizedBox(height: 14),
        for (final choice in _choices) Padding(padding: const EdgeInsets.only(bottom: 8), child: OutlinedButton(onPressed: _selected == null ? () => _choose(choice) : null, style: OutlinedButton.styleFrom(side: BorderSide(color: _selected == choice ? (choice == _title(_question!) ? Colors.green : AppColors.accent) : AppColors.hairline)), child: Text(choice))),
        if (_selected != null) Text(_selected == _title(_question!) ? 'Jawaban benar!' : 'Jawaban: ${_title(_question!)}', style: AppText.title.copyWith(color: AppColors.accent)),
      ],
    ]));
  }
}

class _ScreenshotGalleryScreen extends StatefulWidget {
  const _ScreenshotGalleryScreen();
  @override State<_ScreenshotGalleryScreen> createState() => _ScreenshotGalleryScreenState();
}

class _ScreenshotGalleryScreenState extends State<_ScreenshotGalleryScreen> {
  final _picker = ImagePicker();
  List<String> _paths = [];
  bool _loading = true;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final box = await _openMenuToolsBox();
    final raw = box.get('screenshot_paths');
    if (!mounted) return;
    setState(() { _paths = raw is List ? raw.whereType<String>().where((p) => File(p).existsSync()).toList() : []; _loading = false; });
  }

  Future<void> _add() async {
    try {
      final picked = await _picker.pickMultiImage(imageQuality: 95);
      if (picked.isEmpty) return;
      final docs = await getApplicationDocumentsDirectory();
      final dir = Directory('${docs.path}/animew_screenshots');
      await dir.create(recursive: true);
      for (final x in picked) {
        final ext = x.path.contains('.') ? x.path.substring(x.path.lastIndexOf('.')) : '.jpg';
        final target = '${dir.path}/shot_${DateTime.now().microsecondsSinceEpoch}_${_paths.length}$ext';
        await File(x.path).copy(target);
        _paths.insert(0, target);
      }
      final box = await _openMenuToolsBox();
      await box.put('screenshot_paths', _paths);
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal menambahkan gambar.')));
    }
  }

  Future<void> _remove(String path) async {
    _paths.remove(path);
    try { await File(path).delete(); } catch (_) {}
    final box = await _openMenuToolsBox();
    await box.put('screenshot_paths', _paths);
    if (mounted) setState(() {});
  }

  @override Widget build(BuildContext context) => _BasePage(title: 'Screenshot Gallery', child: _loading ? const Center(child: CircularProgressIndicator()) : Column(children: [
    Padding(padding: const EdgeInsets.all(12), child: Row(children: [Expanded(child: Text('Screenshot tersimpan di perangkat ini.', style: AppText.caption.copyWith(color: AppColors.textSecondary))), FilledButton.icon(onPressed: _add, icon: const Icon(Icons.add_photo_alternate), label: const Text('Tambah'))])),
    Expanded(child: _paths.isEmpty ? Center(child: Text('Belum ada screenshot.', style: AppText.body.copyWith(color: AppColors.textSecondary))) : GridView.builder(padding: const EdgeInsets.all(8), itemCount: _paths.length, gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 7, mainAxisSpacing: 7), itemBuilder: (_, i) {
      final path = _paths[i];
      return GestureDetector(onLongPress: () => _remove(path), onTap: () => showDialog<void>(context: context, builder: (_) => Dialog(child: InteractiveViewer(child: Image.file(File(path), fit: BoxFit.contain)))), child: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(File(path), fit: BoxFit.cover, errorBuilder: (_,__,___) => const ColoredBox(color: Colors.black12, child: Icon(Icons.broken_image)))));
    })),
  ]));
}
