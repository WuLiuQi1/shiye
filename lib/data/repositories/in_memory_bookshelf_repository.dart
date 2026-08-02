import '../../domain/models/book.dart';
import '../../domain/repositories/bookshelf_repository.dart';

/// Temporary seed data. Persistence will be supplied by the data module.
class InMemoryBookshelfRepository implements BookshelfRepository {
  final List<Book> _books = [
    Book(
      id: 'demo-1',
      title: '长夜微光',
      author: '拾页示例',
      progress: .38,
      coverColor: 0xFF4C6B82,
      lastReadAt: DateTime(2026, 8, 2),
    ),
    Book(
      id: 'demo-2',
      title: '海风与纸页',
      author: '拾页示例',
      progress: .71,
      coverColor: 0xFFD17950,
      lastReadAt: DateTime(2026, 8, 1),
    ),
    Book(
      id: 'demo-3',
      title: '北方来信',
      author: '拾页示例',
      progress: 0,
      coverColor: 0xFF7A8062,
      lastReadAt: DateTime(2026, 7, 31),
    ),
  ];

  @override
  Future<List<Book>> loadBooks() async => List.unmodifiable(_books);

  @override
  Future<void> save(Book book) async {
    _books.removeWhere((item) => item.id == book.id);
    _books.insert(0, book);
  }
}
