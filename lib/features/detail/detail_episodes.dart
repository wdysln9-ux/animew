// Episodes tab: list and grid rows, season sheet, range chips, jump dialog.
part of 'detail_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Episodes tab — season selector (multi-season) + rich episode rows. PRESERVES
// season filtering and _openPlayer. Sub/Dub selection now lives in the player.
// ─────────────────────────────────────────────────────────────────────────────

class _EpisodesTab extends StatefulWidget {
  const _EpisodesTab({
    required this.loading,
    required this.eps,
    required this.seasonEps,
    required this.fillerEps,
    required this.hasMultipleSeasons,
    required this.seasonSet,
    required this.currentSeason,
    required this.onSelectSeason,
    required this.coverUrl,
    required this.coverHeaders,
    required this.sourceId,
    required this.downloadSourceId,
    required this.showId,
    required this.showUrl,
    required this.resumeIndex,
    required this.hasAnyMark,
    this.autoScrollToResume = false,
    this.targetEpisodeId,
    this.trackerProgress,
    this.showPopularity,
    this.totalEpisodes,
    this.isAiring = false,
    required this.onOpen,
    this.onEpisodeMenu,
    this.onRefresh,
    required this.onDownload,
    this.onDownloadMany,
    this.resumeChapter,
    this.onSwitchSource,
    this.isReading = false,
  });

  /// Opens the source picker for this title. Set only for catalogue titles,
  /// which are the ones that HAVE another source to try: when the one they
  /// are on returns nothing, the empty state below is otherwise a dead end
  /// and the way out (tapping the source name) is not obvious.
  final VoidCallback? onSwitchSource;

  /// The matched source's list is still being fetched — show the skeleton
  /// rather than the "no episodes" empty state (see
  /// [DetailState.episodesLoading]).
  final bool loading;

  final List<Episode> eps;
  final List<Episode> seasonEps;
  final Set<int> fillerEps; // episode numbers that are filler
  final bool hasMultipleSeasons;
  final Set<int> seasonSet;
  final int currentSeason;
  final ValueChanged<int> onSelectSeason;
  final String coverUrl;
  final Map<String, String>? coverHeaders;
  final String sourceId;

  /// The source that owns the chapter FILES, which for a metadata title is
  /// the matched extension rather than the `zm` pseudo-source in [sourceId].
  ///
  /// Kept apart on purpose: reading progress is keyed to the canonical id and
  /// must stay there, while downloads have to name the source that can
  /// actually fetch the pages.
  final String downloadSourceId;
  final String showId;
  final String showUrl;
  final int Function(List<Episode>) resumeIndex;
  final bool hasAnyMark;
  final bool autoScrollToResume;
  final String? targetEpisodeId;

  /// The connected tracker's watched-episode count, or null. Episodes at or
  /// below it render as watched (grey-out), merged with local playback marks.
  final int? trackerProgress;

  /// Next episode to air and when. Both null unless the title matched a
  /// tracker and is still airing, which is what keeps the row off finished
  /// shows and movies instead of showing an empty countdown.
  final int? showPopularity;
  final int? totalEpisodes;
  final bool isAiring;
  final void Function(int fullIndex) onOpen;

  /// Long-press an episode → pick which player opens it, this once. Null on
  /// the reading path: a chapter opens the reader, so there's nothing to pick.
  final void Function(int fullIndex)? onEpisodeMenu;

  /// Force-refresh the list past the 10-min source cache. Null hides the menu item.
  final Future<void> Function()? onRefresh;

  /// Per-row download icon → the download sheet for an episode, or a straight
  /// enqueue for a chapter.
  final void Function(Episode ep) onDownload;

  /// Queue a run of chapters in one go. Null for video, where downloading is
  /// per-episode through the source picker.
  final Future<void> Function(List<Episode> eps)? onDownloadMany;

  /// Reading resume target from ReadStore / ReadHistory. Batch download starts
  /// here instead of at chapter one; an unfinished chapter is included.
  final Episode? resumeChapter;

  /// True for reading types — the section header reads "Chapters" instead
  /// of "Episodes" (single-season case only; multi-season keeps the season
  /// pill either way).
  final bool isReading;

  @override
  State<_EpisodesTab> createState() => _EpisodesTabState();
}

class _EpisodesTabState extends State<_EpisodesTab> {
  bool _grid = false;
  bool _reverseList = false;

  /// Selected scanlation group, or null for "All". Several groups release the
  /// same chapter number, so an unfiltered list legitimately reads 1, 1, 2, 2
  /// — picking a group is what makes it a single readable run.
  String? _scanlator;
  int _rangeIndex = 0;

  @override
  void initState() {
    super.initState();
    _rangeIndex = _initialRange();
  }


  @override
  void didUpdateWidget(covariant _EpisodesTab old) {
    super.didUpdateWidget(old);
    // Season switched (or the episode set changed) → reset to the resume chunk.
    if (old.currentSeason != widget.currentSeason ||
        old.seasonEps.length != widget.seasonEps.length) {
      _rangeIndex = _initialRange();
    }
  }

  /// The chunk holding the resume episode, so the tab opens where the user left
  /// off instead of always at episode 1.
  int _initialRange() {
    if (!widget.hasAnyMark || widget.seasonEps.isEmpty) return 0;
    final targetIndex = widget.targetEpisodeId == null
        ? -1
        : widget.eps.indexWhere((e) => e.id == widget.targetEpisodeId);
    final resumeEp = targetIndex >= 0
        ? widget.eps[targetIndex]
        : widget.eps[widget.resumeIndex(widget.eps)];
    // Against the filtered display order so reversed lists open at the range
    // containing the saved resume episode.
    final local = _displayEps.indexOf(resumeEp);
    return episodeRangeIndex(
      local,
      total: _displayEps.length,
      reversed: _reverseList,
    );
  }

  int get _rangeCount => episodeRangeCount(_filteredEps.length);

  /// Scanlation groups on offer, first-seen order (which is the source's own
  /// ordering, so the group a reader is following tends to come first).
  List<String> get _scanlators {
    final seen = <String>[];
    for (final e in widget.seasonEps) {
      final s = e.scanlator?.trim();
      if (s != null && s.isNotEmpty && !seen.contains(s)) seen.add(s);
    }
    return seen;
  }

  /// The chapters actually shown. Identical to the source list when no group
  /// is picked, so nothing changes for the titles that have only one.
  List<Episode> get _filteredEps {
    final want = _scanlator;
    if (want == null) return widget.seasonEps;
    return [
      for (final e in widget.seasonEps)
        if (e.scanlator?.trim() == want) e,
    ];
  }

  List<Episode> get _displayEps {
    final episodes = _filteredEps;
    return _reverseList ? episodes.reversed.toList(growable: false) : episodes;
  }

  /// Reading progress lives in [ReadStore] (page index / scroll permille),
  /// keyed by showId — the video [ResumeStore] never holds a mark for a
  /// chapter, so without this a read chapter could never dim. Also OR's in
  /// the connected tracker's chapter progress ([_EpisodesTab.trackerProgress]),
  /// same idea as [_stateFor]'s watched calc for video — a chapter you've
  /// only read on AniList/MAL should dim too. No seasons in reading, so no
  /// hasMultipleSeasons guard is needed here.
  ({bool watched, bool inProgress, bool resume, double fraction}) _readStateFor(
    Episode ep,
  ) {
    final store = sl<ReadStore>();
    // Read marks are keyed by the SOURCE that owns the chapters, which is
    // [downloadSourceId] (`detail.sourceId`) — not [sourceId], which for a
    // metadata title is the `zm` pseudo-source. The reader writes under the
    // real source for the same reason it fetches pages with it, so looking
    // them up under `zm` found nothing and a finished chapter never dimmed.
    final readSource = widget.downloadSourceId.isNotEmpty
        ? widget.downloadSourceId
        : widget.sourceId;
    final mark = store.get(readSource, widget.showId, ep.id);
    final done = store.finished(readSource, widget.showId, ep.id);
    final inProgress = mark != null && !done && mark.total > 0;
    final watched =
        done ||
        (widget.trackerProgress != null &&
            ep.number != null &&
            ep.number! <= widget.trackerProgress!);
    return (
      watched: watched,
      inProgress: inProgress,
      // No CONTINUE badge in the reading row, and the resume index we're
      // handed is the video one — so never claim a resume here.
      resume: false,
      fraction: watched ? 1.0 : (inProgress ? (mark.pos / mark.total).clamp(0.0, 1.0) : 0.0),
    );
  }

  ({bool watched, bool inProgress, bool resume, double fraction}) _stateFor(
    ResumeStore store,
    Episode ep,
    int fullIndex,
  ) {
    if (widget.isReading) return _readStateFor(ep);
    final mark = store.get(widget.sourceId, widget.showUrl, ep.id);
    final inProgress =
        mark != null && !mark.finished && mark.duration > Duration.zero;
    // Watched = finished locally, OR at/below the tracker's watched count.
    // Only applied to single-season shows, where episode numbers map cleanly
    // to the tracker's per-entry progress (avoids mis-greying across seasons).
    final epNum = ep.number?.toInt();
    final watched =
        (mark != null && mark.finished) ||
        (widget.trackerProgress != null &&
            !widget.hasMultipleSeasons &&
            epNum != null &&
            epNum <= widget.trackerProgress!);
    final resume =
        widget.hasAnyMark && fullIndex == widget.resumeIndex(widget.eps);
    final fraction = watched
        ? 1.0
        : (inProgress
            ? (mark.position.inMilliseconds / mark.duration.inMilliseconds).clamp(0.0, 1.0)
            : 0.0);
    return (
      watched: watched,
      inProgress: inProgress,
      resume: resume,
      fraction: fraction,
    );
  }

  Future<void> _jump() async {
    final n = await showDialog<int>(
      context: context,
      builder: (_) => const _JumpDialog(),
    );
    if (n == null || !mounted) return;
    // Match by episode number; fall back to a 1-based position. Searched in
    // the FILTERED list, so jumping while a scanlator is picked lands on that
    // group's chapter rather than a position in the unfiltered run.
    final eps = _displayEps;
    var local = eps.indexWhere((e) => e.number?.toInt() == n);
    if (local < 0 && n >= 1 && n <= eps.length) {
      local = episodePositionForNumber(n, eps.length, reversed: _reverseList);
    }
    if (local < 0) return;
    setState(() {
      _rangeIndex = episodeRangeIndex(
        local,
        total: eps.length,
        reversed: _reverseList,
      );
      _grid = true; // the grid makes the jumped-to episode easy to spot
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.seasonEps.isEmpty) {
      if (widget.loading) return const _EpisodeListSkeleton();
      return EmptyState(
        icon: Icons.video_library_outlined,
        message: context.l10n.noEpisodesAvailableFromThisSource,
        actionLabel: widget.onSwitchSource == null
            ? null
            : context.l10n.switchSource,
        onAction: widget.onSwitchSource,
      );
    }
    final store = sl<ResumeStore>();
    final eps = _filteredEps;
    final displayEps = _displayEps;
    final total = eps.length;
    // A group with fewer chapters than the one before it can leave the range
    // index past the end, so clamp before slicing.
    final maxRange = _rangeCount == 0 ? 0 : _rangeCount - 1;
    final rangeIndex = _rangeIndex.clamp(0, maxRange);
    final slice = episodeRangeSlice(rangeIndex, total, reversed: _reverseList);
    final visible = displayEps.sublist(slice.start, slice.end);
    final showRanges = _rangeCount > 1;
    final groups = _scanlators;

    // One scrollable (slivers): the header + chips scroll with the list so the
    // tab can never overflow when the NestedScrollView hands it a tiny height
    // during a layout pass (the Column+Expanded version did).
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _EpisodesHeader(
            hasMultipleSeasons: widget.hasMultipleSeasons,
            seasons: widget.seasonSet.toList()..sort(),
            currentSeason: widget.currentSeason,
            onSelectSeason: widget.onSelectSeason,
            onRefresh: widget.onRefresh,
            reverseList: _reverseList,
            onToggleReverseList: () => setState(() {
              _reverseList = !_reverseList;
              if (_rangeCount > 0) {
                _rangeIndex = _rangeCount - 1 - _rangeIndex;
              }
            }),
            grid: _grid,
            onToggleView: () => setState(() => _grid = !_grid),
            onJump: showRanges ? _jump : null,
            isReading: widget.isReading,
            onBulkDownload: widget.onDownloadMany != null && !sl<AppMode>().isTv
                ? () => _openBulkDownload(eps)
                : null,
          ),
        // Only when the tracker says the show is still airing. Sits under the
        // header so it reads as part of the episode list rather than another
        // thing competing with the hero.
        // Only when a title actually has more than one group — a single
        // scanlator needs no picker, and most titles have exactly one.
        if (groups.length > 1)
          _RangeChips(
              count: groups.length + 1,
              selected: _scanlator == null
                  ? 0
                  : groups.indexOf(_scanlator!) + 1,
              labelFor: (i) => i == 0 ? context.l10n.all : groups[i - 1],
              onSelect: (i) => setState(() {
                _scanlator = i == 0 ? null : groups[i - 1];
                _rangeIndex = 0;
              }),
            ),
        if (showRanges)
          _RangeChips(
              count: _rangeCount,
              selected: rangeIndex,
              labelFor: (i) =>
                  episodeRangeLabel(displayEps, i, reversed: _reverseList),
              onSelect: (i) => setState(() {
                _rangeIndex = i;
              }),
            ),
        if (_grid)
          _buildGrid(store, visible, slice.start, total)
        else
          _buildList(store, visible, slice.start, total),
        const SizedBox(height: 48),
      ],
    );
  }

  /// Opens the chapter batch sheet. "Next N" follows the reader's saved
  /// resume target, while "All" retains its original whole-list behavior.
  void _openBulkDownload(List<Episode> eps) {
    final store = sl<ChapterDownloadStore>();
    final downloader = sl<ChapterDownloader>();
    final unavailableUrls = <String>{};
    for (final chapter in eps) {
      final id = ChapterDownload.idFor(widget.downloadSourceId, chapter.url);
      if (store.isDownloaded(widget.downloadSourceId, chapter.url) ||
          downloader.isBusy(id)) {
        unavailableUrls.add(chapter.url);
      }
    }
    final pending = selectChapterDownloadRange(
      chapters: eps,
      fromIndex: 0,
      toIndex: eps.length - 1,
      unavailableUrls: unavailableUrls,
    );

    if (pending.isEmpty) {
      showAppToast(context, context.l10n.everyChapterIsAlreadyDownloaded);
      return;
    }

    final resume = widget.resumeChapter;
    final startIndex = resolveChapterDownloadStartIndex(
      chapters: eps,
      resumeChapterId: resume?.id,
      resumeChapterUrl: resume?.url,
      resumeChapterNumber: resume?.number,
    );
    // We only need to know whether each offered preset can be filled. Capping
    // this probe at the largest preset avoids allocating the entire tail of a
    // very long chapter list merely to build the sheet.
    final fromResume = selectNextChapterDownloads(
      chapters: eps,
      startIndex: startIndex,
      count: 50,
      unavailableUrls: unavailableUrls,
    );
    final counts = [
      for (final n in [10, 25, 50])
        if (fromResume.length >= n && !(startIndex == 0 && pending.length == n))
          n,
    ];

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      barrierColor: Colors.black54,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textTertiary.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      context.l10n.downloadChapters,
                      style: AppText.headline,
                    ),
                  ),
                  Text(
                    context.l10n.notSavedCount(pending.length),
                    style: AppText.caption,
                  ),
                ],
              ),
            ),
            for (final n in counts)
              Builder(
                builder: (context) {
                  final chapters = selectNextChapterDownloads(
                    chapters: eps,
                    startIndex: startIndex,
                    count: n,
                    unavailableUrls: unavailableUrls,
                  );
                  final first = eps.indexOf(chapters.first);
                  final last = eps.indexOf(chapters.last);
                  return ListTile(
                    leading: Icon(
                      Icons.file_download_outlined,
                      color: AppColors.accent,
                    ),
                    title: Text(
                      context.l10n.nextCount(n),
                      style: AppText.body.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      '${chapterNumberLabel(eps, first)} – '
                      '${chapterNumberLabel(eps, last)}',
                      style: AppText.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _enqueueAll(chapters);
                    },
                  );
                },
              ),
            ListTile(
              leading: Icon(Icons.tune_rounded, color: AppColors.accent),
              title: Text(
                context.l10n.custom,
                style: AppText.body.copyWith(color: AppColors.textPrimary),
              ),
              onTap: () async {
                Navigator.pop(sheetContext);
                final range = await showModalBottomSheet<({int from, int to})>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: AppColors.surface,
                  barrierColor: Colors.black54,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  builder: (_) => ChapterDownloadRangeSheet(
                    chapters: eps,
                    initialFromIndex: startIndex,
                    initialToIndex: (startIndex + 9).clamp(0, eps.length - 1),
                    unavailableUrls: unavailableUrls,
                  ),
                );
                if (range == null || !mounted) return;
                final chapters = selectChapterDownloadRange(
                  chapters: eps,
                  fromIndex: range.from,
                  toIndex: range.to,
                  unavailableUrls: unavailableUrls,
                );
                if (chapters.isNotEmpty) _enqueueAll(chapters);
              },
            ),
            ListTile(
              leading: Icon(
                Icons.download_for_offline_outlined,
                color: AppColors.accent,
              ),
              title: Text(
                context.l10n.allCount(pending.length),
                style: AppText.body.copyWith(color: AppColors.textPrimary),
              ),
              subtitle: pending.length > 50
                  ? Text(
                      context.l10n.thisWillTakeAWhileAndUseALotOfStorage,
                      style: AppText.caption,
                    )
                  : null,
              onTap: () {
                Navigator.pop(sheetContext);
                _enqueueAll(pending);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _enqueueAll(List<Episode> chapters) async {
    // A long series can be thousands of chapters, and one tap shouldn't commit
    // to that much storage and traffic without saying so out loud.
    if (chapters.length > 50) {
      final ok = await AppDialog.confirm(
        context,
        title: context.l10n.downloadChaptersQuestion(chapters.length),
        message: context.l10n.chapterOneAtATimeWarning,
        confirmLabel: context.l10n.download,
      );
      if (ok != true) return;
      if (!mounted) return;
    }
    await widget.onDownloadMany!(chapters);
    if (!mounted) return;
    showAppToast(context, context.l10n.queuedChapters(chapters.length));
  }

  Widget _buildList(
    ResumeStore store,
    List<Episode> visible,
    int offset,
    int total,
  ) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: visible.length,
      itemBuilder: (context, i) {
        final ep = visible[i];
        final fullIndex = widget.eps.indexOf(ep);
        final st = _stateFor(store, ep, fullIndex);
        final fallbackNumber = _reverseList
            ? total - offset - i
            : offset + i + 1;
        final epNum = ep.number?.toInt() ?? fallbackNumber;
        final displayTitle = widget.hasMultipleSeasons
            ? cleanTitle(ep.title)
            : ep.title;
        if (widget.isReading) {
          return RepaintBoundary(
            child: _ChapterRow(
              ep: ep,
              number: epNum,
              displayTitle: displayTitle,
              coverUrl: widget.coverUrl,
              coverHeaders: widget.coverHeaders,
              isRead: st.watched,
              isInProgress: st.inProgress,
              fraction: st.fraction,
              onTap: () => widget.onOpen(fullIndex),
              onLongPress: widget.onEpisodeMenu == null
                  ? null
                  : () => widget.onEpisodeMenu!(fullIndex),
              onDownload: () => widget.onDownload(ep),
              sourceId: widget.sourceId,
              downloadSourceId: widget.downloadSourceId,
            ),
          );
        }
        return RepaintBoundary(
                    child: _EpisodeRow(
            ep: ep,
            epNum: epNum,
            displayTitle: displayTitle,
            filler: widget.fillerEps.contains(epNum),
            coverUrl: widget.coverUrl,
            coverHeaders: widget.coverHeaders,
            isWatched: st.watched,
            isInProgress: st.inProgress,
            isResume: st.resume,
            fraction: st.fraction,
            onTap: () => widget.onOpen(fullIndex),
            onLongPress: widget.onEpisodeMenu == null
                ? null
                : () => widget.onEpisodeMenu!(fullIndex),
            onDownload: () => widget.onDownload(ep),
            sourceId: widget.sourceId,
            showId: widget.showId,
            showPopularity: widget.showPopularity,
            totalEpisodes: widget.totalEpisodes ?? widget.eps.length,
            isAiring: widget.isAiring,
          ),
        );
      },
    );
  }

  Widget _buildGrid(
    ResumeStore store,
    List<Episode> visible,
    int offset,
    int total,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 5,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.15,
        ),
        itemCount: visible.length,
        itemBuilder: (context, i) {
          final ep = visible[i];
          final fullIndex = widget.eps.indexOf(ep);
          final st = _stateFor(store, ep, fullIndex);
          final fallbackNumber = _reverseList
              ? total - offset - i
              : offset + i + 1;
          final epNum = ep.number?.toInt() ?? fallbackNumber;
          return RepaintBoundary(
            child: _EpisodeGridTile(
            number: epNum,
            isWatched: st.watched,
            isInProgress: st.inProgress,
            isResume: st.resume,
            isFiller: ep.filler,
            fraction: st.fraction,
            available: ep.available,
            onTap: () => widget.onOpen(fullIndex),
            onLongPress: widget.onEpisodeMenu == null
                ? null
                : () => widget.onEpisodeMenu!(fullIndex),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Episodes header — Netflix-style season dropdown (multi-season) that opens a
// dark bottom sheet to pick a season, or a plain "Episodes" label otherwise.
// ─────────────────────────────────────────────────────────────────────────────

class _EpisodesHeader extends StatelessWidget {
  const _EpisodesHeader({
    required this.hasMultipleSeasons,
    required this.seasons,
    required this.currentSeason,
    required this.onSelectSeason,
    this.onRefresh,
    required this.reverseList,
    required this.onToggleReverseList,
    required this.grid,
    required this.onToggleView,
    this.onJump,
    this.isReading = false,
    this.onBulkDownload,
  });

  final bool hasMultipleSeasons;
  final List<int> seasons;
  final int currentSeason;
  final ValueChanged<int> onSelectSeason;

  /// Force-refresh the list past the source cache; null hides the menu item.
  final Future<void> Function()? onRefresh;
  final bool reverseList;
  final VoidCallback onToggleReverseList;

  /// Whether the grid view is active (toggles the view icon).
  final bool grid;
  final VoidCallback onToggleView;

  /// Jump-to-episode; null hides the button (short seasons don't need it).
  final VoidCallback? onJump;

  /// True for reading types — the single-season label reads "Chapters".
  final bool isReading;

  /// Download a run of chapters at once; null hides the button. Reading only —
  /// a 200-chapter manga one tap at a time isn't a feature.
  final VoidCallback? onBulkDownload;

  Widget _circle(IconData icon, VoidCallback onTap, {String? semanticLabel}) =>
      Semantics(
        button: true,
        label: semanticLabel,
        child: Material(
          color: AppColors.surface2,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(icon, color: AppColors.textPrimary, size: 20),
            ),
          ),
        ),
      );

  Future<void> _openSheet(BuildContext context) async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: AppColors.surface,
      barrierColor: Colors.black54,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) =>
          _SeasonSheet(seasons: seasons, currentSeason: currentSeason),
    );
    if (picked != null) onSelectSeason(picked);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      child: Row(
        children: [
          // Left: season dropdown pill (multi-season) or a plain label.
          Expanded(
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: hasMultipleSeasons
                  ? Material(
                      color: AppColors.surface2,
                      borderRadius: BorderRadius.circular(10),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => _openSheet(context),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(13, 8, 10, 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                context.l10n.seasonNumber(currentSeason),
                                style: AppText.headline,
                              ),
                              const SizedBox(width: 6),
                              const Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: AppColors.textPrimary,
                                size: 22,
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : Text(
                      isReading ? context.l10n.chapters : context.l10n.episodes,
                      style: AppText.headline,
                    ),
            ),
          ),
          // Right: jump-to-episode (long seasons) · list/grid toggle · ⓘ info.
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (onBulkDownload != null) ...[
                _circle(
                  Icons.download_rounded,
                  onBulkDownload!,
                  semanticLabel: context.l10n.downloadChapters,
                ),
                const SizedBox(width: 8),
              ],
              if (onJump != null) ...[
                _circle(
                  Icons.search_rounded,
                  onJump!,
                  semanticLabel: context.l10n.findEpisode,
                ),
                const SizedBox(width: 8),
              ],
              _circle(
                grid ? Icons.view_list_rounded : Icons.grid_view_rounded,
                onToggleView,
                semanticLabel: grid
                    ? context.l10n.listView
                    : context.l10n.gridView,
              ),
              const SizedBox(width: 8),
              PopupMenuButton<_EpisodesHeaderAction>(
                tooltip: context.l10n.more,
                icon: const Icon(Icons.more_vert_rounded, size: 20),
                padding: EdgeInsets.zero,
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.surface2,
                  fixedSize: const Size.square(36),
                  minimumSize: const Size.square(36),
                  maximumSize: const Size.square(36),
                  padding: EdgeInsets.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: const CircleBorder(),
                ),
                color: AppColors.surface,
                surfaceTintColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                onSelected: (action) {
                  if (action == _EpisodesHeaderAction.reverseList) {
                    onToggleReverseList();
                    return;
                  }
                  onRefresh?.call();
                  showAppToast(
                    context,
                    isReading
                        ? context.l10n.refreshingChapters
                        : context.l10n.refreshingEpisodes,
                  );
                },
                itemBuilder: (context) => [
                  if (onRefresh != null)
                    PopupMenuItem(
                      value: _EpisodesHeaderAction.refresh,
                      child: Row(
                        children: [
                          const Icon(Icons.refresh_rounded, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              isReading
                                  ? context.l10n.refreshChapters
                                  : context.l10n.refreshEpisodes,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  PopupMenuItem(
                    value: _EpisodesHeaderAction.reverseList,
                    child: Row(
                      children: [
                        const Icon(Icons.swap_vert_rounded, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            context.l10n.reverseList,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: reverseList
                              ? const Icon(Icons.check_rounded, size: 18)
                              : null,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              // The ⓘ that used to sit here jumped to the Details tab — which
              // is a tap away in the tab bar directly above it. Two controls,
              // same destination, inches apart.
            ],
          ),
        ],
      ),
    );
  }
}

enum _EpisodesHeaderAction { refresh, reverseList }

// Dark, rounded-top bottom sheet listing the available seasons with a coral
// check on the current one. Returns the picked season via Navigator.pop.
class _SeasonSheet extends StatelessWidget {
  const _SeasonSheet({required this.seasons, required this.currentSeason});

  final List<int> seasons;
  final int currentSeason;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Grab handle.
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textTertiary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(context.l10n.seasons, style: AppText.title),
            ),
          ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.only(bottom: 8),
              itemCount: seasons.length,
              itemBuilder: (context0, i) {
                final s = seasons[i];
                final selected = s == currentSeason;
                return InkWell(
                  onTap: () => Navigator.of(context0).pop(s),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            context.l10n.seasonNumber(s),
                            style: AppText.body.copyWith(
                              color: selected
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                        if (selected)
                          Icon(
                            Icons.check_rounded,
                            color: AppColors.accent,
                            size: 22,
                          ),
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

// ─────────────────────────────────────────────────────────────────────────────
// Range chips — horizontal "1–50 / 51–100 / …" selector for long seasons so
// big anime stay navigable without endless scrolling. Selected chip is coral.
// ─────────────────────────────────────────────────────────────────────────────

class _RangeChips extends StatelessWidget {
  const _RangeChips({
    required this.count,
    required this.selected,
    required this.labelFor,
    required this.onSelect,
  });

  final int count;
  final int selected;
  final String Function(int) labelFor;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
        itemCount: count,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final sel = i == selected;
          return Material(
            color: sel ? AppColors.accent : AppColors.surface2,
            borderRadius: BorderRadius.circular(9),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => onSelect(i),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Center(
                  child: Text(
                    labelFor(i),
                    style: AppText.caption.copyWith(
                      color: sel ? Colors.white : AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Compact episode-number tile for the grid view — coral when it's the resume
// target, dimmed + ✓ when watched, a filler dot, and a resume bar when partly
// watched. Outlined briefly after a jump.
// ─────────────────────────────────────────────────────────────────────────────

class _EpisodeGridTile extends StatelessWidget {
  const _EpisodeGridTile({
    required this.number,
    required this.isWatched,
    required this.isInProgress,
    required this.isResume,
    required this.isFiller,
    required this.fraction,
    required this.onTap,
    this.onLongPress,
    this.available = true,
  });

  final int number;
  final bool isWatched;
  final bool isInProgress;
  final bool isResume;
  final bool isFiller;
  final double fraction;

  /// False when no matched source has this episode — see [Episode.available].
  final bool available;
  final VoidCallback onTap;

  /// Long-press opens the "play this episode with" sheet. Optional so the
  /// reading path can leave it off — a chapter opens the reader, where a
  /// player picker has nothing to say.
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final bg = isWatched ? AppColors.surface : AppColors.surface2;
    // Nothing has this one yet — same dimming the list row uses, so the two
    // views agree about which numbers will actually open.
    final fg = !available
        ? AppColors.textTertiary
        : (isWatched ? AppColors.textTertiary : AppColors.textPrimary);
    const side = BorderSide(color: AppColors.hairline, width: 0.5);

    return Material(
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: side,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Stack(
          children: [
            Center(
              child: Text(
                '$number',
                style: AppText.body.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (isResume)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _EpisodeProgressOutlinePainter(fraction: fraction),
                  ),
                ),
              ),
if (isFiller)
              const Positioned(
                top: 6,
                left: 6,
                child: SizedBox(
                  width: 6,
                  height: 6,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.textTertiary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _ThumbnailProgressBar(fraction: fraction),
            ),
          ],
        ),
      ),
    );
  }
}

// Small number-input dialog for "jump to episode".
class _JumpDialog extends StatefulWidget {
  const _JumpDialog();

  @override
  State<_JumpDialog> createState() => _JumpDialogState();
}

class _JumpDialogState extends State<_JumpDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(context).pop(int.tryParse(_ctrl.text.trim()));

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(context.l10n.goToEpisode, style: AppText.headline),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        keyboardType: TextInputType.number,
        style: AppText.body.copyWith(color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: context.l10n.episodeNumber,
          hintStyle: AppText.body.copyWith(color: AppColors.textTertiary),
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.cancel, style: AppText.body),
        ),
        TextButton(
          onPressed: _submit,
          child: Text(
            'Go',
            style: AppText.body.copyWith(color: AppColors.accent),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reading (manga/novel) chapter row — the minimal counterpart to _EpisodeRow.
// A 44×62 portrait cover (the series art, dimmed once read), the chapter title
// with no "14." prefix (sources put the number in the title already), a muted
// meta line, and a hairline accent bar while a chapter is part-read. No play
// glyph, no tick, no badges — none of that means anything for a chapter.
//
// Deliberately a separate widget rather than a flag inside _EpisodeRow: it
// needs a third of _EpisodeRow's inputs, and this way the streaming row's code
// is untouched.
// ─────────────────────────────────────────────────────────────────────────────

class _ChapterRow extends StatelessWidget {
  const _ChapterRow({
    required this.ep,
    required this.number,
    required this.displayTitle,
    required this.coverUrl,
    required this.coverHeaders,
    required this.isRead,
    required this.isInProgress,
    required this.fraction,
    required this.onTap,
    this.onLongPress,
    required this.onDownload,
    required this.sourceId,
    required this.downloadSourceId,
  });

  /// Key on the portrait cover — the one structural marker that tells a
  /// chapter row apart from an episode row (see chapter row tests).
  static const coverKey = Key('chapterCover');

  final Episode ep;
  final int number;
  final String displayTitle;
  final String coverUrl;
  final Map<String, String>? coverHeaders;
  final bool isRead;
  final bool isInProgress;
  final double fraction;
  final VoidCallback onTap;

  /// The chapter actions menu — mark read, mark this and all above. A chapter
  /// row is NOT an episode row (that's the point of this class), so it needs
  /// its own: wiring the menu up to [_EpisodeRow] alone left reading with no
  /// long-press at all.
  final VoidCallback? onLongPress;
  final VoidCallback onDownload;
  final String sourceId;

  /// The source holding the chapter files — the matched extension for a
  /// metadata title, where [sourceId] is the pseudo-source.
  final String downloadSourceId;

  @override
  Widget build(BuildContext context) {
    final title = displayTitle.trim().isNotEmpty
        ? displayTitle.trim()
        : context.l10n.chapterLabel(number);
    final meta = chapterMetaLine(context.l10n, ep);
    final art = (ep.thumbnail != null && ep.thumbnail!.isNotEmpty)
        ? ep.thumbnail!
        : coverUrl;

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      splashColor: AppColors.accentSoft,
      highlightColor: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Row(
          children: [
            SizedBox(
              key: coverKey,
              width: 40,
              height: 56,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: Opacity(
                  opacity: isRead ? 0.45 : 1,
                  child: art.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: art,
                          cacheManager: AppImageCache.cacheManagerOrDefault,
                          httpHeaders: coverHeaders,
                          fit: BoxFit.cover,
                          memCacheWidth: 140,
                          placeholder: (c, u) =>
                              ColoredBox(color: AppColors.surface2),
                          errorWidget: (c, u, e) =>
                              ColoredBox(color: AppColors.surface2),
                        )
                      : ColoredBox(color: AppColors.surface2),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: AppText.body.copyWith(
                      color: isRead
                          ? AppColors.textTertiary
                          : AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  // Dropped entirely when the source gives us nothing to put
                  // here, so the row shrinks instead of holding blank space.
                  if (meta != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      meta,
                      style: AppText.caption.copyWith(
                        color: isRead
                            ? AppColors.textTertiary
                            : AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (isInProgress && fraction > 0) ...[
                    const SizedBox(height: 6),
                    FractionallySizedBox(
                      widthFactor: fraction.clamp(0.0, 1.0),
                      alignment: AlignmentDirectional.centerStart,
                      child: Container(
                        height: 2,
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Same rule as the episode row: phone only. Reading is phone-only
            // anyway, but a TV chapter list would still reach this.
            if (!sl<AppMode>().isTv) ...[
              const SizedBox(width: 8),
              _ChapterDownloadIcon(
                sourceId: downloadSourceId,
                chapterUrl: ep.url,
                onDownload: onDownload,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Netflix episode block — a Column per episode (NO divider lines, whitespace
// instead):  Row[ rounded ~116px 16:9 thumb + centered play-circle (watched dim
// / ✓ / resume bar) | "N. Title" bold + date under + CONTINUE/FILLER badges |
// download icon ]  then, when the episode has a date, a muted line full-width
// below. Our model has no per-episode synopsis/duration, so we surface the air
// date in the below-row slot and omit it gracefully when absent (no faked data).
// ─────────────────────────────────────────────────────────────────────────────

class _EpisodeRow extends StatelessWidget {
  const _EpisodeRow({
    required this.ep,
    required this.epNum,
    required this.displayTitle,
    required this.coverUrl,
    required this.coverHeaders,
    required this.isWatched,
    required this.isInProgress,
    required this.isResume,
    required this.fraction,
    required this.onTap,
    this.onLongPress,
    required this.onDownload,
    required this.sourceId,
    required this.showId,
    this.filler = false,
    this.showPopularity,
    required this.totalEpisodes,
    required this.isAiring,
  });

  final Episode ep;
  final int epNum;
  final String displayTitle;
  final bool filler;
  final int? showPopularity;
  final int totalEpisodes;
  final bool isAiring;
  final String coverUrl;
  final Map<String, String>? coverHeaders;
  final bool isWatched;
  final bool isInProgress;
  final bool isResume;
  final double fraction;
  final VoidCallback onTap;

  /// Long-press opens the "play this episode with" sheet. Optional so the
  /// reading path can leave it off — a chapter opens the reader, where a
  /// player picker has nothing to say.
  final VoidCallback? onLongPress;
  final VoidCallback onDownload;
  final String sourceId;
  final String showId;

  @override
  Widget build(BuildContext context) {
    final unavailable = !ep.available;
    final titleColor = unavailable
        ? AppColors.textTertiary
        : (isWatched ? AppColors.textSecondary : AppColors.textPrimary);

    final srcTitle = displayTitle.trim();
    final titleText =
        episodeDisplayTitle(ep, sourceTitle: srcTitle, number: epNum) ?? '';
    final heading = titleText.isNotEmpty
        ? titleText
        : context.l10n.episodeLabel(epNum);
    final episodeDate = ep.date?.trim();
    String? dateLabel;
    if (episodeDate != null && episodeDate.isNotEmpty) {
      final parsedDate = DateTime.tryParse(episodeDate);
      if (parsedDate == null) {
        dateLabel = relativeDate(context.l10n, episodeDate);
      } else if (isAiring) {
        final now = DateTime.now();
        final age = now.difference(parsedDate);
        final isDateOnly = !episodeDate.contains('T') && !episodeDate.contains(':');
        final ageDays = DateTime(now.year, now.month, now.day)
            .difference(DateTime(parsedDate.year, parsedDate.month, parsedDate.day)).inDays;
        if (age >= Duration.zero && age < const Duration(days: 7)) {
          if (isDateOnly) {
            dateLabel = ageDays <= 0 ? 'hari ini' : '$ageDays hari lalu';
          } else if (age.inMinutes < 60) {
            dateLabel = '${age.inMinutes.clamp(1, 59)} menit lalu';
          } else if (age.inHours < 24) {
            dateLabel = '${age.inHours} jam lalu';
          } else {
            dateLabel = '${age.inDays} hari lalu';
          }
        }
      }
      if (dateLabel == null) {
        const months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
          'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
        final absoluteDate = parsedDate == null
            ? relativeDate(context.l10n, episodeDate)
            : '${months[parsedDate.month - 1]} ${parsedDate.day} ${parsedDate.year}';
        dateLabel = parsedDate != null && isAiring && dateLabel != null
            ? '$absoluteDate ($dateLabel)'
            : absoluteDate;
      }
    }
    final progress = totalEpisodes <= 1
        ? 0.0
        : ((epNum - 1) / (totalEpisodes - 1)).clamp(0.0, 1.0);
    final viewers = showPopularity == null
        ? null
        : (showPopularity! * math.pow(0.4, progress)).round();
    String compact(int value) => value >= 100000
        ? '${(value / 1000).round()}k'
        : value >= 1000
            ? '${(value / 1000).toStringAsFixed(1)}k'
            : value.toString();
    final metaParts = <String>[
      viewers == null ? '—' : compact(viewers),
      if (dateLabel != null && dateLabel.isNotEmpty) dateLabel,
      if (unavailable && ep.unavailable?.trim().isNotEmpty == true) ep.unavailable!.trim(),
    ];
    final metaLine = metaParts.join('  ·  ');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 3, 16, 3),
      child: Material(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(9),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          splashColor: AppColors.accentSoft,
          highlightColor: AppColors.surface,
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(9, 7, 7, 7),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 34,
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '$epNum',
                        style: AppText.body.copyWith(
                          color: unavailable ? AppColors.textTertiary : AppColors.accent,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AutoTranslatedText(
                            text: heading,
                            style: AppText.body.copyWith(
                              color: titleColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              height: 1.25,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (metaLine.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Row(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(Icons.visibility_outlined, size: 12, color: AppColors.textSecondary),
                              const SizedBox(width: 3),
                              Flexible(child: Text(metaLine, maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: AppText.caption.copyWith(fontSize: 10, color: AppColors.textSecondary))),
                            ]),
                          ],
                          if (filler) ...[
                            const SizedBox(height: 5),
                            Row(
                              children: [
                                if (filler) TagBadge(text: context.l10n.fillerBadge),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (!sl<AppMode>().isTv) ...[
                      const SizedBox(width: 5),
                      _EpisodeDownloadIcon(
                        sourceId: sourceId,
                        showId: showId,
                        episodeId: ep.id,
                        onTap: onDownload,
                      ),
                    ],
                  ],
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _ThumbnailProgressBar(fraction: fraction),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Per-chapter download icon (manga/novel). Watches the downloader for live
// progress and the store for what's already saved, so only this row rebuilds.
// A chapter that failed shows the plain download glyph again — enqueueing it
// again is the retry, and it picks up the pages already in the .part folder.
class _ChapterDownloadIcon extends StatelessWidget {
  const _ChapterDownloadIcon({
    required this.sourceId,
    required this.chapterUrl,
    required this.onDownload,
  });

  final String sourceId;
  final String chapterUrl;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final downloader = sl<ChapterDownloader>();
    final store = sl<ChapterDownloadStore>();
    final id = ChapterDownload.idFor(sourceId, chapterUrl);
    return ListenableBuilder(
      listenable: Listenable.merge([downloader, store.listenable()]),
      builder: (context, _) {
        final live = downloader.inFlight[id];
        if (live != null) {
          return _button(
            tooltip: context.l10n.cancelDownload,
            onPressed: () => unawaited(downloader.cancel(id)),
            icon: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                value: live.progress > 0 ? live.progress : null,
                strokeWidth: 2.4,
                color: AppColors.accent,
                backgroundColor: AppColors.surface2,
              ),
            ),
          );
        }
        if (store.isDownloaded(sourceId, chapterUrl)) {
          return _button(
            tooltip: context.l10n.downloaded,
            onPressed: () => _offerDelete(context, store, id),
            icon: Icon(
              Icons.check_circle_rounded,
              color: AppColors.accent,
              size: 24,
            ),
          );
        }
        return _button(
          tooltip: context.l10n.downloadChapter,
          onPressed: onDownload,
          icon: const Icon(
            Icons.file_download_outlined,
            color: AppColors.textPrimary,
            size: 24,
          ),
        );
      },
    );
  }

  Widget _button({
    required String tooltip,
    required VoidCallback onPressed,
    required Widget icon,
  }) => IconButton(
    onPressed: onPressed,
    visualDensity: VisualDensity.compact,
    splashRadius: 22,
    tooltip: tooltip,
    icon: icon,
  );

  void _offerDelete(
    BuildContext context,
    ChapterDownloadStore store,
    String id,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      barrierColor: Colors.black54,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                Icons.delete_outline_rounded,
                color: AppColors.accent,
              ),
              title: Text(
                context.l10n.deleteDownload,
                style: AppText.body.copyWith(color: AppColors.accent),
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                unawaited(store.remove(id));
              },
            ),
          ],
        ),
      ),
    );
  }
}

// Per-episode download icon — self-updates from the DownloadManager so the
// row reflects live progress without the whole list rebuilding.
class _EpisodeDownloadIcon extends StatelessWidget {
  const _EpisodeDownloadIcon({
    required this.sourceId,
    required this.showId,
    required this.episodeId,
    required this.onTap,
  });

  final String sourceId;
  final String showId;
  final String episodeId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final manager = sl<DownloadManager>();
    return ListenableBuilder(
      listenable: manager,
      builder: (context, _) {
        final rec = manager.recordFor(sourceId, showId, episodeId);
        final s = rec?.status;
        // While a download is live (or paused/queued/resolving), tapping the ring
        // opens a Pause/Cancel menu instead of re-opening the server picker.
        final inProgress =
            rec != null &&
            (s == DownloadStatus.downloading ||
                s == DownloadStatus.paused ||
                s == DownloadStatus.queued ||
                s == DownloadStatus.resolving);
        return _glyph(
          context.l10n,
          s,
          rec?.progress ?? 0,
          onPressed: inProgress
              ? () => _showDownloadMenu(context, manager, rec)
              : onTap,
        );
      },
    );
  }

  Widget _glyph(
    AppLocalizations l10n,
    DownloadStatus? status,
    double progress, {
    required VoidCallback onPressed,
  }) {
    final child = switch (status) {
      DownloadStatus.done => Icon(
        Icons.download_done_rounded,
        color: AppColors.accent,
        size: 24,
      ),
      DownloadStatus.downloading || DownloadStatus.paused => SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          value: progress > 0 ? progress : null,
          strokeWidth: 2.4,
          color: AppColors.accent,
          backgroundColor: AppColors.surface2,
        ),
      ),
      DownloadStatus.queued || DownloadStatus.resolving => const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppColors.textSecondary,
        ),
      ),
      DownloadStatus.unsupported => const Icon(
        Icons.cloud_off_outlined,
        color: AppColors.textTertiary,
        size: 22,
      ),
      DownloadStatus.failed => Icon(
        Icons.refresh_rounded,
        color: AppColors.accent,
        size: 24,
      ),
      // null (never downloaded) or canceled → offer to download.
      _ => const Icon(
        Icons.file_download_outlined,
        color: AppColors.textPrimary,
        size: 24,
      ),
    };
    final label = switch (status) {
      DownloadStatus.done => l10n.downloaded,
      DownloadStatus.downloading || DownloadStatus.paused => l10n.downloading,
      DownloadStatus.queued || DownloadStatus.resolving => l10n.downloading,
      DownloadStatus.unsupported => l10n.downloadUnsupported,
      DownloadStatus.failed => l10n.retryDownload,
      _ => l10n.downloadEpisode,
    };
    return IconButton(
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      splashRadius: 22,
      tooltip: label,
      icon: child,
    );
  }

  // Tap on a live download's ring → a small Pause/Resume + Cancel sheet, rather
  // than the server picker (which only makes sense before a download starts).
  void _showDownloadMenu(
    BuildContext context,
    DownloadManager manager,
    DownloadRecord rec,
  ) {
    final l10n = context.l10n;
    final paused = rec.status == DownloadStatus.paused;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      barrierColor: Colors.black54,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                color: AppColors.textPrimary,
              ),
              title: Text(
                paused ? l10n.resumeDownload : l10n.pauseDownload,
                style: AppText.body.copyWith(color: AppColors.textPrimary),
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                if (paused) {
                  manager.resume(rec);
                } else {
                  manager.pause(rec);
                }
              },
            ),
            ListTile(
              leading: Icon(Icons.close_rounded, color: AppColors.accent),
              title: Text(
                l10n.cancelDownload,
                style: AppText.body.copyWith(color: AppColors.accent),
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                manager.cancel(rec);
              },
            ),
          ],
        ),
      ),
    );
  }
}


class _EpisodeProgressOutlinePainter extends CustomPainter {
  const _EpisodeProgressOutlinePainter({required this.fraction});

  final double fraction;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        rect.deflate(1),
        const Radius.circular(10),
      ));
    final metric = path.computeMetrics().first;
    final progress = fraction.clamp(0.0, 1.0);
    if (progress <= 0) return;
    final paint = Paint()
      ..color = AppColors.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(metric.extractPath(0, metric.length * progress), paint);
  }

  @override
  bool shouldRepaint(covariant _EpisodeProgressOutlinePainter oldDelegate) =>
      oldDelegate.fraction != fraction;
}
