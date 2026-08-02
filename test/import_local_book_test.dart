import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:reader/domain/models/book.dart';
import 'package:reader/domain/repositories/bookshelf_repository.dart';
import 'package:reader/domain/repositories/local_book_storage.dart';
import 'package:reader/domain/repositories/local_book_parser.dart';
import 'package:reader/domain/use_cases/import_local_book.dart';

void main() {
  test('imports txt books into the bookshelf', () async {
    final directory = await Directory.systemTemp.createTemp('shiye-local-book');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/月光.txt');
    await file.writeAsString('第一章\n本地正文');
    final bookshelf = _FakeBookshelfRepository();
    final storage = _FakeLocalBookStorage(directory.path);

    final book = await ImportLocalBook(bookshelf, storage, const _FakeParser())(file.path);

    expect(book.title, '月光');
    expect(book.author, '本地书籍');
    expect(book.localFormat, LocalBookFormat.txt);
    expect(book.localPath, isNot(file.path));
    expect(book.sourceName, '本地文件');
    expect(bookshelf.books.single.id, book.id);
  });

  test('imports epub metadata after validating its readable structure', () async {
    final directory = await Directory.systemTemp.createTemp('shiye-local-book');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/sample.epub');
    await file.writeAsBytes([1, 2, 3]);

    final book = await ImportLocalBook(
      _FakeBookshelfRepository(),
      _FakeLocalBookStorage(directory.path),
      const _FakeParser(),
    )(file.path);

    expect(book.localFormat, LocalBookFormat.epub);
    expect(book.title, 'EPUB 标题');
    expect(book.author, 'EPUB 作者');
  });

  test('imports PDF into the private bookshelf library', () async {
    final directory = await Directory.systemTemp.createTemp('shiye-local-book');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/报告.pdf');
    await file.writeAsBytes([37, 80, 68, 70]);
    final bookshelf = _FakeBookshelfRepository();

    final book = await ImportLocalBook(
      bookshelf,
      _FakeLocalBookStorage(directory.path),
      const _FakeParser(),
    )(file.path);

    expect(book.localFormat, LocalBookFormat.pdf);
    expect(book.title, '报告');
    expect(bookshelf.books.single.localPath, isNot(file.path));
  });

}

class _FakeBookshelfRepository implements BookshelfRepository {
  final List<Book> books = [];

  @override
  Future<List<Book>> loadBooks() async => books;

  @override
  Future<void> save(Book book) async {
    books
      ..removeWhere((item) => item.id == book.id)
      ..insert(0, book);
  }
}

class _FakeLocalBookStorage implements LocalBookStorage {
  const _FakeLocalBookStorage(this.directory);

  final String directory;

  @override
  Future<String> storeCopy({
    required String sourcePath,
    required String title,
    required LocalBookFormat format,
  }) async {
    final target = File('$directory/imported-${format.name}');
    return (await File(sourcePath).copy(target.path)).path;
  }
}

class _FakeParser implements LocalBookParser {
  const _FakeParser();

  @override
  Future<LocalBookMetadata> inspectEpub(String path) async =>
      const LocalBookMetadata(title: 'EPUB 标题', author: 'EPUB 作者');

  @override
  Future<List<LocalBookChapterInfo>> epubToc(String path) async => const [];

  @override
  Future<LocalBookChapterContent> readEpubChapter(String path, int index) async =>
      const LocalBookChapterContent(index: 0, title: '第一章', text: '正文', chapterCount: 1);

}
