import 'package:flutter_test/flutter_test.dart';
import 'package:reader/data/repositories/in_memory_bookshelf_repository.dart';
import 'package:reader/features/bookshelf/presentation/bookshelf_view_model.dart';

void main() {
  test('loads the seeded bookshelf', () async {
    final viewModel = BookshelfViewModel(InMemoryBookshelfRepository());

    await viewModel.load();

    expect(viewModel.books, hasLength(3));
    expect(viewModel.books.first.title, '长夜微光');
  });
}
