import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../zmode/metadata_filters.dart';
import '../zmode/zmode_ids.dart';

class HomeCustomCatalog {
  const HomeCustomCatalog({
    required this.id,
    required this.name,
    required this.kind,
    required this.filtersJson,
  });

  final String id;
  final String name;
  final ZKind kind;
  final String filtersJson;

  MetaFilters get filters => MetaFilters.fromJson(filtersJson) ?? const MetaFilters();

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'kind': kind.name,
    'filters': filtersJson,
  };

  factory HomeCustomCatalog.fromJson(Map<String, dynamic> json) {
    return HomeCustomCatalog(
      id: json['id'] as String,
      name: json['name'] as String,
      kind: ZKind.values.firstWhere((v) => v.name == json['kind']),
      filtersJson: json['filters'] as String? ?? '',
    );
  }
}

/// User-defined metadata rows. Stored in the already-open Home rows Hive box,
/// so this feature needs no extra startup migration or box registration.
class HomeCustomCatalogPrefs {
  HomeCustomCatalogPrefs._();

  static const _key = 'custom_catalogues_v1';
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  static Box? get _box =>
      Hive.isBoxOpen('home_rows_prefs') ? Hive.box('home_rows_prefs') : null;

  static List<HomeCustomCatalog> all() {
    final raw = _box?.get(_key) as String?;
    if (raw == null || raw.isEmpty) return const [];
    try {
      final values = (jsonDecode(raw) as List).cast<Map>();
      return values.map((v) => HomeCustomCatalog.fromJson(
        Map<String, dynamic>.from(v),
      )).toList();
    } catch (_) {
      return const [];
    }
  }

  static List<HomeCustomCatalog> forKind(ZKind kind) =>
      all().where((c) => c.kind == kind).toList();

  static Future<void> save(HomeCustomCatalog catalog) async {
    final values = all().where((c) => c.id != catalog.id).toList()
      ..add(catalog);
    await _write(values);
  }

  static Future<void> delete(String id) async {
    await _write(all().where((c) => c.id != id).toList());
  }

  static Future<void> _write(List<HomeCustomCatalog> values) async {
    final box = _box;
    if (box == null) return;
    await box.put(_key, jsonEncode(values.map((v) => v.toJson()).toList()));
    revision.value++;
  }
}
