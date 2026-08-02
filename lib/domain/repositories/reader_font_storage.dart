import '../models/reader_settings.dart';

abstract interface class ReaderFontStorage {
  Future<ReaderFont> storeCopy(String sourcePath);
}
