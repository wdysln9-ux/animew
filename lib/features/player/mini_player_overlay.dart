import 'dart:math' as math;

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

/// Floating video surface mounted above the root Navigator.
class MiniPlayerOverlay extends StatefulWidget {
  const MiniPlayerOverlay({super.key});

  @override
  State<MiniPlayerOverlay> createState() => _MiniPlayerOverlayState();
}

class _MiniPlayerOverlayState extends State<MiniPlayerOverlay> {
  double? _left;
  double? _top;
  bool _expanded = false;

  static const _snapDuration = Duration(milliseconds: 280);
  static const _snapCurve = Curves.easeOutCubic;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<MiniPlayerSession?>(
      valueListenable: MiniPlayerState.active,
      builder: (context, session, _) {
        if (session == null) {
          if (_expanded || _left != null || _top != null) {
            _expanded = false;
            _left = null;
            _top = null;
          }
          return const SizedBox.expand();
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final screenWidth = constraints.maxWidth;
            final screenHeight = constraints.maxHeight;
            final safe = MediaQuery.paddingOf(context);
            final width = _expanded
                ? math.max(180.0, screenWidth - 20)
                : (screenWidth * 0.48).clamp(150.0, 190.0).toDouble();
            final height = width * 9 / 16;
            final minLeft = 8.0;
            final maxLeft = math.max(minLeft, screenWidth - width - 8);
            final minTop = safe.top + 8;
            final maxTop = math.max(
              minTop,
              screenHeight - height - safe.bottom - 8,
            );

            final left = _left == null
                ? maxLeft
                : _left!.clamp(minLeft, maxLeft).toDouble();
            final top = _top == null
                ? (screenHeight - height - safe.bottom - 76)
                    .clamp(minTop, maxTop)
                    .toDouble()
                : _top!.clamp(minTop, maxTop).toDouble();

            return Stack(
              fit: StackFit.expand,
              children: [
                AnimatedPositioned(
                  duration: _snapDuration,
                  curve: _snapCurve,
                  left: _expanded ? (screenWidth - width) / 2 : left,
                  top: top,
                  width: width,
                  height: height,
                  child: AnimatedContainer(
                    duration: _snapDuration,
                    curve: _snapCurve,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(_expanded ? 14 : 11),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x66000000),
                          blurRadius: 18,
                          spreadRadius: 1,
                          offset: Offset(0, 5),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onPanUpdate: (details) {
                        if (_expanded) return;
                        setState(() {
                          _left = (left + details.delta.dx)
                              .clamp(minLeft, maxLeft)
                              .toDouble();
                          _top = (top + details.delta.dy)
                              .clamp(minTop, maxTop)
                              .toDouble();
                        });
                      },
                      onPanEnd: (_) {
                        if (_expanded) return;
                        final currentLeft = _left ?? left;
                        final currentTop = _top ?? top;
                        final snapLeft = currentLeft + width / 2 < screenWidth / 2
                            ? minLeft
                            : maxLeft;
                        final snapTop = currentTop + height / 2 < screenHeight / 2
                            ? minTop
                            : maxTop;
                        setState(() {
                          _left = snapLeft;
                          _top = snapTop;
                        });
                      },
                      onTap: session.onRestore,
                      onDoubleTap: () {
                        setState(() {
                          _expanded = !_expanded;
                          if (!_expanded) {
                            _left = left;
                            _top = top;
                          } else {
                            _left = (screenWidth - width) / 2;
                          }
                        });
                      },
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          const ColoredBox(color: Colors.black),
                          Positioned.fill(
                            child: Video(
                              controller: session.controller,
                              controls: NoVideoControls,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 3,
                            left: 3,
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
                            top: 3,
                            right: 3,
                            child: _MiniControlButton(
                              icon: Icons.close_rounded,
                              tooltip: 'Tutup pemutar',
                              onPressed: session.onClose,
                            ),
                          ),
                          Positioned(
                            left: 8,
                            right: 8,
                            bottom: 5,
                            child: _MiniProgressBar(session: session),
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

class _MiniProgressBar extends StatelessWidget {
  const _MiniProgressBar({required this.session});

  final MiniPlayerSession session;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration>(
      stream: session.controller.player.stream.position,
      initialData: session.controller.player.state.position,
      builder: (context, positionSnapshot) {
        return StreamBuilder<Duration>(
          stream: session.controller.player.stream.duration,
          initialData: session.controller.player.state.duration,
          builder: (context, durationSnapshot) {
            final duration =
                durationSnapshot.data ?? Duration.zero;
            final position =
                positionSnapshot.data ?? Duration.zero;
            final total = duration.inMilliseconds;
            final progress = total <= 0
                ? 0.0
                : (position.inMilliseconds / total).clamp(0.0, 1.0);
            void seek(Offset local, double width) {
              if (total <= 0 || width <= 0) return;
              final fraction = (local.dx / width).clamp(0.0, 1.0);
              session.controller.player.seek(Duration(
                milliseconds: (fraction * total).round(),
              ));
            }

            return LayoutBuilder(
              builder: (context, constraints) => GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (details) =>
                    seek(details.localPosition, constraints.maxWidth),
                onHorizontalDragUpdate: (details) =>
                    seek(details.localPosition, constraints.maxWidth),
                child: SizedBox(
                  height: 18,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: SizedBox(
                      height: 3,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            const ColoredBox(color: Color(0x99FFFFFF)),
                            FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: progress,
                              child: const ColoredBox(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
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
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: SizedBox(
          width: 34,
          height: 34,
          child: Center(
            child: Icon(icon, color: Colors.white, size: 22),
          ),
        ),
      ),
    );
  }
}
