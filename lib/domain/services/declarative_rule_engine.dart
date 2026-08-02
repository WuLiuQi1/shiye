import 'package:html/parser.dart' as html_parser;

import '../models/book_source.dart';
import '../models/book_source_content.dart';

/// Evaluates the safe, data-only subset of imported source rules.
///
/// Supported selectors deliberately stay small for the first release: element,
/// `.class`, `#id`, `element.class`, `@text`, `@html` and `@attribute`. XPath
/// supports the corresponding simple `//element`, `//*[@id='x']` and
/// `//*[contains(@class,'x')]` forms. No selector can execute code.
class DeclarativeRuleEngine {
  const DeclarativeRuleEngine();

  List<BookSearchResult> parseSearch({
    required BookSource source,
    required String document,
    required Uri responseUrl,
  }) {
    final rules = _section(source.rules, 'search');
    final items = _selectAll(document, _value(rules, ['bookList', 'list', 'items']));
    return [
      for (final item in items)
        BookSearchResult(
          sourceId: source.id,
          title: _required(item, _value(rules, ['name', 'bookName', 'title'])),
          author: _text(item, _value(rules, ['author', 'bookAuthor'])) ?? '未知作者',
          detailUrl: _requiredUrl(
            responseUrl,
            _required(item, _value(rules, ['bookUrl', 'url', 'detailUrl'])),
          ),
          coverUrl: _url(responseUrl, _text(item, _value(rules, ['coverUrl', 'cover']))),
          latestChapter: _text(item, _value(rules, ['latestChapter', 'lastChapter'])),
        ),
    ];
  }

  BookDetails parseDetails({
    required BookSource source,
    required String document,
    required Uri responseUrl,
  }) {
    final rules = _section(source.rules, 'bookInfo');
    final toc = _text(document, _value(rules, ['tocUrl', 'chapterUrl', 'catalogUrl'])) ?? responseUrl.toString();
    return BookDetails(
      sourceId: source.id,
      title: _required(document, _value(rules, ['name', 'bookName', 'title'])),
      author: _text(document, _value(rules, ['author', 'bookAuthor'])) ?? '未知作者',
      detailUrl: responseUrl,
      tocUrl: _requiredUrl(responseUrl, toc),
      coverUrl: _url(responseUrl, _text(document, _value(rules, ['coverUrl', 'cover']))),
      introduction: _text(document, _value(rules, ['intro', 'introduction'])),
    );
  }

  List<BookChapter> parseToc({
    required BookSource source,
    required String document,
    required Uri responseUrl,
  }) {
    final rules = _section(source.rules, 'toc');
    final items = _selectAll(document, _value(rules, ['chapterList', 'list', 'items']));
    return [
      for (var index = 0; index < items.length; index++)
        BookChapter(
          sourceId: source.id,
          title: _required(items[index], _value(rules, ['chapterName', 'name', 'title'])),
          url: _requiredUrl(responseUrl, _required(items[index], _value(rules, ['chapterUrl', 'url']))),
          index: index,
        ),
    ];
  }

  ChapterContent parseContent({
    required BookSource source,
    required String document,
    required Uri responseUrl,
  }) {
    final rules = _section(source.rules, 'content');
    final raw = _required(document, _value(rules, ['content', 'text', 'body']));
    final replacements = rules['replaceRegex'];
    final cleaned = _replace(raw, replacements);
    return ChapterContent(sourceId: source.id, chapterUrl: responseUrl, text: _normaliseText(cleaned));
  }

  Map<String, Object?> _section(Map<String, Object?> rules, String name) {
    final legacyName = switch (name) {
      'search' => 'ruleSearch',
      'bookInfo' => 'ruleBookInfo',
      'toc' => 'ruleToc',
      'content' => 'ruleContent',
      _ => name,
    };
    final value = rules[legacyName] ?? rules[name];
    return value is Map ? Map<String, Object?>.from(value) : rules;
  }

  String? _value(Map<String, Object?> rules, List<String> keys) {
    for (final key in keys) {
      final value = rules[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return null;
  }

  String _required(String document, String? rule) {
    final result = _text(document, rule);
    if (result == null || result.isEmpty) throw const FormatException('书源规则未提取到必填字段。');
    return result;
  }

  String? _text(String document, String? rule) {
    if (rule == null || rule.isEmpty) return null;
    final replacements = rule.split('##');
    final expression = replacements.first.trim();
    final parts = _ruleParts(expression);
    final element = _first(document, parts.first);
    if (element == null) return null;
    String? result;
    if (parts.length == 1 || parts[1] == 'text') result = _plainText(element);
    else if (parts[1] == 'html') result = _innerHtml(element);
    else if (parts.length == 2 && _isAttribute(parts[1])) result = _attribute(element, parts[1]);
    else {
      final nested = _first(element, parts[1]);
      final target = nested ?? element;
      result = parts.length >= 3 && parts[2].isNotEmpty
          ? _attribute(target, parts[2])
          : _plainText(target);
    }
    if (result == null) return null;
    // A safe subset of Legado's inline "selector##pattern##replacement"
    // syntax.  It is plain regular-expression substitution, never code.
    if (replacements.length == 3) {
      try {
        return result.replaceAll(RegExp(replacements[1]), replacements[2]);
      } on FormatException {
        throw const FormatException('书源中的正则替换规则无效。');
      }
    }
    if (replacements.length != 1) {
      throw const FormatException('不支持的书源规则链。');
    }
    return result;
  }

  bool _isAttribute(String value) => const {'href', 'src', 'id', 'class', 'title', 'data-url'}.contains(value);

  List<String> _selectAll(String document, String? selector) {
    if (selector == null || selector.isEmpty) return const [];
    final elementSelector = _ruleParts(selector).first.trim();
    final css = _cssSelector(elementSelector);
    try {
      return html_parser.parse(document).querySelectorAll(css).map((node) => node.outerHtml).toList();
    } on Object {
      throw FormatException('不支持的 CSS/XPath 选择器：$elementSelector');
    }
  }

  String? _first(String document, String selector) {
    final matches = _selectAll(document, selector);
    return matches.isEmpty ? null : matches.first;
  }

  String _cssSelector(String selector) {
    if (!selector.startsWith('//')) return selector;
    final id = RegExp(r'''@id\s*=\s*['"]([^'"]+)''').firstMatch(selector)?.group(1);
    if (id != null) return '#$id';
    final className = RegExp(r'''contains\(@class\s*,\s*['"]([^'"]+)''').firstMatch(selector)?.group(1);
    final tag = RegExp(r'^//([a-zA-Z][\w-]*)').firstMatch(selector)?.group(1) ?? '';
    if (className != null) return '$tag.$className';
    if (tag.isNotEmpty) return tag;
    throw const FormatException('不支持的 XPath 选择器。');
  }

  /// XPath attribute tests contain `@` themselves.  Only an ending read mode
  /// such as `@text` is a rule separator; the `@id` inside
  /// `//*[@id='chapter']` must remain part of the XPath.
  List<String> _ruleParts(String expression) {
    if (!expression.trimLeft().startsWith('//')) return expression.split('@');
    final match = RegExp(r'@(text|html|href|src|id|class|title|data-url)$').firstMatch(expression);
    if (match == null) return [expression];
    return [expression.substring(0, match.start), match.group(1)!];
  }

  String? _attribute(String element, String name) =>
      RegExp("$name\\s*=\\s*[\"']([^\"']*)[\"']", caseSensitive: false).firstMatch(element)?.group(1);

  String _innerHtml(String element) => element.replaceFirst(RegExp(r'^<[^>]+>|</[^>]+>$'), '');

  String _plainText(String element) => _innerHtml(element).replaceAll(RegExp(r'<[^>]*>'), ' ').replaceAll('&nbsp;', ' ').trim();

  String _replace(String value, Object? replacements) {
    var result = value;
    if (replacements is Map) {
      replacements.forEach((pattern, replacement) {
        if (pattern is String && replacement is String) result = result.replaceAll(RegExp(pattern), replacement);
      });
    } else if (replacements is List) {
      for (final item in replacements) {
        if (item is! Map) continue;
        final pattern = item['regex'] ?? item['pattern'];
        final replacement = item['replacement'] ?? item['replace'];
        if (pattern is String && replacement is String) result = result.replaceAll(RegExp(pattern), replacement);
      }
    }
    return result;
  }

  String _normaliseText(String text) => text
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</p\s*>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll(RegExp(r'\n[ \t]*\n+'), '\n\n')
      .trim();

  Uri _requiredUrl(Uri base, String raw) => _url(base, raw) ?? (throw const FormatException('书源规则给出了无效链接。'));

  Uri? _url(Uri base, String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final value = Uri.tryParse(raw);
    if (value == null) return null;
    return value.hasScheme ? value : base.resolveUri(value);
  }
}
