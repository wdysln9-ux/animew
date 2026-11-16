import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Copies a resolved playback URL and gives the user a brief confirmation.
Future<void> copyPlaybackLink(BuildContext context, String url) async {
  final value = url.trim();
  if (value.isEmpty) return;
  await Clipboard.setData(ClipboardData(text: value));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      const SnackBar(content: Text('Link berhasil disalin')),
    );
}
