import '../models/book_source.dart';

abstract interface class BookSourceRepository {
  Future<void> saveAll(Iterable<BookSource> sources);

  Future<List<BookSource>> loadAll();

  Future<void> remove(String sourceId);
}
