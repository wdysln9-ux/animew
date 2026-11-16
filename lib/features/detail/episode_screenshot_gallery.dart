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
  final key = '${malId ?? 0}:${tmdbId ?? 0}:${episodes.length}:${episodes.map((e) => '${e.season ?? 0}-${e.number?.round() ?? 0}').join(',')}';
  return _allEpisodeStillCache.putIfAbsent(key, () async {
    final result = <_EpisodeStill>[];
    // Keep the request fan-out bounded for long-running series.
    for (var start = 0; start < episodes.length; start += 8) {
      final batch = episodes.skip(start).take(8);
      final groups = await Future.wait([
        for (final episode in batch)
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
      result.addAll(groups.expand((items) => items));
    }
    return result;
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
  int _selectedEpisode = -1; // Default = Semua episode.

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
    // Keep the default filter unambiguously on "Semua". A missing or
    // stale episode selection also falls back to the all-episodes rail.
    final selectedEpisode = _selectedEpisode == -1 ||
            !episodeNumbers.contains(_selectedEpisode)
        ? null
        : _selectedEpisode;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 0, 0),
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
                  FutureBuilder<List<_EpisodeStill>>(
                    future: _loadAllEpisodeStills(
                      episodes: widget.episodes,
                      malId: widget.malId,
                      tmdbId: widget.tmdbId,
                    ),
                    builder: (context, snapshot) => Text(
                      snapshot.hasData ? '${snapshot.data!.length}' : '…',
                      style: AppText.caption.copyWith(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const Spacer(),
                  AnimatedRotation(
                    turns: _expanded ? 0.25 : 0,
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeInOutCubic,
                    child: Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.textSecondary,
                      size: 21,
                    ),
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
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  clipBehavior: Clip.none,
                  children: [
                    _EpisodeGalleryChip(
                      label: 'Semua',
                      selected: _selectedEpisode == -1,
                      onTap: () => setState(() => _selectedEpisode = -1),
                    ),
                    for (final number in episodeNumbers)
                      _EpisodeGalleryChip(
                        label: 'Episode $number',
                        selected: selectedEpisode == number,
                        onTap: () => setState(() => _selectedEpisode = number),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              if (selectedEpisode == null)
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
      padding: const EdgeInsets.fromLTRB(16, 16, 0, 0),
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
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Row(
                  children: [
                    Text(
                      'Gallery Episode',
                      style: AppText.headline.copyWith(fontSize: 16),
                    ),
                    const Spacer(),
                    AnimatedRotation(
                      turns: _expanded ? 0.25 : 0,
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeInOutCubic,
                      child: Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.textSecondary,
                        size: 21,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_expanded) ...[
              const SizedBox(height: 9),
              _EpisodeDetailGalleryContent(
                key: ValueKey('episode-detail:${widget.malId}:${widget.tmdbId}:${widget.season}:${widget.episodeNumber}'),
                malId: widget.malId,
                tmdbId: widget.tmdbId,
                season: widget.season,
                episodeNumber: widget.episodeNumber,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EpisodeDetailGalleryContent extends StatefulWidget {
  const _EpisodeDetailGalleryContent({
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
  State<_EpisodeDetailGalleryContent> createState() =>
      _EpisodeDetailGalleryContentState();
}

class _EpisodeDetailGalleryContentState
    extends State<_EpisodeDetailGalleryContent> {
  late final Future<List<String>> _future =
      sl<EpisodeMetadataService>().episodeScreenshots(
    malId: widget.malId,
    tmdbId: widget.tmdbId,
    season: widget.season,
    episodeNumber: widget.episodeNumber,
  );

  Future<void> _download(List<String> urls) async {
    if (urls.isEmpty) return;
    var saved = 0;
    for (var i = 0; i < urls.length; i++) {
      try {
        final response = await Dio().get<List<int>>(
          urls[i],
          options: Options(
            responseType: ResponseType.bytes,
            connectTimeout: const Duration(seconds: 20),
            receiveTimeout: const Duration(seconds: 60),
          ),
        );
        final bytes = response.data;
        if (bytes == null || bytes.isEmpty) continue;
        final uri = await _episodeGalleryChannel.invokeMethod<String>(
          'saveImage',
          {
            'bytes': Uint8List.fromList(bytes),
            'fileName': 'AnimeW_Episode_${widget.episodeNumber}_Screenshot_${DateTime.now().millisecondsSinceEpoch}_${i + 1}',
            'mimeType': response.headers.value('content-type') ?? 'image/jpeg',
          },
        );
        if (uri != null && uri.isNotEmpty) saved++;
      } catch (_) {
        // Continue with the remaining images if one URL fails.
      }
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(saved == urls.length
            ? '$saved foto berhasil disimpan ke Galeri'
            : '$saved dari ${urls.length} foto berhasil disimpan'),
      ),
    );
  }

  Future<void> _chooseImages(List<String> urls) async {
    final selected = await showModalBottomSheet<List<int>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      barrierColor: Colors.black54,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ScreenshotSelectionSheet(urls: urls),
    );
    if (selected == null || selected.isEmpty || !mounted) return;
    await _download([for (final index in selected) urls[index]]);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<String>>(
    future: _future,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const _GalleryLoading();
      }
      final urls = snapshot.data ?? const <String>[];
      if (urls.isEmpty) {
        return const _GalleryMessage('Screenshot untuk episode ini belum tersedia.');
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${urls.length} foto tersedia',
                  style: AppText.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => _chooseImages(urls),
                child: Text(
                  'Pilih',
                  style: TextStyle(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _StillRail(
            stills: [for (final url in urls) (episode: widget.episodeNumber, url: url)],
            edgeBleed: 12,
          ),
        ],
      );
    },
  );
}

class _ScreenshotSelectionSheet extends StatefulWidget {
  const _ScreenshotSelectionSheet({required this.urls});
  final List<String> urls;

  @override
  State<_ScreenshotSelectionSheet> createState() =>
      _ScreenshotSelectionSheetState();
}

class _ScreenshotSelectionSheetState extends State<_ScreenshotSelectionSheet> {
  final Set<int> _selected = {};

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.72,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text('Pilih foto', style: AppText.headline),
                ),
                Text(
                  '${_selected.length} / ${widget.urls.length}',
                  style: AppText.caption.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 9,
                mainAxisSpacing: 9,
                childAspectRatio: 1.55,
              ),
              itemCount: widget.urls.length,
              itemBuilder: (context, index) {
                final selected = _selected.contains(index);
                return GestureDetector(
                  onTap: () => setState(() {
                    if (selected) {
                      _selected.remove(index);
                    } else {
                      _selected.add(index);
                    }
                  }),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(9),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(widget.urls[index], fit: BoxFit.cover),
                        if (selected)
                          ColoredBox(color: AppColors.accent.withValues(alpha: 0.28)),
                        Positioned(
                          top: 7,
                          right: 7,
                          child: Icon(
                            selected
                                ? Icons.check_circle
                                : Icons.radio_button_unchecked,
                            color: selected ? AppColors.accent : Colors.white,
                            size: 23,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _selected.isEmpty
                    ? null
                    : () => Navigator.pop(context, _selected.toList()..sort()),
                icon: const Icon(Icons.download_rounded),
                label: Text('Unduh ${_selected.length} foto'),
              ),
            ),
          ),
        ],
      ),
    ),
  );
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
  const _StillRail({required this.stills, this.edgeBleed = 16});
  final List<_EpisodeStill> stills;
  final double edgeBleed;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 106,
    child: LayoutBuilder(
      builder: (context, constraints) => Transform.translate(
        offset: Offset(-edgeBleed, 0),
        child: SizedBox(
          width: constraints.maxWidth + edgeBleed,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.only(left: edgeBleed + 4, right: 16),
            clipBehavior: Clip.none,
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
        ),
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

