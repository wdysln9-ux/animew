import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/di/injector.dart';
import '../../core/metadata/episode_metadata_service.dart';
import '../../core/models/episode.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';

const _episodeGalleryChannel = MethodChannel('animew/image_gallery');

typedef _EpisodeStill = ({int episode, String url});

final Map<String, Future<List<_EpisodeStill>>> _allEpisodeStillCache = {};

Future<List<_EpisodeStill>> _loadAllEpisodeStills({
  required List<Episode> episodes,
  required int? malId,
  required int? tmdbId,
}) {
  final key = '${malId ?? 0}:${tmdbId ?? 0}:${episodes.length}:${episodes.map((e) => e.number?.round() ?? 0).join(',')}';
  return _allEpisodeStillCache.putIfAbsent(key, () async {
    final groups = await Future.wait([
      for (final episode in episodes)
        () async {
          final number = episode.number?.round();
          if (number == null || number <= 0) return <_EpisodeStill>[];
          final urls = await sl<EpisodeMetadataService>().episodeScreenshots(
            malId: malId,
            tmdbId: tmdbId,
            season: episode.season,
            episodeNumber: number,
          );
          return [
            for (final url in urls) (episode: number, url: url),
          ];
        }(),
    ]);
    return groups.expand((items) => items).toList(growable: false);
  });
}

/// Anime detail page: trailer-style expandable header with horizontal episode
/// chips and a sideways still-image rail.
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
  int _selectedEpisode = 1; // -1 = Semua; default = Episode 1.

  @override
  void initState() {
    super.initState();
    if (!widget.episodes.any((e) => e.number?.round() == 1)) {
      _selectedEpisode = widget.episodes.isEmpty
          ? 1
          : (widget.episodes.first.number?.round() ?? 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.episodes.isEmpty ||
        ((widget.malId == null || widget.malId! <= 0) &&
            (widget.tmdbId == null || !widget.tmdbIsTv))) {
      return const SizedBox.shrink();
    }
    final episodeNumbers = widget.episodes
        .map((e) => e.number?.round())
        .whereType<int>()
        .where((n) => n > 0)
        .toSet()
        .toList()
      ..sort();
    final selectedEpisode = episodeNumbers.contains(_selectedEpisode)
        ? _selectedEpisode
        : (episodeNumbers.isEmpty ? 1 : episodeNumbers.first);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeInOutCubic,
        alignment: Alignment.topCenter,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _expanded = !_expanded),
              child: Row(
                children: [
                  Text('Gallery', style: AppText.headline.copyWith(fontSize: 16)),
                  const SizedBox(width: 7),
                  Text(
                    '${episodeNumbers.length}',
                    style: AppText.caption.copyWith(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_down_rounded
                        : Icons.chevron_right_rounded,
                    color: AppColors.textSecondary,
                    size: 21,
                  ),
                ],
              ),
            ),
            if (_expanded) ...[
              const SizedBox(height: 10),
              SizedBox(
                height: 34,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _EpisodeGalleryChip(
                      label: 'Semua',
                      selected: _selectedEpisode == -1,
                      onTap: () => setState(() => _selectedEpisode = -1),
                    ),
                    for (final number in episodeNumbers)
                      _EpisodeGalleryChip(
                        label: 'Episode $number',
                        selected: selectedEpisode == number && _selectedEpisode != -1,
                        onTap: () => setState(() => _selectedEpisode = number),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              if (_selectedEpisode == -1)
                _AllEpisodeStillRail(
                  episodes: widget.episodes,
                  malId: widget.malId,
                  tmdbId: widget.tmdbId,
                )
              else
                _EpisodeStillRail(
                  key: ValueKey('anime-gallery:$selectedEpisode'),
                  malId: widget.malId,
                  tmdbId: widget.tmdbId,
                  episode: widget.episodes.firstWhere(
                    (e) => e.number?.round() == selectedEpisode,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EpisodeGalleryChip extends StatelessWidget {
  const _EpisodeGalleryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 7),
    child: Material(
      color: selected ? AppColors.accent : AppColors.surface2,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
          child: Text(
            label,
            style: AppText.caption.copyWith(
              color: selected ? Colors.white : AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    ),
  );
}

/// Episode detail page: keeps the original compact expandable section and
/// automatically loads only the episode currently being viewed.
class EpisodeScreenshotGallery extends StatefulWidget {
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
  State<EpisodeScreenshotGallery> createState() =>
      _EpisodeScreenshotGalleryState();
}

class _EpisodeScreenshotGalleryState extends State<EpisodeScreenshotGallery> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    if (widget.episodeNumber <= 0 ||
        ((widget.malId == null || widget.malId! <= 0) &&
            (widget.tmdbId == null || widget.season == null))) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.hairline),
        ),
        child: Column(
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
                child: Row(
                  children: [
                    Icon(Icons.photo_library_outlined, color: AppColors.accent, size: 19),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        'Gallery Episode',
                        style: AppText.body.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Icon(
                      _expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
            if (_expanded) ...[
              Divider(height: 1, color: AppColors.hairline),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: _EpisodeStillRail(
                  key: ValueKey('episode-detail:${widget.malId}:${widget.tmdbId}:${widget.season}:${widget.episodeNumber}'),
                  malId: widget.malId,
                  tmdbId: widget.tmdbId,
                  season: widget.season,
                  episodeNumber: widget.episodeNumber,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AllEpisodeStillRail extends StatelessWidget {
  const _AllEpisodeStillRail({
    required this.episodes,
    this.malId,
    this.tmdbId,
  });

  final List<Episode> episodes;
  final int? malId;
  final int? tmdbId;

  @override
  Widget build(BuildContext context) => FutureBuilder<List<_EpisodeStill>>(
    future: _loadAllEpisodeStills(
      episodes: episodes,
      malId: malId,
      tmdbId: tmdbId,
    ),
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const _GalleryLoading();
      }
      final stills = snapshot.data ?? const <_EpisodeStill>[];
      if (stills.isEmpty) return const _GalleryMessage('Screenshot belum tersedia.');
      return _StillRail(stills: stills);
    },
  );
}

class _EpisodeStillRail extends StatelessWidget {
  const _EpisodeStillRail({
    super.key,
    this.malId,
    this.tmdbId,
    this.season,
    this.episode,
    this.episodeNumber,
  });

  final int? malId;
  final int? tmdbId;
  final int? season;
  final Episode? episode;
  final int? episodeNumber;

  @override
  Widget build(BuildContext context) {
    final number = episodeNumber ?? episode?.number?.round() ?? 0;
    return FutureBuilder<List<String>>(
      future: sl<EpisodeMetadataService>().episodeScreenshots(
        malId: malId,
        tmdbId: tmdbId,
        season: season ?? episode?.season,
        episodeNumber: number,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _GalleryLoading();
        }
        final urls = snapshot.data ?? const <String>[];
        if (urls.isEmpty) {
          return const _GalleryMessage('Screenshot untuk episode ini belum tersedia.');
        }
        return _StillRail(
          stills: [for (final url in urls) (episode: number, url: url)],
        );
      },
    );
  }
}

class _GalleryLoading extends StatelessWidget {
  const _GalleryLoading();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 22),
    child: Center(
      child: SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    ),
  );
}

class _StillRail extends StatelessWidget {
  const _StillRail({required this.stills});
  final List<_EpisodeStill> stills;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 132,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: stills.length,
      separatorBuilder: (_, _) => const SizedBox(width: 9),
      itemBuilder: (context, index) {
        final still = stills[index];
        return GestureDetector(
          onTap: () => showDialog<void>(
            context: context,
            barrierColor: Colors.black.withValues(alpha: 0.50),
            barrierDismissible: false,
            builder: (_) => _EpisodeScreenshotViewer(
              urls: [for (final item in stills) item.url],
              initialIndex: index,
            ),
          ),
          child: SizedBox(
            width: 187,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    still.url,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => ColoredBox(
                      color: AppColors.surface2,
                      child: Icon(Icons.broken_image_outlined, color: AppColors.textTertiary),
                    ),
                    loadingBuilder: (_, child, progress) => progress == null
                        ? child
                        : ColoredBox(
                            color: AppColors.surface2,
                            child: const Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                          ),
                  ),
                  Positioned(
                    left: 7,
                    bottom: 7,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.62),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                        child: Text(
                          'Episode ${still.episode}',
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}

class _GalleryMessage extends StatelessWidget {
  const _GalleryMessage(this.message);
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 18),
    child: Center(
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: AppText.caption.copyWith(color: AppColors.textSecondary),
      ),
    ),
  );
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
      backgroundColor: Colors.transparent,
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
