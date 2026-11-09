import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watch_app/core/metadata/metadata_enrichment.dart';
import 'package:watch_app/core/models/media_detail.dart';
import 'package:watch_app/core/models/provider_info.dart';

class _JikanAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(RequestOptions request, _, __) async {
    final path = request.uri.path;
    final Object body = switch (path) {
      '/v4/anime/100/characters' => {
          'data': [
            {
              'character': {
                'name': 'Yamada Taro',
                'images': {
                  'jpg': {'image_url': 'https://img.test/character.jpg'},
                },
              },
              'role': 'Main',
              'voice_actors': [
                {
                  'person': {
                    'name': 'Japanese Voice Actor',
                    'images': {
                      'jpg': {'image_url': 'https://img.test/voice.jpg'},
                    },
                  },
                  'language': 'Japanese',
                },
              ],
            },
          ],
        },
      '/v4/anime/100/relations' => {
          'data': [
            {
              'relation': 'Prequel',
              'entry': [
                {'mal_id': 90, 'type': 'anime', 'name': 'Season Two'},
              ],
            },
            {
              'relation': 'Sequel',
              'entry': [
                {'mal_id': 110, 'type': 'anime', 'name': 'Season Four'},
              ],
            },
          ],
        },
      '/v4/anime/90/relations' => {
          'data': [
            {
              'relation': 'Prequel',
              'entry': [
                {'mal_id': 80, 'type': 'anime', 'name': 'Season One'},
              ],
            },
          ],
        },
      '/v4/anime/110/relations' => {
          'data': [
            {
              'relation': 'Sequel',
              'entry': [
                {'mal_id': 120, 'type': 'anime', 'name': 'Season Five'},
              ],
            },
          ],
        },
      '/v4/anime/80/relations' || '/v4/anime/120/relations' => {'data': []},
      '/v4/anime/80/full' => _full('Season One', 80),
      '/v4/anime/90/full' => _full('Season Two', 90),
      '/v4/anime/110/full' => _full('Season Four', 110),
      '/v4/anime/120/full' => _full('Season Five', 120),
      '/v4/anime/100/recommendations' => {'data': []},
      _ => {'data': []},
    };
    return ResponseBody.fromString(
      jsonEncode(body),
      path == '/v4/anime/100/recommendations' ? 503 : 200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  Map<String, dynamic> _full(String title, int id) => {
    'data': {
      'type': 'TV',
      'title': title,
      'title_english': title,
      'episodes': 12,
      'popularity': 1000 - id,
      'images': {
        'jpg': {'large_image_url': 'https://img.test/$id.jpg'},
      },
    },
  };

  @override
  void close({bool force = false}) {}
}

void main() {
  test('anime extras keep character names and roles despite a recommendations endpoint failure', () async {
    final dio = Dio()..httpClientAdapter = _JikanAdapter();
    final enrichment = MetadataEnrichment(dio);
    final detail = MediaDetail(
      id: 'current',
      title: 'Season Three',
      url: 'anime://100',
      type: ProviderType.anime,
      sourceId: 'test',
      malId: 100,
    );

    final extras = await enrichment.fetch(detail);
    // A recommendations failure is isolated: valid character records and
    // franchise relations must still survive the same enrichment request.
    expect(extras.cast.map((person) => person.name), ['Yamada Taro']);
    expect(extras.cast.single.role, 'Main');
    expect(extras.cast.single.photo, 'https://img.test/character.jpg');

    final seasons = await enrichment.seasons(detail);
    expect(seasons.map((season) => season.malId), [80, 90, 110, 120]);
    expect(seasons.map((season) => season.number), [1, 2, 4, 5]);
    expect(seasons.first.cover, 'https://img.test/80.jpg');
    expect(seasons.first.episodes, 12);
  });
}
