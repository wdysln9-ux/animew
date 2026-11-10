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
    this.onAniListTap,
    this.maxHeight = 376,
  });

  final String coverUrl;
  final String? posterUrl;
  final Map<String, String>? coverHeaders;
  final String sourceLabel;
  final String animeId;
  final VoidCallback? onAniListTap;
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
      onAniListTap: onAniListTap,
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
    this.onAniListTap,
  });

  final String coverUrl;
  final String? posterUrl;
  final Map<String, String>? coverHeaders;
  final String sourceLabel;
  final String animeId;
  final double maxHeight;
  final VoidCallback? onAniListTap;

  Widget _image(
    String url, {
    int width = 900,
    Alignment alignment = Alignment.center,
    BoxFit fit = BoxFit.cover,
  }) {
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
        fit: fit,
        alignment: alignment,
        errorBuilder: (_, _, _) => ColoredBox(color: AppColors.surface2),
      );
    }
    return CachedNetworkImage(
      imageUrl: url,
      httpHeaders: coverHeaders,
      fit: fit,
      alignment: alignment,
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
    final poster = posterUrl?.isNotEmpty == true ? posterUrl! : coverUrl;
    final topInset = MediaQuery.paddingOf(context).top;
    final posterWidth = (MediaQuery.sizeOf(context).width * 0.45)
        .clamp(170.0, 194.0)
        .toDouble();
    final posterHeight = posterWidth * 1.5;

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
              // Keep the backdrop moving with the rest of the page.
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                bottom: -150,
                child: _image(coverUrl, alignment: Alignment.topCenter),
              ),
              // Darken the complete backdrop evenly first. The gradient
              // then fades it into the page color without leaving a bright
              // strip between the poster, title block, and the rest of page.
              Positioned.fill(
                child: ColoredBox(color: Color.fromRGBO(0, 0, 0, 0.25)),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.20),
                          Colors.black.withValues(alpha: 0.32),
                          AppColors.bg.withValues(alpha: 0.58),
                          Color.alphaBlend(
                            Colors.black.withValues(alpha: 0.12),
                            AppColors.bg,
                          ),
                          Color.alphaBlend(
                            Colors.black.withValues(alpha: 0.12),
                            AppColors.bg,
                          ),
                        ],
                        stops: [0.0, 0.25, 0.52, 0.82, 1.0],
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
                  top: topInset + 8,
                  right: 14,
                  child: InkWell(
                    onTap: sourceLabel.toUpperCase() == 'ANILIST' ? onAniListTap : null,
                    borderRadius: BorderRadius.circular(22),
                    child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0x66000000),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: SizedBox(
                      height: 32,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                          if (sourceLabel.isNotEmpty)
                            sourceLabel.toUpperCase() == 'MAL'
                                ? const _MalTextWordmark()
                                : sourceLabel.toUpperCase() == 'ANILIST'
                                    ? Image.asset(
                                        'assets/icon/providers/anilist.png',
                                        width: 19,
                                        height: 19,
                                        fit: BoxFit.contain,
                                      )
                                    : Text(
                                        sourceLabel,
                                        style: AppText.caption.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12,
                                        ),
                                      ),
                          if (sourceLabel.isNotEmpty && animeId.isNotEmpty)
                            const SizedBox(width: 6),
                          if (animeId.isNotEmpty)
                            Text(
                              '#$animeId',
                              style: AppText.caption.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 12.5,
                                height: 1,
                              ),
                            ),
                        ],
                        ),
                      ),
                    ),
                    ),
                  ),
                ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: SizedBox(
                      width: posterWidth,
                      height: posterHeight,
                      child: _image(poster, width: 528, fit: BoxFit.contain),
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
  double get minExtent => maxHeight;

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
    color: const Color(0x99000000),
    shape: const CircleBorder(),
    child: InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: SizedBox(
        width: 38,
        height: 38,
        child: Center(
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    ),
  );
}

class _MalTextWordmark extends StatelessWidget {
  const _MalTextWordmark();

  @override
  Widget build(BuildContext context) => Text(
    'MAL',
    style: AppText.caption.copyWith(
      color: Colors.white,
      fontSize: 13,
      fontWeight: FontWeight.w900,
      fontStyle: FontStyle.italic,
      letterSpacing: -0.5,
      height: 1,
    ),
  );
}

class AnimeDetailTitleBlock extends StatelessWidget {
  const AnimeDetailTitleBlock({
    required this.title,
    required this.metaLine,
    this.englishTitle,
    this.romajiTitle,
    this.alternateTitle,
    this.format,
    this.status,
    this.ageRating,
    this.dateLine,
    this.broadcastLabel,
    this.rank,
  });

  final String title;
  final String? englishTitle;
  final String? romajiTitle;
  final String? alternateTitle;
  final String metaLine;
  final String? format;
  final String? status;
  final String? ageRating;
  final String? dateLine;
  final String? broadcastLabel;
  final int? rank;

  @override
  Widget build(BuildContext context) {
    final romaji = romajiTitle?.trim().isNotEmpty == true
        ? romajiTitle!.trim()
        : title.trim();
    final english = englishTitle?.trim().isNotEmpty == true
        ? englishTitle!.trim()
        : '';
    final translatedSource = english.isNotEmpty ? english : romaji;
    return SizedBox(
      width: double.infinity,
      child: Stack(
        children: [
        // Keep the information area image-free: reusing the hero poster
        // here caused a second, visibly cropped copy behind the metadata.
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color.alphaBlend(
                    Colors.black.withValues(alpha: 0.12),
                    AppColors.bg,
                  ),
                  Color.alphaBlend(
                    Colors.black.withValues(alpha: 0.075),
                    AppColors.bg,
                  ),
                  Color.alphaBlend(
                    Colors.black.withValues(alpha: 0.035),
                    AppColors.bg,
                  ),
                  AppColors.bg,
                ],
                stops: [0.0, 0.38, 0.76, 1.0],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (romaji.isNotEmpty)
            Text(romaji, textAlign: TextAlign.center, maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppText.largeTitle.copyWith(fontSize: 22, height: 1.14)),
          if (romaji.isNotEmpty && english.isNotEmpty) const SizedBox(height: 2),
          if (english.isNotEmpty) ...[
            Text(english, textAlign: TextAlign.center, maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppText.body.copyWith(fontSize: 13, height: 1.2, color: AppColors.textSecondary)),
            const SizedBox(height: 2),
          ],
          AutoTranslatedText(text: translatedSource, textAlign: TextAlign.center, maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppText.body.copyWith(fontSize: 13, color: AppColors.textSecondary)),
          if (metaLine.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text.rich(
              TextSpan(children: [
                for (var i = 0; i < metaLine.split('  ·  ').length; i++) ...[
                  if (i > 0)
                    TextSpan(
                      children: [
                        const TextSpan(text: '  '),
                        TextSpan(text: '·', style: AppText.body.copyWith(fontSize: 17, color: AppColors.textTertiary, fontWeight: FontWeight.w900)),
                        const TextSpan(text: '  '),
                      ],
                    ),
                  if (metaLine.split('  ·  ')[i].startsWith('◉ '))
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 3),
                        child: Icon(
                          Icons.visibility_outlined,
                          size: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  TextSpan(
                    text: metaLine.split('  ·  ')[i].startsWith('◉ ')
                        ? metaLine.split('  ·  ')[i].substring(2)
                        : metaLine.split('  ·  ')[i],
                    style: AppText.body.copyWith(
                      fontSize: 15,
                      color: i == 0 ? AppColors.accent
                          : (metaLine.split('  ·  ')[i].startsWith('★')
                              ? const Color(0xFF24C66A)
                              : AppColors.textSecondary),
                      fontWeight: i == 1 ? FontWeight.w700 : FontWeight.normal,
                    ),
                  ),
                ],
              ]),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if ((ageRating?.isNotEmpty ?? false) || (dateLine?.isNotEmpty ?? false) || rank != null) ...[
            const SizedBox(height: 4),
            Text.rich(
              TextSpan(children: [
                for (var i = 0; i < [
                  if (ageRating?.isNotEmpty == true) 'Age ${ageRating!}',
                  if (dateLine?.isNotEmpty == true) dateLine!,
                ].length; i++) ...[
                  if (i > 0)
                    TextSpan(
                      children: [
                        const TextSpan(text: '   '),
                        TextSpan(text: '·', style: AppText.body.copyWith(fontSize: 16, color: AppColors.textTertiary, fontWeight: FontWeight.w900)),
                        const TextSpan(text: '   '),
                      ],
                    ),
                  TextSpan(
                    text: [
                      if (ageRating?.isNotEmpty == true) 'Age ${ageRating!}',
                      if (dateLine?.isNotEmpty == true) dateLine!,
                    ][i],
                    style: AppText.body.copyWith(
                      fontSize: 15,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ]),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (broadcastLabel?.isNotEmpty == true) ...[
            const SizedBox(height: 4),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.access_time_rounded, size: 16, color: AppColors.accent),
              const SizedBox(width: 5),
              Flexible(child: Text(broadcastLabel!, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: AppText.body.copyWith(fontSize: 14, color: AppColors.accent))),
            ]),
          ],
          if ((format?.isNotEmpty ?? false) || (status?.isNotEmpty ?? false)) ...[
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 6,
              runSpacing: 6,
              children: [
                if (format?.isNotEmpty == true) _AnimeDetailMetadataChip(format!, isFormat: true),
                if (status?.isNotEmpty == true) _AnimeDetailMetadataChip(status!),
              ],
            ),
          ],
        ],
            ),
          ),
        ),
        ],
      ),
    );
  }
}

class _AnimeDetailMetadataChip extends StatelessWidget {
  const _AnimeDetailMetadataChip(this.label, {this.isFormat = false});
  final String label;
  final bool isFormat;

  @override
  Widget build(BuildContext context) {
    final value = label.toLowerCase();
    final isAiring = value.contains('tayang') || value.contains('ongoing');
    final isCompleted = value.contains('selesai') || value.contains('completed');
    final isUpcoming = value.contains('segera') || value.contains('upcoming');
    final statusColor = isCompleted ? const Color(0xFF4389E8) : (isAiring ? const Color(0xFF24A765) : const Color(0xFFB86A2A));
    final background = isFormat ? AppColors.accent : statusColor.withValues(alpha: 0.20);
    final foreground = isFormat
        ? Colors.white
        : value.contains('selesai') || value.contains('completed')
        ? const Color(0xFF9CC7FF)
        : value.contains('tayang') || value.contains('ongoing')
            ? const Color(0xFF8BE0AE)
            : (isUpcoming ? const Color(0xFFFFC58A) : const Color(0xFFFFC58A));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        border: isFormat ? null : Border.all(color: statusColor, width: 1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: AppText.caption.copyWith(
          fontSize: 12,
          color: foreground,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class AnimeDetailActionButton extends StatelessWidget {
  const AnimeDetailActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.loading = false,
    this.primary = false,
    this.active = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool loading;
  final bool primary;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final foreground = active ? Colors.white : AppColors.textPrimary;
    final background = active ? AppColors.accent : (primary ? AppColors.bg : AppColors.surface2);
    return Opacity(
      opacity: onPressed != null || loading ? 1 : 0.42,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(23),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(23),
          child: Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(23),
              border: Border.all(
                color: AppColors.textTertiary.withValues(alpha: 0.48),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: foreground),
                const SizedBox(width: 6),
                Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: AppText.button.copyWith(fontSize: 13, color: foreground))),
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Sinopsis', style: AppText.headline.copyWith(fontSize: 15)),
          const SizedBox(height: 9),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: _expanded
                ? AniListMarkdown(data: data, textStyle: AppText.body.copyWith(
                    fontSize: 14, height: 1.45, color: AppColors.textSecondary))
                : Text(data, maxLines: 3, overflow: TextOverflow.ellipsis,
                    style: AppText.body.copyWith(fontSize: 14, height: 1.45, color: AppColors.textSecondary)),
          ),
          const SizedBox(height: 5),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onMore ?? () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Text(
                widget.onMore != null ? 'Selengkapnya' : (_expanded ? 'Lebih sedikit' : 'Selengkapnya'),
                style: AppText.caption.copyWith(fontSize: 12.5, color: AppColors.accent, fontWeight: FontWeight.w700),
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
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Wrap(
        alignment: WrapAlignment.center,
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
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.accent.withValues(alpha: 0.72)),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(genre, style: AppText.caption.copyWith(fontSize: 12, color: AppColors.accent)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DetailCredits extends StatefulWidget {
  const _DetailCredits({
    required this.genres,
    required this.studios,
    required this.tags,
    required this.onGenreTap,
    required this.onStudioTap,
    required this.onTagsTap,
  });
  final List<String> genres;
  final List<String> studios;
  final List<MediaTag> tags;
  final ValueChanged<String> onGenreTap;
  final ValueChanged<String> onStudioTap;
  final VoidCallback onTagsTap;

  @override
  State<_DetailCredits> createState() => _DetailCreditsState();
}

class _DetailCreditsState extends State<_DetailCredits> {
  bool _expanded = false;

  Widget _chip(String label, Color color, {VoidCallback? onTap}) {
    final child = Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.20),
        border: Border.all(color: color, width: 1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppText.caption.copyWith(
          fontSize: 12,
          height: 1.1,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
    if (onTap == null) return child;
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(5), child: child);
  }

  @override
  Widget build(BuildContext context) {
    const studioBlue = Color(0xFF2864B7);
    final genreColor = AppColors.accent;
    final hasCredits = widget.studios.isNotEmpty || widget.tags.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: AnimatedSize(duration: const Duration(milliseconds: 240), curve: Curves.easeInOutCubic, alignment: Alignment.topCenter, child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (widget.genres.isNotEmpty)
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final genre in widget.genres)
                  InkWell(
                    onTap: () => widget.onGenreTap(genre),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(
                        border: Border.all(color: genreColor.withValues(alpha: 0.8)),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Text(
                        genre,
                        style: AppText.caption.copyWith(
                          fontSize: 12,
                          color: genreColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          if (hasCredits && !_expanded) ...[
            const SizedBox(height: 7),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _expanded = true),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: AppColors.textSecondary),
                    const SizedBox(width: 2),
                    Text('Selengkapnya', style: AppText.caption.copyWith(
                      fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w700,
                    )),
                  ],
                ),
              ),
            ),
          ],
          if (_expanded && hasCredits) ...[
            const SizedBox(height: 7),
            Wrap(alignment: WrapAlignment.center, spacing: 6, runSpacing: 6, children: [
              for (final studio in widget.studios)
                _chip(studio, studioBlue, onTap: () => widget.onStudioTap(studio)),
              if (widget.tags.isNotEmpty)
                _chip('Tags (${widget.tags.length})', AppColors.accent, onTap: widget.onTagsTap),
            ]),
          ],
          if (_expanded && hasCredits)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _expanded = false),
              child: Padding(
                padding: const EdgeInsets.only(top: 6, bottom: 1),
                child: Text('Lebih sedikit', style: AppText.caption.copyWith(
                  fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w600,
                )),
              ),
            ),
        ],
      )),
    );
  }
}

class AnimeDetailCharacterRail extends StatefulWidget {
  const AnimeDetailCharacterRail({required this.cast, this.loading = false, this.onOpenPerson, this.onRetry});
  final List<CastMember> cast;
  final bool loading;
  final ValueChanged<PersonRef>? onOpenPerson;
  final VoidCallback? onRetry;
  @override
  State<AnimeDetailCharacterRail> createState() => _AnimeDetailCharacterRailState();
}
class _AnimeDetailCharacterRailState extends State<AnimeDetailCharacterRail> {
  bool _expanded = true;
  @override
  Widget build(BuildContext context) {
    final cast = widget.cast;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 0, 0),
      child: AnimatedSize(duration: const Duration(milliseconds: 240), curve: Curves.easeInOutCubic, alignment: Alignment.topCenter, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(children: [
              Text('Karakter', style: AppText.headline.copyWith(fontSize: 16)),
              const SizedBox(width: 7),
              Text(cast.length.toString(), style: AppText.caption.copyWith(fontSize: 12, color: AppColors.textSecondary)),
              const Spacer(),
              Icon(_expanded ? Icons.keyboard_arrow_down_rounded : Icons.chevron_right_rounded, color: AppColors.textSecondary),
            ]),
          ),
        ),
        if (_expanded && cast.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 9, right: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.loading ? 'Memuat karakter...' : 'Karakter belum bisa dimuat.',
                    style: AppText.caption.copyWith(color: AppColors.textSecondary),
                  ),
                ),
                if (!widget.loading && widget.onRetry != null)
                  TextButton(onPressed: widget.onRetry, child: const Text('Coba lagi')),
              ],
            ),
          ),
        if (_expanded && cast.isNotEmpty) ...[
          const SizedBox(height: 11),
          SizedBox(height: 148, child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(right: 16),
            itemCount: cast.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final member = cast[index];
              return SizedBox(width: 86, child: GestureDetector(
                onTap: member.person == null || widget.onOpenPerson == null
                    ? null : () => widget.onOpenPerson!(member.person!),
                child: Column(children: [
                  ClipOval(child: SizedBox(width: 77, height: 77,
                    child: member.photo?.isNotEmpty == true
                        ? CachedNetworkImage(imageUrl: member.photo!, fit: BoxFit.cover,
                            placeholder: (_, _) => ColoredBox(color: AppColors.surface2),
                            errorWidget: (_, _, _) => ColoredBox(color: AppColors.surface2,
                              child: const Icon(Icons.person_outline_rounded)))
                        : ColoredBox(color: AppColors.surface2,
                            child: Icon(Icons.person_outline_rounded, color: AppColors.textSecondary)))),
                  const SizedBox(height: 6),
                  Text(member.name, maxLines: 2, textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.caption.copyWith(fontSize: 12, color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                  if (member.role?.isNotEmpty == true)
                    Text(_indonesianCharacterRole(member.role!), maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.caption.copyWith(fontSize: 10.5, color: _indonesianCharacterRole(member.role!) == 'Utama' ? AppColors.accent : AppColors.textSecondary)),
                ]),
              ));
            },
          )),
        ],
      ])),
    );
  }
}

class AnimeDetailSeasonRail extends StatefulWidget {
  const AnimeDetailSeasonRail({
    required this.seasons,
    required this.relations,
    this.loading = false,
    required this.onOpenSeason,
    required this.onOpenRelation,
  });
  final List<SeasonEntry> seasons;
  final List<MediaRelation> relations;
  final bool loading;
  final ValueChanged<SeasonEntry> onOpenSeason;
  final ValueChanged<MediaRelation> onOpenRelation;

  @override
  State<AnimeDetailSeasonRail> createState() => _AnimeDetailSeasonRailState();
}

class _AnimeDetailSeasonRailState extends State<AnimeDetailSeasonRail> {
  int _selected = 0;

  bool _isRecommended(MediaRelation relation) {
    final value = relation.relation?.trim().toLowerCase().replaceAll('_', ' ');
    return value == 'recommended' || value == 'recommendation';
  }

  bool _isSeasonRelation(MediaRelation relation) {
    final value = relation.relation?.trim().toLowerCase().replaceAll('_', ' ');
    return value == 'prequel' || value == 'sequel' || value == 'prekuel';
  }

  List<MediaRelation> _uniqueAnimeRelations(
    Iterable<MediaRelation> source, {
    required Set<int> anilistIds,
    required Set<int> malIds,
    required Set<String> seasonTitles,
  }) {
    final seenAniList = <int>{...anilistIds};
    final seenMal = <int>{...malIds};
    final seenTitles = <String>{...seasonTitles};
    final result = <MediaRelation>[];
    for (final relation in source) {
      if (relation.isReading) continue;
      final aid = relation.anilistId;
      final mid = relation.malId;
      final title = relation.title.trim().toLowerCase();
      if ((aid != null && seenAniList.contains(aid)) ||
          (mid != null && seenMal.contains(mid)) ||
          (title.isNotEmpty && seenTitles.contains(title))) {
        continue;
      }
      if (aid != null) seenAniList.add(aid);
      if (mid != null) seenMal.add(mid);
      if (title.isNotEmpty) seenTitles.add(title);
      result.add(relation);
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final anilistIds = widget.seasons.map((s) => s.anilistId).whereType<int>().toSet();
    final malIds = widget.seasons.map((s) => s.malId).whereType<int>().toSet();
    final seasonTitles = widget.seasons.map((s) => s.title.trim().toLowerCase()).where((s) => s.isNotEmpty).toSet();

    // AniList's full franchise chain is authoritative. Relations only fill
    // gaps if a linked season could not be resolved into the chain.
    final seasonRelations = _uniqueAnimeRelations(
      widget.relations.where(_isSeasonRelation),
      anilistIds: anilistIds,
      malIds: malIds,
      seasonTitles: seasonTitles,
    );
    final related = _uniqueAnimeRelations(
      widget.relations.where((r) => !_isRecommended(r) && !_isSeasonRelation(r)),
      anilistIds: anilistIds,
      malIds: malIds,
      seasonTitles: seasonTitles,
    );
    final recommendations = _uniqueAnimeRelations(
      widget.relations.where(_isRecommended),
      anilistIds: anilistIds,
      malIds: malIds,
      seasonTitles: seasonTitles,
    );

    // Empty categories are omitted entirely, so there is no dead tab.
    final tabs = <String>[
      'Semua Musim',
      if (related.isNotEmpty) 'Terkait',
      if (recommendations.isNotEmpty) 'Rekomendasi',
    ];
    if (_selected >= tabs.length) _selected = 0;

    final width = posterRowWidth(context);
    final height = posterRowHeight(context);
    final selectedTab = tabs[_selected];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 0, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 27,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(right: 16),
              itemCount: tabs.length,
              separatorBuilder: (_, _) => const SizedBox(width: 9),
              itemBuilder: (context, index) {
                final selected = index == _selected;
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _selected = index),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          tabs[index],
                          style: AppText.headline.copyWith(
                            fontSize: 13,
                            height: 1.2,
                            color: selected ? AppColors.textPrimary : AppColors.textSecondary,
                            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeInOut,
                          width: selected ? 26 : 0,
                          height: 2,
                          decoration: BoxDecoration(
                            color: AppColors.accent,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: height,
            child: Builder(
              builder: (context) {
                final cards = <Widget>[];
                if (selectedTab == 'Semua Musim') {
                  for (final season in widget.seasons) {
                    cards.add(SizedBox(
                      width: width,
                      child: PosterCard(
                        title: season.title,
                        imageUrl: season.cover,
                        cellWidth: width,
                        seriesBadge: season.isCurrent ? 'Sedang dibuka' : 'Seri ${season.number}',
                        viewsBadge: season.popularity,
                        metaLine: season.episodes == null ? null : 'TV · ${season.episodes} eps',
                        onTap: () => widget.onOpenSeason(season),
                      ),
                    ));
                  }
                  for (final relation in seasonRelations) {
                    cards.add(SizedBox(
                      width: width,
                      child: PosterCard(
                        title: relation.title,
                        imageUrl: relation.cover,
                        cellWidth: width,
                        seriesBadge: relation.relation,
                        scoreBadge: relation.score,
                        statusBadge: relation.status,
                        genres: relation.genres,
                        metaLine: [
                          if (relation.year != null) '${relation.year}',
                          if (relation.format != null) relation.format!,
                          if (relation.episodes != null) '${relation.episodes} eps',
                        ].join(' · '),
                        viewsBadge: relation.popularity,
                        onTap: () => widget.onOpenRelation(relation),
                      ),
                    ));
                  }
                } else {
                  final rows = selectedTab == 'Terkait' ? related : recommendations;
                  for (final relation in rows) {
                    cards.add(SizedBox(
                      width: width,
                      child: PosterCard(
                        title: relation.title,
                        imageUrl: relation.cover,
                        cellWidth: width,
                        seriesBadge: relation.relation,
                        onTap: () => widget.onOpenRelation(relation),
                      ),
                    ));
                  }
                }

                if (cards.isEmpty) {
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: widget.loading && selectedTab == 'Semua Musim'
                          ? Row(
                              children: [
                                const SizedBox(
                                  width: 13,
                                  height: 13,
                                  child: CircularProgressIndicator(strokeWidth: 1.6),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Memuat daftar musim...',
                                  style: AppText.caption.copyWith(color: AppColors.textSecondary),
                                ),
                              ],
                            )
                          : Text(
                              'Belum ada musim lain.',
                              style: AppText.caption.copyWith(color: AppColors.textSecondary),
                            ),
                    ),
                  );
                }
                return ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(right: 16),
                  itemCount: cards.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 9),
                  itemBuilder: (_, index) => cards[index],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
