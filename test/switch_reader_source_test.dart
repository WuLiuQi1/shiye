import 'package:flutter_test/flutter_test.dart';

import 'package:reader/domain/models/book.dart';
import 'package:reader/domain/models/book_source.dart';
import 'package:reader/domain/models/book_source_content.dart';
import 'package:reader/domain/repositories/book_source_gateway.dart';
import 'package:reader/domain/repositories/book_source_repository.dart';
import 'package:reader/domain/services/declarative_rule_engine.dart';
import 'package:reader/domain/use_cases/browse_book_source.dart';
import 'package:reader/domain/use_cases/switch_reader_source.dart';

void main() {
  final source = BookSource(
    id: 'source-b', name: '备用来源', baseUrl: Uri.parse('https://example.com/'), format: BookSourceFormat.legado, rules: const {},
  );

  test('manual switch retains a same-named chapter before using its index', () async {
    final browse = _BrowseFake([
      BookChapter(sourceId: source.id, title: '第一章 开始', url: Uri.parse('https://example.com/1'), index: 0),
      BookChapter(sourceId: source.id, title: '第二章 重逢', url: Uri.parse('https://example.com/2'), index: 1),
    ]);
    final useCase = SwitchReaderSource(_SourceRepository([source]), browse);
    final link = BookSourceLink(sourceId: source.id, sourceName: source.name, detailUrl: Uri.parse('https://example.com/book'));
    final book = Book(
      id: 'book', title: '示例书', author: '作者', progress: .2, coverColor: 0, lastReadAt: DateTime(2026), sourceLinks: [link],
      readingChapterIndex: 0, readingChapterTitle: '第二章：重逢',
    );

    final result = await useCase(book, link);

    expect(result.source.id, source.id);
    expect(result.chapter?.index, 1);
  });

  test('manual switch rejects a source that was not previously matched', () async {
    final useCase = SwitchReaderSource(_SourceRepository([source]), _BrowseFake(const []));
    final book = Book(id: 'book', title: '示例书', author: '作者', progress: 0, coverColor: 0, lastReadAt: DateTime(2026));
    final link = BookSourceLink(sourceId: source.id, sourceName: source.name, detailUrl: Uri.parse('https://example.com/book'));

    expect(useCase(book, link), throwsA(isA<StateError>()));
  });
}

class _SourceRepository implements BookSourceRepository {
  _SourceRepository(this.sources);
  final List<BookSource> sources;
  @override
  Future<List<BookSource>> loadAll() async => sources;
  @override
  Future<void> remove(String sourceId) async {}
  @override
  Future<void> saveAll(Iterable<BookSource> sources) async {}
}

class _BrowseFake extends BrowseBookSource {
  _BrowseFake(this._chapters) : super(_GatewayFake(), const DeclarativeRuleEngine());
  final List<BookChapter> _chapters;
  @override
  Future<BookDetails> details(BookSource source, Uri url) async => BookDetails(
        sourceId: source.id, title: '示例书', author: '作者', detailUrl: url, tocUrl: Uri.parse('https://example.com/toc'),
      );
  @override
  Future<List<BookChapter>> chapters(BookSource source, Uri url) async => _chapters;
}

class _GatewayFake implements BookSourceGateway {
  @override
  Future<String> get(Uri url) async => '';
}
