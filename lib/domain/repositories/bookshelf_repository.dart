import '../models/book.dart';

abstract interface class BookshelfRepository {
  Future<List<Book>> loadBooks();

  Future<void> save(Book book);
}
