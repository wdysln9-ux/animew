import 'package:flutter/material.dart';

import '../../core/models/media_detail.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';

/// A dedicated view of every tag AniList supplies for one anime.
class AnimeTagsPage extends StatelessWidget {
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
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.bg,
    appBar: AppBar(
      backgroundColor: AppColors.bg,
      elevation: 0,
      title: Text('Tags', style: AppText.title),
    ),
    body: tags.isEmpty
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
                        '${tags.length} tag dari AniList',
                        style: AppText.caption.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                sliver: SliverList.separated(
                  itemCount: tags.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final tag = tags[index];
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.hairline),
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
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (tag.isSpoiler) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    'Mengandung spoiler',
                                    style: AppText.caption.copyWith(color: AppColors.accent),
                                  ),
                                ],
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
