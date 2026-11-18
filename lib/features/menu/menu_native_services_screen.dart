import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive/hive.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/hive/safe_box.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';

class MenuNativeServicesScreen extends StatelessWidget {
  const MenuNativeServicesScreen({super.key, required this.featureId});
  final String featureId;
  @override Widget build(BuildContext context) => switch (featureId) {
    'chess' => const _ChessScreen(),
    'shorts' => const _ShortsScreen(),
    'music' => const _MusicScreen(),
    'news' => const _NewsScreen(),
    _ => const Scaffold(body: Center(child: Text('Fitur tidak tersedia.'))),
  };
}

class _Page extends StatelessWidget {
  const _Page(this.title, this.subtitle, this.child, {this.actions = const []});
  final String title, subtitle;
  final Widget child;
  final List<Widget> actions;
  @override Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.bg,
    appBar: AppBar(backgroundColor: AppColors.bg, foregroundColor: AppColors.textPrimary, elevation: 0,
      title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: AppText.title.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w800)),
        Text(subtitle, style: AppText.caption.copyWith(color: AppColors.textTertiary, fontSize: 10)),
      ]), actions: actions),
    body: SafeArea(top: false, child: child),
  );
}
Widget _panel(Widget child) => Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.hairline)), child: child);

class _ChessScreen extends StatefulWidget {
  const _ChessScreen();
  @override State<_ChessScreen> createState() => _ChessScreenState();
}
class _ChessScreenState extends State<_ChessScreen> {
  static const _storage = FlutterSecureStorage();
  static const _key = 'menu_lichess_token';
  final Dio _dio = Dio(BaseOptions(baseUrl: 'https://lichess.org', receiveTimeout: const Duration(seconds: 0)));
  StreamSubscription<String>? _seek, _gameStream;
  String? _token, _user, _game, _message, _initialFen, _selected;
  List<String> _board = List.filled(64, '.');
  Map<String, dynamic> _gameState = {};
  bool _myWhite = true, _myTurn = false;
  String _status = 'Belum terhubung';
  bool _busy = false;
  @override void initState() { super.initState(); _restore(); }
  Future<void> _restore() async { _token = await _storage.read(key: _key); if (_token != null) await _verify(); if (mounted) setState(() {}); }
  Options get _auth => Options(headers: {'Authorization': 'Bearer $_token'});
  Future<void> _verify() async {
    if (_token == null) return;
    setState(() => _busy = true);
    try {
      final r = await _dio.get('/api/account', options: _auth);
      _user = (r.data as Map?)?['username']?.toString();
      if (_user == null) throw StateError('Invalid account');
      _status = 'Terhubung sebagai $_user';
    } catch (_) {
      _token = null; _user = null; _status = 'Token tidak valid';
      await _storage.delete(key: _key);
    } finally { if (mounted) setState(() => _busy = false); }
  }
  Future<void> _connect() async {
    final c = TextEditingController();
    final token = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface, title: const Text('Hubungkan Lichess'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('Masukkan token pribadi dengan izin board:play. Token disimpan aman di perangkat. Jangan bagikan kepada siapa pun.'),
        const SizedBox(height: 12),
        TextField(controller: c, obscureText: true, decoration: const InputDecoration(hintText: 'Personal access token')),
        TextButton(onPressed: () => launchUrl(Uri.parse('https://lichess.org/account/oauth/token'), mode: LaunchMode.externalApplication), child: const Text('Pengaturan token Lichess')),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')), FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('Hubungkan'))],
    ));
    c.dispose();
    if (token == null || token.isEmpty) return;
    await _storage.write(key: _key, value: token); _token = token; await _verify();
  }
  Future<void> _match() async {
    if (_token == null || _busy) return;
    setState(() { _busy = true; _message = null; _status = 'Mencari pemain online…'; });
    try {
      final r = await _dio.post<ResponseBody>('/api/board/seek',
        data: {'rated': 'false', 'time': '10', 'increment': '0', 'variant': 'standard', 'color': 'random'},
        options: Options(responseType: ResponseType.stream, contentType: Headers.formUrlEncodedContentType, headers: {'Authorization': 'Bearer $_token', 'Accept': 'application/x-ndjson'}));
      await _seek?.cancel();
      _seek = r.data!.stream.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
        try {
          final event = jsonDecode(line) as Map;
          if (event['type'] == 'gameStart') {
            final id = (event['game'] as Map?)?['id']?.toString();
            if (id != null && mounted) { _seek?.cancel(); setState(() { _game = id; _busy = false; _status = 'Pertandingan ditemukan'; }); unawaited(_watchGame(id)); }
          }
        } catch (_) {}
      }, onError: (_) { if (mounted) setState(() { _busy = false; _status = 'Pencarian terhenti'; _message = 'Tidak bisa tersambung ke Lichess.'; }); });
    } catch (_) {
      if (mounted) setState(() { _busy = false; _status = 'Pencarian gagal'; _message = 'Periksa token dan koneksi internet.'; });
    }
  }
  Future<void> _watchGame(String id) async {
    try {
      final r = await _dio.get<ResponseBody>('/api/board/game/stream/$id',
        options: Options(responseType: ResponseType.stream, headers: {'Authorization': 'Bearer $_token', 'Accept': 'application/x-ndjson'}));
      _gameStream?.cancel();
      _gameStream = r.data!.stream.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
        if (line.trim().isEmpty) return;
        try {
          final event = jsonDecode(line) as Map<String, dynamic>;
          if (event['type'] == 'gameFull') {
            _initialFen = event['initialFen']?.toString() ?? 'startpos';
            final white = event['white'] is Map ? event['white'] as Map : const {};
            _myWhite = white['id']?.toString().toLowerCase() == _user?.toLowerCase();
            _applyGameState(event['state'] is Map ? Map<String, dynamic>.from(event['state']) : {});
          } else if (event['type'] == 'gameState') {
            _applyGameState(event);
          }
        } catch (_) {}
      }, onError: (_) {
        if (mounted) setState(() => _message = 'Koneksi pertandingan terputus.');
      });
    } catch (_) {
      if (mounted) setState(() => _message = 'Tidak bisa membuka data pertandingan.');
    }
  }

  void _applyGameState(Map<String, dynamic> state) {
    final moves = state['moves']?.toString() ?? '';
    final initial = _initialFen ?? 'startpos';
    final board = _makeBoard(initial, moves);
    final fields = initial.split(' ');
    final startsWhite = fields.length < 2 || fields[1] == 'w';
    final count = moves.trim().isEmpty ? 0 : moves.trim().split(RegExp(r'\\s+')).length;
    final whiteTurn = startsWhite ? count.isEven : count.isOdd;
    _gameState = state;
    _board = board;
    _myTurn = whiteTurn == _myWhite;
    if (mounted) setState(() { _selected = null; });
  }

  List<String> _makeBoard(String fen, String moves) {
    final board = List<String>.filled(64, '.');
    final placement = fen == 'startpos' ? 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR' : fen.split(' ').first;
    final ranks = placement.split('/');
    for (var rank = 0; rank < 8 && rank < ranks.length; rank++) {
      var file = 0;
      for (final char in ranks[rank].split('')) {
        final empty = int.tryParse(char);
        if (empty != null) { file += empty; continue; }
        if (file < 8) board[rank * 8 + file] = char;
        file++;
      }
    }
    for (final move in moves.split(' ')) {
      if (move.length < 4) continue;
      final from = _squareIndex(move.substring(0, 2));
      final to = _squareIndex(move.substring(2, 4));
      if (from < 0 || to < 0) continue;
      final piece = board[from];
      if (piece == '.') continue;
      final fileDiff = to % 8 - from % 8;
      if (piece.toLowerCase() == 'p' && fileDiff != 0 && board[to] == '.') {
        final captured = to + (piece == 'P' ? 8 : -8);
        if (captured >= 0 && captured < 64) board[captured] = '.';
      }
      if (piece.toLowerCase() == 'k' && fileDiff.abs() == 2) {
        final rookFrom = to > from ? from + 3 : from - 4;
        final rookTo = to > from ? from + 1 : from - 1;
        if (rookFrom >= 0 && rookFrom < 64 && rookTo >= 0 && rookTo < 64) {
          board[rookTo] = board[rookFrom];
          board[rookFrom] = '.';
        }
      }
      board[from] = '.';
      board[to] = move.length > 4 ? (piece == piece.toUpperCase() ? move[4].toUpperCase() : move[4].toLowerCase()) : piece;
    }
    return board;
  }

  int _squareIndex(String square) {
    if (square.length != 2 || !'abcdefgh'.contains(square[0])) return -1;
    final rank = int.tryParse(square[1]);
    if (rank == null || rank < 1 || rank > 8) return -1;
    return (8 - rank) * 8 + 'abcdefgh'.indexOf(square[0]);
  }

  String _squareName(int index) => '${'abcdefgh'[index % 8]}${8 - index ~/ 8}';

  Future<void> _tapSquare(int displayIndex) async {
    if (_game == null || !_myTurn || _busy || _gameState['status']?.toString() != 'started') return;
    final index = _myWhite ? displayIndex : 63 - displayIndex;
    final piece = _board[index];
    final mine = piece != '.' && ((piece == piece.toUpperCase()) == _myWhite);
    if (_selected == null) {
      if (mine) setState(() => _selected = _squareName(index));
      return;
    }
    if (mine) { setState(() => _selected = _squareName(index)); return; }
    final from = _squareIndex(_selected!);
    final moving = from < 0 ? '.' : _board[from];
    final promotion = moving.toLowerCase() == 'p' && (index < 8 || index >= 56) ? 'q' : '';
    final uci = '$_selected${_squareName(index)}$promotion';
    setState(() { _busy = true; _message = null; });
    try {
      await _dio.post('/api/board/game/$_game/move/$uci', options: Options(headers: {'Authorization': 'Bearer $_token'}));
    } catch (_) {
      if (mounted) setState(() => _message = 'Langkah tidak diterima. Pilih langkah legal lainnya.');
    } finally {
      if (mounted) setState(() { _busy = false; _selected = null; });
    }
  }

  Widget _liveBoard() => _panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [
      Expanded(child: Text('Pertandingan langsung', style: AppText.title.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w800))),
      Text(_myWhite ? 'Putih' : 'Hitam', style: AppText.caption.copyWith(color: AppColors.textSecondary)),
    ]),
    const SizedBox(height: 12),
    AspectRatio(aspectRatio: 1, child: GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 64,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 8),
      itemBuilder: (context, displayIndex) {
        final index = _myWhite ? displayIndex : 63 - displayIndex;
        final piece = _board[index];
        final light = ((index ~/ 8) + (index % 8)).isEven;
        final selected = _selected == _squareName(index);
        return GestureDetector(
          onTap: () => _tapSquare(displayIndex),
          child: Container(
            color: selected ? AppColors.accent.withValues(alpha: .65) : light ? const Color(0xFFE8DCC8) : const Color(0xFF92765E),
            alignment: Alignment.center,
            child: Text(_glyph(piece), style: TextStyle(fontSize: 28, color: piece == '.' ? Colors.transparent : piece == piece.toUpperCase() ? const Color(0xFFFFFEF7) : const Color(0xFF191919), shadows: const [Shadow(color: Colors.black54, blurRadius: 2)])),
          ),
        );
      },
    )),
    const SizedBox(height: 10),
    Text(_gameState['status']?.toString() == 'started' ? (_myTurn ? 'Giliran kamu' : 'Menunggu langkah lawan…') : 'Pertandingan selesai', style: AppText.caption.copyWith(color: AppColors.textSecondary)),
    if (_gameState['winner'] != null) Text('Pemenang: ${_gameState['winner']}', style: AppText.body.copyWith(color: AppColors.accent, fontWeight: FontWeight.w800)),
    if (_message != null) Text(_message!, style: AppText.caption.copyWith(color: AppColors.accent)),
  ]));

  String _glyph(String p) => const {'K':'♔','Q':'♕','R':'♖','B':'♗','N':'♘','P':'♙','k':'♚','q':'♛','r':'♜','b':'♝','n':'♞','p':'♟'}[p] ?? '';

  @override void dispose() { _seek?.cancel(); _gameStream?.cancel(); _dio.close(force: true); super.dispose(); }
  @override Widget build(BuildContext context) => _Page('Catur Online', 'PERTANDINGAN ANTARPEMAIN · LICHESS', ListView(padding: const EdgeInsets.all(16), children: [
    _panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(width: 46, height: 46, decoration: BoxDecoration(color: AppColors.accentSoft, borderRadius: BorderRadius.circular(15)), child: Icon(Icons.grid_4x4_rounded, color: AppColors.accent)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_user == null ? 'Main online' : 'Halo, $_user', style: AppText.title.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w800)),
          Text(_status, style: AppText.caption.copyWith(color: AppColors.textSecondary)),
        ])),
        if (_busy) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
      ]),
      const SizedBox(height: 16),
      if (_token == null)
        FilledButton.icon(onPressed: _busy ? null : _connect, icon: const Icon(Icons.link_rounded), label: const Text('Hubungkan akun'), style: FilledButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(48)))
      else
        FilledButton.icon(onPressed: _busy || _game != null ? null : _match, icon: const Icon(Icons.bolt_rounded), label: Text(_busy ? 'Mencari lawan…' : 'Cari lawan · 10 menit'), style: FilledButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(48))),
      if (_message != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_message!, style: AppText.caption.copyWith(color: AppColors.accent))),
    ])),
    const SizedBox(height: 14),
    if (_game != null) ...[const SizedBox(height: 14), _liveBoard()],
    _panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Mode pertandingan', style: AppText.title.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w800)),
      const SizedBox(height: 10),
      _info('Online matchmaking', 'Dipertemukan dengan pemain Lichess lain.'),
      _info('Tanpa bot atau mode lokal', 'Semua pertandingan berlangsung online.'),
      _info('Tanpa chat', 'Fokus pada permainan dan keamanan pemain.'),
      if (_game != null) Text('ID pertandingan: $_game', style: AppText.caption.copyWith(color: AppColors.accent, fontWeight: FontWeight.w800)),
      const SizedBox(height: 6),
      Text('Papan native · langkah dikirim dan divalidasi server Lichess.', style: AppText.caption.copyWith(color: AppColors.textTertiary, height: 1.4)),
    ])),
  ]), actions: [
    if (_token != null) IconButton(onPressed: () async { await _storage.delete(key: _key); setState(() { _token = null; _user = null; _game = null; _status = 'Belum terhubung'; }); }, icon: const Icon(Icons.logout_rounded)),
    IconButton(onPressed: _token == null ? _connect : _verify, icon: Icon(_token == null ? Icons.link_rounded : Icons.refresh_rounded)),
  ]);
  Widget _info(String title, String body) => Padding(padding: const EdgeInsets.only(bottom: 10), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Icon(Icons.check_circle_rounded, color: AppColors.accent, size: 17), const SizedBox(width: 9),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: AppText.body.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
      Text(body, style: AppText.caption.copyWith(color: AppColors.textSecondary)),
    ])),
  ]));
}

class _ShortsScreen extends StatefulWidget {
  const _ShortsScreen();
  @override State<_ShortsScreen> createState() => _ShortsScreenState();
}
class _ShortsScreenState extends State<_ShortsScreen> {
  static const _boxName = 'menu_custom_sources', _key = 'shorts_api_url';
  final Dio _dio = Dio();
  final _search = TextEditingController();
  String? _endpoint;
  List<Map<String, dynamic>> _videos = [];
  bool _loading = false;
  String? _error;
  Future<Box> _box() async => Hive.isBoxOpen(_boxName) ? Hive.box(_boxName) : openBoxSafely(_boxName);
  @override void initState() { super.initState(); _init(); }
  Future<void> _init() async { final b = await _box(); _endpoint = b.get(_key) as String?; if (_endpoint != null) await _load(); if (mounted) setState(() {}); }
  Future<void> _configure() async {
    final c = TextEditingController(text: _endpoint ?? '');
    final value = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface, title: const Text('Sumber Short custom'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('API mengembalikan videos: [{title, author, thumbnail, streamUrl, isAdult}]. Hanya URL HTTPS dan konten non-dewasa ditampilkan.'),
        const SizedBox(height: 12), TextField(controller: c, keyboardType: TextInputType.url, decoration: const InputDecoration(hintText: 'https://alamat-api-kamu')),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')), FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('Simpan'))],
    ));
    c.dispose();
    if (value == null) return;
    final uri = Uri.tryParse(value);
    if (value.isNotEmpty && (uri == null || uri.scheme != 'https' || uri.host.isEmpty)) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Masukkan URL HTTPS yang valid.')));
      return;
    }
    final b = await _box(); _endpoint = value.isEmpty ? null : value;
    if (_endpoint == null) { await b.delete(_key); _videos = []; } else { await b.put(_key, _endpoint); await _load(); }
    if (mounted) setState(() {});
  }
  Future<void> _load() async {
    if (_endpoint == null) return;
    setState(() { _loading = true; _error = null; });
    try {
      final r = await _dio.get(_endpoint!, queryParameters: _search.text.trim().isEmpty ? null : {'q': _search.text.trim()});
      final raw = r.data is Map ? ((r.data as Map)['videos'] ?? (r.data as Map)['data']) : r.data;
      if (raw is! List) throw StateError('Bad feed');
      _videos = [for (final v in raw) if (v is Map && v['isAdult'] != true && v['streamUrl'] is String && Uri.tryParse(v['streamUrl'].toString())?.scheme == 'https') Map<String, dynamic>.from(v)];
    } catch (_) { _error = 'Sumber gagal dimuat. Periksa endpoint dan format respons.'; }
    finally { if (mounted) setState(() => _loading = false); }
  }
  @override void dispose() { _dio.close(force: true); _search.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => _Page('Short', 'VIDEO VERTIKAL · PROVIDER CUSTOM', Column(children: [
    Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 10), child: TextField(controller: _search, onSubmitted: (_) => _load(), decoration: InputDecoration(hintText: 'Cari video...', prefixIcon: const Icon(Icons.search_rounded), suffixIcon: IconButton(onPressed: _load, icon: const Icon(Icons.arrow_forward_rounded)), filled: true, fillColor: AppColors.surface, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)))),
    Expanded(child: _endpoint == null
      ? _empty(Icons.video_library_outlined, 'Feed videomu sendiri', 'Tambahkan endpoint API custom. Tidak ada WebView atau feed video palsu.', FilledButton.icon(onPressed: _configure, icon: const Icon(Icons.add_link_rounded), label: const Text('Atur sumber')))
      : _loading ? const Center(child: CircularProgressIndicator())
      : _error != null ? _empty(Icons.wifi_off_rounded, 'Feed belum tersedia', _error!, TextButton(onPressed: _load, child: const Text('Coba lagi')))
      : _videos.isEmpty ? _empty(Icons.movie_filter_outlined, 'Belum ada video', 'Provider belum mengirim video yang bisa diputar.', null)
      : GridView.builder(padding: const EdgeInsets.all(14), itemCount: _videos.length, gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: .7), itemBuilder: (ctx, i) {
        final v = _videos[i], image = v['thumbnail']?.toString();
        return GestureDetector(onTap: () => Navigator.push(ctx, MaterialPageRoute<void>(builder: (_) => _ShortPlayer(video: v))), child: ClipRRect(borderRadius: BorderRadius.circular(18), child: Stack(fit: StackFit.expand, children: [
          if (image != null && Uri.tryParse(image)?.scheme == 'https') Image.network(image, fit: BoxFit.cover, errorBuilder: (_, __, ___) => ColoredBox(color: AppColors.surface2, child: Icon(Icons.movie_rounded, color: AppColors.textTertiary))) else ColoredBox(color: AppColors.surface2, child: Icon(Icons.movie_rounded, color: AppColors.textTertiary)),
          const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Color(0xE0000000)], stops: [.45, 1]))),
          const Center(child: Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 40)),
          Positioned(left: 10, right: 10, bottom: 10, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(v['title']?.toString() ?? 'Video', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
            Text(v['author']?.toString() ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 11)),
          ])),
        ])));
      })),
  ]), actions: [IconButton(onPressed: _configure, icon: const Icon(Icons.tune_rounded)), IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded))]);
  Widget _empty(IconData icon, String title, String body, Widget? action) => Center(child: Padding(padding: const EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, color: AppColors.accent, size: 44), const SizedBox(height: 12),
    Text(title, style: AppText.title.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w800)),
    const SizedBox(height: 6), Text(body, textAlign: TextAlign.center, style: AppText.caption.copyWith(color: AppColors.textSecondary, height: 1.45)),
    if (action != null) ...[const SizedBox(height: 16), action],
  ])));
}

class _ShortPlayer extends StatefulWidget {
  const _ShortPlayer({required this.video});
  final Map<String, dynamic> video;
  @override State<_ShortPlayer> createState() => _ShortPlayerState();
}
class _ShortPlayerState extends State<_ShortPlayer> {
  late final Player _player;
  late final VideoController _controller;
  @override void initState() { super.initState(); _player = Player(); _controller = VideoController(_player); _player.open(Media(widget.video['streamUrl'].toString())); }
  @override void dispose() { _player.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => Scaffold(backgroundColor: Colors.black, body: Stack(children: [
    Positioned.fill(child: Video(controller: _controller)),
    SafeArea(child: IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back_rounded, color: Colors.white))),
    SafeArea(child: Align(alignment: Alignment.bottomLeft, child: Padding(padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(widget.video['title']?.toString() ?? 'Video', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
      Text(widget.video['author']?.toString() ?? '', style: const TextStyle(color: Colors.white70)),
    ])))),
  ]));
}

class _MusicScreen extends StatefulWidget {
  const _MusicScreen();
  @override State<_MusicScreen> createState() => _MusicScreenState();
}
class _MusicScreenState extends State<_MusicScreen> {
  final Dio _dio = Dio(BaseOptions(baseUrl: 'https://api.audius.co/v1'));
  final Player _player = Player();
  final _query = TextEditingController(text: 'anime soundtrack');
  List<Map<String, dynamic>> _tracks = [];
  Map<String, dynamic>? _current;
  bool _loading = false, _playing = false;
  String? _error;
  @override void initState() { super.initState(); _search(); _player.stream.playing.listen((v) { if (mounted) setState(() => _playing = v); }); }
  Future<void> _search() async {
    if (_query.text.trim().isEmpty) return;
    setState(() { _loading = true; _error = null; });
    try {
      final r = await _dio.get('/tracks/search', queryParameters: {'query': _query.text.trim(), 'limit': 30});
      final raw = (r.data as Map?)?['data'];
      if (raw is! List) throw StateError('No data');
      _tracks = [for (final t in raw) if (t is Map && t['is_explicit'] != true && t['id'] != null) Map<String, dynamic>.from(t)];
    } catch (_) { _error = 'Katalog musik belum bisa dimuat.'; }
    finally { if (mounted) setState(() => _loading = false); }
  }
  Future<void> _play(Map<String, dynamic> track) async {
    setState(() => _current = track);
    try { await _player.open(Media('https://api.audius.co/v1/tracks/${track['id']}/stream')); await _player.play(); }
    catch (_) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Audio tidak bisa diputar.'))); }
  }
  @override void dispose() { _query.dispose(); _dio.close(force: true); _player.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => _Page('Musik', 'OPEN AUDIO CATALOG · AUDIUS', Column(children: [
    Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 10), child: TextField(controller: _query, onSubmitted: (_) => _search(), decoration: InputDecoration(hintText: 'Cari lagu atau artis...', prefixIcon: const Icon(Icons.search_rounded), suffixIcon: IconButton(onPressed: _search, icon: const Icon(Icons.arrow_forward_rounded)), filled: true, fillColor: AppColors.surface, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)))),
    Expanded(child: _loading ? const Center(child: CircularProgressIndicator()) : _error != null ? Center(child: Text(_error!, style: AppText.body.copyWith(color: AppColors.textSecondary))) : ListView.separated(padding: const EdgeInsets.fromLTRB(16, 4, 16, 12), itemCount: _tracks.length, separatorBuilder: (_, __) => const SizedBox(height: 9), itemBuilder: (ctx, i) {
      final t = _tracks[i], user = t['user'] is Map ? t['user'] as Map : const {};
      final artwork = t['artwork'] is Map ? (t['artwork'] as Map)['150x150']?.toString() : null;
      final active = _current?['id'] == t['id'];
      return Material(color: AppColors.surface, borderRadius: BorderRadius.circular(17), child: ListTile(contentPadding: const EdgeInsets.all(10),
        leading: ClipRRect(borderRadius: BorderRadius.circular(11), child: artwork == null ? const SizedBox(width: 52, height: 52, child: Icon(Icons.music_note_rounded)) : Image.network(artwork, width: 52, height: 52, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox(width: 52, height: 52, child: Icon(Icons.music_note_rounded)))),
        title: Text(t['title']?.toString() ?? 'Untitled', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.body.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w800)),
        subtitle: Text(user['name']?.toString() ?? 'Unknown artist', maxLines: 1, style: AppText.caption.copyWith(color: AppColors.textSecondary)),
        trailing: Icon(active && _playing ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded, color: AppColors.accent, size: 30),
        onTap: () => _play(t)));
    })),
    if (_current != null) SafeArea(top: false, child: _panel(Row(children: [
      const Icon(Icons.equalizer_rounded, color: AppColors.accent), const SizedBox(width: 10),
      Expanded(child: Text(_current!['title']?.toString() ?? 'Now playing', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.caption.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w800))),
      IconButton(onPressed: () => _playing ? _player.pause() : _player.play(), icon: Icon(_playing ? Icons.pause_rounded : Icons.play_arrow_rounded, color: AppColors.accent)),
      IconButton(onPressed: () { _player.stop(); setState(() => _current = null); }, icon: const Icon(Icons.close_rounded)),
    ]))),
  ]), actions: [IconButton(onPressed: _search, icon: const Icon(Icons.refresh_rounded))]);
}

class _NewsItem {
  const _NewsItem(this.title, this.url, this.summary, this.date);
  final String title, url, summary, date;
}
class _NewsScreen extends StatefulWidget {
  const _NewsScreen();
  @override State<_NewsScreen> createState() => _NewsScreenState();
}
class _NewsScreenState extends State<_NewsScreen> {
  final Dio _dio = Dio();
  List<_NewsItem> _items = [];
  bool _loading = true;
  String? _error;
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final r = await _dio.get('https://www.animenewsnetwork.com/all/rss.xml?ann-edition=us', options: Options(responseType: ResponseType.plain));
      final doc = html_parser.parse(r.data?.toString() ?? '');
      _items = [for (final item in doc.querySelectorAll('item'))
        if ((item.querySelector('title')?.text.trim() ?? '').isNotEmpty && (item.querySelector('link')?.text.trim() ?? '').startsWith('https://'))
          _NewsItem(item.querySelector('title')!.text.trim(), item.querySelector('link')!.text.trim(), item.querySelector('description')?.text.trim() ?? '', item.querySelector('pubDate')?.text.trim() ?? '')];
      if (_items.isEmpty) throw StateError('Empty feed');
    } catch (_) { _error = 'Berita belum bisa dimuat. Coba lagi nanti.'; }
    finally { if (mounted) setState(() => _loading = false); }
  }
  @override void dispose() { _dio.close(force: true); super.dispose(); }
  @override Widget build(BuildContext context) => _Page('Anime News', 'BERITA · PEMBACA NATIVE', _loading ? const Center(child: CircularProgressIndicator()) : _error != null ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, style: AppText.body.copyWith(color: AppColors.textSecondary)))) : RefreshIndicator(onRefresh: _load, child: ListView.separated(padding: const EdgeInsets.all(16), itemCount: _items.length, separatorBuilder: (_, __) => const SizedBox(height: 12), itemBuilder: (ctx, i) {
    final item = _items[i];
    return Material(color: AppColors.surface, borderRadius: BorderRadius.circular(18), child: InkWell(borderRadius: BorderRadius.circular(18), onTap: () => Navigator.push(ctx, MaterialPageRoute<void>(builder: (_) => _ArticleScreen(item: item))), child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Text('ANIME NEWS NETWORK', style: AppText.caption.copyWith(color: AppColors.accent, fontWeight: FontWeight.w900, fontSize: 9, letterSpacing: .7)), const Spacer(), Flexible(child: Text(item.date, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.caption.copyWith(color: AppColors.textTertiary, fontSize: 9)))]),
      const SizedBox(height: 10), Text(item.title, style: AppText.title.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w800, height: 1.25)),
      const SizedBox(height: 8), Text(_plain(item.summary), maxLines: 3, overflow: TextOverflow.ellipsis, style: AppText.caption.copyWith(color: AppColors.textSecondary, height: 1.45)),
      const SizedBox(height: 10), Text('Baca ringkasan  →', style: AppText.caption.copyWith(color: AppColors.accent, fontWeight: FontWeight.w800)),
    ]))));
  }), actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded))]);
}
String _plain(String s) => s.replaceAll(RegExp(r'<[^>]*>'), ' ').replaceAll('&amp;', '&').replaceAll('&quot;', '"').replaceAll(RegExp(r'\s+'), ' ').trim();

class _ArticleScreen extends StatefulWidget {
  const _ArticleScreen({required this.item});
  final _NewsItem item;
  @override State<_ArticleScreen> createState() => _ArticleScreenState();
}
class _ArticleScreenState extends State<_ArticleScreen> {
  final Dio _dio = Dio();
  String _body = '';
  bool _loading = true;
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    try {
      final r = await _dio.get(widget.item.url, options: Options(responseType: ResponseType.plain));
      final doc = html_parser.parse(r.data?.toString() ?? '');
      _body = doc.querySelectorAll('article p, #content p, .meat p').map((e) => e.text.trim()).where((e) => e.length > 35).take(12).join('\n\n');
    } catch (_) {}
    if (_body.isEmpty) _body = _plain(widget.item.summary);
    if (mounted) setState(() => _loading = false);
  }
  @override void dispose() { _dio.close(force: true); super.dispose(); }
  @override Widget build(BuildContext context) => Scaffold(backgroundColor: AppColors.bg, appBar: AppBar(backgroundColor: AppColors.bg, foregroundColor: AppColors.textPrimary, title: const Text('Baca berita')), body: _loading ? const Center(child: CircularProgressIndicator()) : ListView(padding: const EdgeInsets.all(20), children: [
    Text('ANIME NEWS NETWORK', style: AppText.caption.copyWith(color: AppColors.accent, fontWeight: FontWeight.w900, letterSpacing: 1)),
    const SizedBox(height: 12), Text(widget.item.title, style: AppText.headline.copyWith(color: AppColors.textPrimary, fontSize: 25, fontWeight: FontWeight.w900, height: 1.2)),
    const SizedBox(height: 12), Text(widget.item.date, style: AppText.caption.copyWith(color: AppColors.textTertiary)),
    const SizedBox(height: 22), Text(_body.isEmpty ? 'Ringkasan artikel belum tersedia.' : _body, style: AppText.body.copyWith(color: AppColors.textSecondary, height: 1.7)),
    const SizedBox(height: 20), OutlinedButton.icon(onPressed: () => launchUrl(Uri.parse(widget.item.url), mode: LaunchMode.externalApplication), icon: const Icon(Icons.open_in_new_rounded), label: const Text('Buka sumber asli di browser')),
  ]));
}
