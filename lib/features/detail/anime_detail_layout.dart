part of 'detail_screen.dart';

/// Fresh anime-detail scroll composition. The hero is a normal collapsing
/// sliver, not a FlexibleSpaceBar: its artwork is clipped in place and never
/// translated, blurred, or parallax-scrolled.
class AnimeDetailHeroSliver extends StatelessWidget {
  const AnimeDetailHeroSliver({
    required this.coverUrl,
    required this.posterUrl,
    required this.posterColor,
    required this.coverHeaders,
    required this.sourceLabel,
    required this.animeId,
    required this.adaptiveTint,
    this.onAniListTap,
    this.onPosterTap,
    this.maxHeight = 376,
  });

  final String coverUrl;
  final String? posterUrl;
  /// AniList coverImage.color for the portrait poster's loading surface.
  final String? posterColor;
  final Map<String, String>? coverHeaders;
  final String sourceLabel;
  final String animeId;
  final ValueListenable<Color?> adaptiveTint;
  final VoidCallback? onAniListTap;
  final VoidCallback? onPosterTap;
  final double maxHeight;

  @override
  Widget build(BuildContext context) => SliverPersistentHeader(
    pinned: false,
    delegate: _AnimeDetailHeroDelegate(
      coverUrl: coverUrl,
      posterUrl: posterUrl,
      posterColor: posterColor,
      coverHeaders: coverHeaders,
      sourceLabel: sourceLabel,
      animeId: animeId,
      adaptiveTint: adaptiveTint,
      onAniListTap: onAniListTap,
      onPosterTap: onPosterTap,
      maxHeight: maxHeight,
    ),
  );
}

class _AnimeDetailHeroDelegate extends SliverPersistentHeaderDelegate {
  const _AnimeDetailHeroDelegate({
    required this.coverUrl,
    required this.posterUrl,
    required this.posterColor,
    required this.coverHeaders,
    required this.sourceLabel,
    required this.animeId,
    required this.adaptiveTint,
    required this.maxHeight,
    this.onAniListTap,
    this.onPosterTap,
  });

  final String coverUrl;
  final String? posterUrl;
  final String? posterColor;
  final Map<String, String>? coverHeaders;
  final String sourceLabel;
  final String animeId;
  final ValueListenable<Color?> adaptiveTint;
  final double maxHeight;
  final VoidCallback? onAniListTap;
  final VoidCallback? onPosterTap;

  Widget _image(
    String url, {
    int width = 900,
    Alignment alignment = Alignment.center,
    BoxFit fit = BoxFit.cover,
    Color? placeholderColor,
  }) {
    final loadingColor = placeholderColor ?? AppColors.surface2;
    if (url.isEmpty) return ColoredBox(color: loadingColor);
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
        errorBuilder: (_, _, _) => ColoredBox(color: loadingColor),
      );
    }
    return CachedNetworkImage(
      imageUrl: url,
      httpHeaders: coverHeaders,
      fit: fit,
      alignment: alignment,
      memCacheWidth: width,
      placeholder: (_, _) => ColoredBox(color: loadingColor),
      errorWidget: (_, _, _) => ColoredBox(color: loadingColor),
    );
  }

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final poster = posterUrl?.isNotEmpty == true ? posterUrl! : coverUrl;
    final rawPosterColor = posterColor?.trim();
    final normalizedPosterColor = rawPosterColor == null || rawPosterColor.isEmpty
        ? null
        : (rawPosterColor.startsWith('#') ? rawPosterColor.substring(1) : rawPosterColor);
    final posterColorValue = normalizedPosterColor == null
        ? null
        : int.tryParse(
            normalizedPosterColor.length == 6
                ? 'FF$normalizedPosterColor'
                : normalizedPosterColor,
            radix: 16,
          );
    final posterLoadingColor = posterColorValue == null
        ? AppColors.surface2
        : Color(posterColorValue);
    final topInset = MediaQuery.paddingOf(context).top;
    final posterWidth = ((MediaQuery.sizeOf(context).width * 0.45)
        .clamp(170.0, 194.0)
        .toDouble()) + 1;
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
                bottom: 0,
                child: _image(coverUrl, alignment: Alignment.topCenter),
              ),
              // Keep the artwork consistently dark. Only the lower edge
              // transitions into the page background, so the fade does not
              // wash out the top half of the hero.
              Positioned.fill(
                child: ColoredBox(color: Color.fromRGBO(0, 0, 0, 0.30)),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: ValueListenableBuilder<Color?>(
                    valueListenable: adaptiveTint,
                    builder: (context, tint, _) => DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.16),
                            Colors.black.withValues(alpha: 0.34),
                            tint ?? AppColors.bg,
                          ],
                          stops: const [0.0, 0.58, 1.0],
                        ),
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
                bottom: 15.5,
                child: Center(
                  child: GestureDetector(
                    onTap: onPosterTap,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: SizedBox(
                        width: posterWidth,
                        height: posterHeight,
                        child: _image(
                          poster,
                          width: 528,
                          fit: BoxFit.cover,
                          placeholderColor: posterLoadingColor,
                        ),
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
  double get minExtent => maxHeight;

  @override
  bool shouldRebuild(covariant _AnimeDetailHeroDelegate oldDelegate) =>
      oldDelegate.coverUrl != coverUrl ||
      oldDelegate.posterUrl != posterUrl ||
      oldDelegate.posterColor != posterColor ||
      oldDelegate.coverHeaders != coverHeaders ||
      oldDelegate.sourceLabel != sourceLabel ||
      oldDelegate.animeId != animeId ||
      oldDelegate.onPosterTap != onPosterTap ||
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
                  style: AppText.animeTitle.copyWith(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
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
    required this.adaptiveTint,
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
  final ValueListenable<Color?> adaptiveTint;

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
        // The information area uses the exact page background color. The
        // hero artwork fades into this surface at its lower edge.
        Positioned.fill(
          child: ValueListenableBuilder<Color?>(
            valueListenable: adaptiveTint,
            builder: (context, tint, _) => DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  // Keep the adaptive poster tint through the bottom edge.
                  // Fading to AppColors.bg here caused the lower half of the
                  // detail header to lose its poster-derived colour.
                  colors: [tint ?? AppColors.bg, tint ?? AppColors.bg],
                ),
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
              style: AppText.animeTitle.copyWith(fontSize: 22, height: 1.14)),
          if (romaji.isNotEmpty && english.isNotEmpty) const SizedBox(height: 4),
          if (english.isNotEmpty) ...[
            Text(english, textAlign: TextAlign.center, maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppText.body.copyWith(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 4),
          ],
          AutoTranslatedText(text: translatedSource, textAlign: TextAlign.center, maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppText.body.copyWith(fontSize: 13, color: AppColors.textSecondary)),
          if (metaLine.isNotEmpty) ...[
            const SizedBox(height: 4),
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
                  if (metaLine.split('  ·  ')[i].startsWith('★'))
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 2),
                        child: Icon(
                          Icons.star_rounded,
                          size: 15,
                          color: const Color(0xFF24C66A),
                        ),
                      ),
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
                        : metaLine.split('  ·  ')[i].startsWith('★')
                            ? metaLine.split('  ·  ')[i].substring(1).trimLeft()
                            : metaLine.split('  ·  ')[i],
                    style: AppText.body.copyWith(
                      fontSize: 13,
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
                      fontSize: 13,
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
                style: AppText.body.copyWith(fontSize: 13, color: AppColors.accent))),
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
    final statusColor = isCompleted ? const Color(0xFF4E8DFF) : (isAiring ? const Color(0xFF24A765) : const Color(0xFFB86A2A));
    final background = isFormat ? AppColors.accent : statusColor.withValues(alpha: 0.20);
    // Status text uses the same solid color as its outline, matching
    // the studio chip's text/border treatment.
    final foreground = isFormat ? Colors.white : statusColor;
    return Container(
      constraints: const BoxConstraints(minHeight: 24),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        border: isFormat ? null : Border.all(color: statusColor, width: 1),
        borderRadius: BorderRadius.circular(isFormat ? 7 : 20),
      ),
      child: Text(
        label,
        style: AppText.caption.copyWith(
          fontSize: 12,
          height: 1.0,
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
    this.progress = 0,
    required this.adaptiveTint,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool loading;
  final bool primary;
  final bool active;
  final double progress;
  final ValueListenable<Color?> adaptiveTint;

  @override
  Widget build(BuildContext context) {
    final foreground = active ? Colors.white : AppColors.textPrimary;
    return ValueListenableBuilder<Color?>(
      valueListenable: adaptiveTint,
      builder: (context, tint, _) {
        final base = primary ? AppColors.bg : AppColors.surface2;
        final background = active
            ? Color.lerp(AppColors.accent, tint ?? AppColors.accent, 0.35)!
            : Color.lerp(base, tint ?? base, primary ? 0.62 : 0.42)!;
        return Opacity(
      opacity: onPressed != null || loading ? 1 : 0.42,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(23),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(23),
          child: CustomPaint(
            foregroundPainter: _ActionProgressOutlinePainter(
              progress: progress.clamp(0.0, 1.0),
              color: AppColors.accent,
            ),
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
      ),
    );
      },
    );
  }
}

class _ActionProgressOutlinePainter extends CustomPainter {
  const _ActionProgressOutlinePainter({
    required this.progress,
    required this.color,
  });

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final rect = Offset.zero & size;
    const inset = 1.25;
    const radius = 22.0;
    final left = inset;
    final top = inset;
    final right = size.width - inset;
    final bottom = size.height - inset;
    final r = radius;
    final path = Path()
      ..moveTo(size.width / 2, top)
      ..lineTo(right - r, top)
      ..arcToPoint(Offset(right, top + r), radius: Radius.circular(r))
      ..lineTo(right, bottom - r)
      ..arcToPoint(Offset(right - r, bottom), radius: Radius.circular(r))
      ..lineTo(left + r, bottom)
      ..arcToPoint(Offset(left, bottom - r), radius: Radius.circular(r))
      ..lineTo(left, top + r)
      ..arcToPoint(Offset(left + r, top), radius: Radius.circular(r))
      ..lineTo(size.width / 2, top);
    final metric = path.computeMetrics().first;
    final progressPath = metric.extractPath(0, metric.length * progress);
    canvas.drawPath(
      progressPath,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _ActionProgressOutlinePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

class AnimeDetailSynopsisSection extends StatefulWidget {
  const AnimeDetailSynopsisSection({required this.text, this.onMore});
  final String text;
  final VoidCallback? onMore;

  @override
  State<AnimeDetailSynopsisSection> createState() => _AnimeDetailSynopsisSectionState();
}

class _AnimeDetailSynopsisSectionState extends State<AnimeDetailSynopsisSection> {
  late bool _expanded = sl<PlaybackPrefs>().detailSectionExpanded('synopsis');
  String? _translated;

  @override
  void initState() {
    super.initState();
    _translate();
  }

  void _toggleExpanded() {
    if (widget.onMore != null) {
      widget.onMore!();
      return;
    }
    setState(() => _expanded = !_expanded);
    unawaited(sl<PlaybackPrefs>().setDetailSectionExpanded('synopsis', _expanded));
  }

  @override
  void didUpdateWidget(covariant AnimeDetailSynopsisSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _translated = null;
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
          Text('Sinopsis', style: AppText.headline.copyWith(fontSize: 16)),
          const SizedBox(height: 9),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _toggleExpanded,
            child: AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOutCubic,
              alignment: Alignment.topCenter,
              child: _expanded
                  ? AniListMarkdown(data: data, textStyle: AppText.body.copyWith(
                      fontSize: 14.1, height: 1.45, color: AppColors.textSecondary))
                  : Text(data, maxLines: 3, overflow: TextOverflow.ellipsis,
                      style: AppText.body.copyWith(fontSize: 14.1, height: 1.45, color: AppColors.textSecondary)),
            ),
          ),
          const SizedBox(height: 6),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _toggleExpanded,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                _expanded ? 'Lebih sedikit' : 'Selengkapnya',
                style: AppText.caption.copyWith(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w700,
                ),
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
    this.onNakamaTap,
    this.nakamaMediaId,
  });
  final List<String> genres;
  final List<String> studios;
  final List<MediaTag> tags;
  final ValueChanged<String> onGenreTap;
  final ValueChanged<String> onStudioTap;
  final VoidCallback onTagsTap;
  final VoidCallback? onNakamaTap;
  final int? nakamaMediaId;

  @override
  State<_DetailCredits> createState() => _DetailCreditsState();
}

class _DetailCreditsState extends State<_DetailCredits> {
  late bool _expanded = sl<PlaybackPrefs>().detailSectionExpanded('credits');
  String? _nakamaCount;

  @override
  void initState() {
    super.initState();
    _loadNakamaCount();
  }

  @override
  void didUpdateWidget(covariant _DetailCredits oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.nakamaMediaId != widget.nakamaMediaId) {
      _nakamaCount = null;
      _loadNakamaCount();
    }
  }

  Future<void> _loadNakamaCount() async {
    final mediaId = widget.nakamaMediaId;
    if (mediaId == null) return;
    try {
      final api = sl<AniListService>().api;
      final firstPage = await api.nakamaWatching(mediaId, page: 1);
      // PageInfo.total can be a capped estimate. Only show a count when the
      // first page is also the final page, so the number is exact without
      // eagerly requesting every followed user's list just to paint a chip.
      if (mounted && widget.nakamaMediaId == mediaId) {
        setState(() => _nakamaCount = firstPage.hasNextPage
            ? null
            : firstPage.entries.length.toString());
      }
    } catch (_) {
      // Keep the chip usable even if the count endpoint is temporarily unavailable.
    }
  }

  Widget _nakamaChip() {
    final color = AppColors.accent;
    return InkWell(
      onTap: widget.onNakamaTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.20),
          border: Border.all(color: color, width: 1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_rounded, size: 14, color: color),
            const SizedBox(width: 5),
            Text(
              _nakamaCount == null
                  ? 'nakama menonton'
                  : '$_nakamaCount nakama menonton',
              style: AppText.caption.copyWith(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, Color color, {VoidCallback? onTap, IconData? icon, double iconGap = 5}) {
    final child = Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.20),
        border: Border.all(color: color, width: 1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            SizedBox(width: iconGap),
          ],
          Flexible(
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
          ),
        ],
      ),
    );
    if (onTap == null) return child;
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(20), child: child);
  }

  @override
  Widget build(BuildContext context) {
    const studioBlue = Color(0xFF4E8DFF);
    final genreColor = AppColors.accent;
    final hasCredits = widget.studios.isNotEmpty || widget.tags.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
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
                    borderRadius: BorderRadius.circular(7),
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
          if (widget.onNakamaTap != null && (!_expanded || !hasCredits)) ...[
            const SizedBox(height: 8),
            _nakamaChip(),
          ],
          if (hasCredits && !_expanded) ...[
            const SizedBox(height: 7),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() {
                _expanded = true;
                unawaited(sl<PlaybackPrefs>().setDetailSectionExpanded('credits', true));
              }),
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
                _chip(studio, studioBlue, icon: Icons.business_rounded, onTap: () => widget.onStudioTap(studio)),
              if (widget.tags.isNotEmpty)
                _chip('Tags (${widget.tags.length})', const Color(0xFFEB4899), icon: Icons.tag_rounded, iconGap: 2, onTap: widget.onTagsTap),
            ]),
          ],
          if (_expanded && widget.onNakamaTap != null) ...[
            const SizedBox(height: 8),
            _nakamaChip(),
          ],
          if (_expanded && hasCredits)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() {
                _expanded = false;
                unawaited(sl<PlaybackPrefs>().setDetailSectionExpanded('credits', false));
              }),
              child: Padding(
                padding: const EdgeInsets.only(top: 6, bottom: 1),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.keyboard_arrow_up_rounded, size: 18, color: AppColors.textSecondary),
                  const SizedBox(width: 2),
                  Text('Sembunyikan', style: AppText.caption.copyWith(
                    fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w600,
                  )),
                ]),
              ),
            ),
        ],
      )),
    );
  }
}

class AnimeDetailCharacterRail extends StatefulWidget {
  const AnimeDetailCharacterRail({required this.cast, this.loading = false, this.totalCount, this.hasMore = false, this.loadingMore = false, this.onLoadMore, this.onOpenPerson, this.onRetry});
  final List<CastMember> cast;
  final bool loading;
  final int? totalCount;
  final bool hasMore;
  final bool loadingMore;
  final VoidCallback? onLoadMore;
  final ValueChanged<PersonRef>? onOpenPerson;
  final VoidCallback? onRetry;
  @override
  State<AnimeDetailCharacterRail> createState() => _AnimeDetailCharacterRailState();
}
class _AnimeDetailCharacterRailState extends State<AnimeDetailCharacterRail> {
  late bool _expanded = sl<PlaybackPrefs>().detailSectionExpanded('characters', defaultValue: true);

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scrollController.hasClients || widget.loadingMore || !widget.hasMore) return;
    if (_scrollController.position.extentAfter < 180) widget.onLoadMore?.call();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cast = widget.cast;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 11, 0, 0),
      child: AnimatedSize(duration: const Duration(milliseconds: 240), curve: Curves.easeInOutCubic, alignment: Alignment.topCenter, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() {
            _expanded = !_expanded;
            unawaited(sl<PlaybackPrefs>().setDetailSectionExpanded('characters', _expanded));
          }),
          child: Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(children: [
              Text('Karakter', style: AppText.headline.copyWith(fontSize: 16)),
              const SizedBox(width: 7),
              if (widget.totalCount != null)
                Text(
                  widget.totalCount.toString(),
                  style: AppText.caption.copyWith(fontSize: 12, color: AppColors.textSecondary),
                ),
              const Spacer(),
              Icon(_expanded ? Icons.keyboard_arrow_down_rounded : Icons.chevron_right_rounded, color: AppColors.textSecondary, size: 21),
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
          const SizedBox(height: 8),
          SizedBox(height: 124, child: ListView.separated(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            padding: const EdgeInsets.only(right: 16),
            itemCount: cast.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final member = cast[index];
              return SizedBox(width: 86, child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onOpenPerson == null ? null : () async {
                  final person = member.person ?? await sl<PeopleService>().findCharacter(member.name);
                  if (!mounted || person == null) return;
                  widget.onOpenPerson!(person);
                },
                child: Column(children: [
                  ClipOval(child: SizedBox(width: 69.3, height: 69.3,
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
    this.onLoadMoreRecommendations,
    this.recommendationsLoading = false,
    this.recommendationsHasNextPage = false,
  });
  final List<SeasonEntry> seasons;
  final List<MediaRelation> relations;
  final bool loading;
  final ValueChanged<SeasonEntry> onOpenSeason;
  final ValueChanged<MediaRelation> onOpenRelation;
  final VoidCallback? onLoadMoreRecommendations;
  final bool recommendationsLoading;
  final bool recommendationsHasNextPage;

  @override
  State<AnimeDetailSeasonRail> createState() => _AnimeDetailSeasonRailState();
}

class _AnimeDetailSeasonRailState extends State<AnimeDetailSeasonRail> {
  int _selected = 0;
  final ScrollController _recommendationsController = ScrollController();

  @override
  void initState() {
    super.initState();
    _recommendationsController.addListener(_onRecommendationsScroll);
  }

  void _onRecommendationsScroll() {
    if (!_recommendationsController.hasClients || widget.recommendationsLoading || !widget.recommendationsHasNextPage) return;
    if (_recommendationsController.position.extentAfter < 220) {
      widget.onLoadMoreRecommendations?.call();
    }
  }

  @override
  void dispose() {
    _recommendationsController.dispose();
    super.dispose();
  }

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
      padding: const EdgeInsets.fromLTRB(16, 4, 0, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 30,
            child: DefaultTabController(
              length: tabs.length,
              initialIndex: _selected,
              child: TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                padding: const EdgeInsets.only(right: 16),
                labelPadding: const EdgeInsets.only(left: 0, right: 14),
                dividerColor: Colors.transparent,
                indicatorSize: TabBarIndicatorSize.label,
                splashFactory: NoSplash.splashFactory,
                splashBorderRadius: BorderRadius.zero,
                overlayColor: const WidgetStatePropertyAll(Colors.transparent),
                indicator: UnderlineTabIndicator(
                  borderSide: BorderSide(color: AppColors.accent, width: 2),
                  borderRadius: BorderRadius.circular(2),
                  insets: const EdgeInsets.only(bottom: 1),
                ),
                labelStyle: AppText.headline.copyWith(
                  fontSize: 15, height: 1.2, fontWeight: FontWeight.w700,
                ),
                unselectedLabelStyle: AppText.headline.copyWith(
                  fontSize: 15, height: 1.2, fontWeight: FontWeight.w500,
                ),
                labelColor: AppColors.textPrimary,
                unselectedLabelColor: AppColors.textSecondary,
                onTap: (index) => setState(() => _selected = index),
                tabs: [for (final tab in tabs) Tab(height: 28, text: tab)],
              ),
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
                        seriesBadge: 'Seri ${season.number}',
                        isCurrentSeason: season.isCurrent,
                        scoreBadge: season.score,
                        statusBadge: season.status,
                        viewsBadge: season.popularity,
                        metaFormat: 'TV',
                        metaEpisodes: season.episodes,
                        // The currently open season is highlighted and cannot be reopened.
                        onTap: season.isCurrent
                            ? null
                            : () => widget.onOpenSeason(season),
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
                        imageColor: relation.coverColor,
                        cellWidth: width,
                        seriesBadge: _isRecommended(relation) ? null : relation.relation,
                        scoreBadge: relation.score,
                        viewsBadge: relation.popularity,
                        recommendationRatingBadge: _isRecommended(relation)
                            ? relation.recommendationRating
                            : null,
                        statusBadge: relation.status,
                        metaFormat: relation.format,
                        metaEpisodes: relation.episodes,
                        metaYear: relation.year?.toString(),
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
                if (selectedTab == 'Rekomendasi' && widget.recommendationsLoading) {
                  cards.add(SizedBox(width: 54, child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 1.8)))));
                }
                return ListView.separated(
                  controller: selectedTab == 'Rekomendasi' ? _recommendationsController : null,
                  scrollDirection: Axis.horizontal,
                  clipBehavior: Clip.none,
                  padding: const EdgeInsets.only(right: 16),
                  itemCount: cards.length,
                  // Match the 12 px spacing used by ContentRow on Home.
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
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
