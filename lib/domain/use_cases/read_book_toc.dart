import '../models/book.dart';
import '../models/book_source_content.dart';
import '../repositories/book_source_repository.dart';
import '../repositories/chapter_content_cache.dart';
import 'browse_book_source.dart';

class ReaderTocItem {
  const ReaderTocItem({required this.chapter, required this.isCached});

  final BookChapter chapter;
  final bool isCached;
}

/// Fetches a book's table of contents for the reader; widgets never access
/// source rules or network clients directly.
class ReadBookToc {
  const ReadBookToc(this._sources, this._browse, this._cache);

  final BookSourceRepository _sources;
  final BrowseBookSource _browse;
  final ChapterContentCache _cache;

  Future<List<ReaderTocItem>> call(Book book) async {
    final sourceId = book.sourceId;
    final link = book.sourceLinks.where((item) => item.sourceId == sourceId).firstOrNull;
    final source = (await _sources.loadAll())
        .where((item) => item.id == sourceId && item.canBrowse)
        .firstOrNull;
    if (link == null || source == null) throw StateError('当前书源不可用。');
    final details = await _browse.details(source, link.detailUrl);
    final chapters = await _browse.chapters(source, details.tocUrl);
    return Future.wait(chapters.map((chapter) async => ReaderTocItem(
          chapter: chapter,
          isCached: await _cache.read(source.id, chapter.url) != null,
        )));
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
