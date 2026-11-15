// The controls laid over the video: top bar, centre transport, bottom block.
part of 'player_screen.dart';

class _ControlsOverlay extends StatelessWidget {
  const _ControlsOverlay({
    required this.controller,
    required this.state,
    required this.showTitle,
    required this.duration,
    required this.onDurationChanged,
    required this.onInteract,
    required this.onBack,
    required this.onSpeed,
    required this.onAudioSubs,
    required this.onQuality,
    required this.onSources,
    required this.onLock,
    required this.onRotate,
    required this.portraitMode,
    this.episodeDetailMode = false,
    required this.onSettings,
    required this.barConfig,
    required this.onZoom,
    required this.zoomLabel,
    required this.onPrev,
    required this.onSleep,
    required this.sleepActive,
    required this.decoderLabel,
    required this.onDecoder,
    required this.onEpisodes,
    required this.megaSkipEnabled,
    required this.megaSkipSeconds,
    required this.onMegaSkip,
    this.onPip,
    this.onChat,
    this.onEpisodeComments,
    this.onInfo,
    this.infoOpen = false,
    this.showQuality = false,
    required this.onScreenshot,
    required this.onEnhance,
    required this.enhanceActive,
    required this.onColorProfile,
    required this.cinematicLightingActive,
    required this.onCinematicLighting,
    required this.onEpisodeSummary,
    this.visible = true,
    required this.multiTouchActive,
  });

  final PlayerCubit controller;
  final PlayerState state;
  final String? showTitle;
  final Duration duration;
  final ValueChanged<Duration> onDurationChanged;
  final VoidCallback onInteract;
  final VoidCallback onBack;
  final VoidCallback onSpeed;
  final VoidCallback onAudioSubs;
  final VoidCallback onQuality;
  final VoidCallback onSources;
  final VoidCallback onLock;
  final VoidCallback
  onRotate; // flip between locked landscape and locked portrait
  final bool portraitMode; // true while watching upright
  final bool episodeDetailMode;
  final VoidCallback onSettings;

  /// The user's control arrangement — which bar each control sits on, in what
  /// order. Drives both bars; anything not placed is reachable via ⋮ More.
  final PlayerControlsConfig barConfig;

  final VoidCallback onZoom;
  final String zoomLabel;
  final VoidCallback? onPrev; // null = no previous episode
  final VoidCallback onSleep;
  final bool sleepActive;
  final String decoderLabel; // current decoder short label (HW/HW+/SW/AUTO)
  final VoidCallback onDecoder; // opens the in-player decoder picker
  final VoidCallback? onEpisodes; // null = single episode (no picker)
  final bool megaSkipEnabled; // MegaSkip pill above the seek bar
  final int megaSkipSeconds;
  final VoidCallback onMegaSkip;
  final VoidCallback? onPip; // null = PiP unsupported (hide the button)
  final VoidCallback? onChat; // in-room chat toggle (null = no active room)
  final VoidCallback? onEpisodeComments; // AniList episode thread discussions
  final VoidCallback? onInfo; // toggle the info panel (null = no fields picked)
  final bool infoOpen; // whether the info panel is currently shown
  final bool
  showQuality; // plain quality text on the top-bar right (with controls)
  final VoidCallback onScreenshot; // grab the current frame → gallery
  final VoidCallback onEnhance; // opens the video-enhancement (upscaler) picker
  final bool enhanceActive; // an upscaling preset is currently on
  final VoidCallback onColorProfile; // opens the colour-profile picker
  final bool cinematicLightingActive;
  final VoidCallback onCinematicLighting;
  final VoidCallback onEpisodeSummary;
  final bool visible; // drives the bars' slide-in (top drops, bottom rises)
  final bool multiTouchActive; // disables seek while two-finger stretch is active

  /// Overflow panel that slides in from the RIGHT (like the episodes panel) —
  /// holds the occasional actions so the control bars stay clean.
  void _showMore(BuildContext context) {
    onInteract();
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'More',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (ctx, _, _) {
        // Same width and surface as the episodes panel — this slides in from
        // the same edge with the same motion, so looking different was just
        // two panels wearing two skins. 40% was wider than it needed to be
        // for a short list of labels, too.
        final w = (MediaQuery.of(ctx).size.width * 0.33).clamp(250.0, 360.0);
        return Align(
          alignment: AlignmentDirectional.centerEnd,
          child: Material(
            color: Colors.transparent,
            child: FrostedSurface(
              blur: true,
              opacity: 0.88,
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(20),
              ),
              // Left inset dropped for the same reason as the episodes panel:
              // this is pinned to the RIGHT edge, so padding it away from a
              // cutout on the opposite side just eats its width.
              child: SafeArea(
                left: false,
                child: SizedBox(
                  width: w,
                  height: double.infinity,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 13, 8, 9),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(ctx.l10n.more, style: AppText.title),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.close_rounded,
                                color: AppColors.textSecondary,
                              ),
                              tooltip: ctx.l10n.close,
                              onPressed: () => Navigator.of(ctx).pop(),
                            ),
                          ],
                        ),
                      ),
                      const Divider(color: AppColors.hairline, height: 1),
                      const SizedBox(height: 4),
                      _MoreRow(
                        icon: Icons.memory_rounded,
                        label: ctx.l10n.decoderColon(decoderLabel),
                        onTap: () {
                          Navigator.pop(ctx);
                          onDecoder();
                        },
                      ),
                      _MoreRow(
                        icon: enhanceActive
                            ? Icons.auto_awesome_rounded
                            : Icons.auto_awesome_outlined,
                        label: ctx.l10n.anime4kEnhancement,
                        onTap: () {
                          Navigator.pop(ctx);
                          onEnhance();
                        },
                      ),
                      _MoreRow(
                        icon: cinematicLightingActive
                            ? Icons.wb_twilight_rounded
                            : Icons.wb_twilight_outlined,
                        label: cinematicLightingActive
                            ? 'Cinematic lighting: On'
                            : 'Cinematic lighting: Off',
                        onTap: () {
                          Navigator.pop(ctx);
                          onCinematicLighting();
                        },
                      ),
                      _MoreRow(
                        icon: Icons.subject_rounded,
                        label: 'Ringkasan episode',
                        onTap: () {
                          Navigator.pop(ctx);
                          onEpisodeSummary();
                        },
                      ),
                      _MoreRow(
                        icon: Icons.palette_outlined,
                        label: ctx.l10n.colour,
                        onTap: () {
                          Navigator.pop(ctx);
                          onColorProfile();
                        },
                      ),
                      _MoreRow(
                        icon: Icons.photo_camera_rounded,
                        label: ctx.l10n.snapshot,
                        onTap: () {
                          Navigator.pop(ctx);
                          onScreenshot();
                        },
                      ),
                      _MoreRow(
                        icon: sleepActive
                            ? Icons.bedtime_rounded
                            : Icons.bedtime_outlined,
                        label: ctx.l10n.sleepTimer,
                        onTap: () {
                          Navigator.pop(ctx);
                          onSleep();
                        },
                      ),
                      if (onPip != null)
                        _MoreRow(
                          icon: Icons.picture_in_picture_alt_rounded,
                          label: ctx.l10n.pictureInPicture,
                          onTap: () {
                            Navigator.pop(ctx);
                            onPip!();
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (ctx, anim, _, child) => SlideTransition(
        position: Tween(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
        child: child,
      ),
    );
  }

  /// Whether [id] sits on any bar. Used so a control that's already placed
  /// doesn't also get drawn by one of the player's own conditional buttons.
  bool _placedAnywhere(String id) => barConfig.slotOf(id) != ControlSlot.hidden;

  /// Top-bar versions of the arrangeable controls. Plain [IconButton]s rather
  /// than the bottom bar's chips, so anything moved up here matches the row
  /// it lands in instead of importing the bottom bar's look.
  List<Widget> _topButtons(BuildContext context, List<String> ids) {
    final out = <Widget>[];
    for (final id in ids) {
      switch (id) {
        case 'cast':
          // Android only, and only where the Cast framework is actually
          // supported — the setting decides placement, not availability.
          if (Platform.isAndroid) {
            out.add(
              AnimatedBuilder(
                animation: sl<CastController>(),
                builder: (context, _) {
                  final castCtrl = sl<CastController>();
                  if (!castCtrl.castSupported) return const SizedBox.shrink();
                  return _BarButton(
                    icon: castCtrl.state == CastState.connected
                        ? Icons.cast_connected
                        : Icons.cast,
                    tooltip: context.l10n.cast,
                    onTap: () => castCtrl.pickDevice(),
                  );
                },
              ),
            );
          }
        case 'lock':
          out.add(
            _BarButton(
              icon: Icons.lock_open_rounded,
              tooltip: context.l10n.lockControls,
              onTap: onLock,
            ),
          );
        case 'info':
          if (onInfo != null) {
            out.add(
              _BarButton(
                icon: Icons.info_outline_rounded,
                color: infoOpen ? AppColors.accent : Colors.white,
                tooltip: context.l10n.playbackStats,
                onTap: onInfo!,
              ),
            );
          }
        default:
          final spec = _specFor(context, id);
          if (spec != null) {
            out.add(
              _BarButton(
                icon: spec.$1,
                tooltip: spec.$2,
                onTap: spec.$3,
              ),
            );
          }
      }
    }
    if (out.isEmpty) return out;
    return [
      for (var i = 0; i < out.length; i++) ...[
        if (i > 0) const SizedBox(width: 0),
        out[i],
      ],
    ];
  }

  /// Icon, tooltip and action for the controls that render the same wherever
  /// they're placed. Returns null when the control isn't available right now
  /// (no second quality to pick, a single-episode item, no PiP support).
  (IconData, String, VoidCallback)? _specFor(BuildContext context, String id) {
    final c = controller;
    switch (id) {
      case 'lock':
        return (Icons.lock_open_rounded, context.l10n.lockControls, onLock);
      case 'speed':
        return (Icons.speed_rounded, 'Playback speed', onSpeed);
      case 'tracks':
        return (Icons.subtitles_rounded, 'Audio & subtitles', onAudioSubs);
      case 'quality':
        // Nothing to switch inside the stream that's playing -> no button,
        // rather than a menu of other servers pretending to be qualities.
        final hasSourceQualities = state.sources.any((source) =>
            RegExp(
              r'(2160|1440|1080|720|576|540|480|360|240|144)\s*p?',
              caseSensitive: false,
            ).hasMatch('${source.quality ?? ''} ${source.label ?? ''}'));
        if (state.qualities.isEmpty &&
            c.mediaVideoTracks.length <= 1 &&
            !hasSourceQualities) {
          return null;
        }
        return (Icons.high_quality_rounded, 'Quality', onQuality);
      case 'sources':
        return (Icons.layers_rounded, 'Sources', onSources);
      case 'more':
        return (Icons.more_horiz_rounded, 'More', () => _showMore(context));
      case 'episodes':
        if (portraitMode || c.episodes.length <= 1 || onEpisodes == null) return null;
        return (Icons.video_library_outlined, 'Episode lainnya', onEpisodes!);
      case 'summary':
        return (Icons.subject_rounded, 'Episode summary', onEpisodeSummary);
      case 'comments':
        if (!episodeDetailMode || onEpisodeComments == null) return null;
        return (Icons.forum_outlined, 'Episode comments', onEpisodeComments!);
      case 'fit':
        return (_fitIcon(zoomLabel), 'Aspect ratio · $zoomLabel', onZoom);
      case 'rotate':
        if (episodeDetailMode) {
          return (
            portraitMode
                ? Icons.fullscreen_rounded
                : Icons.fullscreen_exit_rounded,
            portraitMode ? 'Fullscreen' : 'Episode details',
            onRotate,
          );
        }
        return (
          Icons.screen_rotation_rounded,
          portraitMode ? 'Landscape' : 'Portrait',
          onRotate,
        );
      case 'decoder':
        return (Icons.memory_rounded, 'Decoder · $decoderLabel', onDecoder);
      case 'enhance':
        return (
          enhanceActive
              ? Icons.auto_awesome_rounded
              : Icons.auto_awesome_outlined,
          'Anime4K enhancement',
          onEnhance,
        );
      case 'colour':
        return (Icons.palette_outlined, 'Colour', onColorProfile);
      case 'snapshot':
        return (Icons.photo_camera_rounded, 'Snapshot', onScreenshot);
      case 'sleep':
        return (
          sleepActive ? Icons.bedtime_rounded : Icons.bedtime_outlined,
          'Sleep timer',
          onSleep,
        );
      case 'pip':
        if (onPip == null) return null;
        return (
          Icons.picture_in_picture_alt_rounded,
          'Picture-in-picture',
          onPip!,
        );
    }
    return null; // unknown id — a layout from a newer build
  }

  /// Turns saved control ids into real buttons.
  ///
  /// The availability rules that were baked into the old fixed row still
  /// apply on top of the user's arrangement — Quality with nothing to pick
  /// between, Episodes on a single-episode item and PiP where the device
  /// doesn't support it drop out even if they've been placed on the bar.
  /// Anything unrecognised is skipped rather than crashing, which is what
  /// makes a layout saved by a newer build safe to load.
  List<Widget> _barButtons(BuildContext context, List<String> ids) {
    final specs = <(IconData, String, VoidCallback)>[];
    for (final id in ids) {
      final spec = _specFor(context, id);
      if (spec != null) specs.add(spec);
    }
    return [
      for (var i = 0; i < specs.length; i++)
        _BarButton(
          icon: specs[i].$1,
          tooltip: specs[i].$2,
          onTap: specs[i].$3,
          // The last right-side button is flush with the screen edge.
          rightPadding: i == specs.length - 1 ? 0 : 10,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final ep = c.currentEpisode;
    final epNum = ep.number?.toInt() ?? state.currentIndex + 1;
    // The episode's own name, but only when it's more than a generic
    // "Episode N" / bare number (many sources just echo the number there).
    final epName = ep.title.trim();
    final hasEpName =
        epName.isNotEmpty &&
        epName.toLowerCase() != 'episode $epNum' &&
        epName != '$epNum';
    // Line 1 = show name (falls back to "Episode N" when no show title).
    final primaryTitle = showTitle ?? 'Episode $epNum';
    // Line 2 = "E5 · Episode Name" — only when there's a show name above it to
    // pair with (otherwise line 1 already carries the episode number).
    final secondaryTitle = showTitle == null
        ? null
        : 'E$epNum${hasEpName ? ' · $epName' : ''}';
    // Quality appended to the E-line when enabled — prefers
    // the source's quality label, else the live video height (e.g. "1080p").
    String? qualityLabel;
    if (showQuality) {
      final q = state.active?.quality?.trim();
      if (q != null && q.isNotEmpty && q.toLowerCase() != 'auto') {
        qualityLabel = q;
      } else {
        final h = c.player.state.height ?? 0;
        if (h > 0) qualityLabel = '${h}p';
      }
    }
    final secondaryLine = qualityLabel == null
        ? secondaryTitle
        : (secondaryTitle == null
              ? qualityLabel
              : '$secondaryTitle · $qualityLabel');
    // Not just "is there another entry" — an episode nothing has yet is not a
    // next episode. Shared with the outro pill, the Up-next card and autoplay
    // so every Next affordance agrees.
    final hasNext = c.hasPlayableNext;
    // Movies and one-off items have nowhere to step, so they get a lone play
    // button rather than two arrows that can never do anything.
    final multiEpisode = c.episodes.length > 1;
    // The episode-detail player sits inside a portrait page rather than
    // occupying the whole display. Keep its controls compact and predictable;
    // the full set of tools remains available from More / player settings.
    final compactEpisodePortrait = episodeDetailMode && portraitMode;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Top scrim.
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: compactEpisodePortrait ? 76 : 110,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x59000000), Color(0x00000000)],
                ),
              ),
            ),
          ),
        ),
        // Bottom scrim. There were two of these stacked at each end — 0xCC over
        // 0x99 up top, 0xE6 over 0xB3 down here — which is why showing the
        // controls dropped a heavy curtain over the video. One gentle pass each
        // way is plenty to keep white text legible on a bright frame.
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: compactEpisodePortrait ? 96 : 132,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Color(0x70000000), Color(0x00000000)],
                ),
              ),
            ),
          ),
        ),

        // Top bar.
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            // Vertical insets only. Now that the window draws into the display
            // cutout, the horizontal safe inset is the camera's — and it exists
            // on one edge only, so honouring it shunts the whole bar sideways
            // and the margins stop matching. The cutout sits mid-edge; this bar
            // is pinned to the top, so they never meet.
            left: false,
            right: false,
            child: Padding(
              // 32, not the bottom block's 44, and the difference is on
              // purpose: these are IconButtons, which reserve 12px around the
              // glyph before it draws (8 default padding, plus 4 stretching the
              // 40px button out to the 48px minimum touch target). 32 + 12 puts
              // the back arrow on 44 — the exact line the bottom capsules start
              // at. Writing 44 here would land it at 56 and overshoot inward.
              padding: EdgeInsets.symmetric(
                horizontal: compactEpisodePortrait ? 10 : 9,
                vertical: compactEpisodePortrait ? 0 : 0,
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: Colors.white,
                    ),
                    tooltip: context.l10n.back,
                    onPressed: onBack,
                  ),
                  // Text hit-tests as opaque (RenderParagraph.hitTestSelf is
                  // true), so the title used to eat taps aimed at the video —
                  // a wide dead strip across the top where tapping did nothing.
                  // Nothing here is interactive, so let taps fall through to the
                  // zones below and toggle the controls like anywhere else.
                  Expanded(
                    child: IgnorePointer(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  primaryTitle,
                                  style: (compactEpisodePortrait
                                          ? AppText.body
                                          : AppText.headline)
                                      .copyWith(
                                        color: Colors.white,
                                        fontSize: compactEpisodePortrait ? null : 16,
                                        fontWeight: FontWeight.w600,
                                        height: 1.15,
                                      ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              // Filler comes from the Jikan lookup, not the
                              // source — Episode.filler is always false here.
                              // Listened to because that lookup lands long
                              // after this is first built.
                              ValueListenableBuilder<Set<int>>(
                                valueListenable: c.fillerEpisodes,
                                builder: (context, _, _) =>
                                    c.isFillerAt(state.currentIndex)
                                    ? const Padding(
                                        padding: EdgeInsetsDirectional.only(start: 8),
                                        // No colour passed: TagBadge falls back
                                        // to the app accent, so the badge
                                        // follows the user's theme colour.
                                        child: TagBadge(text: 'FILLER'),
                                      )
                                    : const SizedBox.shrink(),
                              ),
                            ],
                          ),
                          if (secondaryLine != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 1),
                              child: AutoTranslatedText(
                                text: secondaryLine,
                                style: AppText.caption.copyWith(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  height: 1.15,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                showToggle: false,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  // Whatever the user put up here, in their order. Cast and
                  // the ⓘ stats toggle live here by default; anything else in
                  // the registry can be moved up in Settings.
                  if (!compactEpisodePortrait)
                    ..._topButtons(context, barConfig.top),
                  // Sleep timer armed — a visible accent moon; tap to adjust or
                  // cancel. Only shown while a timer / end-of-episode is set,
                  // and only when Sleep isn't already placed somewhere, or an
                  // armed timer would show two of the same button.
                  if (!compactEpisodePortrait &&
                      sleepActive &&
                      !_placedAnywhere('sleep'))
                    Padding(
                      padding: const EdgeInsets.only(left: 1),
                      child: _BarButton(
                        icon: Icons.bedtime_rounded,
                        tooltip: context.l10n.sleepTimerOn,
                        onTap: onSleep,
                      ),
                    ),
                  // Episodes and ⋮ More live in the bottom bar now — a second
                  // copy up here just split the same action across two places.
                  if (!compactEpisodePortrait)
                    Padding(
                      padding: const EdgeInsets.only(left: 1),
                      child: _BarButton(
                        icon: Icons.more_vert_rounded,
                        tooltip: context.l10n.settingsTooltip,
                        onTap: onSettings,
                      ),
                    ),
                  if (!compactEpisodePortrait && onChat != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 1),
                      child: _BarButton(
                        icon: Icons.chat_bubble_outline_rounded,
                        tooltip: context.l10n.chat,
                        onTap: onChat!,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),

        // Centre transport — episode step either side of play/pause. The ±10s
        // buttons used to live here, but they jumped a hardcoded 10s while
        // double-tap honoured the user's Double-tap skip setting, so the two
        // disagreed; seeking is covered by double-tap, drag-to-seek and the
        // MegaSkip pill, all of which read the same preference.
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (multiEpisode && !compactEpisodePortrait) ...[
                _TransportButton(
                  icon: Icons.skip_previous_rounded,
                  label: context.l10n.previousEpisode,
                  onTap: onPrev,
                ),
                const SizedBox(width: 8),
              ],
              _BufferAwarePlayPause(
                controller: c,
                onInteract: onInteract,
              ),
              if (multiEpisode && !compactEpisodePortrait) ...[
                const SizedBox(width: 8),
                _TransportButton(
                  icon: Icons.skip_next_rounded,
                  label: context.l10n.nextEpisode2,
                  onTap: hasNext
                      ? () {
                          c.playNext();
                          onInteract();
                        }
                      : null,
                ),
              ],
            ],
          ),
        ),

        // Bottom: a compact timestamp / shortcut row above a thin seek line.
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: SafeArea(
              top: false,
              bottom: !compactEpisodePortrait,
              // Vertical inset only — the bottom one keeps the bar clear of the
              // gesture nav. See the top bar for why the horizontal cutout inset
              // is skipped: it lands on one edge only and pushed this whole block
              // sideways, leaving a fat gap on the camera side and a thin one
              // opposite. The camera sits mid-edge, well clear of this bar.
              left: false,
              right: false,
              child: Padding(
                // One margin for the whole block — timestamp, progress bar and
                // both button groups share it, so every edge lines up. Kept wide
                // so the controls sit clear of the screen edges.
                padding: EdgeInsets.fromLTRB(
                  compactEpisodePortrait ? 4 : 16,
                  0,
                  0,
                  24,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Duration tracker (off-screen listener via StreamBuilder).
                    StreamBuilder<Duration>(
                      stream: c.player.stream.duration,
                      builder: (context, snap) {
                        final d = snap.data ?? duration;
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (d > Duration.zero) onDurationChanged(d);
                        });
                        final left = _barButtons(context, barConfig.left);
                        final right = _barButtons(context, barConfig.right);
                        final rightActions = <Widget>[
                          if (megaSkipEnabled)
                            _BarButton(
                              icon: Icons.fast_forward_rounded,
                              tooltip: 'Skip $megaSkipSeconds seconds',
                              onTap: onMegaSkip,
                              rightPadding: right.isEmpty ? 0 : 10,
                            ),
                          ...right,
                        ];
                        return _SeekRow(
                          controller: c,
                          duration: d > Duration.zero ? d : duration,
                          onInteract: onInteract,
                          multiTouchActive: multiTouchActive,
                          leading: left.isEmpty
                              ? null
                              : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: left,
                                ),
                          trailing: rightActions.isEmpty
                              ? null
                              : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: rightActions,
                                ),
                        );
                      },
                    ),
                    SizedBox(height: compactEpisodePortrait ? 0 : 2),
                  ],
                ),
              ),
          ),
        ),
      ],
    );
  }
}

class _EpisodePickerButton extends StatelessWidget {
  const _EpisodePickerButton({required this.onTap, this.thumbnail});

  final VoidCallback onTap;
  final String? thumbnail;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: 'Episode lainnya',
    child: Material(
      color: Colors.black.withValues(alpha: 0.3),
      borderRadius: BorderRadius.circular(26),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(26),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(11, 6, 6, 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Episode lainnya',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 9),
              Container(
                width: 54,
                height: 31,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                ),
                clipBehavior: Clip.antiAlias,
                child: thumbnail != null && thumbnail!.trim().isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: thumbnail!,
                        fit: BoxFit.cover,
                        memCacheWidth: 180,
                        placeholder: (_, __) => const ColoredBox(
                          color: Color(0xFF333333),
                          child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 18),
                        ),
                        errorWidget: (_, __, ___) => const ColoredBox(
                          color: Color(0xFF333333),
                          child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 18),
                        ),
                      )
                    : const ColoredBox(
                        color: Color(0xFF333333),
                        child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 18),
                      ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Seek row — current time + slider (stream-bound) + total time.
// ─────────────────────────────────────────────────────────────────────────────


// A pause requested during buffering is held until playback has genuinely
// resumed and the position has advanced, avoiding a pause against a stalled
// decoder/buffer state.
class _BufferAwarePlayPause extends StatefulWidget {
  const _BufferAwarePlayPause({
    required this.controller,
    required this.onInteract,
  });

  final PlayerCubit controller;
  final VoidCallback onInteract;

  @override
  State<_BufferAwarePlayPause> createState() => _BufferAwarePlayPauseState();
}

class _BufferAwarePlayPauseState extends State<_BufferAwarePlayPause> {
  StreamSubscription<Duration>? _positionSub;
  bool _pendingPause = false;
  Duration _positionAtRequest = Duration.zero;

  @override
  void initState() {
    super.initState();
    _positionSub = widget.controller.player.stream.position.listen(_onPosition);
  }

  void _onPosition(Duration position) {
    if (!_pendingPause) return;
    final player = widget.controller.player;
    if (!player.state.buffering &&
        player.state.playing &&
        position - _positionAtRequest >= const Duration(milliseconds: 300)) {
      _pendingPause = false;
      widget.controller.togglePlay();
      widget.onInteract();
    }
  }

  void _onTap() {
    final player = widget.controller.player;
    if (player.state.buffering && player.state.playing) {
      _pendingPause = true;
      _positionAtRequest = player.state.position;
    } else {
      _pendingPause = false;
      widget.controller.togglePlay();
    }
    widget.onInteract();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: widget.controller.player.stream.playing,
      builder: (context, pSnap) {
        final playing = pSnap.data ?? widget.controller.player.state.playing;
        return StreamBuilder<bool>(
          stream: widget.controller.player.stream.buffering,
          builder: (context, bSnap) {
            final buffering =
                bSnap.data ?? widget.controller.player.state.buffering;
            if (buffering && playing) {
              return SizedBox(
                width: 51,
                height: 51,
                child: Material(
                  color: Colors.transparent,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _onTap,
                    child: Center(
                      child: SizedBox(
                        width: 29,
                        height: 29,
                        child: CircularProgressIndicator(
                          color: AppColors.accent,
                          strokeWidth: 3,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }
            return _AnimatedPlayPause(
              playing: playing,
              onTap: _onTap,
            );
          },
        );
      },
    );
  }
}
