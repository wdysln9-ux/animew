import 'package:flutter/material.dart';

import '../../core/anilist/anilist_service.dart';
import '../../core/di/injector.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/ui/anilist_markdown.dart';

/// People followed by the signed-in AniList account who have this anime
/// somewhere in their list.
class NakamaWatchingPage extends StatefulWidget {
  const NakamaWatchingPage({
    super.key,
    required this.mediaId,
    required this.animeTitle,
  });

  final int mediaId;
  final String animeTitle;

  @override
  State<NakamaWatchingPage> createState() => _NakamaWatchingPageState();
}

class _NakamaWatchingPageState extends State<NakamaWatchingPage> {
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _entries = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasNextPage = false;
  String? _error;
  int _page = 1;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadFirstPage();
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients ||
        _scrollController.position.extentAfter > 420 ||
        !_hasNextPage ||
        _loadingMore ||
        _loading) {
      return;
    }
    _loadNextPage();
  }

  Future<void> _loadFirstPage() async {
    setState(() {
      _loading = true;
      _error = null;
      _entries.clear();
      _page = 1;
    });
    try {
      final anilist = sl<AniListService>();
      if (!anilist.isConnected) {
        if (!mounted) return;
        setState(() {
          _error = 'Hubungkan akun AniList terlebih dahulu untuk melihat daftar nakama.';
          _loading = false;
        });
        return;
      }
      final result = await anilist.api.nakamaWatching(
        widget.mediaId,
        page: 1,
      );
      if (!mounted) return;
      setState(() {
        _entries.addAll(result.entries);
        _hasNextPage = result.hasNextPage;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Bad state: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _loadNextPage() async {
    if (_loadingMore || !_hasNextPage) return;
    setState(() => _loadingMore = true);
    try {
      final nextPage = _page + 1;
      final result = await sl<AniListService>().api.nakamaWatching(
        widget.mediaId,
        page: nextPage,
      );
      if (!mounted) return;
      setState(() {
        _page = nextPage;
        _entries.addAll(result.entries);
        _hasNextPage = result.hasNextPage;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  String _statusLabel(String? status) => switch (status) {
    'CURRENT' => 'Sedang ditonton',
    'COMPLETED' => 'Selesai',
    'PAUSED' => 'Ditunda',
    'DROPPED' => 'Ditinggalkan',
    'PLANNING' => 'Berencana',
    'REPEATING' => 'Ditonton ulang',
    _ => 'Tidak diketahui',
  };

  Color _statusColor(String? status) => switch (status) {
    'CURRENT' => const Color(0xFF42B883),
    'COMPLETED' => const Color(0xFF5799E8),
    'DROPPED' => const Color(0xFFE16B70),
    'PAUSED' => const Color(0xFFE0A34A),
    'REPEATING' => const Color(0xFF9B6DDB),
    _ => AppColors.textSecondary,
  };

  Widget _ratingWidget(double score, String format) {
    final color = AppColors.accent;
    if (format == 'POINT_5') {
      final stars = score.round().clamp(0, 5).toInt();
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(
          stars,
          (_) => Icon(Icons.star_rounded, size: 15, color: color),
        ),
      );
    }
    if (format == 'POINT_3') {
      final value = score.round().clamp(0, 3).toInt();
      final icon = switch (value) {
        1 => Icons.sentiment_dissatisfied_rounded,
        2 => Icons.sentiment_neutral_rounded,
        _ => Icons.sentiment_satisfied_rounded,
      };
      return Icon(icon, size: 19, color: color);
    }
    final text = format == 'POINT_10_DECIMAL'
        ? score.toStringAsFixed(1)
        : score.toStringAsFixed(0);
    return Text(
      text,
      style: AppText.caption.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _entryCard(Map<String, dynamic> entry) {
    final user = entry['user'] is Map
        ? Map<String, dynamic>.from(entry['user'] as Map)
        : <String, dynamic>{};
    final avatar = user['avatar'] is Map
        ? (user['avatar'] as Map)['large']?.toString()
        : null;
    final name = user['name']?.toString() ?? 'Pengguna AniList';
    final progress = (entry['progress'] as num?)?.toInt() ?? 0;
    final score = (entry['score'] as num?)?.toDouble() ?? 0;
    final options = user['mediaListOptions'] is Map
        ? Map<String, dynamic>.from(user['mediaListOptions'] as Map)
        : <String, dynamic>{};
    final scoreFormat = options['scoreFormat']?.toString() ?? 'POINT_10';
    final status = entry['status']?.toString();
    final statusColor = _statusColor(status);
    final notes = entry['notes']?.toString().trim() ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: AppColors.hairline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
            ClipOval(
              child: SizedBox(
                width: 46,
                height: 46,
                child: avatar == null || avatar.isEmpty
                    ? ColoredBox(
                        color: AppColors.surface2,
                        child: const Icon(Icons.person_rounded, color: AppColors.textSecondary),
                      )
                    : Image.network(
                        avatar,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => ColoredBox(
                          color: AppColors.surface2,
                          child: const Icon(Icons.person_rounded, color: AppColors.textSecondary),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.body.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Wrap(
                    spacing: 7,
                    runSpacing: 5,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        '$progress episode',
                        style: AppText.caption.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 11.5,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.13),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          _statusLabel(status),
                          style: AppText.caption.copyWith(
                            color: statusColor,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (score > 0) _ratingWidget(score, scoreFormat),
              ],
            ),
            if (notes.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Divider(height: 1, color: AppColors.hairline),
              const SizedBox(height: 9),
              AniListMarkdown(
                data: notes,
                textStyle: AppText.body.copyWith(
                  fontSize: 12.5,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(
          _hasNextPage || _loading
              ? 'Nakama Menonton'
              : 'Nakama Menonton (${_entries.length})',
          style: AppText.headline.copyWith(fontSize: 18),
        ),
        backgroundColor: AppColors.bg,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Text(
              widget.animeTitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppText.caption.copyWith(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(28),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.cloud_off_rounded, size: 34, color: AppColors.textSecondary),
                              const SizedBox(height: 12),
                              Text(
                                _error!,
                                textAlign: TextAlign.center,
                                style: AppText.body.copyWith(color: AppColors.textSecondary),
                              ),
                              const SizedBox(height: 14),
                              TextButton(onPressed: _loadFirstPage, child: const Text('Coba lagi')),
                            ],
                          ),
                        ),
                      )
                    : _entries.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(28),
                              child: Text(
                                'Belum ada orang yang kamu follow memasukkan anime ini ke daftar mereka.',
                                textAlign: TextAlign.center,
                                style: AppText.body.copyWith(color: AppColors.textSecondary),
                              ),
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadFirstPage,
                            child: ListView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.only(bottom: 24),
                              itemCount: _entries.length + (_loadingMore ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (index >= _entries.length) {
                                  return const Padding(
                                    padding: EdgeInsets.all(18),
                                    child: Center(child: CircularProgressIndicator()),
                                  );
                                }
                                return _entryCard(_entries[index]);
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}
