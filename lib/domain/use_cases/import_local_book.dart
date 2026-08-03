import 'dart:io';

import '../models/book.dart';
import '../repositories/bookshelf_repository.dart';
import '../repositories/local_book_storage.dart';
import '../repositories/local_book_parser.dart';

class ImportLocalBook {
  const ImportLocalBook(this._bookshelf, this._storage, this._parser);

  final BookshelfRepository _bookshelf;
  final LocalBookStorage _storage;
  final LocalBookParser _parser;

  Future<Book> call(String path) async {
    final sourceFile = File(path);
    if (!await sourceFile.exists()) throw const LocalBookImportException('文件不存在。');
    final format = _formatFromPath(path);
    if (format == null) {
      throw const LocalBookImportException('暂不支持这个文件格式。');
    }
    if (format == LocalBookFormat.mobi || format == LocalBookFormat.azw3) {
      throw LocalBookImportException('${format.label} 暂未开放阅读。');
    }
    final stat = await sourceFile.stat();
    if (stat.size <= 0) throw const LocalBookImportException('文件内容为空。');
    final maximumBytes = switch (format) {
      LocalBookFormat.txt => 10 * 1024 * 1024,
      LocalBookFormat.epub => 50 * 1024 * 1024,
      LocalBookFormat.pdf => 100 * 1024 * 1024,
      LocalBookFormat.mobi || LocalBookFormat.azw3 =>
        throw StateError('Unsupported e-book format passed validation.'),
    };
    if (stat.size > maximumBytes) {
      throw LocalBookImportException('${format.label} 文件过大，当前最多支持 ${maximumBytes ~/ 1024 ~/ 1024} MiB。');
    }
    final metadata = format == LocalBookFormat.epub ? await _parser.inspectEpub(path) : null;
    final title = metadata?.title ?? _titleFromPath(path);
    final storedPath = await _storage.storeCopy(
      sourcePath: sourceFile.path,
      title: title,
      format: format,
    );
    final importedAt = DateTime.now();
    final book = Book(
      id: 'local:${importedAt.millisecondsSinceEpoch}',
      title: title,
      author: metadata?.author ?? '本地书籍',
      progress: 0,
      coverColor: _coverColor(title),
      lastReadAt: DateTime.now(),
      sourceName: '本地文件',
      readingChapterTitle: title,
      localFormat: format,
      localPath: storedPath,
      localImportedAt: importedAt,
    );
    await _bookshelf.save(book);
    return book;
  }

  LocalBookFormat? _formatFromPath(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.txt')) return LocalBookFormat.txt;
    if (lower.endsWith('.epub')) return LocalBookFormat.epub;
    if (lower.endsWith('.pdf')) return LocalBookFormat.pdf;
    if (lower.endsWith('.mobi')) return LocalBookFormat.mobi;
    if (lower.endsWith('.azw') || lower.endsWith('.azw3')) return LocalBookFormat.azw3;
    return null;
  }

  String _titleFromPath(String path) {
    final name = path.split(Platform.pathSeparator).last;
    final dot = name.lastIndexOf('.');
    return dot <= 0 ? name : name.substring(0, dot);
  }

  int _coverColor(String title) {
    const colors = [
      0xFF8E6E53,
      0xFF466A8F,
      0xFF7B5E8E,
      0xFF577C68,
      0xFF965C5C,
    ];
    return colors[title.hashCode.abs() % colors.length];
  }
}

class LocalBookImportException implements Exception {
  const LocalBookImportException(this.message);

  final String message;

  @override
  String toString() => message;
}
