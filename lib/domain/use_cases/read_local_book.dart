import 'dart:io';

import '../models/book.dart';
import '../models/book_source_content.dart';
import 'read_book_chapter.dart';
import 'read_book_toc.dart';
import '../repositories/local_book_parser.dart';

class ReadLocalBookChapter {
  const ReadLocalBookChapter(this._parser);

  final LocalBookParser _parser;

  Future<ReaderChapter> call(Book book, {int? chapterIndex}) async {
    if (book.localPath == null) {
      throw StateError('当前本地格式暂未接入正文解析。');
    }
    if (book.localFormat == LocalBookFormat.epub) {
      final local = await _parser.readEpubChapter(
        book.localPath!,
        chapterIndex ?? book.readingChapterIndex,
      );
      final chapter = BookChapter(
        sourceId: 'local',
        title: local.title,
        url: Uri.file(book.localPath!, windows: false).replace(fragment: 'chapter-${local.index}'),
        index: local.index,
      );
      return ReaderChapter(
        chapter: chapter,
        content: ChapterContent(sourceId: 'local', chapterUrl: chapter.url, text: local.text),
        chapterCount: local.chapterCount,
        fromCache: true,
      );
    }
    if (book.localFormat != LocalBookFormat.txt) {
      throw StateError('当前本地格式暂未接入正文解析。');
    }
    final file = File(book.localPath!);
    if (!await file.exists()) throw StateError('本地文件不存在。');
    final text = await file.readAsString();
    if (text.trim().isEmpty) throw const FormatException('本地文件为空。');
    final chapter = BookChapter(
      sourceId: 'local',
      title: book.title,
      url: Uri.file(book.localPath!),
      index: 0,
    );
    return ReaderChapter(
      chapter: chapter,
      content: ChapterContent(
        sourceId: 'local',
        chapterUrl: Uri.file(book.localPath!),
        text: text,
      ),
      chapterCount: 1,
      fromCache: true,
    );
  }
}

class ReadLocalBookToc {
  const ReadLocalBookToc(this._parser);

  final LocalBookParser _parser;

  Future<List<ReaderTocItem>> call(Book book) async {
    if (book.localFormat == LocalBookFormat.epub && book.localPath != null) {
      final toc = await _parser.epubToc(book.localPath!);
      return [
        for (final item in toc)
          ReaderTocItem(
            chapter: BookChapter(
              sourceId: 'local',
              title: item.title,
              url: Uri.file(book.localPath!, windows: false).replace(fragment: 'chapter-${item.index}'),
              index: item.index,
            ),
            isCached: true,
          ),
      ];
    }
    return [
        ReaderTocItem(
          chapter: BookChapter(
            sourceId: 'local',
            title: book.title,
            url: Uri.file(book.localPath ?? book.id),
            index: 0,
          ),
          isCached: true,
        ),
      ];
  }
}
