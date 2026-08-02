import '../models/book_source.dart';
import '../repositories/book_source_repository.dart';

abstract interface class BookSourceImporter {
  List<BookSource> importJson(String content);
}

class ImportBookSources {
  const ImportBookSources(this._importer, this._repository);

  final BookSourceImporter _importer;
  final BookSourceRepository _repository;

  Future<List<BookSource>> call(String content) async {
    final sources = _importer.importJson(content);
    await _repository.saveAll(sources);
    return sources;
  }
}
