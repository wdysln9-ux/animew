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
      child: OverflowBox(
        alignment: Alignment.topCenter,
        minHeight: maxHeight,
        maxHeight: maxHeight,
        child: SizedBox(
          width: MediaQuery.sizeOf(context).width,
          height: maxHeight,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // The artwork is laid out at its original hero dimensions and
              // clipped by the collapsing sliver. Its scale/crop never changes
              // while scrolling, so it cannot look like a camera zoom.
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
                      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (sourceLabel.isNotEmpty)
                            Text(sourceLabel, style: AppText.caption.copyWith(
                              color: Colors.white, fontWeight: FontWeight.w700)),
                          if (sourceLabel.isNotEmpty && animeId.isNotEmpty)
                            const SizedBox(width: 7),
                          if (animeId.isNotEmpty)
                            Text('#$animeId', style: AppText.caption.copyWith(
                              color: Colors.white, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ),
                ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 12,
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
        ),
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


class AnimeDetailTitleBlock extends StatelessWidget {
  const AnimeDetailTitleBlock({
    required this.title,
    required this.metaLine,
    this.englishTitle,
    this.format,
    this.status,
  });

  final String title;
  final String? englishTitle;
  final String metaLine;
  final String? format;
  final String? status;

  @override
  Widget build(BuildContext context) {
    final subtitle = englishTitle?.trim();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(title, textAlign: TextAlign.center, maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppText.largeTitle.copyWith(fontSize: 24, height: 1.14)),
          if (subtitle != null && subtitle.isNotEmpty && subtitle != title) ...[
            const SizedBox(height: 4),
            Text(subtitle, textAlign: TextAlign.center, maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppText.body.copyWith(fontSize: 13, color: AppColors.textSecondary)),
          ],
          if (metaLine.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(metaLine, textAlign: TextAlign.center, maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.body.copyWith(fontSize: 12, color: AppColors.textSecondary)),
          ],
          if ((format?.isNotEmpty ?? false) || (status?.isNotEmpty ?? false)) ...[
            const SizedBox(height: 10),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 6,
              runSpacing: 6,
              children: [
                if (format?.isNotEmpty == true) _AnimeDetailMetadataChip(format!),
                if (status?.isNotEmpty == true) _AnimeDetailMetadataChip(status!),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _AnimeDetailMetadataChip extends StatelessWidget {
  const _AnimeDetailMetadataChip(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(6)),
    child: Text(label, style: AppText.caption.copyWith(
      fontSize: 10.5, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
  );
}

class AnimeDetailActionButton extends StatelessWidget {
  const AnimeDetailActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.loading = false,
    this.primary = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool loading;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final foreground = primary ? Colors.white : AppColors.textPrimary;
    final background = primary ? AppColors.accent : AppColors.surface2;
    return Opacity(
      opacity: onPressed != null || loading ? 1 : 0.42,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(24),
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: primary ? null : Border.all(color: AppColors.textTertiary.withValues(alpha: 0.28)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 20, color: foreground),
                const SizedBox(width: 6),
                Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: AppText.button.copyWith(fontSize: 12, color: foreground))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AnimeDetailSynopsisSection extends StatefulWidget {
  const AnimeDetailSynopsisSection({required this.text, this.onMore});
  final String text;
  final VoidCallback? onMore;

  @override
  State<AnimeDetailSynopsisSection> createState() => _AnimeDetailSynopsisSectionState();
}

class _AnimeDetailSynopsisSectionState extends State<AnimeDetailSynopsisSection> {
  bool _expanded = false;
  String? _translated;

  @override
  void initState() {
    super.initState();
    _translate();
  }

  @override
  void didUpdateWidget(covariant AnimeDetailSynopsisSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _translated = null;
      _expanded = false;
      _translate();
    }
  }

  Future<void> _translate() async {
    final result = await SynopsisTranslator.instance.translateToIndonesian(widget.text);
    if (!mounted) return;
    setState(() => _translated = result == widget.text ? null : result);
  }

  @override
  Widget build(BuildContext context) {
    final data = _translated ?? widget.text;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: ClipRect(
              child: ConstrainedBox(
                constraints: _expanded ? const BoxConstraints() : const BoxConstraints(maxHeight: 64),
                child: AniListMarkdown(data: data, textStyle: AppText.body.copyWith(
                  fontSize: 13, height: 1.48, color: AppColors.textSecondary)),
              ),
            ),
          ),
          const SizedBox(height: 5),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onMore ?? () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Text(
                widget.onMore != null ? 'Selengkapnya' : (_expanded ? 'Lebih sedikit' : 'Selengkapnya'),
                style: AppText.caption.copyWith(color: AppColors.accent, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AnimeDetailGenreChips extends StatelessWidget {
  const AnimeDetailGenreChips({required this.genres, required this.onTap});
  final List<String> genres;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    if (genres.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final genre in genres)
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(7),
                onTap: () => onTap(genre),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.accent.withValues(alpha: 0.72)),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(genre, style: AppText.caption.copyWith(fontSize: 11, color: AppColors.accent)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class AnimeDetailCharacterRail extends StatelessWidget {
  const AnimeDetailCharacterRail({required this.cast, this.onOpenPerson});
  final List<CastMember> cast;
  final ValueChanged<PersonRef>? onOpenPerson;

  @override
  Widget build(BuildContext context) {
    if (cast.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 0, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text('Karakter', style: AppText.headline.copyWith(fontSize: 17)),
            const SizedBox(width: 7),
            Text(cast.length.toString(), style: AppText.caption.copyWith(color: AppColors.textSecondary)),
          ]),
          const SizedBox(height: 11),
          SizedBox(
            height: 128,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(right: 16),
              itemCount: cast.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final member = cast[index];
                return SizedBox(
                  width: 82,
                  child: GestureDetector(
                    onTap: member.person == null || onOpenPerson == null ? null : () => onOpenPerson!(member.person!),
                    child: Column(children: [
                      ClipOval(
                        child: SizedBox(
                          width: 68,
                          height: 68,
                          child: member.photo?.isNotEmpty == true
                              ? CachedNetworkImage(
                                  imageUrl: member.photo!, fit: BoxFit.cover,
                                  placeholder: (_, _) => ColoredBox(color: AppColors.surface2),
                                  errorWidget: (_, _, _) => ColoredBox(color: AppColors.surface2, child: const Icon(Icons.person_outline_rounded)),
                                )
                              : ColoredBox(color: AppColors.surface2, child: Icon(Icons.person_outline_rounded, color: AppColors.textSecondary)),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(member.name, maxLines: 2, textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.caption.copyWith(fontSize: 10.5, color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                      if (member.role?.isNotEmpty == true)
                        Text(_indonesianCharacterRole(member.role!), maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.caption.copyWith(fontSize: 9, color: AppColors.accent)),
                    ]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class AnimeDetailSeasonRail extends StatelessWidget {
  const AnimeDetailSeasonRail({required this.seasons, required this.onOpen});
  final List<SeasonEntry> seasons;
  final ValueChanged<SeasonEntry> onOpen;

  @override
  Widget build(BuildContext context) {
    if (seasons.isEmpty) return const SizedBox.shrink();
    final width = posterRowWidth(context);
    final height = posterRowHeight(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 0, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Semua Musim', style: AppText.headline.copyWith(fontSize: 17)),
          const SizedBox(height: 11),
          SizedBox(
            height: height,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(right: 16),
              itemCount: seasons.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final season = seasons[index];
                return SizedBox(
                  width: width,
                  child: PosterCard(
                    title: season.title,
                    imageUrl: season.cover,
                    cellWidth: width,
                    seriesBadge: 'Seri ' + season.number.toString(),
                    metaLine: season.episodes == null ? null : 'TV · ' + season.episodes.toString() + ' eps',
                    onTap: () => onOpen(season),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
