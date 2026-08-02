import 'package:flutter/foundation.dart';

import '../../../domain/models/book_source.dart';
import '../../../domain/models/book_source_content.dart';
import '../../../domain/repositories/book_source_repository.dart';
import '../../../domain/use_cases/browse_book_source.dart';

class BookSearchViewModel extends ChangeNotifier {
  BookSearchViewModel(this._sources, this._browse);

  final BookSourceRepository _sources;
  final BrowseBookSource _browse;
  List<BookSearchResult> _results = const [];
  bool _isLoading = false;
  String? _message;
  int _failedSourceCount = 0;

  List<BookSearchResult> get results => List.unmodifiable(_results);
  bool get isLoading => _isLoading;
  String? get message => _message;
  int get failedSourceCount => _failedSourceCount;

  Future<void> search(String keyword) async {
    if (keyword.trim().isEmpty) return;
    _isLoading = true;
    _message = null;
    _failedSourceCount = 0;
    notifyListeners();
    try {
      final enabled = (await _sources.loadAll())
          .where((source) => source.canBrowse)
          .toList();
      if (enabled.isEmpty) {
        _results = const [];
        _message = '请先在书源管理中导入并启用书源。';
      } else {
        final batches = await Future.wait(
          enabled.map((source) => _searchOne(source, keyword)),
        );
        _results = batches.expand((items) => items).toList();
        if (_results.isEmpty && _failedSourceCount == enabled.length) {
          _message = '所有已启用书源均无法连接，请稍后重试或检查书源。';
        } else if (_results.isEmpty) {
          _message = _failedSourceCount == 0
              ? '没有找到与“${keyword.trim()}”相关的结果。'
              : '没有找到结果；${_failedSourceCount} 个书源暂时不可用。';
        } else if (_failedSourceCount > 0) {
          _message = '${_failedSourceCount} 个书源暂时不可用，已显示其余结果。';
        }
      }
    } catch (_) {
      _results = const [];
      _message = '搜索初始化失败，请稍后重新打开页面。';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<List<BookSearchResult>> _searchOne(BookSource source, String keyword) async {
    try {
      return await _browse.search(source, keyword);
    } catch (_) {
      _failedSourceCount++;
      return const [];
    }
  }
}
