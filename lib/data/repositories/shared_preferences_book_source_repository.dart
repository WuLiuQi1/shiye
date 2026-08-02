import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/book_source.dart';
import '../../domain/repositories/book_source_repository.dart';

class SharedPreferencesBookSourceRepository implements BookSourceRepository {
  SharedPreferencesBookSourceRepository(this._preferences);

  static const _key = 'shiye.bookSources.v1';
  final SharedPreferences _preferences;

  @override
  Future<List<BookSource>> loadAll() async {
    final raw = _preferences.getString(_key);
    if (raw == null || raw.isEmpty) return const [];
    final values = jsonDecode(raw) as List<Object?>;
    return values.map((value) {
      final item = Map<String, Object?>.from(value! as Map);
      return BookSource(
        id: item['id']! as String,
        name: item['name']! as String,
        baseUrl: Uri.parse(item['baseUrl']! as String),
        format: BookSourceFormat.values.byName(item['format']! as String),
        rules: Map<String, Object?>.from(item['rules']! as Map),
        isEnabled: item['isEnabled'] as bool? ?? true,
        supportStatus: item['supportStatus'] is String
            ? BookSourceSupportStatus.values.byName(item['supportStatus']! as String)
            : BookSourceSupportStatus.usable,
        supportNote: item['supportNote'] as String?,
      );
    }).toList();
  }

  @override
  Future<void> saveAll(Iterable<BookSource> sources) async {
    final current = await loadAll();
    final map = {for (final source in current) source.id: source};
    for (final source in sources) map[source.id] = source;
    await _write(map.values);
  }

  @override
  Future<void> remove(String sourceId) async {
    final current = await loadAll();
    await _write(current.where((source) => source.id != sourceId));
  }

  Future<void> _write(Iterable<BookSource> sources) => _preferences.setString(
        _key,
        jsonEncode(sources
            .map((source) => {
                  'id': source.id,
                  'name': source.name,
                  'baseUrl': source.baseUrl.toString(),
                  'format': source.format.name,
                  'rules': source.rules,
                  'isEnabled': source.isEnabled,
                  'supportStatus': source.supportStatus.name,
                  'supportNote': source.supportNote,
                })
            .toList()),
      );
}
