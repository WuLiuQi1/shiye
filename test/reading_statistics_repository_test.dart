import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:reader/data/repositories/shared_preferences_reading_statistics_repository.dart';

void main() {
  test('stores reading time locally and splits an overnight session by day', () async {
    SharedPreferences.setMockInitialValues({});
    final repository = SharedPreferencesReadingStatisticsRepository(
      await SharedPreferences.getInstance(),
    );
    final startedAt = DateTime(2026, 8, 2, 23, 59, 30);

    await repository.record(
      bookId: 'book-1',
      startedAt: startedAt,
      endedAt: startedAt.add(const Duration(minutes: 2)),
      isCompleted: true,
    );
    final statistics = await repository.load();

    expect(statistics.secondsForDay(DateTime(2026, 8, 2)), 30);
    expect(statistics.secondsForDay(DateTime(2026, 8, 3)), 90);
    expect(statistics.bookSeconds['book-1'], 120);
    expect(statistics.completedBookIds, contains('book-1'));
  });

  test('ignores a zero-length reading event', () async {
    SharedPreferences.setMockInitialValues({});
    final repository = SharedPreferencesReadingStatisticsRepository(
      await SharedPreferences.getInstance(),
    );
    final now = DateTime(2026, 8, 2, 10);

    await repository.record(bookId: 'book-1', startedAt: now, endedAt: now, isCompleted: false);

    expect((await repository.load()).bookSeconds, isEmpty);
  });
}
