import '../../domain/models/book_source.dart';
import '../../domain/repositories/book_source_repository.dart';

/// Temporary app-lifetime store. It preserves the same repository contract as
/// the future encrypted local database, so presentation code does not change.
class InMemoryBookSourceRepository implements BookSourceRepository {
  final List<BookSource> _sources = [];

  @override
  Future<List<BookSource>> loadAll() async => List.unmodifiable(_sources);

  @override
  Future<void> saveAll(Iterable<BookSource> sources) async {
    for (final source in sources) {
      _sources.removeWhere((item) => item.id == source.id);
      _sources.add(source);
    }
  }

  @override
  Future<void> remove(String sourceId) async {
    _sources.removeWhere((source) => source.id == sourceId);
  }
}
