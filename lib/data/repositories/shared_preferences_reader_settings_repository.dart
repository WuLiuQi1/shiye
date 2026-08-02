import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/reader_settings.dart';
import '../../domain/repositories/reader_settings_repository.dart';

class SharedPreferencesReaderSettingsRepository
    implements ReaderSettingsRepository {
  SharedPreferencesReaderSettingsRepository(this._preferences);

  static const _key = 'shiye.reader-settings.v1';
  final SharedPreferences _preferences;

  @override
  Future<ReaderSettings> load() async {
    final values = _preferences.getStringList(_key);
    if (values == null || values.length < 5) return const ReaderSettings();
    return ReaderSettings(
      fontSize: double.tryParse(values[0]) ?? 19,
      lineHeight: double.tryParse(values[1]) ?? 1.85,
      horizontalPadding: double.tryParse(values[2]) ?? 28,
      theme: ReaderTheme.values.firstWhere(
        (item) => item.name == values[3],
        orElse: () => ReaderTheme.paper,
      ),
      layout: ReaderLayout.values.firstWhere(
        (item) => item.name == values[4],
        orElse: () => ReaderLayout.scroll,
      ),
      appAppearance: values.length > 5
          ? AppAppearance.values.firstWhere(
              (item) => item.name == values[5],
              orElse: () => AppAppearance.system,
            )
          : AppAppearance.system,
      font: values.length > 8 && values[6].isNotEmpty && values[7].isNotEmpty
          ? ReaderFont(family: values[6], path: values[7], name: values[8])
          : null,
      contentFilters: values.length > 9 ? _decodeFilters(values[9]) : const [],
    );
  }

  @override
  Future<void> save(ReaderSettings settings) => _preferences.setStringList(
        _key,
        [
          settings.fontSize.toString(),
          settings.lineHeight.toString(),
          settings.horizontalPadding.toString(),
          settings.theme.name,
          settings.layout.name,
          settings.appAppearance.name,
          settings.font?.family ?? '',
          settings.font?.path ?? '',
          settings.font?.name ?? '',
          jsonEncode(settings.contentFilters.map((rule) => {
                'pattern': rule.pattern,
                'replacement': rule.replacement,
                'isRegExp': rule.isRegExp,
              }).toList()),
        ],
      );

  List<ContentFilterRule> _decodeFilters(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((item) => ContentFilterRule(
                pattern: item['pattern'] as String? ?? '',
                replacement: item['replacement'] as String? ?? '',
                isRegExp: item['isRegExp'] == true,
              ))
          .where((item) => item.pattern.trim().isNotEmpty)
          .toList(growable: false);
    } on Object {
      return const [];
    }
  }
}
