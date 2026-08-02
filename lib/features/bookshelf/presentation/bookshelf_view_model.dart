import 'package:flutter/foundation.dart';

import '../../../domain/models/book.dart';
import '../../../domain/repositories/bookshelf_repository.dart';

class BookshelfViewModel extends ChangeNotifier {
  BookshelfViewModel(this._repository);

  final BookshelfRepository _repository;
  List<Book> _books = const [];
  bool _isLoading = false;

  List<Book> get books => List.unmodifiable(_books);
  bool get isLoading => _isLoading;
  BookshelfRepository get repository => _repository;

  Future<void> load() async {
    if (_isLoading) return;
    _isLoading = true;
    notifyListeners();
    _books = await _repository.loadBooks();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> add(Book book) async {
    await _repository.save(book);
    await load();
  }

  Future<void> updateReading(Book book) => add(book);
}
