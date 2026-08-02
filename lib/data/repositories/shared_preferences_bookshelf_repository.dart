import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/book.dart';
import '../../domain/repositories/bookshelf_repository.dart';

/// Durable device-local shelf storage. It contains no account data and stays
/// behind the repository boundary so a future sync provider can replace it.
class SharedPreferencesBookshelfRepository implements BookshelfRepository {
  SharedPreferencesBookshelfRepository(this._preferences);

  static const _key = 'shiye.bookshelf.v1';
  final SharedPreferences _preferences;

  @override
  Future<List<Book>> loadBooks() async {
    final raw = _preferences.getString(_key);
    if (raw == null || raw.isEmpty) return const [];
    final values = jsonDecode(raw) as List<Object?>;
    return values.map((value) => _fromJson(Map<String, Object?>.from(value! as Map))).toList();
  }

  @override
  Future<void> save(Book book) async {
    final books = await loadBooks();
    final updated = [book, ...books.where((item) => item.id != book.id)];
    await _preferences.setString(_key, jsonEncode(updated.map(_toJson).toList()));
  }

  Map<String, Object?> _toJson(Book book) => {
        'id': book.id,
        'title': book.title,
        'author': book.author,
        'progress': book.progress,
        'coverColor': book.coverColor,
        'lastReadAt': book.lastReadAt.toIso8601String(),
        'sourceId': book.sourceId,
        'sourceName': book.sourceName,
        'introduction': book.introduction,
        'coverUrl': book.coverUrl?.toString(),
        'sourceLinks': book.sourceLinks
            .map((link) => {'sourceId': link.sourceId, 'sourceName': link.sourceName, 'detailUrl': link.detailUrl.toString()})
            .toList(),
        'readingChapterIndex': book.readingChapterIndex,
        'readingChapterTitle': book.readingChapterTitle,
        'readingChapterOffset': book.readingChapterOffset,
        'localFormat': book.localFormat?.name,
        'localPath': book.localPath,
        'localImportedAt': book.localImportedAt?.toIso8601String(),
      };

  Book _fromJson(Map<String, Object?> json) => Book(
        id: json['id']! as String,
        title: json['title']! as String,
        author: json['author']! as String,
        progress: (json['progress']! as num).toDouble(),
        coverColor: json['coverColor']! as int,
        lastReadAt: DateTime.parse(json['lastReadAt']! as String),
        sourceId: json['sourceId'] as String?,
        sourceName: json['sourceName'] as String?,
        introduction: json['introduction'] as String?,
        coverUrl: json['coverUrl'] == null ? null : Uri.parse(json['coverUrl']! as String),
        sourceLinks: ((json['sourceLinks'] as List<Object?>?) ?? const [])
            .map((item) => Map<String, Object?>.from(item! as Map))
            .map((item) => BookSourceLink(
                  sourceId: item['sourceId']! as String,
                  sourceName: item['sourceName']! as String,
                  detailUrl: Uri.parse(item['detailUrl']! as String),
                ))
            .toList(),
        readingChapterIndex: (json['readingChapterIndex'] as num?)?.toInt() ?? 0,
        readingChapterTitle: json['readingChapterTitle'] as String?,
        readingChapterOffset: (json['readingChapterOffset'] as num?)?.toDouble() ?? 0,
        localFormat: _localFormat(json['localFormat'] as String?),
        localPath: json['localPath'] as String?,
        localImportedAt: json['localImportedAt'] == null
            ? null
            : DateTime.parse(json['localImportedAt']! as String),
      );

  LocalBookFormat? _localFormat(String? value) {
    if (value == null) return null;
    for (final format in LocalBookFormat.values) {
      if (format.name == value) return format;
    }
    return null;
  }
}
