import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:reader/data/repositories/shared_preferences_chapter_content_cache.dart';
import 'package:reader/domain/models/book_source_content.dart';

void main() {
  test('reports cache use and clears a single source without touching others', () async {
    SharedPreferences.setMockInitialValues({});
    final cache = SharedPreferencesChapterContentCache(await SharedPreferences.getInstance());
    await cache.write(ChapterContent(sourceId: 'one', chapterUrl: Uri.parse('https://one.example/1'), text: '第一章'));
    await cache.write(ChapterContent(sourceId: 'two', chapterUrl: Uri.parse('https://two.example/1'), text: '第二章'));

    final before = await cache.summary();
    expect(before.entryCount, 2);
    expect(before.byteCount, greaterThan(0));

    await cache.clearSource('one');

    expect(await cache.read('one', Uri.parse('https://one.example/1')), isNull);
    expect(await cache.read('two', Uri.parse('https://two.example/1')), isNotNull);
  });
}
