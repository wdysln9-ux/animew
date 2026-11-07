import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// Holds the live in-app playback surface while the app shell is on screen.
/// The PlayerScreen route stays underneath this shell route, so its cubit,
/// resolver, subscriptions and native player are never disposed on minimize.
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
  final ValueChanged<bool> onRestore;
  final VoidCallback onClose;
}

class MiniPlayerState {
  MiniPlayerState._();

  static final ValueNotifier<MiniPlayerSession?> active =
      ValueNotifier<MiniPlayerSession?>(null);

  static void show(MiniPlayerSession session) => active.value = session;
  static void clear() => active.value = null;
}

/// Draggable YouTube-style floating player drawn above the app's tab shell.
class MiniPlayerOverlay extends StatefulWidget {
  const MiniPlayerOverlay({super.key});

  @override
  State<MiniPlayerOverlay> createState() => _MiniPlayerOverlayState();
}

class _MiniPlayerOverlayState extends State<MiniPlayerOverlay> {
  Offset _dragOffset = Offset.zero;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<MiniPlayerSession?>(
      valueListenable: MiniPlayerState.active,
      builder: (context, session, _) {
        if (session == null) return const SizedBox.shrink();
        return LayoutBuilder(
          builder: (context, constraints) {
            final width = (constraints.maxWidth * 0.62)
                .clamp(190.0, 270.0)
                .toDouble();
            final cardHeight = width * 9 / 16 + 48;
            final left = (constraints.maxWidth - width - 14 + _dragOffset.dx)
                .clamp(8.0, constraints.maxWidth - width - 8)
                .toDouble();
            final top = (constraints.maxHeight - cardHeight - 20 -
                    _dragOffset.dy)
                .clamp(
                  MediaQuery.paddingOf(context).top + 8,
                  constraints.maxHeight - cardHeight -
                      MediaQuery.paddingOf(context).bottom - 8,
                )
                .toDouble();
            return Positioned(
              left: left,
              top: top,
              width: width,
              child: Material(
                color: const Color(0xFF171719),
                elevation: 14,
                shadowColor: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(13),
                clipBehavior: Clip.antiAlias,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanUpdate: (details) => setState(() {
                    _dragOffset += Offset(
                      details.delta.dx,
                      -details.delta.dy,
                    );
                  }),
                  onTap: () => session.onRestore(false),
                  onDoubleTap: () => session.onRestore(true),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Video(
                          controller: session.controller,
                          controls: NoVideoControls,
                          fit: BoxFit.contain,
                        ),
                      ),
                      SizedBox(
                        height: 48,
                        child: Row(
                          children: [
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    session.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    session.subtitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white60,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              tooltip: 'Tutup pemutar',
                              onPressed: session.onClose,
                              icon: const Icon(
                                Icons.close_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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
