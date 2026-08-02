import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:reader/domain/models/book.dart';
import 'package:reader/domain/repositories/local_book_parser.dart';
import 'package:reader/domain/use_cases/read_local_book.dart';

void main() {
  final epub = Book(
    id: 'local:epub',
    title: '样书',
    author: '作者',
    progress: 0,
    coverColor: 0,
    lastReadAt: DateTime(2026),
    localFormat: LocalBookFormat.epub,
    localPath: '/private/LocalBooks/sample.epub',
  );

  test('reads requested EPUB chapter and exposes its chapter count', () async {
    final reader = ReadLocalBookChapter(const _Parser());
    final chapter = await reader(epub, chapterIndex: 1);

    expect(chapter.chapter.title, '第二章');
    expect(chapter.chapter.index, 1);
    expect(chapter.chapterCount, 2);
    expect(chapter.content.text, 'EPUB 正文');
  });

  test('builds an EPUB table of contents with stable chapter indexes', () async {
    final toc = await ReadLocalBookToc(const _Parser())(epub);

    expect(toc.map((item) => item.chapter.title), ['第一章', '第二章']);
    expect(toc.last.chapter.index, 1);
  });

  test('still reads TXT as a one-chapter local book', () async {
    final directory = await Directory.systemTemp.createTemp('shiye-local-reader');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/sample.txt');
    await file.writeAsString('TXT 正文');
    final txt = Book(
      id: 'local:txt', title: 'TXT', author: '本地书籍', progress: 0,
      coverColor: 0, lastReadAt: DateTime(2026), localFormat: LocalBookFormat.txt, localPath: file.path,
    );

    final chapter = await ReadLocalBookChapter(const _Parser())(txt);

    expect(chapter.chapterCount, 1);
    expect(chapter.content.text, 'TXT 正文');
  });

}

class _Parser implements LocalBookParser {
  const _Parser();

  @override
  Future<LocalBookMetadata> inspectEpub(String path) async =>
      const LocalBookMetadata(title: '样书', author: '作者');

  @override
  Future<List<LocalBookChapterInfo>> epubToc(String path) async => const [
        LocalBookChapterInfo(index: 0, title: '第一章'),
        LocalBookChapterInfo(index: 1, title: '第二章'),
      ];

  @override
  Future<LocalBookChapterContent> readEpubChapter(String path, int index) async =>
      LocalBookChapterContent(
        index: index,
        title: index == 0 ? '第一章' : '第二章',
        text: 'EPUB 正文',
        chapterCount: 2,
      );

}
