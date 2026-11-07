import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// Holds the live playback surface while the user browses the app.
class MiniPlayerSession {
  MiniPlayerSession({
    required this.controller,
    required this.title,
    required this.subtitle,
    required this.onRestore,
    required this.onClose,
  });

  final VideoController controller;
  final String title;
  final String subtitle;
  final VoidCallback onRestore;
  final VoidCallback onClose;
}

class MiniPlayerState {
  MiniPlayerState._();

  static final ValueNotifier<MiniPlayerSession?> active =
      ValueNotifier<MiniPlayerSession?>(null);

  static void show(MiniPlayerSession session) => active.value = session;
  static void clear() => active.value = null;
}

/// YouTube-like floating playback controls, mounted above the root Navigator.
class MiniPlayerOverlay extends StatefulWidget {
  const MiniPlayerOverlay({super.key});

  @override
  State<MiniPlayerOverlay> createState() => _MiniPlayerOverlayState();
}

class _MiniPlayerOverlayState extends State<MiniPlayerOverlay> {
  Offset _dragOffset = Offset.zero;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<MiniPlayerSession?>(
      valueListenable: MiniPlayerState.active,
      builder: (context, session, _) {
        if (session == null) {
          if (_expanded) _expanded = false;
          return const SizedBox.expand();
        }
        return LayoutBuilder(
          builder: (context, constraints) {
            final width = _expanded
                ? (constraints.maxWidth - 20).clamp(180.0, constraints.maxWidth - 20).toDouble()
                : (constraints.maxWidth * 0.48).clamp(150.0, 190.0).toDouble();
            final height = width * 9 / 16;
            final safeBottom = MediaQuery.paddingOf(context).bottom;
            final safeTop = MediaQuery.paddingOf(context).top;
            final left = (constraints.maxWidth - width - 12 + _dragOffset.dx)
                .clamp(8.0, constraints.maxWidth - width - 8)
                .toDouble();
            final top = (constraints.maxHeight - height - safeBottom - 76 -
                    _dragOffset.dy)
                .clamp(
                  safeTop + 8,
                  (constraints.maxHeight - height - safeBottom - 8)
                      .clamp(safeTop + 8, double.infinity),
                )
                .toDouble();

            return Stack(
              fit: StackFit.expand,
              children: [
                Positioned(
                  left: left,
                  top: top,
                  width: width,
                  height: height,
                  child: Material(
                    color: Colors.black,
                    elevation: 16,
                    shadowColor: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                    clipBehavior: Clip.antiAlias,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onPanUpdate: (details) => setState(() {
                        _dragOffset += Offset(
                          details.delta.dx,
                          -details.delta.dy,
                        );
                      }),
                      onTap: session.onRestore,
                      onDoubleTap: () => setState(() {
                        _expanded = !_expanded;
                        _dragOffset = Offset.zero;
                      }),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Video(
                            controller: session.controller,
                            controls: NoVideoControls,
                            fit: BoxFit.contain,
                          ),
                          Positioned(
                            top: 2,
                            right: 2,
                            child: _MiniControlButton(
                              icon: Icons.close_rounded,
                              tooltip: 'Tutup pemutar',
                              onPressed: session.onClose,
                            ),
                          ),
                          Positioned(
                            left: 2,
                            bottom: 9,
                            child: StreamBuilder<bool>(
                              stream: session.controller.player.stream.playing,
                              initialData:
                                  session.controller.player.state.playing,
                              builder: (context, snapshot) {
                                final playing = snapshot.data ?? false;
                                return _MiniControlButton(
                                  icon: playing
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                  tooltip: playing ? 'Jeda' : 'Putar',
                                  onPressed: () {
                                    final player = session.controller.player;
                                    if (player.state.playing) {
                                      player.pause();
                                    } else {
                                      player.play();
                                    }
                                  },
                                );
                              },
                            ),
                          ),
                          Positioned(
                            left: 42,
                            right: 9,
                            bottom: 13,
                            child: StreamBuilder<Duration>(
                              stream: session.controller.player.stream.position,
                              initialData:
                                  session.controller.player.state.position,
                              builder: (context, positionSnapshot) {
                                return StreamBuilder<Duration>(
                                  stream:
                                      session.controller.player.stream.duration,
                                  initialData:
                                      session.controller.player.state.duration,
                                  builder: (context, durationSnapshot) {
                                    final duration =
                                        durationSnapshot.data ?? Duration.zero;
                                    final position =
                                        positionSnapshot.data ?? Duration.zero;
                                    final maxMs = duration.inMilliseconds;
                                    final value = maxMs <= 0
                                        ? 0.0
                                        : position.inMilliseconds
                                            .clamp(0, maxMs)
                                            .toDouble();
                                    return SliderTheme(
                                      data: SliderTheme.of(context).copyWith(
                                        trackHeight: 2,
                                        thumbShape:
                                            const RoundSliderThumbShape(
                                              enabledThumbRadius: 3,
                                            ),
                                        overlayShape:
                                            const RoundSliderOverlayShape(
                                              overlayRadius: 7,
                                            ),
                                        activeTrackColor: Colors.white,
                                        inactiveTrackColor: Colors.white38,
                                        thumbColor: Colors.white,
                                        overlayColor:
                                            Colors.white.withValues(alpha: 0.15),
                                      ),
                                      child: Slider(
                                        min: 0,
                                        max: maxMs > 0 ? maxMs.toDouble() : 1,
                                        value: value
                                            .clamp(
                                              0,
                                              maxMs > 0 ? maxMs.toDouble() : 1,
                                            )
                                            .toDouble(),
                                        onChanged: maxMs <= 0
                                            ? null
                                            : (next) => session.controller.player
                                                .seek(Duration(
                                                  milliseconds: next.round(),
                                                )),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _MiniControlButton extends StatelessWidget {
  const _MiniControlButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.58),
      shape: const CircleBorder(),
      child: IconButton(
        visualDensity: VisualDensity.compact,
        constraints: const BoxConstraints.tightFor(width: 30, height: 30),
        padding: EdgeInsets.zero,
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white, size: 19),
      ),
    );
  }
}
