import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/di/injector.dart';
import '../../core/metadata/episode_metadata_service.dart';
import '../../core/models/episode.dart';

const _episodeGalleryChannel = MethodChannel('animew/image_gallery');

/// Expandable episode-still gallery used on the anime detail page.
class EpisodeGallerySection extends StatefulWidget {
  const EpisodeGallerySection({
    super.key,
    required this.episodes,
    this.malId,
    this.tmdbId,
    this.tmdbIsTv = false,
  });

  final List<Episode> episodes;
  final int? malId;
  final int? tmdbId;
  final bool tmdbIsTv;

  @override
  State<EpisodeGallerySection> createState() => _EpisodeGallerySectionState();
}

class _EpisodeGallerySectionState extends State<EpisodeGallerySection> {
  bool _expanded = false;
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.episodes.isEmpty ||
        ((widget.malId == null || widget.malId! <= 0) &&
            (widget.tmdbId == null || !widget.tmdbIsTv))) {
      return const SizedBox.shrink();
    }
    final safeIndex = _selectedIndex.clamp(0, widget.episodes.length - 1) as int;
    final episode = widget.episodes[safeIndex];
    final episodeNumber = episode.number?.round();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF100D0B),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF302923)),
        ),
        child: Column(
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                child: Row(
                  children: [
                    const Icon(Icons.photo_library_outlined,
                        color: Color(0xFFF47521), size: 20),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Gallery',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Icon(
                      _expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      color: Colors.white70,
                    ),
                  ],
                ),
              ),
            ),
            if (_expanded) ...[
              const Divider(height: 1, color: Color(0xFF302923)),
              const DefaultTabController(
                length: 1,
                child: _EpisodeGalleryTabLabel(),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<int>(
                      value: safeIndex,
                      isExpanded: true,
                      dropdownColor: const Color(0xFF201A16),
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Pilih episode',
                        labelStyle: const TextStyle(color: Colors.white60),
                        filled: true,
                        fillColor: const Color(0xFF191410),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFF302923)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFF302923)),
                        ),
                      ),
                      items: [
                        for (var i = 0; i < widget.episodes.length; i++)
                          DropdownMenuItem(
                            value: i,
                            child: Text(
                              'Episode ${_episodeLabel(widget.episodes[i], i)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (value) {
                        if (value != null) setState(() => _selectedIndex = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    if (episodeNumber == null)
                      const _GalleryMessage('Nomor episode belum tersedia.')
                    else
                      _EpisodeStillGrid(
                        key: ValueKey(
                          '${widget.malId}:${widget.tmdbId}:${episode.season}:$episodeNumber',
                        ),
                        malId: widget.malId,
                        tmdbId: widget.tmdbId,
                        season: episode.season,
                        episodeNumber: episodeNumber,
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EpisodeGalleryTabLabel extends StatelessWidget {
  const _EpisodeGalleryTabLabel();

  @override
  Widget build(BuildContext context) {
    return const TabBar(
      isScrollable: true,
      tabAlignment: TabAlignment.start,
      labelColor: Color(0xFFF47521),
      unselectedLabelColor: Colors.white60,
      indicatorColor: Color(0xFFF47521),
      dividerColor: Colors.transparent,
      tabs: [Tab(text: 'Episode')],
    );
  }
}

/// Compact gallery used inside the currently selected episode detail page.
class EpisodeScreenshotGallery extends StatelessWidget {
  const EpisodeScreenshotGallery({
    super.key,
    this.malId,
    this.tmdbId,
    this.season,
    required this.episodeNumber,
  });

  final int? malId;
  final int? tmdbId;
  final int? season;
  final int episodeNumber;

  @override
  Widget build(BuildContext context) {
    if (episodeNumber <= 0 ||
        ((malId == null || malId! <= 0) && (tmdbId == null || season == null))) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Gallery Episode',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          _EpisodeStillGrid(
            key: ValueKey('${malId}:$tmdbId:$season:$episodeNumber'),
            malId: malId,
            tmdbId: tmdbId,
            season: season,
            episodeNumber: episodeNumber,
          ),
        ],
      ),
    );
  }
}

class _EpisodeStillGrid extends StatelessWidget {
  const _EpisodeStillGrid({
    super.key,
    this.malId,
    this.tmdbId,
    this.season,
    required this.episodeNumber,
  });

  final int? malId;
  final int? tmdbId;
  final int? season;
  final int episodeNumber;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<String>>(
      future: sl<EpisodeMetadataService>().episodeScreenshots(
        malId: malId,
        tmdbId: tmdbId,
        season: season,
        episodeNumber: episodeNumber,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 22),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFFF47521),
                ),
              ),
            ),
          );
        }
        final urls = snapshot.data ?? const <String>[];
        if (urls.isEmpty) {
          return const _GalleryMessage(
            'Screenshot untuk episode ini belum tersedia.',
          );
        }
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: urls.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 16 / 9,
          ),
          itemBuilder: (context, index) {
            final url = urls[index];
            return Material(
              color: const Color(0xFF201A16),
              borderRadius: BorderRadius.circular(9),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => _openStill(context, urls, index),
                child: Image.network(
                  url,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFFF47521),
                        ),
                      ),
                    );
                  },
                  errorBuilder: (_, __, ___) => const Center(
                    child: Icon(Icons.broken_image_outlined,
                        color: Colors.white38),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _openStill(BuildContext context, List<String> urls, int initialIndex) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black,
      barrierDismissible: false,
      builder: (dialogContext) => _EpisodeScreenshotViewer(
        urls: urls,
        initialIndex: initialIndex,
      ),
    );
  }
}


class _EpisodeScreenshotViewer extends StatefulWidget {
  const _EpisodeScreenshotViewer({
    required this.urls,
    required this.initialIndex,
  });

  final List<String> urls;
  final int initialIndex;

  @override
  State<_EpisodeScreenshotViewer> createState() =>
      _EpisodeScreenshotViewerState();
}

class _EpisodeScreenshotViewerState extends State<_EpisodeScreenshotViewer> {
  late final PageController _pages =
      PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;
  bool _saving = false;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _downloadCurrent() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final url = widget.urls[_index];
      final response = await Dio().get<List<int>>(
        url,
        options: Options(
          responseType: ResponseType.bytes,
          connectTimeout: const Duration(seconds: 20),
          receiveTimeout: const Duration(seconds: 60),
        ),
      );
      final bytes = response.data;
      if (bytes == null || bytes.isEmpty) {
        throw StateError('Gambar kosong');
      }
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final uri = await _episodeGalleryChannel.invokeMethod<String>(
        'saveImage',
        {
          'bytes': Uint8List.fromList(bytes),
          'fileName': 'AnimeW_Episode_Screenshot_$stamp',
          'mimeType': response.headers.value('content-type') ?? 'image/jpeg',
        },
      );
      if (!mounted) return;
      if (uri == null || uri.isEmpty) {
        throw StateError('Gagal menyimpan gambar');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Screenshot berhasil disimpan ke Galeri')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengunduh screenshot: $error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              controller: _pages,
              itemCount: widget.urls.length,
              onPageChanged: (index) => setState(() => _index = index),
              itemBuilder: (context, index) => Center(
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: Image.network(
                    widget.urls[index],
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      );
                    },
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.broken_image_outlined,
                      color: Colors.white70,
                      size: 42,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              left: 8,
              child: _ViewerCircleButton(
                icon: Icons.close_rounded,
                tooltip: 'Tutup',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            Positioned(
              top: 18,
              left: 68,
              right: 68,
              child: Center(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.52),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 7,
                    ),
                    child: Text(
                      '${_index + 1} / ${widget.urls.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: _ViewerCircleButton(
                icon: _saving ? null : Icons.download_rounded,
                tooltip: 'Unduh screenshot',
                onPressed: _saving ? null : _downloadCurrent,
                child: _saving
                    ? const SizedBox(
                        width: 21,
                        height: 21,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ViewerCircleButton extends StatelessWidget {
  const _ViewerCircleButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.child,
  });

  final IconData? icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.48),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: child ?? Icon(icon, color: Colors.white),
      ),
    );
  }
}

String _episodeLabel(Episode episode, int index) {
  final n = episode.number;
  if (n != null) return n.toString().replaceFirst(RegExp(r'\.0$'), '');
  return '${index + 1}';
}

class _GalleryMessage extends StatelessWidget {
  const _GalleryMessage(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
      ),
    );
  }
}
