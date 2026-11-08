// Supplementary MAL content and compact horizontal rails for the anime page.
part of 'detail_screen.dart';

class _MalTrailerSection extends StatefulWidget {
  const _MalTrailerSection({required this.malId});
  final int? malId;

  @override
  State<_MalTrailerSection> createState() => _MalTrailerSectionState();
}

class _MalTrailerSectionState extends State<_MalTrailerSection> {
  Future<MalAnimeExtras>? _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _MalTrailerSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.malId != widget.malId) _load();
  }

  void _load() {
    final id = widget.malId;
    _future = id == null ? null : sl<TrailerService>().malAnimeExtras(id);
  }

  @override
  Widget build(BuildContext context) {
    final future = _future;
    if (future == null) return const SizedBox.shrink();
    return FutureBuilder<MalAnimeExtras>(
      future: future,
      builder: (context, snapshot) {
        final videos = snapshot.data?.videos ?? const <MalAnimeVideo>[];
        if (videos.isEmpty) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const SizedBox.shrink();
          }
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 22, 0, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Trailer & PV', style: AppText.headline.copyWith(fontSize: 17)),
              const SizedBox(height: 12),
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
                                      const ColoredBox(color: AppColors.surface2),
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
          ),
        );
      },
    );
  }
}

class _CharacterRail extends StatelessWidget {
  const _CharacterRail({required this.cast, this.onOpenPerson});
  final List<CastMember> cast;
  final void Function(PersonRef)? onOpenPerson;

  @override
  Widget build(BuildContext context) {
    if (cast.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 0, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Karakter', style: AppText.headline.copyWith(fontSize: 17)),
              const SizedBox(width: 8),
              Text('${cast.length}', style: AppText.caption.copyWith(color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 132,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(right: 16),
              itemCount: cast.length,
              separatorBuilder: (_, _) => const SizedBox(width: 14),
              itemBuilder: (context, index) {
                final member = cast[index];
                return SizedBox(
                  width: 82,
                  child: GestureDetector(
                    onTap: member.person == null || onOpenPerson == null
                        ? null
                        : () => onOpenPerson!(member.person!),
                    child: Column(
                      children: [
                        ClipOval(
                          child: SizedBox(
                            width: 72,
                            height: 72,
                            child: member.photo == null
                                ? const ColoredBox(color: AppColors.surface2, child: Icon(Icons.person, color: AppColors.textSecondary))
                                : CachedNetworkImage(
                                    imageUrl: member.photo!,
                                    fit: BoxFit.cover,
                                    errorWidget: (_, _, _) => const ColoredBox(color: AppColors.surface2, child: Icon(Icons.person, color: AppColors.textSecondary)),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(member.name, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: AppText.caption.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                        if (member.role?.isNotEmpty == true)
                          Text(_indonesianCharacterRole(member.role!), maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.caption.copyWith(fontSize: 10, color: AppColors.accent)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MalThemeSection extends StatefulWidget {
  const _MalThemeSection({required this.malId});
  final int? malId;

  @override
  State<_MalThemeSection> createState() => _MalThemeSectionState();
}

class _MalThemeSectionState extends State<_MalThemeSection> {
  Future<MalAnimeExtras>? _future;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    final id = widget.malId;
    if (id != null) _future = sl<TrailerService>().malAnimeExtras(id);
  }

  @override
  void didUpdateWidget(covariant _MalThemeSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.malId != widget.malId) {
      _future = widget.malId == null
          ? null
          : sl<TrailerService>().malAnimeExtras(widget.malId!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final future = _future;
    if (future == null) return const SizedBox.shrink();
    return FutureBuilder<MalAnimeExtras>(
      future: future,
      builder: (context, snapshot) {
        final data = snapshot.data;
        if (data == null) return const SizedBox.shrink();
        final songs = <(String, String)>[
          for (final s in data.openings) ('Opening', s),
          for (final s in data.endings) ('Ending', s),
        ];
        if (songs.isEmpty) return const SizedBox.shrink();
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
                    Icon(_expanded ? Icons.expand_less : Icons.chevron_right, color: AppColors.textSecondary),
                  ],
                ),
              ),
              const SizedBox(height: 8),
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
}

class _SeasonRail extends StatelessWidget {
  const _SeasonRail({required this.seasons, required this.onOpen});
  final List<SeasonEntry> seasons;
  final ValueChanged<SeasonEntry> onOpen;

  @override
  Widget build(BuildContext context) {
    if (seasons.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 0, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Semua Musim', style: AppText.headline.copyWith(fontSize: 17)),
          const SizedBox(height: 12),
          SizedBox(
            height: 188,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(right: 16),
              itemCount: seasons.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final season = seasons[index];
                return SizedBox(
                  width: 116,
                  child: GestureDetector(
                    onTap: () => onOpen(season),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(11),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                if (season.cover != null)
                                  CachedNetworkImage(imageUrl: season.cover!, fit: BoxFit.cover, errorWidget: (_, _, _) => const ColoredBox(color: AppColors.surface2))
                                else
                                  const ColoredBox(color: AppColors.surface2),
                                Positioned(left: 6, bottom: 6, child: Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4), decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(6)), child: Text('Seri ${season.number}', style: AppText.caption.copyWith(color: Colors.white, fontSize: 10)))),
                                if (season.isCurrent)
                                  Positioned(right: 6, top: 6, child: Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3), decoration: BoxDecoration(color: const Color(0xFF438BE8), borderRadius: BorderRadius.circular(6)), child: Text('Dibuka', style: AppText.caption.copyWith(color: Colors.white, fontSize: 9)))),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(season.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.caption.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                        Text('TV · ${season.episodes ?? '—'} Eps', maxLines: 1, style: AppText.caption.copyWith(fontSize: 10, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
