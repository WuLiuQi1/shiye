import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/book_source_content.dart';
import '../../domain/repositories/chapter_content_cache.dart';

/// A small, bounded offline cache. It is deliberately separate from the shelf
/// data, and can later be moved to a file/database cache without touching UI.
class SharedPreferencesChapterContentCache implements ChapterContentCache {
  SharedPreferencesChapterContentCache(this._preferences);

  static const _key = 'shiye.chapter-cache.v1';
  static const _maximumEntries = 24;
  final SharedPreferences _preferences;

  @override
  Future<ChapterContent?> read(String sourceId, Uri chapterUrl) async {
    final entries = _entries();
    final entry = entries[_entryKey(sourceId, chapterUrl)];
    if (entry is! Map) return null;
    final text = entry['text'];
    if (text is! String || text.isEmpty) return null;
    return ChapterContent(sourceId: sourceId, chapterUrl: chapterUrl, text: text);
  }

  @override
  Future<void> write(ChapterContent content) async {
    if (content.text.trim().isEmpty) return;
    final entries = _entries();
    entries[_entryKey(content.sourceId, content.chapterUrl)] = {
      'text': content.text,
      'savedAt': DateTime.now().millisecondsSinceEpoch,
    };
    if (entries.length > _maximumEntries) {
      final oldest = entries.entries.reduce(
        (left, right) => _savedAt(left.value).isBefore(_savedAt(right.value))
            ? left
            : right,
      );
      entries.remove(oldest.key);
    }
    await _preferences.setString(_key, jsonEncode(entries));
  }

  @override
  Future<ChapterCacheSummary> summary() async {
    final entries = _entries();
    var bytes = 0;
    final counts = <String, int>{};
    for (final entry in entries.entries) {
      final value = entry.value;
      if (value is Map && value['text'] is String) {
        bytes += utf8.encode(value['text'] as String).length;
        final separator = entry.key.indexOf('|');
        if (separator > 0) {
          final sourceId = entry.key.substring(0, separator);
          counts[sourceId] = (counts[sourceId] ?? 0) + 1;
        }
      }
    }
    return ChapterCacheSummary(
      entryCount: entries.length,
      byteCount: bytes,
      sourceEntryCounts: Map.unmodifiable(counts),
    );
  }

  @override
  Future<void> clearAll() => _preferences.remove(_key);

  @override
  Future<void> clearSource(String sourceId) async {
    final entries = _entries();
    entries.removeWhere((key, _) => key.startsWith('$sourceId|'));
    if (entries.isEmpty) {
      await _preferences.remove(_key);
    } else {
      await _preferences.setString(_key, jsonEncode(entries));
    }
  }

  Map<String, dynamic> _entries() {
    final raw = _preferences.getString(_key);
    if (raw == null || raw.isEmpty) return {};
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } on Object {
      return {};
    }
  }

  DateTime _savedAt(Object? value) {
    if (value is Map && value['savedAt'] is num) {
      return DateTime.fromMillisecondsSinceEpoch(
        (value['savedAt'] as num).toInt(),
      );
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  String _entryKey(String sourceId, Uri url) => '$sourceId|$url';
}
