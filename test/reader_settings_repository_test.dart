import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:reader/data/repositories/shared_preferences_reader_settings_repository.dart';
import 'package:reader/domain/models/reader_settings.dart';

void main() {
  test('persists reader typography, theme and layout choices', () async {
    SharedPreferences.setMockInitialValues({});
    final repository = SharedPreferencesReaderSettingsRepository(
      await SharedPreferences.getInstance(),
    );
    const settings = ReaderSettings(
      fontSize: 22,
      lineHeight: 2,
      horizontalPadding: 24,
      theme: ReaderTheme.night,
      layout: ReaderLayout.page,
      appAppearance: AppAppearance.dark,
    );

    await repository.save(settings);
    final restored = await repository.load();

    expect(restored.fontSize, 22);
    expect(restored.lineHeight, 2);
    expect(restored.horizontalPadding, 24);
    expect(restored.theme, ReaderTheme.night);
    expect(restored.layout, ReaderLayout.page);
    expect(restored.appAppearance, AppAppearance.dark);
  });

  test('defaults older reader settings to system app appearance', () async {
    SharedPreferences.setMockInitialValues({
      'shiye.reader-settings.v1': ['20', '1.8', '26', 'sepia', 'scroll'],
    });
    final repository = SharedPreferencesReaderSettingsRepository(
      await SharedPreferences.getInstance(),
    );

    final restored = await repository.load();

    expect(restored.theme, ReaderTheme.sepia);
    expect(restored.appAppearance, AppAppearance.system);
  });

  test('persists imported font and content filters', () async {
    SharedPreferences.setMockInitialValues({});
    final repository = SharedPreferencesReaderSettingsRepository(
      await SharedPreferences.getInstance(),
    );
    const settings = ReaderSettings(
      font: ReaderFont(family: 'shiye_font_demo', path: '/documents/font.ttf', name: '阅读体'),
      contentFilters: [ContentFilterRule(pattern: '推广', isRegExp: false)],
    );

    await repository.save(settings);
    final restored = await repository.load();

    expect(restored.font?.name, '阅读体');
    expect(restored.contentFilters.single.pattern, '推广');
  });
}
