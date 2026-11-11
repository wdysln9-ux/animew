import 'package:flutter/material.dart';

import '../../core/metadata/synopsis_translator.dart';
import '../../core/models/media_detail.dart';
import '../../core/theme/app_colors.dart';

Future<void> showAnimeTitleSheet(
  BuildContext context,
  MediaDetail detail,
) async {
  final romaji = detail.romajiTitle?.trim().isNotEmpty == true
      ? detail.romajiTitle!.trim()
      : detail.title.trim();
  final english = detail.englishTitle?.trim() ?? '';
  final translationSource = english.isNotEmpty ? english : romaji;
  final translated = SynopsisTranslator.instance
      .translateTextToIndonesian(translationSource);

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => DraggableScrollableSheet(
      initialChildSize: 0.48,
      minChildSize: 0.34,
      maxChildSize: 0.78,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 42,
              height: 5,
              decoration: BoxDecoration(
                color: AppColors.textTertiary.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 18, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Judul anime',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Tutup',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                children: [
                  _TitleValue(label: 'Romaji', value: romaji),
                  const SizedBox(height: 17),
                  _TitleValue(
                    label: 'Inggris',
                    value: english.isNotEmpty ? english : 'Belum tersedia',
                  ),
                  const SizedBox(height: 17),
                  FutureBuilder<String?>(
                    future: translated,
                    builder: (context, snapshot) => _TitleValue(
                      label: 'Indonesia (terjemahan)',
                      value: snapshot.data ??
                          (snapshot.connectionState == ConnectionState.waiting
                              ? 'Menerjemahkan…'
                              : 'Terjemahan belum tersedia'),
                    ),
                  ),
                  if (detail.synonyms.isNotEmpty) ...[
                    const SizedBox(height: 17),
                    Text(
                      'Sinonim',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: detail.synonyms.map((value) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.surface2,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
                      )).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _TitleValue extends StatelessWidget {
  const _TitleValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 5),
      SelectableText(
        value,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.35),
      ),
    ],
  );
}
