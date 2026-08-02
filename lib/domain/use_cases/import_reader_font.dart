import '../models/reader_settings.dart';
import '../repositories/reader_font_storage.dart';

class ImportReaderFont {
  const ImportReaderFont(this._storage);

  final ReaderFontStorage _storage;

  Future<ReaderFont> call(String sourcePath) => _storage.storeCopy(sourcePath);
}
