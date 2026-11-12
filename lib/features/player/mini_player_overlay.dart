import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../core/theme/app_colors.dart';
import '../../core/ui/dock_visibility.dart';

/// Holds the live playback surface while the user browses the app.
class MiniPlayerSession {
  MiniPlayerSession({
    required this.controller,
    required this.title,
    required this.subtitle,
    required this.onRestore,
    required this.onClose,
    this.pageBuilder,
  });

  final VideoController controller;
  final String title;
  final String subtitle;
  final VoidCallback onRestore;
  final VoidCallback onClose;
  final WidgetBuilder? pageBuilder;
}

class MiniPlayerState {
  MiniPlayerState._();

  static final ValueNotifier<MiniPlayerSession?> active =
      ValueNotifier<MiniPlayerSession?>(null);

  static void show(MiniPlayerSession session) => active.value = session;
  static void clear() => active.value = null;
}


/// A player page route whose modal barrier becomes non-blocking while the
/// player is minimized. The player route stays mounted to preserve playback,
/// but taps and scroll gestures can reach the page underneath it.
class MiniPlayerAwarePageRoute<T> extends PageRouteBuilder<T> {
  MiniPlayerAwarePageRoute({
    required RoutePageBuilder<T> pageBuilder,
    required RouteTransitionsBuilder transitionsBuilder,
    required Duration transitionDuration,
    required Duration reverseTransitionDuration,
  }) : super(
          opaque: false,
          pageBuilder: pageBuilder,
          transitionsBuilder: transitionsBuilder,
          transitionDuration: transitionDuration,
          reverseTransitionDuration: reverseTransitionDuration,
        );

  @override
  Widget buildModalBarrier() {
    final normalBarrier = super.buildModalBarrier();
    return ValueListenableBuilder<MiniPlayerSession?>(
      valueListenable: MiniPlayerState.active,
      builder: (context, session, _) => session != null
          ? const IgnorePointer(child: SizedBox.expand())
          : normalBarrier,
    );
  }
}

/// Floating video surface mounted above the root Navigator.
class MiniPlayerOverlay extends StatefulWidget {
  const MiniPlayerOverlay({super.key});

  @override
  State<MiniPlayerOverlay> createState() => _MiniPlayerOverlayState();
}

class _MiniPlayerOverlayState extends State<MiniPlayerOverlay> {
  final ValueNotifier<Offset> _position = ValueNotifier(Offset.zero);
  bool _positionReady = false;
  bool _expanded = false;
  bool _dragging = false;

  static const _snapDuration = Duration(milliseconds: 220);
  static const _snapCurve = Curves.easeOutCubic;

  @override
  void dispose() {
    _position.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<MiniPlayerSession?>(
      valueListenable: MiniPlayerState.active,
      builder: (context, session, _) {
        if (session == null) {
          _expanded = false;
          _positionReady = false;
          // Keep the overlay out of the hit-test tree when inactive.
          return const SizedBox.shrink();
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
            final bottomClearance = math.max(safe.bottom, kDockClearance);
            final maxTop = math.max(
              minTop,
              screenHeight - height - bottomClearance - 8,
            );

            final initialTop = (screenHeight - height - safe.bottom - 76)
                .clamp(minTop, maxTop)
                .toDouble();
            if (!_positionReady) {
              _position.value = Offset(maxLeft, initialTop);
              _positionReady = true;
            }
            final compactWidth = (screenWidth * 0.48)
                .clamp(150.0, 190.0)
                .toDouble();
            final compactMaxLeft = math.max(8.0, screenWidth - compactWidth - 8);

            // Only the mini-player card is a hit-test target. The full-screen
            // overlay itself must remain transparent to gestures so the page
            // underneath can continue scrolling and swiping.
            return Stack(
              clipBehavior: Clip.none,
              children: [
                ValueListenableBuilder<Offset>(
                  valueListenable: _position,
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
                      onPanStart: (_) => setState(() => _dragging = true),
                      onPanUpdate: (details) {
                        final current = _position.value;
                        _position.value = Offset(
                          _expanded
                              ? current.dx
                              : (current.dx + details.delta.dx).clamp(
                                  minLeft - width * 0.28,
                                  maxLeft + width * 0.28,
                                ).toDouble(),
                          (current.dy + details.delta.dy).clamp(
                            minTop - height * 0.18,
                            maxTop + height * 0.18,
                          ).toDouble(),
                        );
                      },
                      onPanEnd: (_) {
                        final current = _position.value;
                        final safeTop = current.dy.clamp(minTop, maxTop).toDouble();
                        if (_expanded) {
                          _position.value = Offset(current.dx, safeTop);
                          setState(() => _dragging = false);
                          return;
                        }
                        final snapLeft = current.dx + width / 2 < screenWidth / 2
                            ? minLeft
                            : maxLeft;
                        _position.value = Offset(snapLeft, safeTop);
                        setState(() => _dragging = false);
                      },
                      onTap: session.onRestore,
                      onDoubleTap: () {
                        final current = _position.value;
                        setState(() {
                          if (!_expanded) {
                            _expanded = true;
                            _position.value = Offset(
                              (screenWidth - width) / 2,
                              current.dy.clamp(minTop, maxTop).toDouble(),
                            );
                          } else {
                            _expanded = false;
                            _position.value = Offset(
                              current.dx.clamp(8.0, compactMaxLeft).toDouble(),
                              current.dy.clamp(minTop, maxTop).toDouble(),
                            );
                          }
                        });
                      },
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          const ColoredBox(color: Colors.black),
                          Positioned.fill(
                            child: IgnorePointer(
                              ignoring: true,
                              child: Video(
                                controller: session.controller,
                                controls: NoVideoControls,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          Positioned(
                            top: 3,
                            left: 3,
                            child: StreamBuilder<bool>(
                              stream: session.controller.player.stream.playing,
                              initialData: session.controller.player.state.playing,
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
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: _MiniProgressBar(session: session),
                          ),
                        ],
                      ),
                    ),
                  ),
                  builder: (context, position, child) {
                    final safeLeft = position.dx.clamp(
                      _dragging ? minLeft - width * 0.28 : minLeft,
                      _dragging ? maxLeft + width * 0.28 : maxLeft,
                    ).toDouble();
                    final safeTop = position.dy.clamp(
                      _dragging ? minTop - height * 0.18 : minTop,
                      _dragging ? maxTop + height * 0.18 : maxTop,
                    ).toDouble();
                    return AnimatedPositioned(
                      duration: _dragging ? Duration.zero : _snapDuration,
                      curve: _snapCurve,
                      left: _expanded ? (screenWidth - width) / 2 : safeLeft,
                      top: safeTop,
                      width: width,
                      height: height,
                      child: child!,
                    );
                  },
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

            return StreamBuilder<bool>(
              stream: session.controller.player.stream.buffering,
              initialData: session.controller.player.state.buffering,
              builder: (context, bufferingSnapshot) {
                final buffering = bufferingSnapshot.data ?? false;
                return LayoutBuilder(
                  builder: (context, constraints) => GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (details) =>
                        seek(details.localPosition, constraints.maxWidth),
                    onHorizontalDragUpdate: (details) =>
                        seek(details.localPosition, constraints.maxWidth),
                    child: SizedBox(
                      height: 3,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // No pale full-width remainder track. During
                            // buffering, show a moving accent loading bar.
                            if (buffering)
                              LinearProgressIndicator(
                                minHeight: 3,
                                backgroundColor: Colors.transparent,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppColors.accent.withValues(alpha: 0.65),
                                ),
                              ),
                            FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: progress,
                              child: ColoredBox(color: AppColors.accent),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
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
