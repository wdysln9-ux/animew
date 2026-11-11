import 'package:flutter/material.dart';

import '../../core/models/media_detail.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';

/// A dedicated view of every tag AniList supplies for one anime.
class AnimeTagsPage extends StatefulWidget {
  const AnimeTagsPage({
    super.key,
    required this.title,
    required this.tags,
  });

  final String title;
  final List<MediaTag> tags;

  static Route<void> route({
    required String title,
    required List<MediaTag> tags,
  }) => MaterialPageRoute<void>(
    builder: (_) => AnimeTagsPage(title: title, tags: tags),
  );

  @override
  State<AnimeTagsPage> createState() => _AnimeTagsPageState();
}

class _AnimeTagsPageState extends State<AnimeTagsPage> {
  bool _showSpoilers = false;

  @override
  Widget build(BuildContext context) {
    final visibleTags = widget.tags
        .where((tag) => _showSpoilers || !tag.isSpoiler)
        .toList(growable: false);
    final spoilerCount = widget.tags.where((tag) => tag.isSpoiler).length;
    return Scaffold(
    backgroundColor: AppColors.bg,
    appBar: AppBar(
      backgroundColor: AppColors.bg,
      elevation: 0,
      title: Text('Tags', style: AppText.title),
    ),
    body: widget.tags.isEmpty
        ? Center(
            child: Text(
              'Belum ada tag untuk anime ini.',
              style: AppText.caption.copyWith(color: AppColors.textSecondary),
            ),
          )
        : CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppText.headline),
                      const SizedBox(height: 5),
                      Text(
                        '${widget.tags.length} tag dari AniList',
                        style: AppText.caption.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
              if (spoilerCount > 0)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Material(
                        color: const Color(0x26E53945),
                        borderRadius: BorderRadius.circular(9),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(9),
                          onTap: () => setState(() => _showSpoilers = !_showSpoilers),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _showSpoilers ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                  size: 16,
                                  color: const Color(0xFFE53945),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _showSpoilers
                                      ? 'Sembunyikan #tag spoiler'
                                      : 'Tampilkan #tag spoiler',
                                  style: AppText.caption.copyWith(
                                    color: const Color(0xFFE53945),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                sliver: SliverList.separated(
                  itemCount: visibleTags.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final tag = visibleTags[index];
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: tag.isSpoiler
                            ? const Color(0x14E53945)
                            : AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: tag.isSpoiler
                              ? const Color(0x99E53945)
                              : AppColors.hairline,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tag.name,
                                  style: AppText.body.copyWith(
                                    color: tag.isSpoiler
                                        ? const Color(0xFFE53945)
                                        : AppColors.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (tag.rank != null)
                            Text(
                              '${tag.rank}%',
                              style: AppText.caption.copyWith(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                        ],
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
