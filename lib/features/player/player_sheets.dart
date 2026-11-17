// Audio & subtitles, online subtitle search, subtitle styling and colour sheets.
part of 'player_screen.dart';

String _subtitleOutlineLabel(AppLocalizations l10n, String id) => switch (id) {
  'none' => l10n.subtitleOutlineNone,
  'soft' => l10n.subtitleOutlineSoft,
  'outline' => l10n.subtitleOutlineOutline,
  'bold' => l10n.subtitleOutlineBold,
  'shadow' => l10n.subtitleOutlineShadow,
  'glow' => l10n.subtitleOutlineGlow,
  _ => id,
};

String _subtitleColourLabel(AppLocalizations l10n, String hex) => switch (hex) {
  '#FFFFFFFF' => l10n.colourWhite,
  '#FFFF00FF' => l10n.colourYellow,
  '#00E5FFFF' => l10n.accentCyan,
  '#7CFC00FF' => l10n.colourGreen,
  '#FF6B6BFF' => l10n.colourRed,
  '#000000FF' => l10n.colourBlack,
  _ => hex,
};

class _AudioSubsSheet extends StatefulWidget {
  const _AudioSubsSheet({
    required this.controller,
    required this.onInteract,
    required this.onLoadFile,
    required this.onSearchOnline,
    required this.onTranslate,
    this.castMode = false,
    this.onAfterChange,
    this.onSoftSubPicked,
    this.onSubtitlesOff,
  });
  final PlayerCubit controller;
  final VoidCallback onInteract;
  final VoidCallback onLoadFile;
  final VoidCallback onSearchOnline;
  final VoidCallback onTranslate;

  /// Chromecast can't switch muxed in-stream tracks or apply local files.
  final bool castMode;
  final VoidCallback? onAfterChange;
  final ValueChanged<Subtitle>? onSoftSubPicked;
  final VoidCallback? onSubtitlesOff;

  @override
  State<_AudioSubsSheet> createState() => _AudioSubsSheetState();
}

class _AudioSubsSheetState extends State<_AudioSubsSheet> {
  late String _category = widget.controller.activeCategory;
  String? _selectedSubtitleId;

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final h = MediaQuery.of(context).size.height;
    return StreamBuilder<Track>(
      stream: c.player.stream.track,
      builder: (context, snap) {
        final track = snap.data ?? c.player.state.track;
        final subId = _selectedSubtitleId ?? track.subtitle.id;
        return Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: (h * 0.46).clamp(280.0, 350.0),
                child: _subColumn(c, subId),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _subColumn(PlayerCubit c, String subId) {
    final embedded = c.mediaSubtitleTracks;
    final embeddedIds = embedded.map((t) => t.id.trim().toLowerCase()).toSet();
    final embeddedHasEnglish = embedded.any(
      (t) => _isEnglishSubtitle(t.language, t.title),
    );
    final soft = c.softSubs
        .where((s) => !embeddedIds.contains(s.url.trim().toLowerCase()))
        .where((s) => !embeddedHasEnglish || !_isEnglishSubtitle(s.lang, s.label))
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: ListView(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            children: [
              _SheetRow(
                compactDialog: true,
                label: 'No',
                active: subId == 'no',
                onTap: () {
                  setState(() => _selectedSubtitleId = 'no');
                  widget.onSubtitlesOff?.call();
                  c.subtitlesOff();
                  widget.onInteract();
                  widget.onAfterChange?.call();
                },
              ),
              if (!widget.castMode)
                for (final t in _orderedSubtitleTracks(embedded))
                  _SheetRow(
                    compactDialog: true,
                  label: _isTranslatedTrack(t)
                        ? 'Indonesia (translated)'
                        : (_isEnglishSubtitle(t.language, t.title)
                            ? 'Inggris'
                            : _trackLabel(
                                t.title,
                                t.language,
                                t.id,
                                titleSaysSomething: _titlesSaySomething(
                                  embedded.map((t) => t.title),
                                ),
                              )),
                    active: subId == t.id,
                    onTap: () {
                      setState(() => _selectedSubtitleId = t.id);
                      c.setSubtitle(t);
                      widget.onInteract();
                    },
                  ),
              for (final s in _orderedSoftSubs(soft))
                _SheetRow(
                  compactDialog: true,
                  label: _isEnglishSubtitle(s.lang, s.label)
                      ? 'Inggris'
                      : (s.label ?? s.lang),
                  // A URI soft-sub is applied via SubtitleTrack.uri(s.url), whose
                  // media_kit track id IS the url — so the active one highlights.
                  active: subId == s.url,
                  onTap: () async {
                    setState(() => _selectedSubtitleId = s.url);
                    widget.onSoftSubPicked?.call(s);
                    await c.setSoftSub(s);
                    widget.onInteract();
                    widget.onAfterChange?.call();
                  },
                ),
              if (!widget.castMode) ...[
                _SheetRow(
                  compactDialog: true,
                  label: 'Terjemahkan subtitle',
                  icon: Icons.translate_rounded,
                  active: false,
                  onTap: () {
                    widget.onInteract();
                    widget.onTranslate();
                  },
                ),
                _SheetRow(
                  compactDialog: true,
                  label: 'Pertahankan gaya ASS/SSA',
                  toggleValue: c.styledSubtitlesOn,
                  active: false,
                  onTap: () {
                    c.toggleStyledSubtitles();
                    if (mounted) setState(() {});
                    widget.onInteract();
                  },
                ),
                _SheetRow(
                  compactDialog: true,
                  label: 'Import subtitle',
                  icon: Icons.upload_file_rounded,
                  active: false,
                  onTap: widget.onLoadFile,
                ),
                _SheetRow(
                  compactDialog: true,
                  label: 'Kunci Posisi Subtitle',
                  icon: Icons.lock_outline_rounded,
                  toggleValue: sl<PlaybackPrefs>().subtitlePositionLocked,
                  active: false,
                  onTap: () async {
                    final prefs = sl<PlaybackPrefs>();
                    await prefs.setSubtitlePositionLocked(
                      !prefs.subtitlePositionLocked,
                    );
                    if (mounted) setState(() {});
                    widget.onInteract();
                  },
                ),
                _SheetRow(
                  compactDialog: true,
                  label: context.l10n.subtitleStyle,
                  icon: Icons.text_fields_rounded,
                  active: false,
                  onTap: () {
                    widget.onInteract();
                    openSubtitleStyleSheet(context, c, widget.onInteract);
                  },
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  bool _isTranslatedTrack(SubtitleTrack t) {
    final title = t.title?.trim().toLowerCase() ?? '';
    final id = t.id.trim().toLowerCase();
    return title == 'translated' || id.contains('translated_');
  }

  bool _isEnglishSubtitle(String? language, String? title) {
    final lang = (language ?? '').trim().toLowerCase();
    final name = (title ?? '').trim().toLowerCase();
    return lang == 'en' || lang.startsWith('en-') ||
        name.contains('english') || name.contains('inggris') ||
        name == 'eng' || name.startsWith('eng ');
  }

  List<SubtitleTrack> _orderedSubtitleTracks(List<SubtitleTrack> tracks) {
    final seen = <String>{};
    final result = tracks.where((track) {
      final id = track.id.trim().toLowerCase();
      final title = (track.title ?? '').trim().toLowerCase();
      final language = (track.language ?? '').trim().toLowerCase();
      final identity = _isEnglishSubtitle(track.language, track.title)
          ? 'english'
          : (title.isNotEmpty || language.isNotEmpty ? '$language|$title' : id);
      if (id.isEmpty || !seen.add(identity)) return false;
      return true;
    }).toList();
    result.sort((a, b) {
      int rank(SubtitleTrack t) => _isEnglishSubtitle(t.language, t.title)
          ? 0
          : (_isTranslatedTrack(t) ? 1 : 2);
      return rank(a).compareTo(rank(b));
    });
    return result;
  }

  List<Subtitle> _orderedSoftSubs(List<Subtitle> subs) {
    final seen = <String>{};
    final result = subs.where((sub) {
      final uri = sub.url.trim().toLowerCase();
      final identity = _isEnglishSubtitle(sub.lang, sub.label)
          ? 'english'
          : sub.lang.trim().toLowerCase() + '|' + (sub.label ?? '').trim().toLowerCase();
      if (uri.isEmpty || !seen.add(identity)) return false;
      return true;
    }).toList();
    result.sort((a, b) =>
        (_isEnglishSubtitle(a.lang, a.label) ? 0 : 1)
            .compareTo(_isEnglishSubtitle(b.lang, b.label) ? 0 : 1));
    return result;
  }
}

/// Online subtitle search (OpenSubtitles). A query field (prefilled with the
/// show title) + a results list; tapping a result downloads it and calls
/// [onApply] with the local file path. Surfaces a loading state and readable
/// errors (including the "add an API key" hint when no key is set).
class _OnlineSubtitleSheet extends StatefulWidget {
  const _OnlineSubtitleSheet({
    required this.initialQuery,
    required this.onApply,
    this.initialLanguage = '',
    this.imdbId,
    this.tmdbId,
  });
  final String initialQuery;
  final Future<void> Function(String localPath) onApply;

  /// ISO-639-1 code pre-selected in the language picker ('' = any language).
  final String initialLanguage;

  /// When non-null, passed to [SubtitleSearchService.search] for higher
  /// accuracy (OpenSubtitles can search by IMDb/TMDB id in addition to title).
  final String? imdbId;
  final int? tmdbId;

  @override
  State<_OnlineSubtitleSheet> createState() => _OnlineSubtitleSheetState();
}

class _OnlineSubtitleSheetState extends State<_OnlineSubtitleSheet> {
  final _service = SubtitleSearchService();
  late final TextEditingController _query = TextEditingController(
    text: widget.initialQuery,
  );

  /// ISO-639-1 code for the selected search language, or '' = any language.
  late String _selectedLang = widget.initialLanguage;

  bool _searching = false;
  bool _downloading = false;
  String? _error;
  List<SubtitleSearchResult> _results = const [];

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _search());
    }
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _query.text.trim();
    if (q.isEmpty || _searching) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _searching = true;
      _error = null;
      _results = const [];
    });
    try {
      final results = await _service.search(
        q,
        language: _selectedLang.isEmpty ? '' : _selectedLang,
        imdbId: widget.imdbId,
        tmdbId: widget.tmdbId,
      );
      if (!mounted) return;
      setState(() {
        _results = results;
        _searching = false;
        if (results.isEmpty) {
          _error = context.l10n.noSubtitlesFoundFor(q);
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _error = e is SubtitleSearchException
            ? e.message
            : context.l10n.searchFailedWithError('$e');
      });
    }
  }

  Future<void> _pick(SubtitleSearchResult r) async {
    if (_downloading) return;
    setState(() {
      _downloading = true;
      _error = null;
    });
    try {
      final path = await _service.download(r);
      if (!mounted) return;
      await widget.onApply(path);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _downloading = false;
        _error = e is SubtitleSearchException
            ? e.message
            : context.l10n.downloadFailedWithError('$e');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(12, 0, 12, 10 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Text(
              context.l10n.searchSubtitlesOnline,
              style: AppText.headline,
            ),
          ),
          // Language picker — defaults to the user's preferred subtitle
          // language (when set in Settings) and lets the user change it
          // per-search without leaving the sheet.
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
            child: Row(
              children: [
                Text(
                  context.l10n.language,
                  style: AppText.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _selectedLang.isEmpty ? '' : _selectedLang,
                  dropdownColor: AppColors.surface2,
                  style: AppText.body.copyWith(color: AppColors.textPrimary),
                  underline: const SizedBox.shrink(),
                  items: [
                    DropdownMenuItem(
                      value: '',
                      child: Text(
                        context.l10n.any,
                        style: AppText.body.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    for (final lang in kSubtitleLanguages)
                      DropdownMenuItem(
                        value: lang.iso1,
                        child: Text(
                          lang.name,
                          style: AppText.body.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _selectedLang = v);
                  },
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: TextField(
              controller: _query,
              autofocus: widget.initialQuery.trim().isEmpty,
              textInputAction: TextInputAction.search,
              cursorColor: AppColors.accent,
              style: AppText.body.copyWith(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: context.l10n.movieOrShowTitle,
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                  tooltip: context.l10n.search,
                  onPressed: _search,
                ),
              ),
              onSubmitted: (_) => _search(),
            ),
          ),
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: h * 0.42),
            child: _body(),
          ),
        ],
      ),
    );
  }

  Widget _body() {
    if (_searching) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 28),
        child: Center(
          child: SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: AppColors.accent,
            ),
          ),
        ),
      );
    }
    if (_error != null && _results.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 22),
        child: Center(
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: AppText.body.copyWith(color: AppColors.textSecondary),
          ),
        ),
      );
    }
    return Stack(
      children: [
        ListView(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          children: [
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
                child: Text(
                  _error!,
                  style: AppText.caption.copyWith(color: AppColors.accent),
                ),
              ),
            for (final r in _results)
              _SheetRow(
                label: r.language.isNotEmpty
                    ? '[${r.language.toUpperCase()}] ${r.name}'
                    : r.name,
                active: false,
                onTap: () => _pick(r),
              ),
          ],
        ),
        if (_downloading)
          Positioned.fill(
            child: ColoredBox(
              color: Color(0x66000000),
              child: Center(
                child: SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: AppColors.accent,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Opens the Subtitle-style sheet (font / colour / background / position /
/// size). Lives over whatever opened it; changes apply live via the controller.
/// Opens the shared Subtitle-style sheet (live preview + all controls). Pass a
/// [controller] from the player so changes apply to the video live; pass null
/// from Settings, where there's no active player and it just persists prefs.
void openSubtitleStyleSheet(BuildContext context, PlayerCubit? controller, VoidCallback onInteract) {
  Navigator.of(context).push(MaterialPageRoute<void>(
    builder: (_) => _SubtitleStyleFullScreen(controller: controller, onInteract: onInteract),
  ));
}

class _SubtitleStyleFullScreen extends StatefulWidget {
  const _SubtitleStyleFullScreen({required this.controller, required this.onInteract});
  final PlayerCubit? controller;
  final VoidCallback onInteract;
  @override
  State<_SubtitleStyleFullScreen> createState() => _SubtitleStyleFullScreenState();
}

class _SubtitleStyleFullScreenState extends State<_SubtitleStyleFullScreen> {
  PlaybackPrefs get p => sl<PlaybackPrefs>();
  static const bg = Color(0xFF17110D), card = Color(0xFF211914), line = Color(0xFF35271E);
  static const orange = Color(0xFFFF710D), muted = Color(0xFF82958A);

  Future<void> _apply(Future<void> Function() change) async {
    await change();
    await widget.controller?.applySubtitleStyle();
    if (mounted) setState(() {});
    widget.onInteract();
  }

  Future<void> _reset() => _apply(() async {
    await p.setSubtitleFont('');
    await p.setSubtitleScale(0.78125);
    await p.setSubtitleFontWeight(400);
    await p.setSubtitleItalic(false);
    await p.setSubtitleJustification('center');
    await p.setSubtitleColorHex('#FFFFFFFF');
    await p.setSubtitleOutlineWidth(2.5);
    await p.setSubtitleOutlineType('soft');
    await p.setSubtitleOutlineColorHex('#000000FF');
    await p.setSubtitleShadowAngle(45);
    await p.setSubtitleShadowWidth(2.5);
    await p.setSubtitleShadowDistance(2.5);
    await p.setSubtitleShadowBlur(2.5);
    await p.setSubtitleShadowColorHex('#000000FF');
    await p.setSubtitleBgOpacity(0);
    await p.setSubtitleTextOpacity(1);
    await p.setSubtitleOverallOpacity(1);
    await p.setSubtitlePosition(95);
    await p.resetSubtitleLayout();
  });

  Future<void> _font() async {
    final fonts = <String>{...kBundledSubtitleFonts, ...p.customSubtitleFonts.keys};
    final picked = await showModalBottomSheet<String>(context: context, backgroundColor: card,
      builder: (ctx) => SafeArea(child: ListView(shrinkWrap: true, children: [
        const Padding(padding: EdgeInsets.all(18), child: Text('Gaya Font', style: TextStyle(color: Colors.white, fontSize: 18))),
        for (final f in fonts) ListTile(
          title: Text(f.isEmpty ? 'Bawaan Anidesu (Roboto Medium)' : f, style: const TextStyle(color: Colors.white)),
          trailing: p.subtitleFont == f ? const Icon(Icons.check, color: orange) : null,
          onTap: () => Navigator.pop(ctx, f),
        ),
      ])));
    if (picked != null) {
      if (picked.isNotEmpty) await SubtitleFontService.instance.ensure(picked);
      await _apply(() => p.setSubtitleFont(picked));
    }
  }

  Future<void> _color(String label, String current, Future<void> Function(String) save) async {
    final input = TextEditingController(
      text: current.replaceFirst('#', '').substring(0, 6),
    );
    var selected = parseSubtitleHex(current);
    var hsv = HSVColor.fromColor(selected);
    String toHex(Color color) {
      String two(int v) => v.toRadixString(16).padLeft(2, '0').toUpperCase();
      return '#${two((color.r * 255).round())}${two((color.g * 255).round())}${two((color.b * 255).round())}FF';
    }
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, refresh) => AlertDialog(
          backgroundColor: card,
          title: Text(label, style: const TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 42,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: selected,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: Colors.white30),
                  ),
                ),
                const SizedBox(height: 18),
                const Text('Warna', style: TextStyle(color: Colors.white70, fontSize: 12)),
                Slider(
                  value: hsv.hue.clamp(0.0, 360.0),
                  min: 0,
                  max: 360,
                  activeColor: selected,
                  onChanged: (hue) => refresh(() {
                    hsv = hsv.withHue(hue);
                    selected = hsv.toColor();
                    input.text = toHex(selected).substring(1, 7);
                  }),
                ),
                const Text('Saturasi', style: TextStyle(color: Colors.white70, fontSize: 12)),
                Slider(
                  value: hsv.saturation,
                  min: 0,
                  max: 1,
                  activeColor: orange,
                  onChanged: (value) => refresh(() {
                    hsv = hsv.withSaturation(value);
                    selected = hsv.toColor();
                    input.text = toHex(selected).substring(1, 7);
                  }),
                ),
                const Text('Kecerahan', style: TextStyle(color: Colors.white70, fontSize: 12)),
                Slider(
                  value: hsv.value,
                  min: 0,
                  max: 1,
                  activeColor: orange,
                  onChanged: (value) => refresh(() {
                    hsv = hsv.withValue(value);
                    selected = hsv.toColor();
                    input.text = toHex(selected).substring(1, 7);
                  }),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: input,
                  maxLength: 6,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Kode warna',
                    prefixText: '#',
                    counterText: '',
                  ),
                  onChanged: (value) {
                    final v = value.toUpperCase();
                    if (RegExp(r'^[0-9A-F]{6}$').hasMatch(v)) {
                      refresh(() {
                        selected = Color(int.parse('FF$v', radix: 16));
                        hsv = HSVColor.fromColor(selected);
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            TextButton(
              onPressed: () {
                final v = input.text.toUpperCase();
                if (RegExp(r'^[0-9A-F]{6}$').hasMatch(v)) {
                  selected = Color(int.parse('FF$v', radix: 16));
                }
                Navigator.pop(ctx, toHex(selected));
              },
              child: const Text('Pilih'),
            ),
          ],
        ),
      ),
    );
    input.dispose();
    if (result != null) await _apply(() => save(result));
  }

  Widget _card(Widget child) => Container(
    margin: const EdgeInsets.only(bottom: 9), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
    decoration: BoxDecoration(color: card, border: Border.all(color: line), borderRadius: BorderRadius.circular(17)),
    child: child,
  );

  Widget _step(String label, String value, double current, double step, double minValue, double maxValue,
      Future<void> Function(double) save) => _card(Row(children: [
    Expanded(child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 14))),
    IconButton(onPressed: current > minValue ? () => _apply(() => save((current-step).clamp(minValue,maxValue).toDouble())) : null,
      icon: const Icon(Icons.remove_circle_outline, color: muted)),
    Text(value, style: const TextStyle(color: Colors.white, fontSize: 14)),
    IconButton(onPressed: current < maxValue ? () => _apply(() => save((current+step).clamp(minValue,maxValue).toDouble())) : null,
      icon: const Icon(Icons.add_circle_outline, color: orange)),
  ]));

  Widget _colorRow(String label, String hex, Future<void> Function(String) save) => InkWell(
    onTap: () => _color(label, hex, save),
    child: _card(Row(children: [
      Expanded(child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 14))),
      Text(hex.substring(0, 7), style: const TextStyle(color: muted, fontSize: 13)),
      const SizedBox(width: 12),
      Container(width: 26, height: 26, decoration: BoxDecoration(color: parseSubtitleHex(hex),
        shape: BoxShape.circle, border: Border.all(color: Colors.white24))),
    ])),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: bg,
    appBar: AppBar(backgroundColor: bg, foregroundColor: Colors.white, elevation: 0,
      title: const Text('Kustomisasi Subtitle', style: TextStyle(fontSize: 20)),
      actions: [IconButton(onPressed: _reset, icon: const Icon(Icons.restart_alt_rounded, color: orange))]),
    body: SafeArea(child: Column(children: [
      Expanded(child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 18), children: [
        Center(child: Container(width: MediaQuery.of(context).size.width * .72, height: 190,
          margin: const EdgeInsets.only(bottom: 22),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [Color(0xFF5A4A48), Color(0xFFB87972), Color(0xFF463B3B)])),
          child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
            const Text('Subtitle Non Dialogue', style: TextStyle(color: Colors.white, backgroundColor: Colors.black54, fontSize: 11)),
            Opacity(opacity: p.subtitleOverallOpacity, child: Text('Love Anidesu!!!', style: TextStyle(color: parseSubtitleHex(p.subtitleColorHex), fontSize: 14,
              fontWeight: FontWeight.w700, shadows: buildSubtitleShadows(p.subtitleOutlineType,p.subtitleOutlineWidth,parseSubtitleHex(p.subtitleOutlineColorHex), shadowColor: parseSubtitleHex(p.subtitleShadowColorHex), shadowDistance: p.subtitleShadowDistance, shadowBlur: p.subtitleShadowBlur, shadowAngle: p.subtitleShadowAngle, shadowWidth: p.subtitleShadowWidth)))),
            const SizedBox(height: 12),
            const Text('Subtitle Dialogue', style: TextStyle(color: Colors.white, backgroundColor: Colors.black54, fontSize: 11)),
            Opacity(opacity: p.subtitleOverallOpacity, child: Text('Love Anidesu!!!', style: buildSubtitleTextStyle(p,fontSize: 18))),
            const SizedBox(height: 18),
          ])))),
        InkWell(onTap: _font, child: _card(Row(children: [
          const Expanded(child: Text('Gaya Font', style: TextStyle(color: Colors.white, fontSize: 14))),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            const Icon(Icons.chevron_right, color: orange),
            Text(p.subtitleFont.isEmpty ? 'Bawaan Anidesu (Roboto Medium)' : p.subtitleFont,
              style: const TextStyle(color: muted, fontSize: 12)),
          ]),
        ]))),
        _step('Ukuran Font',(32.0*p.subtitleScale).toStringAsFixed(1)+' px',p.subtitleScale,0.25/25.0,0.5,2.5,p.setSubtitleScale),
        _step('Ketebalan Font',p.subtitleFontWeight.toString(),p.subtitleFontWeight.toDouble(),100,100,900,(v)=>p.setSubtitleFontWeight(v.round())),
        _colorRow('Warna Font',p.subtitleColorHex,p.setSubtitleColorHex),
        _step('Ketebalan Garis Tepi',p.subtitleOutlineWidth.toStringAsFixed(1)+' px',p.subtitleOutlineWidth,0.25,0,8,p.setSubtitleOutlineWidth),
        _colorRow('Warna Garis Tepi',p.subtitleOutlineColorHex,p.setSubtitleOutlineColorHex),
        _step('Sudut Bayangan',p.subtitleShadowAngle.round().toString()+'°',p.subtitleShadowAngle,15,0,360,p.setSubtitleShadowAngle),
        _step('Ketebalan Bayangan',p.subtitleShadowWidth.toStringAsFixed(1)+' px',p.subtitleShadowWidth,0.25,0,8,p.setSubtitleShadowWidth),
        _step('Jarak Bayangan',p.subtitleShadowDistance.toStringAsFixed(1)+' px',p.subtitleShadowDistance,0.25,0,20,p.setSubtitleShadowDistance),
        _step('Ukuran Sebaran Bayangan',p.subtitleShadowBlur.toStringAsFixed(1)+' px',p.subtitleShadowBlur,0.25,0,20,p.setSubtitleShadowBlur),
        _colorRow('Warna Bayangan',p.subtitleShadowColorHex,p.setSubtitleShadowColorHex),
        _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Expanded(child: Text('Transparansi Subtitle', style: TextStyle(color: Colors.white, fontSize: 14))),
            Text('${(p.subtitleOverallOpacity * 100).round()}%', style: const TextStyle(color: muted, fontSize: 13)),
          ]),
          Slider(
            value: p.subtitleOverallOpacity,
            min: 0,
            max: 1,
            divisions: 100,
            activeColor: orange,
            onChanged: (value) => _apply(() => p.setSubtitleOverallOpacity(value)),
          ),
        ])),
        _colorRow('Warna Latar','#000000FF', (v)=>p.setSubtitleBgOpacity(0)),
        _card(const Text('Subtitle dialog mengikuti semua pengaturan tampilan. Subtitle non-dialog hanya mengikuti gaya font yang dipilih.',
          style: TextStyle(color: muted, fontSize: 13, height: 1.5))),
      ])),
      Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 16), child: SizedBox(width: double.infinity, height: 52,
        child: FilledButton(style: FilledButton.styleFrom(backgroundColor: orange, foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
          onPressed: () => Navigator.of(context).pop(), child: const Text('Simpan')))),
    ])),
  );
}

/// Live subtitle styling: bundled-font picker, text colour swatches, a
/// background-opacity slider, a vertical-position slider, and size. Each change
/// persists to [PlaybackPrefs] and re-applies via [PlayerCubit.applySubtitleStyle].
class _SubtitleStyleSheet extends StatefulWidget {
  const _SubtitleStyleSheet({
    required this.controller,
    required this.onInteract,
  });
  final PlayerCubit? controller;
  final VoidCallback onInteract;

  @override
  State<_SubtitleStyleSheet> createState() => _SubtitleStyleSheetState();
}

class _SubtitleStyleSheetState extends State<_SubtitleStyleSheet> {
  PlaybackPrefs get _prefs => sl<PlaybackPrefs>();

  /// Which fonts are usable now (Default/bundled/downloaded). A font that isn't
  /// downloaded yet is fetched on tap. Populated in [initState].
  final Map<String, bool> _fontAvailable = {};

  /// Fonts currently downloading — their row shows a spinner.
  final Set<String> _downloading = {};
  bool _typographyExpanded = true;
  bool _colorsExpanded = true;
  bool _miscExpanded = true;
  String _selectedColor = 'text';

  @override
  void initState() {
    super.initState();
    () async {
      // Only the player registers cached fonts on start, so opening this from
      // Settings would preview every already-cached font in the default one.
      await SubtitleFontService.instance.registerCached();
      for (final f in kBundledSubtitleFonts) {
        if (f.isEmpty) continue;
        _fontAvailable[f] = await SubtitleFontService.instance.isAvailable(f);
      }
      if (mounted) setState(() {});
    }();
  }

  /// Fonts the user added themselves, family → filename. Read fresh each build
  /// so adding or removing one updates the list without extra bookkeeping.
  Map<String, String> get _customFonts => _prefs.customSubtitleFonts;

  /// Pick a .ttf/.otf and add it. The family is read out of the file, so the
  /// name shown here is the one libass will match on.
  Future<void> _addCustomFont() async {
    try {
      final picked = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: const ['ttf', 'otf'],
      );
      final path = picked?.path;
      if (path == null) return;
      final family = await SubtitleFontService.instance.addCustomFont(path);
      if (!mounted) return;
      if (family == null) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text(context.l10n.couldntAddFont)),
        );
        return;
      }
      // Select it straight away — picking a font you just added and having
      // nothing change would read as a failure.
      await _apply(() => _prefs.setSubtitleFont(family));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text(context.l10n.couldntAddFont)),
        );
      }
    }
  }

  /// Remove a custom font. [SubtitleFontService.removeCustomFont] also resets
  /// the selection when the removed font was the active one, so the sheet just
  /// has to re-read and re-apply.
  Future<void> _removeCustomFont(String family) async {
    await SubtitleFontService.instance.removeCustomFont(family);
    if (!mounted) return;
    await _apply(() async {});
  }

  /// Apply a font — downloading it first (with a spinner on its row) if it
  /// isn't cached yet.
  Future<void> _pickFont(String f) async {
    if (f.isNotEmpty && !(_fontAvailable[f] ?? true)) {
      if (_downloading.contains(f)) return; // already fetching
      setState(() => _downloading.add(f));
      final ok = await SubtitleFontService.instance.ensure(f);
      if (!mounted) return;
      setState(() {
        _downloading.remove(f);
        _fontAvailable[f] = ok;
      });
      if (!ok) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text(context.l10n.couldntDownloadFile(f))),
        );
        return;
      }
    }
    await _apply(() => _prefs.setSubtitleFont(f));
  }

  // Text-colour swatches, stored as #RRGGBBAA (opaque).
  static const List<String> _colorHexes = [
    '#FFFFFFFF',
    '#FFFF00FF',
    '#00E5FFFF',
    '#7CFC00FF',
    '#FF6B6BFF',
    '#000000FF',
  ];
  Future<void> _apply(Future<void> Function() mutate) async {
    await mutate();
    await widget.controller?.applySubtitleStyle();
    if (mounted) setState(() {});
    widget.onInteract();
  }

  Future<void> _resetTypography() => _apply(() async {
    await _prefs.setSubtitleFont('');
    await _prefs.setSubtitleFontWeight(400);
    await _prefs.setSubtitleItalic(false);
    await _prefs.setSubtitleJustification('center');
    await _prefs.setSubtitleOutlineType('soft');
    await _prefs.setSubtitleOutlineWidth(2.5);
    await _prefs.setSubtitleShadowAngle(45.0);
    await _prefs.setSubtitleShadowDistance(2.5);
    await _prefs.setSubtitleShadowBlur(2.5);
    await _prefs.setSubtitleShadowWidth(2.5);
    await _prefs.setSubtitleScale(0.78125);
  });

  Future<void> _resetSelectedColor() => _apply(() async {
    switch (_selectedColor) {
      case 'outline':
        await _prefs.setSubtitleOutlineColorHex('#000000FF');
        break;
      case 'shadow':
        await _prefs.setSubtitleShadowColorHex('#000000FF');
        break;
      default:
        await _prefs.setSubtitleColorHex('#FFFFFFFF');
    }
  });

  Future<void> _resetMiscellaneous() => _apply(() async {
    await _prefs.setStyledSubtitles(false);
    await _prefs.setSubtitleBgOpacity(0.0);
    await _prefs.setSubtitlePosition(95);
    await _prefs.setSubtitleScale(0.78125);
  });

  /// Reset every subtitle-style pref to its default value.
  Future<void> _resetToDefault() => _apply(() async {
    await _prefs.setSubtitleFont('');
    await _prefs.setSubtitleColorHex('#FFFFFFFF');
    await _prefs.setSubtitleTextOpacity(1.0);
    await _prefs.setSubtitleOutlineType('soft');
    await _prefs.setSubtitleOutlineColorHex('#000000FF');
    await _prefs.setSubtitleOutlineWidth(2.5);
    await _prefs.setSubtitleFontWeight(400);
    await _prefs.setSubtitleItalic(false);
    await _prefs.setSubtitleJustification('center');
    await _prefs.setSubtitleShadowAngle(45.0);
    await _prefs.setSubtitleShadowWidth(2.5);
    await _prefs.setSubtitleShadowDistance(2.5);
    await _prefs.setSubtitleShadowBlur(2.5);
    await _prefs.setSubtitleShadowColorHex('#000000FF');
    await _prefs.setSubtitleOverallOpacity(1.0);
    await _prefs.setSubtitleBgOpacity(0.0);
    await _prefs.setSubtitlePosition(95);
    await _prefs.setSubtitleScale(0.78125);
    await _prefs.setStyledSubtitles(false);
  });

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    final portrait = MediaQuery.of(context).orientation == Orientation.portrait;
    final font = _prefs.subtitleFont;
    final size = _prefs.subtitleScale;

    Widget card({
      required String title,
      required IconData icon,
      required bool expanded,
      required VoidCallback onToggle,
      required List<Widget> children,
    }) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.hairline),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: onToggle,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                child: Row(
                  children: [
                    Icon(icon, color: AppColors.textPrimary, size: 23),
                    const SizedBox(width: 14),
                    Expanded(child: Text(title, style: AppText.title)),
                    AnimatedRotation(
                      turns: expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 180),
                      child: Icon(Icons.keyboard_arrow_down_rounded,
                          color: AppColors.textSecondary, size: 25),
                    ),
                  ],
                ),
              ),
            ),
            if (expanded) ...children,
            if (expanded) const SizedBox(height: 10),
          ],
        ),
      );
    }

    Widget page(Widget child) => ListView(
      padding: const EdgeInsets.fromLTRB(5, 5, 5, 16),
      children: [child],
    );

    final typographyCard = card(
      title: 'Tipografi',
      icon: Icons.text_fields_rounded,
      expanded: _typographyExpanded,
      onToggle: () => setState(() => _typographyExpanded = !_typographyExpanded),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
              IconButton.filledTonal(
                tooltip: 'Tebal',
                onPressed: () => _apply(() => _prefs.setSubtitleFontWeight(
                  _prefs.subtitleFontWeight >= 600 ? 400 : 700,
                )),
                style: IconButton.styleFrom(
                  foregroundColor: _prefs.subtitleFontWeight >= 600
                      ? AppColors.accent : AppColors.textSecondary,
                  backgroundColor: _prefs.subtitleFontWeight >= 600
                      ? AppColors.accent.withValues(alpha: 0.16) : AppColors.surface,
                ),
                icon: const Icon(Icons.format_bold_rounded, size: 25),
              ),
              IconButton.filledTonal(
                tooltip: 'Miring',
                onPressed: () => _apply(() => _prefs.setSubtitleItalic(!_prefs.subtitleItalic)),
                style: IconButton.styleFrom(
                  foregroundColor: _prefs.subtitleItalic
                      ? AppColors.accent : AppColors.textSecondary,
                  backgroundColor: _prefs.subtitleItalic
                      ? AppColors.accent.withValues(alpha: 0.16) : AppColors.surface,
                ),
                icon: const Icon(Icons.format_italic_rounded, size: 25),
              ),
              const SizedBox(width: 4),
              for (final align in ['left', 'center', 'right'])
                IconButton.filledTonal(
                  tooltip: align == 'left' ? 'Rata kiri' : align == 'right' ? 'Rata kanan' : 'Rata tengah',
                  onPressed: () => _apply(() => _prefs.setSubtitleJustification(align)),
                  style: IconButton.styleFrom(
                    foregroundColor: _prefs.subtitleJustification == align
                        ? AppColors.accent : AppColors.textSecondary,
                    backgroundColor: _prefs.subtitleJustification == align
                        ? AppColors.accent.withValues(alpha: 0.16) : AppColors.surface,
                  ),
                  icon: Icon(
                    align == 'left' ? Icons.format_align_left_rounded
                      : align == 'right' ? Icons.format_align_right_rounded
                      : Icons.format_align_center_rounded,
                    size: 23,
                  ),
                ),
              const SizedBox(width: 4),
              TextButton.icon(
                onPressed: _resetTypography,
                icon: const Icon(Icons.format_clear_rounded, size: 19),
                label: const Text('Reset'),
              ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(context.l10n.font,
              style: AppText.caption.copyWith(color: AppColors.textSecondary)),
        ),
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: h * (portrait ? 0.22 : 0.18)),
          child: ListView(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            children: [
              for (final f in kBundledSubtitleFonts)
                _SheetRow(
                  label: f.isEmpty ? context.l10n.defaultLabel : f,
                  subtitle: _downloading.contains(f)
                      ? context.l10n.downloading
                      : ((_fontAvailable[f] ?? true) ? null : context.l10n.tapToDownloadFont),
                  loading: _downloading.contains(f),
                  active: font == f,
                  onTap: () => _pickFont(f),
                ),
              for (final f in _customFonts.keys)
                _SheetRow(
                  label: f,
                  active: font == f,
                  onTap: () => _pickFont(f),
                  onRemove: () => _removeCustomFont(f),
                ),
              _SheetRow(
                label: context.l10n.addFont,
                icon: Icons.upload_file,
                active: false,
                onTap: _addCustomFont,
              ),
            ],
          ),
        ),
        _SheetSectionHeader('Ukuran font'),
        _SliderRow(
          value: size.clamp(0.6, 2.0),
          min: 0.6,
          max: 2.0,
          divisions: 14,
          label: '${(size * 100).round()}%',
          onChanged: (v) => _apply(() => _prefs.setSubtitleScale(v)),
        ),
        _SheetSectionHeader(context.l10n.outlineStyle),
        for (final (id, _) in kSubtitleOutlineTypes)
          _SheetRow(
            label: _subtitleOutlineLabel(context.l10n, id),
            active: _prefs.subtitleOutlineType == id,
            onTap: () => _apply(() => _prefs.setSubtitleOutlineType(id)),
          ),
        _SheetSectionHeader(context.l10n.outlineWidth),
        _SliderRow(
          value: _prefs.subtitleOutlineWidth,
          min: 0,
          max: 8,
          divisions: 16,
          label: _prefs.subtitleOutlineWidth.toStringAsFixed(1),
          onChanged: (v) => _apply(() => _prefs.setSubtitleOutlineWidth(v)),
        ),
        _SheetSectionHeader('Ketebalan font'),
        _SliderRow(
          value: _prefs.subtitleFontWeight.toDouble(),
          min: 100,
          max: 900,
          divisions: 8,
          label: _prefs.subtitleFontWeight.toString(),
          onChanged: (v) => _apply(() => _prefs.setSubtitleFontWeight(v.round())),
        ),
        _SheetSectionHeader('Ketebalan bayangan'),
        _SliderRow(
          value: _prefs.subtitleShadowWidth,
          min: 0,
          max: 8,
          divisions: 32,
          label: _prefs.subtitleShadowWidth.toStringAsFixed(1),
          onChanged: (v) => _apply(() => _prefs.setSubtitleShadowWidth(v)),
        ),
        _SheetSectionHeader('Jarak bayangan'),
        _SliderRow(
          value: _prefs.subtitleShadowDistance,
          min: 0,
          max: 20,
          divisions: 40,
          label: '${_prefs.subtitleShadowDistance.toStringAsFixed(1)} px',
          onChanged: (v) => _apply(() => _prefs.setSubtitleShadowDistance(v)),
        ),
        _SheetSectionHeader('Ukuran bayangan'),
        _SliderRow(
          value: _prefs.subtitleShadowBlur,
          min: 0,
          max: 20,
          divisions: 40,
          label: '${_prefs.subtitleShadowBlur.toStringAsFixed(1)} px',
          onChanged: (v) => _apply(() => _prefs.setSubtitleShadowBlur(v)),
        ),
      ],
    );

    String selectedHex() => switch (_selectedColor) {
      'outline' => _prefs.subtitleOutlineColorHex,
      'shadow' => _prefs.subtitleShadowColorHex,
      _ => _prefs.subtitleColorHex,
    };
    Future<void> setColorChannel(int channel, double value) async {
      final raw = selectedHex().replaceFirst('#', '').toUpperCase();
      final normalized = raw.length == 8 ? raw : raw.length == 6 ? '${raw}FF' : 'FFFFFFFF';
      final parts = [
        int.parse(normalized.substring(0, 2), radix: 16),
        int.parse(normalized.substring(2, 4), radix: 16),
        int.parse(normalized.substring(4, 6), radix: 16),
        int.parse(normalized.substring(6, 8), radix: 16),
      ];
      parts[channel] = value.round().clamp(0, 255).toInt();
      final hex = '#${parts.map((v) => v.toRadixString(16).padLeft(2, '0').toUpperCase()).join()}';
      await _apply(() async {
        switch (_selectedColor) {
          case 'outline':
            await _prefs.setSubtitleOutlineColorHex(hex);
            break;
          case 'shadow':
            await _prefs.setSubtitleShadowColorHex(hex);
            break;
          default:
            await _prefs.setSubtitleColorHex(hex);
        }
      });
    }

    final rawCurrentHex = selectedHex().replaceFirst('#', '').toUpperCase();
    final currentHex = rawCurrentHex.length == 8 ? rawCurrentHex : rawCurrentHex.length == 6 ? '${rawCurrentHex}FF' : 'FFFFFFFF';
    final colorChannels = [
      int.parse(currentHex.substring(0, 2), radix: 16),
      int.parse(currentHex.substring(2, 4), radix: 16),
      int.parse(currentHex.substring(4, 6), radix: 16),
      int.parse(currentHex.substring(6, 8), radix: 16),
    ];
    final colorsCard = card(
      title: 'Warna',
      icon: Icons.palette_outlined,
      expanded: _colorsExpanded,
      onToggle: () => setState(() => _colorsExpanded = !_colorsExpanded),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 0, 10, 4),
          child: Row(
            children: [
              for (final item in [
                ('text', Icons.format_color_text_rounded, 'Teks'),
                ('outline', Icons.border_color_rounded, 'Outline'),
                ('shadow', Icons.format_color_fill_rounded, 'Bayangan'),
              ])
                IconButton.filledTonal(
                  tooltip: item.$3,
                  onPressed: () => setState(() => _selectedColor = item.$1),
                  style: IconButton.styleFrom(
                    foregroundColor: _selectedColor == item.$1
                        ? AppColors.accent : AppColors.textSecondary,
                    backgroundColor: _selectedColor == item.$1
                        ? AppColors.accent.withValues(alpha: 0.16) : AppColors.surface,
                  ),
                  icon: Icon(item.$2, size: 23),
                ),
              const SizedBox(width: 8),
              Expanded(child: Text(
                _selectedColor == 'outline' ? 'Outline'
                  : _selectedColor == 'shadow' ? 'Bayangan' : 'Teks',
                style: AppText.body,
              )),
              TextButton.icon(
                onPressed: _resetSelectedColor,
                icon: const Icon(Icons.format_color_reset_rounded, size: 19),
                label: const Text('Reset'),
              ),
            ],
          ),
        ),
        for (final item in [
          ('Merah', 0, Color(0xFFFF3B30)),
          ('Hijau', 1, Color(0xFF34C759)),
          ('Biru', 2, Color(0xFF3478F6)),
          ('Alpha', 3, Colors.white),
        ])
          _SliderRow(
            value: colorChannels[item.$2].toDouble(),
            min: 0,
            max: 255,
            divisions: 255,
            label: colorChannels[item.$2].toString(),
            activeColor: item.$3,
            onChanged: (v) => setColorChannel(item.$2, v),
          ),
      ],
    );

    final miscellaneousCard = card(
      title: 'Lainnya',
      icon: Icons.tune_rounded,
      expanded: _miscExpanded,
      onToggle: () => setState(() => _miscExpanded = !_miscExpanded),
      children: [
        SwitchListTile.adaptive(
          value: _prefs.styledSubtitles,
          activeColor: AppColors.accent,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          title: const Text('Pertahankan gaya ASS/SSA'),
          subtitle: const Text('Gunakan format dan gaya asli subtitle ASS/SSA'),
          onChanged: (v) => _apply(() => _prefs.setStyledSubtitles(v)),
        ),
        _SheetSectionHeader('Posisi subtitle'),
        _SliderRow(
          value: _prefs.subtitlePosition.toDouble(),
          min: 0,
          max: 100,
          divisions: 100,
          label: _prefs.subtitlePosition.toString(),
          onChanged: (v) => _apply(() => _prefs.setSubtitlePosition(v.round())),
        ),
        _SheetSectionHeader('Transparansi latar'),
        _SliderRow(
          value: _prefs.subtitleBgOpacity,
          min: 0,
          max: 1,
          divisions: 20,
          label: '${(_prefs.subtitleBgOpacity * 100).round()}%',
          onChanged: (v) => _apply(() => _prefs.setSubtitleBgOpacity(v)),
        ),
        _SheetSectionHeader('Sudut bayangan'),
        _SliderRow(
          value: _prefs.subtitleShadowAngle,
          min: 0,
          max: 360,
          divisions: 36,
          label: '${_prefs.subtitleShadowAngle.round()}°',
          onChanged: (v) => _apply(() => _prefs.setSubtitleShadowAngle(v)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton.icon(
              onPressed: _resetMiscellaneous,
              icon: const Icon(Icons.edit_off_rounded, size: 19),
              label: const Text('Reset'),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: OutlinedButton.icon(
            onPressed: _resetToDefault,
            icon: const Icon(Icons.restart_alt_rounded, size: 19),
            label: Text(context.l10n.resetToDefault),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textPrimary,
              side: BorderSide(color: AppColors.hairline),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );

    return FractionallySizedBox(
      heightFactor: 0.94,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 8, 4),
                child: Row(
                  children: [
                    Expanded(child: Text(context.l10n.subtitleStyle, style: AppText.headline)),
                    IconButton(
                      tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Container(
                margin: const EdgeInsets.fromLTRB(8, 4, 8, 10),
                height: 76,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF33405E), Color(0xFF0E121B)],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    context.l10n.theQuickBrownFox,
                    textAlign: TextAlign.center,
                    style: buildSubtitleTextStyle(_prefs, fontSize: 22.0 * size),
                  ),
                ),
              ),
              Expanded(
                child: portrait
                    ? PageView(
                        children: [
                          page(typographyCard),
                          page(colorsCard),
                          page(miscellaneousCard),
                        ],
                      )
                    : ListView(
                        padding: const EdgeInsets.only(bottom: 16),
                        children: [typographyCard, colorsCard, miscellaneousCard],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Color _colorFromHex(String hex) {
    final h = hex.replaceFirst('#', '');
    if (h.length != 8) return Colors.white;
    final rgb = h.substring(0, 6);
    final a = h.substring(6, 8);
    return Color(int.parse('$a$rgb', radix: 16));
  }
}

/// A circular colour swatch with a label, accent-ringed when active.
class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({
    required this.color,
    required this.label,
    required this.active,
    required this.onTap,
  });
  final Color color;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: active ? AppColors.accent : AppColors.hairline,
              width: active ? 3 : 1,
            ),
          ),
          child: active
              ? Icon(
                  Icons.check_rounded,
                  size: 18,
                  color: color.computeLuminance() > 0.5
                      ? Colors.black
                      : Colors.white,
                )
              : null,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppText.caption.copyWith(
            color: active ? AppColors.accent : AppColors.textSecondary,
          ),
        ),
      ],
    );
    // TV: GestureDetector isn't D-pad focusable, so colours can't be selected.
    // Wrap in TvFocusable (OK selects, shows a focus ring). Mobile keeps the tap.
    if (sl<AppMode>().isTv) {
      return TvFocusable(onTap: onTap, child: content);
    }
    return GestureDetector(onTap: onTap, child: content);
  }
}

/// A labelled slider row used inside the Subtitle-style sheet.
class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.label,
    required this.onChanged,
    this.activeColor,
  });
  final Color? activeColor;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String label;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    // On TV a focused Slider swallows D-pad ↑/↓ (you can't move off it). Swap in
    // a focusable ◄ value ► stepper: ◄/► adjust, ↑/↓ move to the next control.
    if (sl<AppMode>().isTv) {
      final step = (max - min) / divisions;
      return _TvStepperRow(
        label: label,
        onDec: value <= min
            ? null
            : () => onChanged((value - step).clamp(min, max)),
        onInc: value >= max
            ? null
            : () => onChanged((value + step).clamp(min, max)),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: activeColor ?? AppColors.accent,
                thumbColor: activeColor ?? AppColors.accent,
                inactiveTrackColor: AppColors.surface2,
              ),
              child: Slider(
                value: value.clamp(min, max),
                min: min,
                max: max,
                divisions: divisions,
                onChanged: onChanged,
              ),
            ),
          ),
          SizedBox(
            width: 64,
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: AppText.body.copyWith(
                color: AppColors.accent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// TV replacement for [_SliderRow]'s slider: one full-width focusable row so
/// D-pad ▲/▼ reliably land on it (edge buttons get skipped by directional
/// focus, and a Slider would trap ▲/▼). When focused (accent ring), ◀ decreases
/// and ▶ increases; ▲/▼/OK pass through to move to the next control.
class _TvStepperRow extends StatefulWidget {
  const _TvStepperRow({required this.label, this.onDec, this.onInc});
  final String label;
  final VoidCallback? onDec;
  final VoidCallback? onInc;
  @override
  State<_TvStepperRow> createState() => _TvStepperRowState();
}

class _TvStepperRowState extends State<_TvStepperRow> {
  bool _focused = false;

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent)
      return KeyEventResult.ignored;
    if (e.logicalKey == LogicalKeyboardKey.arrowLeft) {
      widget.onDec?.call();
      return KeyEventResult.handled;
    }
    if (e.logicalKey == LogicalKeyboardKey.arrowRight) {
      widget.onInc?.call();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored; // ▲/▼/OK propagate → focus traversal
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      onKeyEvent: _onKey,
      onFocusChange: (f) => setState(() => _focused = f),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: _focused
              ? AppColors.accent.withValues(alpha: 0.16)
              : Colors.transparent,
          border: Border.all(
            color: _focused ? AppColors.accent : AppColors.surface2,
            width: _focused ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.chevron_left,
              color: widget.onDec == null
                  ? AppColors.textTertiary
                  : AppColors.accent,
            ),
            Expanded(
              child: Text(
                widget.label,
                textAlign: TextAlign.center,
                style: AppText.body.copyWith(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: widget.onInc == null
                  ? AppColors.textTertiary
                  : AppColors.accent,
            ),
          ],
        ),
      ),
    );
  }
}

/// Play/pause button whose icon MORPHS between play and pause (the YouTube
/// style) instead of a hard swap. Driven by [playing]; sits in a soft ringed
/// circle. Pure UI — [onTap] is the same togglePlay call as before.
/// Soft, rounded play/pause — the stock [AnimatedIcons]
/// morph uses sharp, blocky shapes; the `_rounded` variants have the pill
/// corners we want. Cross-fades + gently scales between the two on toggle.
/// Compact player panels use the same centered footprint as the episode
/// summary dialog, with a slightly taller content area for selectable rows.
class _CompactPlayerDialog extends StatelessWidget {
  const _CompactPlayerDialog({
    required this.child,
    this.maxHeight = 360,
  });

  final Widget child;
  final double maxHeight;

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: AppColors.surface,
    insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: const BorderSide(color: AppColors.hairline),
    ),
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: 500, maxHeight: maxHeight),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: child,
      ),
    ),
  );
}

class _SheetSurface extends StatelessWidget {
  const _SheetSurface({
    bool blur = true,
    double opacity = 0.75,
    BorderRadius? borderRadius,
    required this.child,
  });
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(24);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        10,
        0,
        10,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: r,
                  border: Border.all(color: AppColors.hairline),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x66000000),
                      blurRadius: 40,
                      offset: Offset(0, 14),
                    ),
                  ],
                ),
                child: ClipRRect(borderRadius: r, child: child),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Colour-adjustment sheet: quick-preset chips + individual sliders for mpv's
/// video equalizer (brightness/contrast/saturation/gamma/hue, -100..100). Live
/// preview on drag; persists on release.
class _ColorSheet extends StatefulWidget {
  const _ColorSheet({required this.controller, required this.onInteract});
  final PlayerCubit controller;
  final VoidCallback onInteract;
  @override
  State<_ColorSheet> createState() => _ColorSheetState();
}

class _ColorSheetState extends State<_ColorSheet> {
  late int _b, _c, _s, _g, _h;

  static const _quick = [
    'natural',
    'anime',
    'anime_vibrant',
    'vivid',
    'cinema',
    'grayscale',
  ];

  @override
  void initState() {
    super.initState();
    final p = sl<PlaybackPrefs>();
    _b = p.colorBrightness;
    _c = p.colorContrast;
    _s = p.colorSaturation;
    _g = p.colorGamma;
    _h = p.colorHue;
  }

  void _applyPreset(ColorProfile prof) {
    widget.controller.applyColorPreset(prof);
    setState(() {
      _b = prof.brightness;
      _c = prof.contrast;
      _s = prof.saturation;
      _g = prof.gamma;
      _h = prof.hue;
    });
    widget.onInteract();
  }

  Widget _slider(String label, String prop, int value, ValueChanged<int> set) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: AppText.body),
              Text(
                value > 0 ? '+$value' : '$value',
                style: AppText.body.copyWith(
                  color: value == 0 ? AppColors.textTertiary : AppColors.accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.accent,
              thumbColor: AppColors.accent,
              inactiveTrackColor: AppColors.textSecondary.withValues(
                alpha: 0.3,
              ),
              overlayColor: AppColors.accent.withValues(alpha: 0.2),
            ),
            child: Slider(
              min: -100,
              max: 100,
              divisions: 200,
              value: value.toDouble(),
              label: '$value',
              onChanged: (v) {
                set(v.round());
                widget.controller.previewColor(prop, v.round());
              },
              onChangeEnd: (v) => widget.controller.setColor(prop, v.round()),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(2),
              ),
              child: const SizedBox(width: 36, height: 4),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 12, 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(context.l10n.colour, style: AppText.headline),
              TextButton(
                onPressed: () {
                  widget.controller.resetColor();
                  setState(() => _b = _c = _s = _g = _h = 0);
                  widget.onInteract();
                },
                child: Text(context.l10n.reset),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              for (final id in _quick)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: GestureDetector(
                    onTap: () => _applyPreset(ColorProfiles.byId(id)),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surface2,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text(
                        ColorProfiles.byId(id).label,
                        style: AppText.body,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
            children: [
              _slider(
                context.l10n.brightness,
                'brightness',
                _b,
                (v) => setState(() => _b = v),
              ),
              _slider(
                context.l10n.contrast,
                'contrast',
                _c,
                (v) => setState(() => _c = v),
              ),
              _slider(
                context.l10n.saturation,
                'saturation',
                _s,
                (v) => setState(() => _s = v),
              ),
              _slider(
                context.l10n.gamma,
                'gamma',
                _g,
                (v) => setState(() => _g = v),
              ),
              _slider(
                context.l10n.hue,
                'hue',
                _h,
                (v) => setState(() => _h = v),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A sheet whose options are one wrapping row of chips rather than a vertical
/// list. For short lists of short values — the kind where a full-height list
/// costs the whole screen for six words. Same grab handle and header as
/// [_SheetColumn] so the two read as the same family.
class _SheetChips extends StatelessWidget {
  const _SheetChips({
    required this.header,
    required this.labels,
    required this.selected,
    required this.onSelect,
  });

  final String header;
  final List<String> labels;
  final int selected; // -1 = nothing matches
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(2),
              ),
              child: const SizedBox(width: 36, height: 4),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
          child: Text(header, style: AppText.headline),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < labels.length; i++)
                Material(
                  color: i == selected ? AppColors.accent : Colors.transparent,
                  shape: StadiumBorder(
                    side: i == selected
                        ? BorderSide.none
                        : BorderSide(
                            color: Colors.white.withValues(alpha: 0.16),
                          ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => onSelect(i),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      child: Text(
                        labels[i],
                        style: AppText.body.copyWith(
                          color: i == selected
                              ? Colors.white
                              : AppColors.textSecondary,
                          fontWeight: i == selected
                              ? FontWeight.w700
                              : FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _QuickSettingRow extends StatelessWidget {
  const _QuickSettingRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.value,
    this.showChevron = true,
    this.enabled = true,
    this.switchValue,
    this.onSwitchChanged,
  });

  final IconData icon;
  final String label;
  final String? value;
  final bool showChevron;
  final bool enabled;
  final bool? switchValue;
  final ValueChanged<bool>? onSwitchChanged;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 39),
        padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 6),
        child: Row(
          children: [
            Icon(icon, size: 19, color: AppColors.textPrimary),
            const SizedBox(width: 11),
            Expanded(
              child: Text(
                label,
                style: AppText.body.copyWith(
                  fontFamily: 'Urbanist',
                  color: enabled ? AppColors.textPrimary : AppColors.textSecondary,
                  fontSize: 13,
                  height: 1.35,
                  fontWeight: FontWeight.w400,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (value != null) ...[
              const SizedBox(width: 8),
              Text(
                value!,
                textAlign: TextAlign.end,
                style: AppText.body.copyWith(
                  fontFamily: 'Urbanist',
                  color: AppColors.textSecondary,
                  fontSize: 11.5,
                  height: 1.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (switchValue != null)
              Switch.adaptive(
                value: switchValue!,
                onChanged: onSwitchChanged,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              )
            else if (showChevron) ...[
              const SizedBox(width: 5),
              const Icon(Icons.chevron_right_rounded,
                  size: 19, color: AppColors.textPrimary),
            ],
          ],
        ),
      ),
    ),
  );
}

class _SheetColumn extends StatelessWidget {
  const _SheetColumn({
    required this.header,
    required this.children,
    this.compactDialog = false,
  });
  final String? header;
  final List<Widget> children;
  final bool compactDialog;

  @override
  Widget build(BuildContext context) {
    final handle = Center(
      child: Container(
        width: 38,
        height: 4,
        decoration: BoxDecoration(
          color: compactDialog
              ? Colors.white.withValues(alpha: 0.18)
              : AppColors.surface2,
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
    return Padding(
      padding: compactDialog
          ? const EdgeInsets.fromLTRB(18, 12, 18, 16)
          : EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (compactDialog) ...[
            handle,
            const SizedBox(height: 10),
          ] else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: handle,
            ),
          if (header != null && header!.isNotEmpty) ...[
            Padding(
              padding: compactDialog
                  ? EdgeInsets.zero
                  : const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Text(
                header!,
                style: compactDialog
                    ? const TextStyle(
                        fontFamily: 'Urbanist',
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      )
                    : AppText.headline.copyWith(fontFamily: 'Urbanist'),
              ),
            ),
            SizedBox(height: compactDialog ? 9 : 0),
          ],
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.48,
              ),
              child: ListView(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                children: children,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Source-picker row label: the provider's per-source name with its resolution
/// appended (e.g. "MovieBox (Hindi Audio) · 1080p"), so the quality shows even
/// when the source carries its own name. Skips a non-resolution quality
/// ("auto"/empty) and never doubles up a resolution the name already contains.
String _sourceLabelWithQuality(String label, String? quality) {
  final q = (quality ?? '').trim();
  if (q.isEmpty || q.toLowerCase() == 'auto') return label;
  if (label.toLowerCase().contains(q.toLowerCase())) return label;
  return '$label · $q';
}

class _SheetRow extends StatelessWidget {
  const _SheetRow({
    required this.label,
    required this.active,
    required this.onTap,
    this.onLongPress,
    this.icon,
    this.subtitle,
    this.subtitleWidget,
    this.toggleValue,
    this.loading = false,
    this.onRemove,
    this.compactDialog = false,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  /// Optional trailing icon (e.g. upload for "Load from file…").
  final IconData? icon;

  /// Optional secondary line under the label — explains what a setting does
  /// (e.g. for jargon like "Audio normalization") so it's self-describing.
  final String? subtitle;
  final Widget? subtitleWidget;

  /// When non-null, the row is a toggle: renders a trailing Switch reflecting
  /// this value (instead of the icon/check), and stays plain (no accent tint).
  final bool? toggleValue;

  /// Show a trailing spinner (e.g. while a font downloads).
  final bool loading;
  final bool compactDialog;

  /// When non-null the row gets a trailing remove button — used by the fonts
  /// the user added themselves, which are the only rows that can be deleted.
  /// Kept as a button rather than a long-press so it is discoverable.
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    // Netflix-style: the selected row is tinted + accent-bold with a trailing
    // check; others are plain.
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: compactDialog ? 0 : 12,
        vertical: compactDialog ? 2 : 3,
      ),
      child: Material(
        color: toggleValue == null && active
            ? AppColors.accentSoft
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          // A toggle owns its own Switch gesture. Letting the parent InkWell
          // also receive that tap can toggle twice and leave every switch
          // appearing stuck or out of sync.
          onTap: toggleValue == null ? onTap : null,
          onLongPress: onLongPress,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compactDialog ? 8 : 12,
              vertical: compactDialog ? 8 : 13,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: AppText.body.copyWith(
                          fontFamily: 'Urbanist',
                          color: toggleValue == null && active
                              ? AppColors.accent
                              : AppColors.textPrimary,
                          fontWeight: toggleValue == null && active
                              ? FontWeight.w700
                              : FontWeight.w500,
                          fontSize: compactDialog ? 13.5 : null,
                          height: compactDialog ? 1.45 : null,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (subtitle != null || subtitleWidget != null) ...[
                        const SizedBox(height: 2),
                        subtitleWidget ?? Text(
                          subtitle!,
                          style: AppText.caption.copyWith(fontFamily: 'Urbanist', color: AppColors.textSecondary),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                if (loading)
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.accent,
                    ),
                  )
                else if (toggleValue != null)
                  Switch.adaptive(
                    value: toggleValue!,
                    onChanged: (_) => onTap(),
                    activeThumbColor: Colors.white,
                    activeTrackColor: AppColors.accent,
                    inactiveThumbColor: AppColors.accent.withValues(alpha: 0.58),
                    inactiveTrackColor: AppColors.surface2,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  )
                else if (icon != null)
                  Icon(icon, color: AppColors.textSecondary, size: 20)
                else ...[
                  if (active)
                    Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.accent,
                      size: 20,
                    ),
                  if (onRemove != null)
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      // Free localised label so the bare icon isn't silent to
                      // screen readers.
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).deleteButtonTooltip,
                      color: AppColors.textSecondary,
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsetsDirectional.only(start: 8),
                      onPressed: onRemove,
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SheetSectionHeader extends StatelessWidget {
  const _SheetSectionHeader(this.label, {this.compactDialog = false});
  final String label;
  final bool compactDialog;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: compactDialog
          ? EdgeInsets.zero
          : const EdgeInsets.fromLTRB(20, 10, 20, 2),
      child: Text(
        compactDialog ? label : label.toUpperCase(),
        style: compactDialog
            ? const TextStyle(
                fontFamily: 'Urbanist',
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              )
            : AppText.caption.copyWith(fontFamily: 'Urbanist',
                color: AppColors.textTertiary,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
      ),
    );
  }
}

/// What to call a track in the picker: its own name when that name says
/// something, otherwise the language it reports, otherwise [fallback].
///
/// The language is spelled out rather than shown as the code the stream
/// carries, so this reads "English" and not "eng".
///
/// [titleSaysSomething] is [_titlesSaySomething] over the whole list, because
/// whether a title is worth showing cannot be judged one track at a time.
String _trackLabel(
  String? title,
  String? language,
  String fallback, {
  bool titleSaysSomething = true,
}) {
  final name = title?.trim();
  if (titleSaysSomething && name != null && name.isNotEmpty) return name;
  final lang = language?.trim();
  if (lang != null && lang.isNotEmpty) {
    return languageOfSource(lang)?.name ?? lang;
  }
  return fallback;
}

/// Whether a set of track titles is worth showing at all.
///
/// Two ways they are not. A release can stamp its own branding into every
/// track — one source labels all of its audio AND its subtitles
/// a site name plus a dot, which names nothing and makes two audio tracks look
/// identical — so a title shared by every track is no title. And a title with
/// no spaces but a dot in it is a domain or a filename, not a name, which
/// catches the same thing when there is only one track to compare.
bool _titlesSaySomething(Iterable<String?> titles) {
  final named = titles
      .map((t) => t?.trim() ?? '')
      .where((t) => t.isNotEmpty)
      .toList();
  if (named.isEmpty) return false;
  if (named.every((t) => !t.contains(' ') && t.contains('.'))) return false;
  return named.length < 2 || named.toSet().length > 1;
}

/// Displays the exact size advertised by a direct-file server, when available.
class _RemoteFileSizeLabel extends StatefulWidget {
  const _RemoteFileSizeLabel({required this.url, this.headers});
  final String url;
  final Map<String, String>? headers;
  @override
  State<_RemoteFileSizeLabel> createState() => _RemoteFileSizeLabelState();
}

class _RemoteFileSizeLabelState extends State<_RemoteFileSizeLabel> {
  late Future<int?> _size;
  @override
  void initState() {
    super.initState();
    _size = RemoteFileSize.lookup(widget.url, headers: widget.headers);
  }
  @override
  Widget build(BuildContext context) => FutureBuilder<int?>(
    future: _size,
    builder: (context, snapshot) {
      final size = snapshot.data;
      final label = snapshot.connectionState != ConnectionState.done
          ? 'Memeriksa ukuran…'
          : size == null ? 'Ukuran tidak diketahui' : RemoteFileSize.format(size);
      return Text(label, style: AppText.caption.copyWith(color: AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis);
    },
  );
}