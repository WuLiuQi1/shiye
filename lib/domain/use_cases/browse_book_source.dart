import '../models/book_source.dart';
import '../models/book_source_content.dart';
import '../repositories/book_source_gateway.dart';
import '../services/declarative_rule_engine.dart';

/// Runs the source browsing chain outside the UI layer.
class BrowseBookSource {
  const BrowseBookSource(this._gateway, this._engine);

  final BookSourceGateway _gateway;
  final DeclarativeRuleEngine _engine;

  Future<List<BookSearchResult>> search(BookSource source, String keyword) async {
    final rules = source.rules['ruleSearch'] is Map ? Map<String, Object?>.from(source.rules['ruleSearch'] as Map) : source.rules;
    final template = rules['searchUrl'] ?? rules['url'];
    if (template is! String || template.trim().isEmpty) throw const FormatException('书源缺少搜索地址规则。');
    final url = _resolve(source.baseUrl, template.replaceAll('{{key}}', Uri.encodeQueryComponent(keyword)).replaceAll('%s', Uri.encodeQueryComponent(keyword)));
    final document = await _gateway.get(url);
    return _engine.parseSearch(source: source, document: document, responseUrl: url);
  }

  Future<BookDetails> details(BookSource source, Uri url) async {
    final document = await _gateway.get(url);
    return _engine.parseDetails(source: source, document: document, responseUrl: url);
  }

  Future<List<BookChapter>> chapters(BookSource source, Uri url) async {
    final document = await _gateway.get(url);
    return _engine.parseToc(source: source, document: document, responseUrl: url);
  }

  Future<ChapterContent> content(BookSource source, Uri url) async {
    final document = await _gateway.get(url);
    return _engine.parseContent(source: source, document: document, responseUrl: url);
  }

  Uri _resolve(Uri base, String value) => base.resolve(value);
}
