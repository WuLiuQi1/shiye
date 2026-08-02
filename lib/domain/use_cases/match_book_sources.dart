import '../models/book.dart';
import '../models/book_source.dart';
import '../models/book_source_content.dart';
import '../repositories/book_source_repository.dart';
import 'browse_book_source.dart';

/// Finds only explicit title-and-author matches. It deliberately does not
/// guess: automatic source switching would make a reader lose trust.
class MatchBookSources {
  const MatchBookSources(this._sources, this._browse);

  final BookSourceRepository _sources;
  final BrowseBookSource _browse;

  Future<List<BookSourceLink>> call(BookDetails details, BookSource current) async {
    final candidates = await _sources.loadAll();
    final links = <BookSourceLink>[
      BookSourceLink(sourceId: current.id, sourceName: current.name, detailUrl: details.detailUrl),
    ];
    final keyword = '${details.title} ${details.author}';
    for (final source in candidates.where((item) => item.canBrowse && item.id != current.id)) {
      try {
        final results = await _browse.search(source, keyword);
        final match = results.where((result) => _sameBook(details, result)).firstOrNull;
        if (match != null) links.add(BookSourceLink(sourceId: source.id, sourceName: source.name, detailUrl: match.detailUrl));
      } catch (_) {
        // A failed source is omitted, not presented as a possible switch.
      }
    }
    return links;
  }

  bool _sameBook(BookDetails details, BookSearchResult result) =>
      _normalise(details.title) == _normalise(result.title) && _normalise(details.author) == _normalise(result.author);

  String _normalise(String value) => value.toLowerCase().replaceAll(RegExp(r'[\s\-_—:：,.，。!！?？()（）\[\]【】]'), '');
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
