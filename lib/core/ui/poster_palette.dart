import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';

import '../theme/app_colors.dart';
import 'native_cover_provider.dart';

/// Dominant colours already extracted, keyed by cover URL, so swiping back
/// through a carousel never re-decodes the same artwork.
final Map<String, Color> _dominantCache = {};

/// The dominant colour of [provider]'s artwork, cached under [cacheKey], or
/// null when it can't be read. Decode happens on a 180px copy — the full-res
/// decode this replaced was the cause of 30s of carousel lag.
Future<Color?> extractDominantColorFrom(
  ImageProvider provider, {
  required String cacheKey,
}) async {
  final cached = _dominantCache[cacheKey];
  if (cached != null) return cached;
  try {
    final pal = await PaletteGenerator.fromImageProvider(
      provider,
      size: const Size(180, 270),
      maximumColorCount: 8,
    );
    final c =
        pal.vibrantColor?.color ??
        pal.dominantColor?.color ??
        pal.darkVibrantColor?.color ??
        pal.mutedColor?.color;
    if (c != null) _dominantCache[cacheKey] = c;
    return c;
  } catch (_) {
    return null;
  }
}

/// The dominant colour of [url]'s artwork (covers routed through the native
/// provider so Cloudflare-walled sources work too), or null when unread.
Future<Color?> extractDominantColor(String url, Map<String, String>? headers) =>
    extractDominantColorFrom(
      ResizeImage(nativeCoverProvider(url, headers), width: 180),
      cacheKey: url,
    );

/// Parses AniList's `coverImage.color` value (#RRGGBB) into an opaque
/// Flutter colour. Null means the metadata provider did not supply a usable
/// colour, so callers can keep the normal theme surface.
Color? parseAniListCoverColor(String? raw) {
  final value = raw?.trim();
  if (value == null || value.isEmpty) return null;
  final hex = value.startsWith('#') ? value.substring(1) : value;
  final normalized = hex.length == 6 ? 'FF$hex' : hex;
  final parsed = int.tryParse(normalized, radix: 16);
  return parsed == null ? null : Color(parsed);
}

/// Uses the artwork's original dominant / AniList coverImage.color without
/// darkening or desaturating it.
Color tintFromDominant(Color dominant) => dominant;

/// Full-bleed animated colour wash for a screen's background. Sits as the
/// bottom child of the screen's body Stack; [notifier] carries the current
/// poster tint (null → the normal theme background) and colour changes morph
/// over ~800ms.
class PosterTintLayer extends StatelessWidget {
  const PosterTintLayer({super.key, required this.notifier});

  final ValueNotifier<Color?> notifier;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: RepaintBoundary(
          child: ValueListenableBuilder<Color?>(
            valueListenable: notifier,
            builder: (context, tint, _) => AnimatedContainer(
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOut,
              color: tint ?? AppColors.bg,
            ),
          ),
        ),
      ),
    );
  }
}
