import 'package:flutter/material.dart';
import '../../core/di/injector.dart';
import '../../core/mode/content_mode_cubit.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/ui/home_custom_catalog_prefs.dart';
import '../../core/zmode/metadata_filters.dart';
import '../../core/zmode/zmode_ids.dart';
import '../../core/zmode/zmode_module.dart' show browseKindFor;
import '../../core/zmode/zmode_prefs.dart';
import '../search/meta_filter_sheet.dart';

class HomeCustomCataloguesScreen extends StatefulWidget {
  const HomeCustomCataloguesScreen({super.key});
  @override
  State<HomeCustomCataloguesScreen> createState() => _HomeCustomCataloguesScreenState();
}

class _HomeCustomCataloguesScreenState extends State<HomeCustomCataloguesScreen> {
  late final ZKind _kind = browseKindFor(sl<ContentModeCubit>().state, ZModePrefs.streamKind);
  List<HomeCustomCatalog> get _catalogues => HomeCustomCatalogPrefs.forKind(_kind);

  Future<void> _edit([HomeCustomCatalog? existing]) async {
    final name = TextEditingController(text: existing?.name ?? '');
    var filters = existing?.filters ?? const MetaFilters();
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'Buat katalog' : 'Edit katalog'),
          content: SingleChildScrollView(child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(controller: name, autofocus: existing == null, maxLength: 40,
                decoration: const InputDecoration(labelText: 'Nama katalog', hintText: 'Contoh: Anime action terbaru')),
              const SizedBox(height: 12),
              Text('Filter', style: AppText.body.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(filters.isEmpty ? 'Belum ada filter' : 'Filter sudah dipilih (' + _filterCount(filters).toString() + ')',
                style: AppText.caption.copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  final selected = await showMetaFilterSheet(context, _kind, filters, showStatus: true);
                  if (selected != null) setDialogState(() => filters = selected);
                },
                icon: const Icon(Icons.tune_rounded, size: 18),
                label: const Text('Pilih filter'),
              ),
              if (!filters.isEmpty) TextButton(
                onPressed: () => setDialogState(() => filters = const MetaFilters()),
                child: const Text('Hapus semua filter'),
              ),
            ],
          )),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Batal')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Simpan')),
          ],
        ),
      ),
    );
    if (result == true && name.text.trim().isNotEmpty) {
      await HomeCustomCatalogPrefs.save(HomeCustomCatalog(
        id: existing?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        name: name.text.trim(), kind: _kind, filtersJson: filters.toJson(),
      ));
      if (mounted) setState(() {});
    }
    name.dispose();
  }

  int _filterCount(MetaFilters f) => f.genres.length + f.tags.length + f.years.length +
      f.seasons.length + f.formats.length + f.statuses.length +
      (f.countryOfOrigin == null ? 0 : 1) + (f.minScore == null ? 0 : 1) +
      (f.minEpisodes == 0 && f.maxEpisodes == 200 ? 0 : 1) +
      (f.minYear == 1980 && f.maxYear == DateTime.now().year ? 0 : 1);

  Future<void> _delete(HomeCustomCatalog catalogue) async {
    final yes = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('Hapus katalog?'),
      content: Text('Katalog "' + catalogue.name + '" akan dihapus dari Beranda.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Hapus')),
      ],
    ));
    if (yes == true) {
      await HomeCustomCatalogPrefs.delete(catalogue.id);
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final entries = _catalogues;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Kustom katalog'), backgroundColor: AppColors.bg),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(), backgroundColor: AppColors.accent,
        foregroundColor: Colors.white, icon: const Icon(Icons.add_rounded),
        label: const Text('Buat katalog'),
      ),
      body: entries.isEmpty
        ? Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(
            mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.view_carousel_outlined, size: 48, color: AppColors.textTertiary),
              const SizedBox(height: 14),
              Text('Belum ada katalog kustom', style: AppText.title),
              const SizedBox(height: 8),
              Text('Buat katalog dengan memilih filter yang tersedia. Katalog akan muncul sebagai deretan baru di Beranda.',
                textAlign: TextAlign.center, style: AppText.caption.copyWith(color: AppColors.textSecondary)),
            ],
          )))
        : ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 100), children: [
            for (final catalogue in entries) Card(
              color: AppColors.surface,
              child: ListTile(
                leading: const Icon(Icons.view_carousel_outlined, color: AppColors.accent),
                title: Text(catalogue.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(_filterCount(catalogue.filters).toString() + ' filter', style: AppText.caption),
                onTap: () => _edit(catalogue),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) { if (value == 'edit') _edit(catalogue); if (value == 'delete') _delete(catalogue); },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(value: 'delete', child: Text('Hapus')),
                  ],
                ),
              ),
            ),
          ]),
    );
  }
}
