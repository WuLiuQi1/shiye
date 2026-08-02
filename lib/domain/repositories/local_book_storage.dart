import '../models/book.dart';

abstract interface class LocalBookStorage {
  Future<String> storeCopy({
    required String sourcePath,
    required String title,
    required LocalBookFormat format,
  });
}
