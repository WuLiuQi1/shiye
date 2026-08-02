import '../models/reading_statistics.dart';

abstract interface class ReadingStatisticsRepository {
  Future<ReadingStatistics> load();

  /// Adds time locally. The caller supplies wall-clock bounds so time crossing
  /// midnight is credited to the correct day without any background service.
  Future<void> record({
    required String bookId,
    required DateTime startedAt,
    required DateTime endedAt,
    required bool isCompleted,
  });
}
