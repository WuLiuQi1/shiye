import 'package:flutter/foundation.dart';

import '../../../domain/models/book_source.dart';
import '../../../domain/repositories/book_source_repository.dart';
import '../../../domain/use_cases/import_book_sources.dart';

class BookSourcesViewModel extends ChangeNotifier {
  BookSourcesViewModel(this._repository, this._import);

  final BookSourceRepository _repository;
  final ImportBookSources _import;
  List<BookSource> _sources = const [];
  String? _error;
  String? _lastImportMessage;

  List<BookSource> get sources => List.unmodifiable(_sources);
  String? get error => _error;
  String? get lastImportMessage => _lastImportMessage;

  Future<void> load() async {
    _sources = await _repository.loadAll();
    notifyListeners();
  }

  Future<bool> importJson(String json) async {
    try {
      final imported = await _import(json);
      _error = null;
      _lastImportMessage = _summary(imported);
      await load();
      return true;
    } on FormatException catch (error) {
      _error = error.message;
      _lastImportMessage = null;
      notifyListeners();
      return false;
    }
  }

  Future<void> setEnabled(BookSource source, bool enabled) async {
    await _repository.saveAll([source.copyWith(isEnabled: enabled)]);
    await load();
  }

  Future<void> remove(BookSource source) async {
    await _repository.remove(source.id);
    await load();
  }

  String _summary(List<BookSource> sources) {
    final usable = sources.where((source) => source.supportStatus == BookSourceSupportStatus.usable).length;
    final partial = sources.where((source) => source.supportStatus == BookSourceSupportStatus.partial).length;
    final script = sources.where((source) => source.supportStatus == BookSourceSupportStatus.scriptBlocked).length;
    final login = sources.where((source) => source.supportStatus == BookSourceSupportStatus.loginRequired).length;
    return '已导入 ${sources.length} 个书源：可用 $usable，部分可用 $partial，脚本受限 $script，登录受限 $login。';
  }
}
