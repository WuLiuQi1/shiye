import 'package:flutter_test/flutter_test.dart';
import 'package:reader/domain/models/book_source.dart';
import 'package:reader/domain/repositories/book_source_gateway.dart';
import 'package:reader/domain/services/declarative_rule_engine.dart';
import 'package:reader/domain/use_cases/browse_book_source.dart';

void main() {
  final source = BookSource(
    id: 'demo',
    name: '离线示例源',
    baseUrl: Uri(scheme: 'https', host: 'books.example'),
    format: BookSourceFormat.legado,
    rules: {
      'ruleSearch': {
        'searchUrl': '/search?q={{key}}',
        'bookList': '.book',
        'name': '.title@text',
        'author': '.author@text',
        'bookUrl': 'a@href',
      },
      'ruleBookInfo': {
        'name': 'h1@text',
        'author': '.author@text',
        'tocUrl': 'a.toc@href',
      },
      'ruleToc': {
        'chapterList': '.chapter',
        'chapterName': 'a@text',
        'chapterUrl': 'a@href',
      },
      'ruleContent': {'content': '#content@html'},
    },
  );

  final gateway = _FakeGateway({
    'https://books.example/search?q=%E6%8B%BE%E9%A1%B5': '<article class="book"><a href="/book/1"><span class="title">拾页</span><span class="author">小柒</span></a></article>',
    'https://books.example/book/1': '<h1>拾页</h1><span class="author">小柒</span><a class="toc" href="/book/1/toc">目录</a>',
    'https://books.example/book/1/toc': '<li class="chapter"><a href="/book/1/1">第一章</a></li>',
    'https://books.example/book/1/1': '<div id="content">第一段<br>第二段</div>',
  });
  final useCase = BrowseBookSource(gateway, const DeclarativeRuleEngine());

  test('runs search, details, toc and content with offline responses', () async {
    final results = await useCase.search(source, '拾页');
    expect(results.single.title, '拾页');
    expect(results.single.detailUrl.toString(), 'https://books.example/book/1');

    final details = await useCase.details(source, results.single.detailUrl);
    expect(details.tocUrl.toString(), 'https://books.example/book/1/toc');

    final chapters = await useCase.chapters(source, details.tocUrl);
    expect(chapters.single.title, '第一章');

    final content = await useCase.content(source, chapters.single.url);
    expect(content.text, '第一段\n第二段');
  });

  test('supports a safe XPath selector and inline regex replacement', () async {
    final xpathSource = BookSource(
      id: 'xpath',
      name: 'XPath 示例源',
      baseUrl: Uri(scheme: 'https', host: 'books.example'),
      format: BookSourceFormat.legado,
      rules: {
        'ruleSearch': {
          'url': '/search?q=%s',
          'bookList': "//*[contains(@class,'book')]",
          'name': "//*[@id='title']@text##广告##",
          'author': '.author@text',
          'bookUrl': 'a@href',
        },
      },
    );
    final xpathBrowse = BrowseBookSource(
      const _FakeGateway({
        'https://books.example/search?q=%E6%8B%BE%E9%A1%B5': '<article class="book"><a href="/book/1"><span id="title">拾页广告</span><span class="author">小柒</span></a></article>',
      }),
      const DeclarativeRuleEngine(),
    );

    final results = await xpathBrowse.search(xpathSource, '拾页');
    expect(results.single.title, '拾页');
    expect(results.single.author, '小柒');
  });
}

class _FakeGateway implements BookSourceGateway {
  const _FakeGateway(this.responses);

  final Map<String, String> responses;

  @override
  Future<String> get(Uri url) async {
    final response = responses[url.toString()];
    if (response == null) throw StateError('Missing fixture for $url');
    return response;
  }
}
