import '../models/reader_settings.dart';

abstract interface class ReaderSettingsRepository {
  Future<ReaderSettings> load();

  Future<void> save(ReaderSettings settings);
}
