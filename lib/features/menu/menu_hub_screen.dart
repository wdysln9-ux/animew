import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../../core/hive/safe_box.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import 'menu_tools_screen.dart';
import 'menu_forum_screen.dart';
import 'menu_social_screen.dart';
import 'menu_native_services_screen.dart';

enum _MenuGroup { community, fun, anime }

class _MenuFeature {
  const _MenuFeature(this.id, this.title, this.description, this.group, this.icon, this.tag);
  final String id, title, description, tag;
  final _MenuGroup group;
  final IconData icon;
}

const _features = <_MenuFeature>[
  _MenuFeature('feed', 'Feed', 'Aktivitas dan kabar terbaru dari komunitas anime.', _MenuGroup.community, Icons.dynamic_feed_rounded, 'COMMUNITY'),
  _MenuFeature('forum', 'Forum', 'Diskusi, rekomendasi, dan obrolan seputar anime.', _MenuGroup.community, Icons.forum_rounded, 'DISCUSS'),
  _MenuFeature('chess', 'Catur', 'Tantang pemain lain dalam pertandingan online.', _MenuGroup.fun, Icons.grid_4x4_rounded, 'ONLINE'),
  _MenuFeature('shorts', 'Short', 'Video singkat dari sumber pilihanmu.', _MenuGroup.fun, Icons.play_circle_fill_rounded, 'VIDEO'),
  _MenuFeature('quiz', 'Kuis Anime', 'Uji ingatan dan pengetahuan anime.', _MenuGroup.fun, Icons.quiz_rounded, 'PLAY'),
  _MenuFeature('music', 'Musik', 'Temukan dan dengarkan musik dari katalog terbuka.', _MenuGroup.fun, Icons.graphic_eq_rounded, 'LISTEN'),
  _MenuFeature('roulette', 'Anime Roulette', 'Temukan anime baru lewat pilihan acak.', _MenuGroup.anime, Icons.casino_rounded, 'DISCOVER'),
  _MenuFeature('news', 'Anime News', 'Ikuti kabar terbaru dari dunia anime.', _MenuGroup.anime, Icons.newspaper_rounded, 'LATEST'),
  _MenuFeature('screenshots', 'Screenshot Gallery', 'Simpan dan jelajahi koleksi screenshot.', _MenuGroup.anime, Icons.photo_library_rounded, 'GALLERY'),
];

const _labels = {
  _MenuGroup.community: 'Komunitas',
  _MenuGroup.fun: 'Hiburan',
  _MenuGroup.anime: 'Anime',
};

class MenuHubScreen extends StatefulWidget {
  const MenuHubScreen({super.key});
  @override
  State<MenuHubScreen> createState() => _MenuHubScreenState();
}

class _MenuHubScreenState extends State<MenuHubScreen> {
  static const _boxName = 'menu_hub_prefs';
  static const _enabledKey = 'enabled_features';
  Box? _box;
  Set<String> _enabled = _features.map((f) => f.id).toSet();
  _MenuGroup? _group;
  String _query = '';
  bool _loading = true;
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final box = Hive.isBoxOpen(_boxName) ? Hive.box(_boxName) : await openBoxSafely(_boxName);
      final saved = box.get(_enabledKey);
      if (saved is List) {
        final valid = saved.whereType<String>().toSet();
        _enabled = _features.where((f) => valid.contains(f.id)).map((f) => f.id).toSet();
      }
      _box = box;
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _toggle(_MenuFeature feature) async {
    setState(() {
      if (_enabled.contains(feature.id)) {
        _enabled.remove(feature.id);
      } else {
        _enabled.add(feature.id);
      }
    });
    await _box?.put(_enabledKey, _enabled.toList());
  }

  List<_MenuFeature> get _visible => _features.where((f) =>
      (_group == null || f.group == _group) &&
      (_query.isEmpty || f.title.toLowerCase().contains(_query.toLowerCase()) || f.description.toLowerCase().contains(_query.toLowerCase())) &&
      (_editing || _enabled.contains(f.id))).toList();

  @override
  Widget build(BuildContext context) {
    final rows = _visible;
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Ruang eksplorasi', style: AppText.caption.copyWith(color: AppColors.accent, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
                        const SizedBox(height: 5),
                        Text('Menu', style: AppText.headline.copyWith(color: AppColors.textPrimary, fontSize: 30, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 4),
                        Text('Temukan sesuatu yang seru hari ini.', style: AppText.body.copyWith(color: AppColors.textSecondary)),
                      ]),
                    ),
                    IconButton.filledTonal(
                      tooltip: _editing ? 'Selesai' : 'Atur fitur',
                      onPressed: () => setState(() => _editing = !_editing),
                      icon: Icon(_editing ? Icons.check_rounded : Icons.tune_rounded),
                      style: IconButton.styleFrom(foregroundColor: AppColors.accent, backgroundColor: AppColors.accentSoft),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.accent.withValues(alpha: .24), AppColors.surface, AppColors.surface2],
                    ),
                    border: Border.all(color: AppColors.accent.withValues(alpha: .16)),
                  ),
                  child: Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(_editing ? 'Atur ruangmu' : 'Lebih dari sekadar anime', style: AppText.title.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 5),
                      Text(_editing ? 'Pilih fitur yang ingin kamu tampilkan.' : 'Komunitas, hiburan, dan hal baru untuk dijelajahi.', style: AppText.caption.copyWith(color: AppColors.textSecondary, height: 1.45)),
                    ])),
                    const SizedBox(width: 12),
                    Container(width: 54, height: 54, decoration: BoxDecoration(color: AppColors.accentSoft, borderRadius: BorderRadius.circular(18)), child: Icon(Icons.auto_awesome_rounded, color: AppColors.accent, size: 29)),
                  ]),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: TextField(
                  onChanged: (value) => setState(() => _query = value.trim()),
                  style: AppText.body.copyWith(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Cari fitur...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    filled: true,
                    fillColor: AppColors.surface,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(17), borderSide: BorderSide.none),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(17), borderSide: BorderSide(color: AppColors.hairline)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(17), borderSide: BorderSide(color: AppColors.accent.withValues(alpha: .65))),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _filterChip('Semua', _group == null, () => setState(() => _group = null)),
                    for (final group in _MenuGroup.values) _filterChip(_labels[group]!, _group == group, () => setState(() => _group = group)),
                  ],
                ),
              ),
            ),
            if (_editing)
              SliverToBoxAdapter(child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Text('Ketuk kartu untuk menampilkan atau menyembunyikan fitur.', style: AppText.caption.copyWith(color: AppColors.textTertiary)),
              )),
            if (_loading)
              const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
            else if (rows.isEmpty)
              SliverFillRemaining(child: Center(child: Text('Tidak ada fitur yang cocok.', style: AppText.body.copyWith(color: AppColors.textSecondary))))
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.35,
                  ),
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final feature = rows[index];
                    return _FeatureCard(
                      feature: feature,
                      enabled: _enabled.contains(feature.id),
                      editing: _editing,
                      onTap: () => _editing ? _toggle(feature) : _openFeature(feature),
                    );
                  }, childCount: rows.length),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String label, bool selected, VoidCallback onTap) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.accentSoft,
      backgroundColor: AppColors.surface,
      side: BorderSide(color: selected ? AppColors.accent.withValues(alpha: .45) : AppColors.hairline),
      labelStyle: AppText.caption.copyWith(color: selected ? AppColors.accent : AppColors.textSecondary, fontWeight: selected ? FontWeight.w800 : FontWeight.w600),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );

  void _openFeature(_MenuFeature feature) {
    final Widget page = switch (feature.id) {
      'feed' => const MenuSocialScreen(featureId: 'feed'),
      'forum' => const MenuForumScreen(),
      'chess' || 'shorts' || 'music' || 'news' => MenuNativeServicesScreen(featureId: feature.id),
      'quiz' || 'roulette' || 'screenshots' => MenuToolsScreen(featureId: feature.id),
      _ => const SizedBox.shrink(),
    };
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({required this.feature, required this.enabled, required this.editing, required this.onTap});
  final _MenuFeature feature;
  final bool enabled;
  final bool editing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(21),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Stack(children: [
        Positioned(right: -20, top: -22, child: Container(width: 92, height: 92, decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.accent.withValues(alpha: .055)))),
        Padding(
          padding: const EdgeInsets.all(15),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 42, height: 42, decoration: BoxDecoration(color: AppColors.accentSoft, borderRadius: BorderRadius.circular(14)), child: Icon(feature.icon, color: AppColors.accent, size: 23)),
              const Spacer(),
              if (editing)
                Icon(enabled ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded, color: enabled ? AppColors.accent : AppColors.textTertiary, size: 20)
              else
                Text(feature.tag, style: AppText.caption.copyWith(color: AppColors.textTertiary, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: .8)),
            ]),
            const Spacer(),
            Text(feature.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.title.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 15)),
            const SizedBox(height: 3),
            Text(feature.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.caption.copyWith(color: AppColors.textSecondary, height: 1.3, fontSize: 10.5)),
          ]),
        ),
      ]),
    ),
  );
}
