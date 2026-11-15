import 'package:flutter/material.dart';

import '../../core/di/injector.dart';
import '../../core/metadata/episode_metadata_service.dart';
import '../../core/models/episode.dart';

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
    final safeIndex = _selectedIndex.clamp(0, widget.episodes.length - 1);
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
      barrierColor: Colors.black.withValues(alpha: 0.94),
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(8),
        child: Stack(
          children: [
            PageView.builder(
              controller: PageController(initialPage: initialIndex),
              itemCount: urls.length,
              itemBuilder: (_, index) => Center(
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: Image.network(
                    urls[index],
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.broken_image_outlined,
                      color: Colors.white54,
                      size: 42,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: IconButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                icon: const Icon(Icons.close_rounded, color: Colors.white),
              ),
            ),
          ],
        ),
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
