import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/anilist/anilist_graphql.dart';
import '../../core/anilist/anilist_service.dart';
import '../../core/di/injector.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/playback/playback_prefs.dart';
import '../../core/ui/poster_card.dart';
import '../../core/ui/states.dart';
import '../detail/open_related.dart';

/// Studio profile and the anime credited to it, loaded from AniList.
class StudioPage extends StatefulWidget {
  const StudioPage({super.key, required this.studioName});

  final String studioName;

  static Route<void> route(String studioName) => MaterialPageRoute<void>(
    builder: (_) => StudioPage(studioName: studioName),
  );

  @override
  State<StudioPage> createState() => _StudioPageState();
}

class _StudioPageState extends State<StudioPage> {
  late Future<Map<String, dynamic>?> _future;
  String? _loadError;
  String _sort = 'START_DATE_DESC';
  bool _onlyInList = false;
  Set<int> _myAnimeIds = {}; 

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>?> _load() async {
    const query = r'''
      query ($search: String, $sort: [MediaSort], $page: Int!) {
        Studio(search: $search) {
          id
          name
          isAnimationStudio
          siteUrl
          favourites
          media(sort: $sort, page: $page, perPage: 50) {
            pageInfo { hasNextPage }
            edges {
              isMainStudio
              node {
              id
              idMal
              title { romaji english }
              coverImage { large }
              averageScore
              popularity
              bannerImage
              episodes
              seasonYear
              format
              studios { edges { isMainStudio node { id } } }
              }
            }
          }
        }
      }
    ''';
    try {
      final dio = sl<Dio>();
      final allAnime = <Map<String, dynamic>>[];
      var page = 1;
      var hasNextPage = true;
      Map<String, dynamic>? result;

      // AniList paginates studio credits (maximum 50 per request). Fetch each
      // page automatically so the Studio screen can show the complete list.
      while (hasNextPage) {
        final response = await dio.post<dynamic>(
          'https://graphql.anilist.co',
          data: {
            'query': query,
            'variables': {
              'search': widget.studioName,
              'sort': [_sort == 'RANDOM' ? 'START_DATE_DESC' : _sort],
              'page': page,
            },
          },
          options: Options(
            headers: AniListGraphql.headers,
            validateStatus: (status) => status != null && status < 500,
          ),
        );
        final data = response.data;
        if (data is! Map || data['data'] is! Map ||
            (data['data'] as Map)['Studio'] is! Map) {
          if (data is Map && data['errors'] is List) {
            final errors = data['errors'] as List;
            if (errors.isNotEmpty && errors.first is Map) {
              _loadError = (errors.first as Map)['message']?.toString();
            }
          }
          if (page == 1) {
            _loadError ??= 'Studio ini tidak ditemukan di AniList.';
            return null;
          }
          break;
        }

        final studio = Map<String, dynamic>.from(
          (data['data'] as Map)['Studio'] as Map,
        );
        result ??= studio;
        final media = studio['media'];
        final edges = media is Map ? media['edges'] : null;
        if (edges is List) {
          for (final edge in edges.whereType<Map>()) {
            final node = edge['node'];
            if (node is Map) {
              allAnime.add({...Map<String, dynamic>.from(node), '_isMainStudio': edge['isMainStudio'] == true});
            }
          }
        }
        final pageInfo = media is Map ? media['pageInfo'] : null;
        hasNextPage = pageInfo is Map &&
            pageInfo['hasNextPage'] == true;
        page++;
      }

      if (result == null) return null;
      if (_sort == 'RANDOM') allAnime.shuffle();
      result['media'] = {'nodes': allAnime, 'pageInfo': {'hasNextPage': false}};
      try {
        final service = sl<AniListService>();
        if (service.isConnected) {
          final entries = await service.fetchList();
          _myAnimeIds = entries
              .where((entry) => entry.item.anilistId != null)
              .map((entry) => entry.item.anilistId!)
              .toSet();
        }
      } catch (_) {}
      return result;
    } on DioException catch (error) {
      _loadError = error.response?.statusCode == 429
          ? 'AniList sedang membatasi permintaan. Coba lagi sebentar.'
          : error.response == null
              ? 'Tidak bisa terhubung ke AniList. Periksa koneksi internet.'
              : 'AniList gagal memuat data (HTTP ${error.response?.statusCode}).';
    } catch (_) {
      _loadError = 'Terjadi kesalahan saat memuat data studio.';
    }
    return null;
  }

  void _changeSort(String? value) {
    if (value == null || value == _sort) return;
    setState(() {
      _sort = value;
      _loadError = null;
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.bg,
    body: FutureBuilder<Map<String, dynamic>?>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Center(child: CircularProgressIndicator(color: AppColors.accent));
        }
        final studio = snapshot.data;
        if (studio == null) {
          return Center(child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.business_outlined, size: 42, color: AppColors.textSecondary),
              const SizedBox(height: 14),
              Text('Informasi studio gagal dimuat', style: AppText.headline),
              const SizedBox(height: 8),
              Text(_loadError ?? 'Periksa koneksi lalu coba lagi.', textAlign: TextAlign.center,
                style: AppText.caption.copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: 18),
              FilledButton.icon(onPressed: () => setState(() { _loadError = null; _future = _load(); }),
                icon: const Icon(Icons.refresh), label: const Text('Coba lagi')),
            ]),
          ));
        }
        final raw = studio['media'] is Map ? (studio['media'] as Map)['nodes'] : null;
        final anime = <Map<String, dynamic>>[if (raw is List) ...raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e))];
        final popular = [...anime]..sort((a,b) => ((b['popularity'] as num?) ?? 0).compareTo((a['popularity'] as num?) ?? 0));
        final heroAnime = popular.isEmpty ? null : popular.first;
        final banner = heroAnime?['bannerImage'] as String?;
        final topFour = popular.take(4).toList();
        final name = (studio['name'] as String?) ?? widget.studioName;
        final listedCount = anime.where((a) => _myAnimeIds.contains(a['id'])).length;
        final scored = anime.where((a) => (a['averageScore'] as num? ?? 0) > 0).toList();
        final avg = scored.isEmpty ? 0 : (scored.map((a) => (a['averageScore'] as num).toDouble()).reduce((a,b) => a+b) / scored.length).round();
        final mainCount = anime.where((a) => a['_isMainStudio'] == true).length;
        final mainPct = anime.isEmpty ? 0 : (mainCount * 100 / anime.length).round();
        final years = anime.map((a) => a['seasonYear']).whereType<int>().toList();
        final yearRange = years.isEmpty ? '—' : '${years.reduce((a,b) => a < b ? a : b)}–${years.reduce((a,b) => a > b ? a : b)}';
        final visible = _onlyInList ? anime.where((a) => _myAnimeIds.contains(a['id'])).toList() : anime;
        final widePosters = posterLayout(context) == PosterCardLayout.wide;
        final posterWidth = posterGridCellWidth(context);
        final titleInside = posterTitleInside(context, wide: widePosters);
        final siteUrl = studio['siteUrl'] as String?;
        return CustomScrollView(slivers: [
          SliverToBoxAdapter(child: SizedBox(
            height: 565,
            child: Stack(clipBehavior: Clip.none, children: [
              Positioned(top: 0, left: 0, right: 0, height: 390,
                child: Stack(fit: StackFit.expand, children: [
                  if (banner != null && banner.isNotEmpty) Image.network(banner, fit: BoxFit.cover)
                  else Container(color: AppColors.surface2),
                  DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [Colors.black.withValues(alpha: .08), AppColors.bg.withValues(alpha: .45), AppColors.bg],
                    stops: const [0, .58, 1]))),
                  Positioned(left: 16, right: 16, top: MediaQuery.paddingOf(context).top + 8,
                    child: Row(children: [
                      _roundAction(Icons.arrow_back, () => Navigator.maybePop(context)),
                      const Spacer(),
                      _roundAction(Icons.favorite_border, () => _openAniList(siteUrl)),
                      const SizedBox(width: 10),
                      _roundAction(Icons.share_outlined, () => _shareStudio(siteUrl)),
                    ])),
                  if (heroAnime != null)
                    Positioned(right: 22, bottom: 16, child: Text(_title(heroAnime),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: AppText.caption.copyWith(color: Colors.white, fontWeight: FontWeight.w600))),
                ]),
              ),
              Positioned(left: 36, top: 280, child: _StudioCollage(items: topFour)),
              Positioned(left: 247, right: 24, top: 382, child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: AppText.title.copyWith(fontSize: 28)),
                  const SizedBox(height: 8),
                  Text(studio['isAnimationStudio'] == true ? 'Studio animasi' : 'Studio',
                    style: AppText.caption.copyWith(color: AppColors.textSecondary, fontSize: 16)),
                  const SizedBox(height: 16),
                  Row(children: [
                    const Icon(Icons.favorite, color: Color(0xFFF16D70), size: 20),
                    const SizedBox(width: 8),
                    Text(_number(studio['favourites']), style: AppText.body.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(width: 8),
                    Text('favorit', style: AppText.caption.copyWith(color: AppColors.textSecondary)),
                  ]),
                ],
              )),
            ]),
          )),
          SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.fromLTRB(36, 0, 36, 0),
            child: Column(children: [
              Container(width: double.infinity, padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(24)),
                child: Column(children: [
                  Row(children: [
                    Expanded(child: _StudioStat(icon: Icons.playlist_add_check, label: 'Di daftarmu', value: '$listedCount')),
                    Expanded(child: _StudioStat(icon: Icons.star, label: 'Skor rata-rata', value: '$avg%', tint: const Color(0xFFFFC21A))),
                  ]),
                  const SizedBox(height: 28),
                  Row(children: [
                    Expanded(child: _StudioStat(icon: Icons.apartment, label: 'Studio utama', value: '$mainPct%')),
                    Expanded(child: _StudioStat(icon: Icons.calendar_month, label: 'Rentang', value: yearRange, tint: const Color(0xFFB9A7E8))),
                  ]),
                ]),
              ),
              const SizedBox(height: 14),
              Align(alignment: Alignment.centerLeft, child: Text('Rata-rata dari ${scored.length} judul yang sudah dimuat',
                style: AppText.caption.copyWith(color: AppColors.textSecondary))),
              const SizedBox(height: 26),
              if (siteUrl != null) InkWell(onTap: () => _openAniList(siteUrl),
                borderRadius: BorderRadius.circular(18),
                child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18)),
                  child: Row(children: [
                    Icon(Icons.public, color: AppColors.textSecondary),
                    const SizedBox(width: 18),
                    Expanded(child: Text('Lihat di AniList', style: AppText.headline)),
                    Text('anilist.co', style: AppText.caption.copyWith(color: AppColors.textSecondary)),
                    const SizedBox(width: 12),
                    Icon(Icons.open_in_new, color: AppColors.textSecondary, size: 20),
                  ]),
                )),
              const SizedBox(height: 38),
              Row(children: [
                Container(width: 5, height: 36, decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(5))),
                const SizedBox(width: 18),
                Text('Karya', style: AppText.title.copyWith(fontSize: 27)),
              ]),
              const SizedBox(height: 24),
              SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
                PopupMenuButton<String>(
                  initialValue: _sort,
                  onSelected: _changeSort,
                  color: AppColors.surface2,
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'START_DATE_DESC', child: Text('Terbaru')),
                    PopupMenuItem(value: 'POPULARITY_DESC', child: Text('Popularitas')),
                    PopupMenuItem(value: 'START_DATE', child: Text('Terlama')),
                    PopupMenuItem(value: 'SCORE_DESC', child: Text('Skor tertinggi')),
                    PopupMenuItem(value: 'RANDOM', child: Text('Acak')),
                  ],
                  child: _StudioChip(icon: Icons.swap_vert, label: _sortLabel),
                ),
                const SizedBox(width: 10),
                FilterChip(label: const Text('Di daftarku'), selected: _onlyInList,
                  onSelected: (v) => setState(() => _onlyInList = v),
                  showCheckmark: false, backgroundColor: AppColors.bg,
                  selectedColor: AppColors.surface2, side: BorderSide(color: AppColors.textSecondary.withValues(alpha: .5)),
                  labelStyle: AppText.body.copyWith(color: _onlyInList ? AppColors.textPrimary : AppColors.textSecondary)),
              ])),
              const SizedBox(height: 24),
            ]),
          )),
          if (visible.isNotEmpty)
            SliverPadding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: posterGridColumns(context),
                  childAspectRatio: posterCellAspect(posterWidth, wide: widePosters, titleInside: titleInside),
                  crossAxisSpacing: 12, mainAxisSpacing: 16),
                delegate: SliverChildBuilderDelegate((context, index) {
                  final item = visible[index];
                  final titleData = item['title'] is Map ? item['title'] as Map : const {};
                  final title = _title(item);
                  final cover = item['coverImage'] is Map ? (item['coverImage'] as Map)['large'] as String? : null;
                  final score = item['averageScore'];
                  return PosterCard(title: title, imageUrl: cover, cellWidth: posterWidth,
                    scoreBadge: score is int && score > 0 ? score : null,
                    metaFormat: item['format'] as String?,
                    metaEpisodes: item['episodes'] is int && (item['episodes'] as int) > 0 ? item['episodes'] as int : null,
                    metaYear: item['seasonYear'] is int ? '${item['seasonYear']}' : null,
                    onTap: () => openRelatedTitle(context, title: title,
                      romaji: titleData['romaji'] as String?, cover: cover, isReading: false,
                      anilistId: item['id'] as int?, malId: item['idMal'] as int?,
                      sourceId: null, fromReadingPage: false));
                }, childCount: visible.length),
              )),
          if (visible.isEmpty)
            SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.all(32),
              child: Center(child: Text(_onlyInList ? 'Belum ada karya studio ini di daftarmu.' : 'Belum ada karya.',
                style: AppText.caption.copyWith(color: AppColors.textSecondary))))),
        ]);
      },
    ),
  );

  String get _sortLabel => switch (_sort) {
    'POPULARITY_DESC' => 'Popularitas',
    'START_DATE' => 'Terlama',
    'SCORE_DESC' => 'Skor tertinggi',
    'RANDOM' => 'Acak',
    _ => 'Terbaru',
  };

  String _title(Map item) {
    final t = item['title'] is Map ? item['title'] as Map : const {};
    final english = t['english'] as String?;
    return english?.trim().isNotEmpty == true ? english! : (t['romaji'] as String? ?? 'Unknown title');
  }

  String _number(dynamic value) {
    final n = value is num ? value.toInt() : 0;
    return n.toString().replaceAllMapped(RegExp(r'(?<=\d)(?=(\d{3})+$)'), (m) => '.');
  }

  Future<void> _openAniList(String? url) async {
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _shareStudio(String? url) async {
    if (url == null || url.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: url));
  }
}

class _StudioCollage extends StatelessWidget {
  const _StudioCollage({required this.items});
  final List<Map<String, dynamic>> items;
  @override
  Widget build(BuildContext context) => SizedBox(width: 186, height: 258,
    child: GridView.builder(physics: const NeverScrollableScrollPhysics(), padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 2, mainAxisSpacing: 2),
      itemCount: 4, itemBuilder: (context, index) {
        final url = index < items.length && items[index]['coverImage'] is Map
          ? (items[index]['coverImage'] as Map)['large'] as String? : null;
        return ClipRRect(borderRadius: BorderRadius.circular(3),
          child: url == null ? Container(color: AppColors.surface2) : Image.network(url, fit: BoxFit.cover,
            errorBuilder: (_,__,___) => Container(color: AppColors.surface2)));
      }));
}

class _StudioStat extends StatelessWidget {
  const _StudioStat({required this.icon, required this.label, required this.value, this.tint});
  final IconData icon; final String label; final String value; final Color? tint;
  @override
  Widget build(BuildContext context) => Row(children: [
    Container(width: 48, height: 48, decoration: BoxDecoration(color: (tint ?? const Color(0xFF607D8B)).withValues(alpha: .22), shape: BoxShape.circle),
      child: Icon(icon, color: tint ?? const Color(0xFFB6CBE0), size: 24)),
    const SizedBox(width: 12),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.caption.copyWith(color: AppColors.textSecondary)),
      const SizedBox(height: 3),
      Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.body.copyWith(fontWeight: FontWeight.w800)),
    ])),
  ]);
}

class _StudioChip extends StatelessWidget {
  const _StudioChip({required this.icon, required this.label});
  final IconData icon; final String label;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(border: Border.all(color: AppColors.textSecondary.withValues(alpha: .5), width: 1.5), borderRadius: BorderRadius.circular(12)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 18, color: AppColors.textSecondary), const SizedBox(width: 10),
      Text(label, style: AppText.body.copyWith(fontWeight: FontWeight.w700)),
      const SizedBox(width: 8), Icon(Icons.keyboard_arrow_down, size: 20, color: AppColors.textSecondary),
    ]));
}

Widget _roundAction(IconData icon, VoidCallback onTap) => Material(
  color: Colors.black.withValues(alpha: .28), shape: const CircleBorder(),
  child: InkWell(onTap: onTap, customBorder: const CircleBorder(),
    child: SizedBox(width: 48, height: 48, child: Icon(icon, color: Colors.white, size: 25))),
);
