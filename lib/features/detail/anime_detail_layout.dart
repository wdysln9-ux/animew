part of 'detail_screen.dart';

/// Fresh anime-detail scroll composition. The hero is a normal collapsing
/// sliver, not a FlexibleSpaceBar: its artwork is clipped in place and never
/// translated, blurred, or parallax-scrolled.
class AnimeDetailHeroSliver extends StatelessWidget {
  const AnimeDetailHeroSliver({
    required this.coverUrl,
    required this.posterUrl,
    required this.coverHeaders,
    required this.sourceLabel,
    required this.animeId,
    this.maxHeight = 438,
  });

  final String coverUrl;
  final String? posterUrl;
  final Map<String, String>? coverHeaders;
  final String sourceLabel;
  final String animeId;
  final double maxHeight;

  @override
  Widget build(BuildContext context) => SliverPersistentHeader(
    pinned: false,
    delegate: _AnimeDetailHeroDelegate(
      coverUrl: coverUrl,
      posterUrl: posterUrl,
      coverHeaders: coverHeaders,
      sourceLabel: sourceLabel,
      animeId: animeId,
      maxHeight: maxHeight,
    ),
  );
}

class _AnimeDetailHeroDelegate extends SliverPersistentHeaderDelegate {
  const _AnimeDetailHeroDelegate({
    required this.coverUrl,
    required this.posterUrl,
    required this.coverHeaders,
    required this.sourceLabel,
    required this.animeId,
    required this.maxHeight,
  });

  final String coverUrl;
  final String? posterUrl;
  final Map<String, String>? coverHeaders;
  final String sourceLabel;
  final String animeId;
  final double maxHeight;

  Widget _image(String url, {int width = 900}) {
    if (url.isEmpty) return ColoredBox(color: AppColors.surface2);
    final aniSource = coverHeaders?['x-ani-src'];
    final mihonSource = coverHeaders?['x-mihon-src'];
    final aniId = int.tryParse(aniSource ?? '');
    final mihonId = int.tryParse(mihonSource ?? '');
    if (aniId != null || mihonId != null) {
      return Image(
        image: ResizeImage(
          aniId != null ? AniyomiImage(aniId, url) : MihonImage(mihonId!, url),
          width: width,
        ),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => ColoredBox(color: AppColors.surface2),
      );
    }
    return CachedNetworkImage(
      imageUrl: url,
      httpHeaders: coverHeaders,
      fit: BoxFit.cover,
      memCacheWidth: width,
      placeholder: (_, _) => ColoredBox(color: AppColors.surface2),
      errorWidget: (_, _, _) => ColoredBox(color: AppColors.surface2),
    );
  }

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final progress = (shrinkOffset / maxHeight).clamp(0.0, 1.0);
    final poster = posterUrl?.isNotEmpty == true ? posterUrl! : coverUrl;
    final topInset = MediaQuery.paddingOf(context).top;

    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(child: _image(coverUrl)),
          const Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x66000000),
                      Color(0x00000000),
                      Color(0xE6000000),
                    ],
                    stops: [0.0, 0.42, 1.0],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: topInset + 8,
            left: 8,
            child: _AnimeDetailCircleAction(
              icon: Icons.arrow_back_rounded,
              label: 'Kembali',
              onTap: () => Navigator.of(context).maybePop(),
            ),
          ),
          if (sourceLabel.isNotEmpty || animeId.isNotEmpty)
            Positioned(
              top: topInset + 14,
              right: 14,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xB8000000),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 7,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (sourceLabel.isNotEmpty)
                        Text(
                          sourceLabel,
                          style: AppText.caption.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      if (sourceLabel.isNotEmpty && animeId.isNotEmpty)
                        const SizedBox(width: 7),
                      if (animeId.isNotEmpty)
                        Text(
                          '#$animeId',
                          style: AppText.caption.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          if (progress < 0.82)
            Positioned(
              left: 0,
              right: 0,
              bottom: 12 - shrinkOffset * 0.18,
              child: Opacity(
                opacity: (1 - progress * 1.2).clamp(0.0, 1.0),
                child: Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: SizedBox(
                      width: 154,
                      height: 224,
                      child: _image(poster, width: 480),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  double get maxExtent => maxHeight;

  @override
  double get minExtent => 0;

  @override
  bool shouldRebuild(covariant _AnimeDetailHeroDelegate oldDelegate) =>
      oldDelegate.coverUrl != coverUrl ||
      oldDelegate.posterUrl != posterUrl ||
      oldDelegate.coverHeaders != coverHeaders ||
      oldDelegate.sourceLabel != sourceLabel ||
      oldDelegate.animeId != animeId ||
      oldDelegate.maxHeight != maxHeight;
}

class AnimeDetailPinnedToolbar extends StatelessWidget {
  const AnimeDetailPinnedToolbar({
    required this.title,
    required this.visible,
    required this.backgroundColor,
  });

  final String title;
  final bool visible;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) => SliverPersistentHeader(
    pinned: true,
    delegate: _AnimeDetailToolbarDelegate(
      title: title,
      visible: visible,
      backgroundColor: backgroundColor,
    ),
  );
}

class _AnimeDetailToolbarDelegate extends SliverPersistentHeaderDelegate {
  const _AnimeDetailToolbarDelegate({
    required this.title,
    required this.visible,
    required this.backgroundColor,
  });

  final String title;
  final bool visible;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Material(
      color: backgroundColor,
      child: SizedBox(
        height: 56,
        child: Row(
          children: [
            IconButton(
              tooltip: 'Kembali',
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            Expanded(
              child: AnimatedOpacity(
                opacity: visible ? 1 : 0,
                duration: const Duration(milliseconds: 160),
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.headline,
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
        ),
      ),
    );
  }

  @override
  double get maxExtent => 56;

  @override
  double get minExtent => 56;

  @override
  bool shouldRebuild(covariant _AnimeDetailToolbarDelegate oldDelegate) =>
      oldDelegate.title != title ||
      oldDelegate.visible != visible ||
      oldDelegate.backgroundColor != backgroundColor;
}

class _AnimeDetailCircleAction extends StatelessWidget {
  const _AnimeDetailCircleAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0x77000000),
    shape: const CircleBorder(),
    child: IconButton(
      tooltip: label,
      onPressed: onTap,
      icon: Icon(icon, color: Colors.white, size: 23),
    ),
  );
}
