import '../models/book_source_content.dart';

/// Device-local cache for parsed chapter text.
///
/// Cache keys include both the source and chapter URL, so content from one
/// source can never be shown after a manual source switch.
abstract interface class ChapterContentCache {
  Future<ChapterContent?> read(String sourceId, Uri chapterUrl);

  Future<void> write(ChapterContent content);

  Future<ChapterCacheSummary> summary();

  Future<void> clearAll();

  Future<void> clearSource(String sourceId);
}

class ChapterCacheSummary {
  const ChapterCacheSummary({
    required this.entryCount,
    required this.byteCount,
    required this.sourceEntryCounts,
  });

  final int entryCount;
  final int byteCount;
  final Map<String, int> sourceEntryCounts;
}
