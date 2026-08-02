import '../models/book.dart';
import '../models/book_source.dart';
import '../models/book_source_content.dart';
import '../repositories/book_source_repository.dart';
import '../repositories/chapter_content_cache.dart';
import '../repositories/reader_settings_repository.dart';
import '../services/reader_content_filter.dart';
import 'browse_book_source.dart';

class ReaderChapter {
  const ReaderChapter({
    required this.chapter,
    required this.content,
    required this.chapterCount,
    required this.fromCache,
  });

  final BookChapter chapter;
  final ChapterContent content;
  final int chapterCount;
  final bool fromCache;
}

/// Loads one chapter while keeping requests, caching and source lookup outside
/// the reader widget. Adjacent prefetching is best-effort and never blocks it.
class ReadBookChapter {
  const ReadBookChapter(this._sources, this._browse, this._cache, this._settings);

  final BookSourceRepository _sources;
  final BrowseBookSource _browse;
  final ChapterContentCache _cache;
  final ReaderSettingsRepository _settings;
  static const _filter = ReaderContentFilter();

  Future<ReaderChapter> call(
    Book book, {
    int? chapterIndex,
    bool ignoreCache = false,
  }) async {
    final context = await _resolve(book);
    final index = (chapterIndex ?? book.readingChapterIndex)
        .clamp(0, context.chapters.length - 1)
        .toInt();
    final chapter = context.chapters[index];
    final cached = await _cache.read(context.source.id, chapter.url);
    if (!ignoreCache && cached != null) {
      _prefetch(context, index + 1);
      return ReaderChapter(
        chapter: chapter,
        content: cached,
        chapterCount: context.chapters.length,
        fromCache: true,
      );
    }
    final fetched = await _browse.content(context.source, chapter.url);
    final settings = await _settings.load();
    final content = ChapterContent(
      sourceId: fetched.sourceId,
      chapterUrl: fetched.chapterUrl,
      text: _filter.apply(fetched.text, settings.contentFilters),
    );
    if (content.text.trim().isEmpty) {
      throw const FormatException('书源返回了空正文。');
    }
    await _cache.write(content);
    _prefetch(context, index + 1);
    return ReaderChapter(
      chapter: chapter,
      content: content,
      chapterCount: context.chapters.length,
      fromCache: false,
    );
  }

  Future<_ReadingContext> _resolve(Book book) async {
    final sourceId = book.sourceId;
    final link = book.sourceLinks.where((item) => item.sourceId == sourceId).firstOrNull;
    if (sourceId == null || link == null) {
      throw StateError('这本书缺少可用的阅读来源。');
    }
    final source = (await _sources.loadAll())
        .where((item) => item.id == sourceId && item.canBrowse)
        .firstOrNull;
    if (source == null) throw StateError('当前书源不存在或已停用。');
    final details = await _browse.details(source, link.detailUrl);
    final chapters = await _browse.chapters(source, details.tocUrl);
    if (chapters.isEmpty) throw StateError('当前书源没有可阅读的章节。');
    return _ReadingContext(source, chapters);
  }

  void _prefetch(_ReadingContext context, int index) {
    if (index >= context.chapters.length) return;
    final chapter = context.chapters[index];
    Future<void>(() async {
      if (await _cache.read(context.source.id, chapter.url) != null) return;
      final fetched = await _browse.content(context.source, chapter.url);
      final settings = await _settings.load();
      final content = ChapterContent(
        sourceId: fetched.sourceId,
        chapterUrl: fetched.chapterUrl,
        text: _filter.apply(fetched.text, settings.contentFilters),
      );
      await _cache.write(content);
    }).catchError((_) {});
  }
}

class _ReadingContext {
  const _ReadingContext(this.source, this.chapters);
  final BookSource source;
  final List<BookChapter> chapters;
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
