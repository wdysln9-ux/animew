// AniList trailer presentation. Trailer data is read from the main detail query.
part of 'detail_screen.dart';

class _AniListTrailerSection extends StatefulWidget {
  const _AniListTrailerSection({
    required this.url,
    this.thumbnail,
  });

  final String url;
  final String? thumbnail;

  @override
  State<_AniListTrailerSection> createState() => _AniListTrailerSectionState();
}

class _AniListTrailerSectionState extends State<_AniListTrailerSection> {
  bool _expanded = false;

  String? get _videoId {
    final uri = Uri.tryParse(widget.url);
    if (uri == null) return null;
    if (uri.host.contains('youtu.be')) return uri.pathSegments.isEmpty ? null : uri.pathSegments.last;
    if (uri.host.contains('youtube.com')) return uri.queryParameters['v'] ?? (uri.pathSegments.length > 1 ? uri.pathSegments.last : null);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _expanded = !_expanded),
            child: Row(
              children: [
                Text('Trailer & PV', style: AppText.headline.copyWith(fontSize: 16)),
                const SizedBox(width: 7),
                Text('1', style: AppText.caption.copyWith(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                )),
                const Spacer(),
                Icon(
                  _expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                  color: AppColors.textSecondary,
                  size: 21,
                ),
              ],
            ),
          ),
          if (_expanded) ...[
            const SizedBox(height: 9),
            Align(
              alignment: Alignment.centerLeft,
              child: GestureDetector(
              onTap: _videoId == null ? null : () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => TrailerScreen(videoId: _videoId!)),
              ),
              child: SizedBox(
                width: 220,
                child: AspectRatio(
                aspectRatio: 16 / 9,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (widget.thumbnail != null && widget.thumbnail!.isNotEmpty)
                        CachedNetworkImage(
                          imageUrl: widget.thumbnail!,
                          fit: BoxFit.cover,
                          errorWidget: (_, _, _) =>
                              ColoredBox(color: AppColors.surface2),
                        )
                      else
                        ColoredBox(color: AppColors.surface2),
                      Center(
                        child: Container(
                          width: 48,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: const Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              ),
            ),
            ),
          ],
        ],
      ),
    );
  }
}
