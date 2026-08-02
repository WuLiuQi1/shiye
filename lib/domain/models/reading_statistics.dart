class ReadingStatistics {
  const ReadingStatistics({
    this.dailySeconds = const {},
    this.bookSeconds = const {},
    this.completedBookIds = const {},
  });

  final Map<String, int> dailySeconds;
  final Map<String, int> bookSeconds;
  final Set<String> completedBookIds;

  int secondsForDay(DateTime date) => dailySeconds[_dayKey(date)] ?? 0;

  int secondsBetween(DateTime start, DateTime end) {
    var cursor = DateTime(start.year, start.month, start.day);
    final last = DateTime(end.year, end.month, end.day);
    var total = 0;
    while (!cursor.isAfter(last)) {
      total += secondsForDay(cursor);
      cursor = cursor.add(const Duration(days: 1));
    }
    return total;
  }

  int get readingStreakDays {
    var cursor = DateTime.now();
    if (secondsForDay(cursor) < 60) cursor = cursor.subtract(const Duration(days: 1));
    var streak = 0;
    while (secondsForDay(cursor) >= 60) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  static String dayKey(DateTime date) => _dayKey(date);
  static String _dayKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
