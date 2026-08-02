import 'dart:io';

import 'package:epubx/epubx.dart';
import 'package:html/parser.dart' as html_parser;

import '../../domain/repositories/local_book_parser.dart';

/// EPUB 2/3 parser backed by [epubx]. The archive stays inside the app's
/// private LocalBooks folder; this class never follows network links in EPUB.
class EpubLocalBookParser implements LocalBookParser {
  const EpubLocalBookParser();

  @override
  Future<LocalBookMetadata> inspectEpub(String path) async {
    final book = await _open(path);
    final title = (book.Title ?? '').trim();
    final author = (book.Author ?? '').trim();
    return LocalBookMetadata(
      title: title.isEmpty ? _fallbackTitle(path) : title,
      author: author.isEmpty ? '本地书籍' : author,
    );
  }

  @override
  Future<List<LocalBookChapterInfo>> epubToc(String path) async {
    final chapters = _readingChapters(await _open(path));
    return [
      for (var index = 0; index < chapters.length; index++)
        LocalBookChapterInfo(
          index: index,
          title: _chapterTitle(chapters[index], index),
        ),
    ];
  }

  @override
  Future<LocalBookChapterContent> readEpubChapter(String path, int index) async {
    final chapters = _readingChapters(await _open(path));
    if (chapters.isEmpty) throw const FormatException('EPUB 中没有可阅读的章节。');
    if (index < 0 || index >= chapters.length) throw RangeError.index(index, chapters, 'index');
    final chapter = chapters[index];
    final text = _htmlToText(chapter.HtmlContent ?? '');
    if (text.isEmpty) throw const FormatException('该 EPUB 章节没有可阅读的正文。');
    return LocalBookChapterContent(
      index: index,
      title: _chapterTitle(chapter, index),
      text: text,
      chapterCount: chapters.length,
    );
  }

  Future<EpubBook> _open(String path) async {
    final file = File(path);
    if (!await file.exists()) throw StateError('本地 EPUB 文件不存在。');
    final bytes = await file.readAsBytes();
    try {
      return await EpubReader.readBook(bytes);
    } catch (_) {
      throw const FormatException('无法解析 EPUB，请确认文件未损坏且不含 DRM 保护。');
    }
  }

  List<EpubChapter> _readingChapters(EpubBook book) {
    final result = <EpubChapter>[];
    void add(EpubChapter chapter) {
      if ((chapter.HtmlContent ?? '').trim().isNotEmpty) result.add(chapter);
      for (final child in chapter.SubChapters ?? const <EpubChapter>[]) {
        add(child);
      }
    }

    for (final chapter in book.Chapters ?? const <EpubChapter>[]) {
      add(chapter);
    }
    return result;
  }

  String _chapterTitle(EpubChapter chapter, int index) {
    final title = (chapter.Title ?? '').trim();
    return title.isEmpty ? '第 ${index + 1} 章' : title;
  }

  String _htmlToText(String html) {
    final document = html_parser.parse(html);
    return document.body?.text.replaceAll(RegExp(r'\n[ \t]*\n+'), '\n\n').trim() ?? '';
  }

  String _fallbackTitle(String path) {
    final name = path.split(Platform.pathSeparator).last;
    final dot = name.lastIndexOf('.');
    return dot <= 0 ? name : name.substring(0, dot);
  }
}
