import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/reading_statistics.dart';
import '../../domain/repositories/reading_statistics_repository.dart';

/// Private, on-device reading metrics. No account or network access is used.
class SharedPreferencesReadingStatisticsRepository
    implements ReadingStatisticsRepository {
  SharedPreferencesReadingStatisticsRepository(this._preferences);

  static const _key = 'shiye.reading-statistics.v1';
  final SharedPreferences _preferences;

  @override
  Future<ReadingStatistics> load() async {
    final raw = _preferences.getString(_key);
    if (raw == null || raw.isEmpty) return const ReadingStatistics();
    final json = Map<String, Object?>.from(jsonDecode(raw) as Map);
    return ReadingStatistics(
      dailySeconds: _intMap(json['dailySeconds']),
      bookSeconds: _intMap(json['bookSeconds']),
      completedBookIds: ((json['completedBookIds'] as List<Object?>?) ?? const [])
          .whereType<String>()
          .toSet(),
    );
  }

  @override
  Future<void> record({
    required String bookId,
    required DateTime startedAt,
    required DateTime endedAt,
    required bool isCompleted,
  }) async {
    if (!endedAt.isAfter(startedAt)) return;
    final current = await load();
    final daily = Map<String, int>.from(current.dailySeconds);
    final books = Map<String, int>.from(current.bookSeconds);
    var cursor = startedAt;
    var recorded = 0;
    while (cursor.isBefore(endedAt)) {
      final nextDay = DateTime(cursor.year, cursor.month, cursor.day + 1);
      final boundary = nextDay.isBefore(endedAt) ? nextDay : endedAt;
      final seconds = boundary.difference(cursor).inSeconds;
      if (seconds > 0) {
        final key = ReadingStatistics.dayKey(cursor);
        daily[key] = (daily[key] ?? 0) + seconds;
        recorded += seconds;
      }
      cursor = boundary;
    }
    if (recorded == 0) return;
    books[bookId] = (books[bookId] ?? 0) + recorded;
    final completed = Set<String>.from(current.completedBookIds);
    if (isCompleted) completed.add(bookId);
    await _preferences.setString(_key, jsonEncode({
      'dailySeconds': daily,
      'bookSeconds': books,
      'completedBookIds': completed.toList()..sort(),
    }));
  }

  Map<String, int> _intMap(Object? value) {
    if (value is! Map) return const {};
    return value.map((key, item) => MapEntry(key.toString(), (item as num).toInt()));
  }
}
