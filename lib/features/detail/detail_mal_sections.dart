// Supplementary MAL content and compact horizontal rails for the anime page.
part of 'detail_screen.dart';

class _MalTrailerSection extends StatefulWidget {
  const _MalTrailerSection({
    required this.malId,
    required this.anilistId,
    required this.title,
    this.englishTitle,
  });

  final int? malId;
  final int? anilistId;
  final String title;
  final String? englishTitle;

  @override
  State<_MalTrailerSection> createState() => _MalTrailerSectionState();
}

class _MalTrailerSectionState extends State<_MalTrailerSection> {
  late Future<AnimeExtras> _future;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _MalTrailerSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.malId != widget.malId ||
        oldWidget.anilistId != widget.anilistId ||
        oldWidget.title != widget.title ||
        oldWidget.englishTitle != widget.englishTitle) {
      _load();
    }
  }

  void _load({bool retry = false}) {
    _future = AnimeExtrasRepository.instance.load(
      malId: widget.malId,
      anilistId: widget.anilistId,
      title: widget.title,
      englishTitle: widget.englishTitle,
      forceRefresh: retry,
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<AnimeExtras>(
    future: _future,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 22, 16, 4),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _expanded = !_expanded),
            child: Row(children: [
              Text('Trailer & PV', style: AppText.headline.copyWith(fontSize: 17)),
              const Spacer(),
              const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 1.6)),
              const SizedBox(width: 8),
              Icon(_expanded ? Icons.keyboard_arrow_down_rounded : Icons.chevron_right_rounded, color: AppColors.textSecondary),
            ]),
          ),
        );
      }
      if (snapshot.hasError) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
          child: Row(
            children: [
              const Expanded(child: Text('Trailer belum bisa dimuat.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary))),
              TextButton(
                onPressed: () => setState(() => _load(retry: true)),
                child: const Text('Coba lagi'),
              ),
            ],
          ),
        );
      }
      final videos = snapshot.data?.videos ?? const <AnimeExtraVideo>[];
      if (videos.isEmpty && snapshot.data?.videoError != null) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
          child: Row(
            children: [
              const Expanded(child: Text('Trailer belum bisa dimuat.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary))),
              TextButton(onPressed: () => setState(_load), child: const Text('Coba lagi')),
            ],
          ),
        );
      }
      // Keep the section header visible even when MAL has no trailer;
      // users can still expand it to see the empty-state explanation.
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 22, 0, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Row(children: [
                  Text('Trailer & PV', style: AppText.headline.copyWith(fontSize: 17)),
                  const Spacer(),
                  Icon(_expanded ? Icons.keyboard_arrow_down_rounded : Icons.chevron_right_rounded,
                    color: AppColors.textSecondary),
                ]),
              ),
            ),
            if (_expanded) ...[
            const SizedBox(height: 12),
            if (videos.isEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Text(
                  'Trailer belum tersedia di MyAnimeList.',
                  style: AppText.caption.copyWith(color: AppColors.textSecondary),
                ),
              )
            else
            SizedBox(
              height: 132,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(right: 16),
                itemCount: videos.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final video = videos[index];
                  return SizedBox(
                    width: 184,
                    child: GestureDetector(
                      onTap: () => launchUrl(
                        Uri.parse('https://www.youtube.com/watch?v=${video.youtubeId}'),
                        mode: LaunchMode.externalApplication,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  if (video.imageUrl != null)
                                    CachedNetworkImage(
                                      imageUrl: video.imageUrl!,
                                      fit: BoxFit.cover,
                                      errorWidget: (_, _, _) => ColoredBox(color: AppColors.surface2),
                                    )
                                  else
                                    ColoredBox(color: AppColors.surface2),
                                  Center(
                                    child: Container(
                                      width: 42,
                                      height: 30,
                                      decoration: BoxDecoration(
                                        color: Colors.red,
                                        borderRadius: BorderRadius.circular(9),
                                      ),
                                      child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 26),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(video.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.caption.copyWith(color: AppColors.textPrimary)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            ],
          ],
        ),
      );
    },
  );
}

class _MalThemeSection extends StatefulWidget {
  const _MalThemeSection({
    required this.malId,
    required this.anilistId,
    required this.title,
    this.englishTitle,
  });

  final int? malId;
  final int? anilistId;
  final String title;
  final String? englishTitle;

  @override
  State<_MalThemeSection> createState() => _MalThemeSectionState();
}

class _MalThemeSectionState extends State<_MalThemeSection> {
  late Future<AnimeExtras> _future;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _MalThemeSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.malId != widget.malId ||
        oldWidget.anilistId != widget.anilistId ||
        oldWidget.title != widget.title ||
        oldWidget.englishTitle != widget.englishTitle) {
      _load();
    }
  }

  void _load({bool retry = false}) {
    _future = AnimeExtrasRepository.instance.load(
      malId: widget.malId,
      anilistId: widget.anilistId,
      title: widget.title,
      englishTitle: widget.englishTitle,
      forceRefresh: retry,
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<AnimeExtras>(
    future: _future,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 22, 16, 4),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _expanded = !_expanded),
            child: Row(children: [
              Text('Lagu Tema', style: AppText.headline.copyWith(fontSize: 17)),
              const Spacer(),
              const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 1.6)),
              const SizedBox(width: 8),
              Icon(_expanded ? Icons.keyboard_arrow_down_rounded : Icons.chevron_right_rounded, color: AppColors.textSecondary),
            ]),
          ),
        );
      }
      if (snapshot.hasError) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
          child: Row(
            children: [
              const Expanded(child: Text('Lagu tema belum bisa dimuat.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary))),
              TextButton(
                onPressed: () => setState(() => _load(retry: true)),
                child: const Text('Coba lagi'),
              ),
            ],
          ),
        );
      }
      final data = snapshot.data;
      if (data == null) return const SizedBox.shrink();
      final songs = <(String, String)>[
        for (final song in data.openings) ('Opening', song),
        for (final song in data.endings) ('Ending', song),
      ];
      if (songs.isEmpty && data.themeError != null) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
          child: Row(
            children: [
              const Expanded(child: Text('Lagu tema belum bisa dimuat.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary))),
              TextButton(onPressed: () => setState(_load), child: const Text('Coba lagi')),
            ],
          ),
        );
      }
      final visible = _expanded ? songs : songs.take(3).toList();
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _expanded = !_expanded),
              child: Row(
                children: [
                  Text('Lagu Tema', style: AppText.headline.copyWith(fontSize: 17)),
                  const SizedBox(width: 8),
                  Text('${songs.length}', style: AppText.caption.copyWith(color: AppColors.textSecondary)),
                  const Spacer(),
                  Icon(_expanded ? Icons.keyboard_arrow_down_rounded : Icons.chevron_right_rounded, color: AppColors.textSecondary),
                ],
              ),
            ),
            if (_expanded && songs.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Lagu tema belum tersedia di MyAnimeList.',
                  style: AppText.caption.copyWith(color: AppColors.textSecondary),
                ),
              ),
            if (songs.isNotEmpty) const SizedBox(height: 8),
            for (final song in visible)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    Icon(song.$1 == 'Opening' ? Icons.play_circle_outline : Icons.music_note, size: 17, color: AppColors.accent),
                    const SizedBox(width: 9),
                    Expanded(child: Text(song.$2, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.body.copyWith(fontSize: 13))),
                    Text(song.$1 == 'Opening' ? 'OP' : 'ED', style: AppText.caption.copyWith(color: AppColors.textSecondary)),
                  ],
                ),
              ),
          ],
        ),
      );
    },
  );
}
