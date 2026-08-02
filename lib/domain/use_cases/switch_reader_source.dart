import '../models/book.dart';
import '../models/book_source.dart';
import '../models/book_source_content.dart';
import '../repositories/book_source_repository.dart';
import 'browse_book_source.dart';

class ReaderSourceSelection {
  const ReaderSourceSelection({required this.source, required this.chapter});

  final BookSource source;
  final BookChapter? chapter;
}

/// Resolves a user-selected, previously matched source. There is intentionally
/// no automatic fallback and no arbitrary source search in this use case.
class SwitchReaderSource {
  const SwitchReaderSource(this._sources, this._browse);

  final BookSourceRepository _sources;
  final BrowseBookSource _browse;

  Future<ReaderSourceSelection> call(Book book, BookSourceLink link) async {
    if (!book.sourceLinks.any((item) => item.sourceId == link.sourceId && item.detailUrl == link.detailUrl)) {
      throw StateError('该来源尚未匹配为同一本书，不能切换。');
    }
    final source = (await _sources.loadAll()).where((item) => item.id == link.sourceId && item.canBrowse).firstOrNull;
    if (source == null) throw StateError('该书源不存在或已停用。');
    final details = await _browse.details(source, link.detailUrl);
    final chapters = await _browse.chapters(source, details.tocUrl);
    return ReaderSourceSelection(source: source, chapter: _locate(chapters, book));
  }

  BookChapter? _locate(List<BookChapter> chapters, Book book) {
    final title = book.readingChapterTitle;
    if (title != null && title.isNotEmpty) {
      for (final chapter in chapters) {
        if (_normalise(chapter.title) == _normalise(title)) return chapter;
      }
    }
    if (chapters.isEmpty) return null;
    return chapters[book.readingChapterIndex.clamp(0, chapters.length - 1).toInt()];
  }

  String _normalise(String value) => value.toLowerCase().replaceAll(RegExp(r'[\s\-_—:：,.，。!！?？()（）\[\]【】]'), '');
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
