import 'package:flutter/material.dart';
import '../../core/anilist/anilist_service.dart';
import '../../core/di/injector.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';

class MenuReleaseTrackerScreen extends StatefulWidget {
  const MenuReleaseTrackerScreen({super.key});
  @override State<MenuReleaseTrackerScreen> createState() => _MenuReleaseTrackerScreenState();
}

class _MenuReleaseTrackerScreenState extends State<MenuReleaseTrackerScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;
  int _tab = 0;
  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final rows = await sl<AniListService>().api.fetchReleaseTracker();
      if (mounted) setState(() => _items = rows);
    } catch (_) {
      if (mounted) setState(() => _error = 'Jadwal rilis AniList gagal dimuat. Coba lagi nanti.');
    } finally { if (mounted) setState(() => _loading = false); }
  }

  DateTime? _date(Map<String, dynamic> item, bool airing) {
    if (airing) {
      final seconds = (item['nextAiringEpisode'] as Map?)?['airingAt'];
      return seconds is num ? DateTime.fromMillisecondsSinceEpoch(seconds.toInt() * 1000) : null;
    }
    final d = item['startDate'];
    if (d is! Map || d['year'] is! num) return null;
    return DateTime((d['year'] as num).toInt(), (d['month'] as num?)?.toInt() ?? 1, (d['day'] as num?)?.toInt() ?? 1);
  }

  String _dateLabel(DateTime? date) {
    if (date == null) return 'Tanggal belum diumumkan';
    const months = ['Jan','Feb','Mar','Apr','Mei','Jun','Jul','Agu','Sep','Okt','Nov','Des'];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _startDateLabel(Map<String, dynamic> item) {
    final d = item['startDate'];
    if (d is! Map || d['year'] is! num) return 'Tanggal belum diumumkan';
    final year = (d['year'] as num).toInt();
    final month = d['month'];
    final day = d['day'];
    const months = ['Jan','Feb','Mar','Apr','Mei','Jun','Jul','Agu','Sep','Okt','Nov','Des'];
    if (month is num && day is num) {
      return '${day.toInt()} ${months[month.toInt() - 1]} $year';
    }
    if (month is num) return '${months[month.toInt() - 1]} $year';
    return year.toString();
  }

  String _countdown(DateTime date) {
    final d = date.difference(DateTime.now());
    if (d.isNegative) return 'Sedang tayang';
    if (d.inDays > 0) return '${d.inDays} hari lagi';
    if (d.inHours > 0) return '${d.inHours} jam lagi';
    if (d.inMinutes > 0) return '${d.inMinutes} menit lagi';
    return 'Segera tayang';
  }

  @override Widget build(BuildContext context) {
    final airing = _items.where((e) => e['status'] == 'RELEASING').toList()
      ..sort((a,b) => (_date(a, true) ?? DateTime(9999)).compareTo(_date(b, true) ?? DateTime(9999)));
    final upcoming = _items.where((e) => e['status'] == 'NOT_YET_RELEASED').toList()
      ..sort((a,b) => (_date(a, false) ?? DateTime(9999)).compareTo(_date(b, false) ?? DateTime(9999)));
    final visible = _tab == 0 ? airing : upcoming;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg, foregroundColor: AppColors.textPrimary,
        title: Text('Release Tracker', style: AppText.title.copyWith(color: AppColors.textPrimary)),
        actions: [IconButton(onPressed: _load, tooltip: 'Muat ulang', icon: const Icon(Icons.refresh_rounded))],
      ),
      body: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(14,8,14,12), child: Row(children: [
          Expanded(child: _tabButton('Sedang tayang', 0, airing.length)),
          const SizedBox(width: 8),
          Expanded(child: _tabButton('Akan datang', 1, upcoming.length)),
        ])),
        Expanded(child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
            ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(_error!, textAlign: TextAlign.center, style: AppText.body.copyWith(color: AppColors.textSecondary)),
                const SizedBox(height: 12), FilledButton(onPressed: _load, child: const Text('Coba lagi')),
              ])))
            : visible.isEmpty
              ? Center(child: Text(_tab == 0 ? 'Belum ada anime yang sedang tayang.' : 'Belum ada jadwal anime mendatang.', style: AppText.body.copyWith(color: AppColors.textSecondary)))
              : RefreshIndicator(onRefresh: _load, child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(14,4,14,24), itemCount: visible.length,
                  separatorBuilder: (_,__) => const SizedBox(height: 10),
                  itemBuilder: (_,i) {
                    final item = visible[i];
                    final title = item['title'] is Map ? item['title'] as Map : const {};
                    final name = (title['romaji'] ?? title['english'] ?? 'Anime').toString();
                    final cover = (item['coverImage'] as Map?)?['large'] as String?;
                    final date = _date(item, _tab == 0);
                    final episode = (_tab == 0 ? (item['nextAiringEpisode'] as Map?)?['episode'] : null);
                    final details = _tab == 0
                      ? '${episode == null ? 'Episode berikutnya' : 'Episode $episode'} · ${_dateLabel(date)}'
                      : _startDateLabel(item);
                    return Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14)),
                      child: Row(children: [
                        ClipRRect(borderRadius: BorderRadius.circular(9), child: cover == null
                          ? Container(width:72,height:100,color:AppColors.surface2,child:const Icon(Icons.movie_outlined))
                          : Image.network(cover,width:72,height:100,fit:BoxFit.cover,errorBuilder:(_,__,___)=>Container(width:72,height:100,color:AppColors.surface2,child:const Icon(Icons.broken_image)))),
                        const SizedBox(width:12),
                        Expanded(child: Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                          Text(name,maxLines:2,overflow:TextOverflow.ellipsis,style:AppText.body.copyWith(color:AppColors.textPrimary,fontWeight:FontWeight.w700)),
                          const SizedBox(height:6),
                          Text(details,style:AppText.caption.copyWith(color:AppColors.textSecondary)),
                          const SizedBox(height:5),
                          Text(_tab == 0 && date != null ? _countdown(date) : 'Tahun ${item['seasonYear'] ?? date?.year ?? '-'} · ${item['episodes'] ?? '?'} episode',style:AppText.caption.copyWith(color:AppColors.accent,fontWeight:FontWeight.w700)),
                        ])),
                      ]),
                    );
                  },
                )),
      ]),
    );
  }

  Widget _tabButton(String label, int index, int count) {
    final selected = _tab == index;
    return FilledButton.tonal(
      onPressed: () => setState(() => _tab = index),
      style: FilledButton.styleFrom(
        backgroundColor: selected ? AppColors.accent.withValues(alpha:.18) : AppColors.surface,
        foregroundColor: selected ? AppColors.accent : AppColors.textSecondary,
        padding: const EdgeInsets.symmetric(vertical:12),
      ),
      child: Text('$label ($count)'),
    );
  }
}
