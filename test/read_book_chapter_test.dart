import 'package:flutter_test/flutter_test.dart';

import 'package:reader/domain/models/book.dart';
import 'package:reader/domain/models/book_source.dart';
import 'package:reader/domain/models/book_source_content.dart';
import 'package:reader/domain/repositories/book_source_gateway.dart';
import 'package:reader/domain/repositories/book_source_repository.dart';
import 'package:reader/domain/repositories/chapter_content_cache.dart';
import 'package:reader/domain/repositories/reader_settings_repository.dart';
import 'package:reader/domain/models/reader_settings.dart';
import 'package:reader/domain/services/declarative_rule_engine.dart';
import 'package:reader/domain/use_cases/browse_book_source.dart';
import 'package:reader/domain/use_cases/read_book_chapter.dart';

void main() {
  final source = BookSource(id: 'one', name: '主来源', baseUrl: Uri.parse('https://example.com/'), format: BookSourceFormat.legado, rules: const {});
  final chapter = BookChapter(sourceId: source.id, title: '第一章', url: Uri.parse('https://example.com/1'), index: 0);
  final book = Book(
    id: 'book', title: '示例书', author: '作者', progress: 0, coverColor: 0, lastReadAt: DateTime(2026), sourceId: source.id,
    sourceLinks: [BookSourceLink(sourceId: source.id, sourceName: source.name, detailUrl: Uri.parse('https://example.com/book'))],
  );

  test('loads chapter text and serves the following request from its local cache', () async {
    final cache = _CacheFake();
    final browse = _BrowseFake([chapter]);
    final read = ReadBookChapter(_SourcesFake([source]), browse, cache, _SettingsFake());

    final first = await read(book);
    final second = await read(book);

    expect(first.content.text, '可阅读正文');
    expect(first.fromCache, isFalse);
    expect(second.fromCache, isTrue);
    expect(browse.contentCalls, 1);
  });

  test('rejects an empty chapter instead of caching an unreadable result', () async {
    final cache = _CacheFake();
    final browse = _BrowseFake([chapter], contentText: '   ');
    final read = ReadBookChapter(_SourcesFake([source]), browse, cache, _SettingsFake());

    await expectLater(read(book), throwsA(isA<FormatException>()));
    expect(cache.values, isEmpty);
  });

  test('filters chapter text before it is cached', () async {
    final cache = _CacheFake();
    final browse = _BrowseFake([chapter], contentText: '正文\n推广内容');
    final read = ReadBookChapter(
      _SourcesFake([source]),
      browse,
      cache,
      _SettingsFake(const ReaderSettings(
        contentFilters: [ContentFilterRule(pattern: '推广内容')],
      )),
    );

    final loaded = await read(book);

    expect(loaded.content.text, '正文\n');
    expect(cache.values.values.single.text, '正文\n');
  });
}

class _SourcesFake implements BookSourceRepository {
  _SourcesFake(this.sources);
  final List<BookSource> sources;
  @override Future<List<BookSource>> loadAll() async => sources;
  @override Future<void> remove(String sourceId) async {}
  @override Future<void> saveAll(Iterable<BookSource> sources) async {}
}

class _CacheFake implements ChapterContentCache {
  final Map<String, ChapterContent> values = {};
  String _key(String id, Uri url) => '$id|$url';
  @override Future<ChapterContent?> read(String sourceId, Uri chapterUrl) async => values[_key(sourceId, chapterUrl)];
  @override Future<void> write(ChapterContent content) async => values[_key(content.sourceId, content.chapterUrl)] = content;
  @override Future<void> clearAll() async => values.clear();
  @override Future<void> clearSource(String sourceId) async => values.removeWhere((key, _) => key.startsWith('$sourceId|'));
  @override Future<ChapterCacheSummary> summary() async => ChapterCacheSummary(entryCount: values.length, byteCount: 0, sourceEntryCounts: const {});
}

class _SettingsFake implements ReaderSettingsRepository {
  _SettingsFake([this.settings = const ReaderSettings()]);
  final ReaderSettings settings;
  @override Future<ReaderSettings> load() async => settings;
  @override Future<void> save(ReaderSettings settings) async {}
}

class _BrowseFake extends BrowseBookSource {
  _BrowseFake(this.items, {this.contentText = '可阅读正文'}) : super(_GatewayFake(), const DeclarativeRuleEngine());
  final List<BookChapter> items;
  final String contentText;
  int contentCalls = 0;
  @override Future<BookDetails> details(BookSource source, Uri url) async => BookDetails(sourceId: source.id, title: '示例书', author: '作者', detailUrl: url, tocUrl: Uri.parse('https://example.com/toc'));
  @override Future<List<BookChapter>> chapters(BookSource source, Uri url) async => items;
  @override Future<ChapterContent> content(BookSource source, Uri url) async {
    contentCalls++;
    return ChapterContent(sourceId: source.id, chapterUrl: url, text: contentText);
  }
}

class _GatewayFake implements BookSourceGateway {
  @override Future<String> get(Uri url) async => '';
}
