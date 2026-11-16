import 'package:flutter/material.dart';

import '../../core/mode/content_mode.dart';
import '../../core/stremio/stremio_ref.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../sources/stremio_sources_screen.dart';
import 'search_screen.dart';
import 'source_catalogue_home_content.dart';

/// Dedicated Stremio catalogue home. Add-on management stays one tap away,
/// while the body browses catalogues from enabled Stremio add-ons.
class StremioHomeScreen extends StatelessWidget {
  const StremioHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        title: Text('Stremio', style: AppText.barTitle),
        actions: [
          IconButton(
            tooltip: 'Cari Stremio',
            icon: const Icon(Icons.search_rounded),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const SearchScreen(
                  forceSources: true,
                  fixedSourceId: stremioSourceId,
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Kelola add-on',
            icon: const Icon(Icons.extension_rounded),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const StremioSourcesScreen(),
              ),
            ),
          ),
        ],
      ),
      body: SourceCatalogueHomeContent(
        initialSourceId: stremioSourceId,
        mode: ContentMode.anime,
        showSourcePicker: false,
      ),
    );
  }
}
