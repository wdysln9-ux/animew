import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../core/playback/playback_prefs.dart';

/// Subtitle outline-style presets for the Subtitle-style picker.
/// `(id, label)` — `id` is what's stored in [PlaybackPrefs.subtitleOutlineType].
const List<(String, String)> kSubtitleOutlineTypes = [
  ('none', 'None'),
  ('soft', 'Soft shadow'),
  ('outline', 'Outline'),
  ('bold', 'Bold outline'),
  ('shadow', 'Drop shadow'),
  ('glow', 'Glow'),
];

/// A ring of zero-blur shadows around a circle of [radius] — a cheap way to
/// draw a real text stroke in pure Flutter (no custom painter). Sample density
/// scales with radius so thick outlines stay smooth.
List<Shadow> _stroke(Color color, double radius) {
  if (radius <= 0) return const [];
  final n = math.max(12, (radius * 8).round());
  return [
    for (var i = 0; i < n; i++)
      Shadow(
        color: color,
        blurRadius: 0,
        offset: Offset(
          math.cos(2 * math.pi * i / n) * radius,
          math.sin(2 * math.pi * i / n) * radius,
        ),
      ),
  ];
}

/// The shadow list implementing a named outline preset.
List<Shadow> buildSubtitleShadows(
  String type,
  double width,
  Color outline, {
  Color? shadowColor,
  double shadowDistance = 1,
  double shadowBlur = 2,
  double shadowAngle = 45,
}) {
  final preset = switch (type) {
    'none' => <Shadow>[],
    'outline' => _stroke(outline, width),
    'bold' => _stroke(outline, width * 1.8),
    'shadow' => _stroke(outline, width * 0.35),
    'glow' => <Shadow>[
      ..._stroke(outline.withValues(alpha: 0.55), width * 0.5),
      Shadow(color: outline, blurRadius: 8 + width * 2),
    ],
    _ => <Shadow>[
      Shadow(color: outline.withValues(alpha: 0.8), blurRadius: 4 + width),
    ],
  };
  final shade = shadowColor ?? const Color(0xB3000000);
  if (shade.alpha == 0 || (shadowDistance <= 0 && shadowBlur <= 0)) {
    return preset;
  }
  final radians = shadowAngle * math.pi / 180;
  return [
    ...preset,
    Shadow(
      color: shade,
      offset: Offset(
        math.cos(radians) * shadowDistance,
        math.sin(radians) * shadowDistance,
      ),
      blurRadius: shadowBlur,
    ),
  ];
}

/// The same presets, expressed as libass numbers: border thickness, blur and
/// shadow offset (all in libass units, sent as mpv's `sub-border-size`,
/// `sub-blur` and `sub-shadow-offset`).
///
/// libass has no "glow" of its own — a glow IS a coloured border with the blur
/// turned up. Kept beside [buildSubtitleShadows] on purpose: these two are the
/// same six presets drawn by two different renderers, and they drifted once
/// already. mpv used to be sent one hardcoded border size, so every preset
/// looked identical there while the preview promised otherwise.
({double border, double blur, double shadow}) libassOutline(
  String type,
  double width,
) => switch (type) {
  'none' => (border: 0, blur: 0, shadow: 0),
  'outline' => (border: width, blur: 0, shadow: 0),
  'bold' => (border: width * 1.8, blur: 0, shadow: 0),
  'shadow' => (border: width * 0.6, blur: 0, shadow: width),
  'glow' => (border: width * 0.8, blur: 6 + width * 2, shadow: 0),
  // 'soft' and anything unknown: the legacy soft halo.
  _ => (border: width * 0.5, blur: 3 + width, shadow: 0),
};

/// Parse a `#RRGGBB`/`#RRGGBBAA` hex into a [Color], scaling alpha by [opacity].
Color parseSubtitleHex(String hex, {double opacity = 1.0}) {
  var h = hex.replaceFirst('#', '').toUpperCase();
  if (h.length == 6) h = '${h}FF';
  if (h.length != 8) return const Color(0xFFFFFFFF);
  final r = int.tryParse(h.substring(0, 2), radix: 16) ?? 255;
  final g = int.tryParse(h.substring(2, 4), radix: 16) ?? 255;
  final b = int.tryParse(h.substring(4, 6), radix: 16) ?? 255;
  final a = int.tryParse(h.substring(6, 8), radix: 16) ?? 255;
  final alpha = (a * opacity.clamp(0.0, 1.0)).round().clamp(0, 255);
  return Color.fromARGB(alpha, r, g, b);
}

/// The single place the subtitle [TextStyle] is built — used by BOTH the
/// media_kit overlay ([SubtitleViewConfiguration]) and the live preview, so
/// what you see in the preview is exactly what renders on the video.
TextStyle buildSubtitleTextStyle(PlaybackPrefs p, {required double fontSize}) {
  return TextStyle(
    height: 1.4,
    fontSize: fontSize,
    fontFamily: p.subtitleFont.isEmpty ? null : p.subtitleFont,
    fontWeight: FontWeight.values[(p.subtitleFontWeight ~/ 100).clamp(1, 9).toInt() - 1],
    fontStyle: p.subtitleItalic ? FontStyle.italic : FontStyle.normal,
    color: parseSubtitleHex(p.subtitleColorHex, opacity: p.subtitleTextOpacity),
    backgroundColor:
        Color.fromRGBO(0, 0, 0, p.subtitleBgOpacity.clamp(0.0, 1.0)),
    shadows: buildSubtitleShadows(
      p.subtitleOutlineType,
      p.subtitleOutlineWidth,
      parseSubtitleHex(p.subtitleOutlineColorHex),
      shadowColor: parseSubtitleHex(p.subtitleShadowColorHex),
      shadowDistance: p.subtitleShadowDistance,
      shadowBlur: p.subtitleShadowBlur,
      shadowAngle: p.subtitleShadowAngle,
    ),
  );
}
