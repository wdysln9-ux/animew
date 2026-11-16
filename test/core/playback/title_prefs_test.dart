import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:watch_app/core/playback/title_prefs.dart';

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('title_prefs');
    Hive.init(dir.path);
    await TitlePrefsStore.init();
  });

  tearDown(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  test('subtitle choice is stored independently per title', () async {
    final prefs = TitlePrefsStore();

    expect(prefs.subtitleTrack('source-a', 'show-a'), isNull);
    await prefs.setSubtitleTrack('source-a', 'show-a', 'en|english');
    await prefs.setSubtitleTrack('source-a', 'show-b', 'ja|japanese');
    await prefs.setSubtitleTrack('source-a', 'show-c', 'off');

    expect(prefs.subtitleTrack('source-a', 'show-a'), 'en|english');
    expect(prefs.subtitleTrack('source-a', 'show-b'), 'ja|japanese');
    expect(prefs.subtitleTrack('source-a', 'show-c'), 'off');
    expect(prefs.subtitleTrack('source-b', 'show-a'), isNull);
  });
}
