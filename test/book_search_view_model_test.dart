import 'package:flutter_test/flutter_test.dart';
import 'package:reader/domain/models/book_source.dart';
import 'package:reader/domain/models/book_source_content.dart';
import 'package:reader/domain/repositories/book_source_gateway.dart';
import 'package:reader/domain/repositories/book_source_repository.dart';
import 'package:reader/domain/services/declarative_rule_engine.dart';
import 'package:reader/domain/use_cases/browse_book_source.dart';
import 'package:reader/features/search/presentation/book_search_view_model.dart';

void main() {
  final online = BookSource(
    id: 'online',
    name: '可用来源',
    baseUrl: Uri.parse('https://example.com'),
    format: BookSourceFormat.legado,
    rules: const {},
  );
  final offline = BookSource(
    id: 'offline',
    name: '故障来源',
    baseUrl: Uri.parse('https://offline.example'),
    format: BookSourceFormat.legado,
    rules: const {},
  );

  test('keeps successful results and reports unavailable sources', () async {
    final viewModel = BookSearchViewModel(
      _Sources([online, offline]),
      _Browse({'online': [BookSearchResult(sourceId: 'online', title: '拾页', author: '小柒', detailUrl: Uri.parse('https://example.com/book'))]}),
    );

    await viewModel.search('拾页');

    expect(viewModel.results.single.title, '拾页');
    expect(viewModel.failedSourceCount, 1);
    expect(viewModel.message, contains('1 个书源'));
  });

  test('skips imported sources that require blocked scripts', () async {
    final scriptOnly = BookSource(
      id: 'script',
      name: '脚本来源',
      baseUrl: Uri.parse('https://script.example'),
      format: BookSourceFormat.legado,
      rules: const {},
      isEnabled: false,
      supportStatus: BookSourceSupportStatus.scriptBlocked,
    );
    final browse = _Browse({});
    final viewModel = BookSearchViewModel(_Sources([scriptOnly]), browse);

    await viewModel.search('拾页');

    expect(browse.requestedSourceIds, isEmpty);
    expect(viewModel.message, contains('请先'));
  });
}

class _Sources implements BookSourceRepository {
  const _Sources(this.items);
  final List<BookSource> items;
  @override Future<List<BookSource>> loadAll() async => items;
  @override Future<void> remove(String sourceId) async {}
  @override Future<void> saveAll(Iterable<BookSource> sources) async {}
}

class _Browse extends BrowseBookSource {
  _Browse(this.results) : super(_Gateway(), const DeclarativeRuleEngine());
  final Map<String, List<BookSearchResult>> results;
  final List<String> requestedSourceIds = [];
  @override Future<List<BookSearchResult>> search(BookSource source, String keyword) async {
    requestedSourceIds.add(source.id);
    final value = results[source.id];
    if (value == null) throw StateError('unavailable');
    return value;
  }
}

class _Gateway implements BookSourceGateway {
  @override Future<String> get(Uri url) async => '';
}
