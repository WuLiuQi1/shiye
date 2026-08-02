import 'package:flutter_test/flutter_test.dart';
import 'package:reader/data/repositories/in_memory_book_source_repository.dart';
import 'package:reader/data/sources/json_book_source_importer.dart';
import 'package:reader/domain/use_cases/import_book_sources.dart';
import 'package:reader/features/sources/presentation/book_sources_view_model.dart';

void main() {
  test('imports, disables and removes a source for app management', () async {
    final repository = InMemoryBookSourceRepository();
    final viewModel = BookSourcesViewModel(
      repository,
      ImportBookSources(JsonBookSourceImporter(), repository),
    );

    final imported = await viewModel.importJson(
      '[{"bookSourceName":"示例源","bookSourceUrl":"https://books.example"}]',
    );

    expect(imported, isTrue);
    expect(viewModel.sources.single.isEnabled, isTrue);
    expect(viewModel.lastImportMessage, contains('可用 1'));

    await viewModel.setEnabled(viewModel.sources.single, false);
    expect(viewModel.sources.single.isEnabled, isFalse);

    await viewModel.remove(viewModel.sources.single);
    expect(viewModel.sources, isEmpty);
  });
}
