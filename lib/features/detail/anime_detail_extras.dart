// AniList trailer presentation. Trailer data is read from the main detail query.
part of 'detail_screen.dart';

class _AniListTrailerSection extends StatelessWidget {
  const _AniListTrailerSection({
    required this.url,
    this.thumbnail,
  });

  final String url;
  final String? thumbnail;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Trailer', style: AppText.headline.copyWith(fontSize: 17)),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => launchUrl(
              Uri.parse(url),
              mode: LaunchMode.externalApplication,
            ),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (thumbnail != null && thumbnail!.isNotEmpty)
                      CachedNetworkImage(
                        imageUrl: thumbnail!,
                        fit: BoxFit.cover,
                        errorWidget: (_, _, _) =>
                            ColoredBox(color: AppColors.surface2),
                      )
                    else
                      ColoredBox(color: AppColors.surface2),
                    Center(
                      child: Container(
                        width: 52,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
