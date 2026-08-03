import 'package:flutter_test/flutter_test.dart';
import 'package:reader/data/sources/json_book_source_importer.dart';
import 'package:reader/domain/models/book_source.dart';

void main() {
  final importer = JsonBookSourceImporter();

  test('imports a 阅读/Legado JSON source without executing rules', () {
    final sources = importer.importJson('''
      [{"bookSourceUrl":"https://example.com","bookSourceName":"示例源","ruleSearch":{"bookList":".item"}}]
    ''');

    expect(sources, hasLength(1));
    expect(sources.single.format, BookSourceFormat.legado);
    expect(sources.single.rules['ruleSearch'], isA<Map<String, Object?>>());
  });

  test('keeps the safe base URL when a Legado source appends header data', () {
    final sources = importer.importJson('''
      [{"bookSourceUrl":"https://example.com, {\\"User-Agent\\":\\"reader\\"}","bookSourceName":"示例源","ruleSearch":{"url":"/search/%s"}}]
    ''');

    expect(sources.single.baseUrl.toString(), 'https://example.com');
  });

  test('imports an ORSP-style JSON source', () {
    final sources = importer.importJson('[{"id":"orsp.demo","name":"ORSP 示例","baseUrl":"https://example.org"}]');

    expect(sources.single.format, BookSourceFormat.orsp);
    expect(sources.single.id, 'orsp.demo');
  });

  test('imports sources with non-critical script fields as partially usable', () {
    final sources = importer.importJson(
      '[{"name":"辅助脚本源","url":"https://example.com","jsLib":"function helper() {}","ruleSearch":{"url":"/search/%s"}}]',
    );

    expect(sources.single.supportStatus, BookSourceSupportStatus.partial);
    expect(sources.single.canBrowse, isTrue);
  });

  test('imports script-dependent sources but disables browsing', () {
    final sources = importer.importJson(
      '[{"bookSourceUrl":"https://example.com","bookSourceName":"脚本源","ruleSearch":{"url":"@js:buildUrl()"}}]',
    );

    expect(sources.single.supportStatus, BookSourceSupportStatus.scriptBlocked);
    expect(sources.single.isEnabled, isFalse);
    expect(sources.single.canBrowse, isFalse);
    expect(sources.single.supportNote, contains('不会执行'));
  });

  test('imports login-dependent sources but disables browsing', () {
    final sources = importer.importJson(
      '[{"bookSourceUrl":"https://example.com","bookSourceName":"登录源","loginUrl":"https://example.com/login","ruleSearch":{"url":"/search/%s"}}]',
    );

    expect(sources.single.supportStatus, BookSourceSupportStatus.loginRequired);
    expect(sources.single.canBrowse, isFalse);
  });

  test('keeps safe and script-dependent entries when importing a source bundle', () {
    final sources = importer.importJson('''
      [
        {"bookSourceUrl":"https://safe.example.com","bookSourceName":"可导入源","ruleSearch":{"bookList":".item"}},
        {"bookSourceUrl":"https://unsafe.example.com","bookSourceName":"不支持源","ruleSearch":{"url":"@js:buildUrl()"}}
      ]
    ''');

    expect(sources, hasLength(2));
    expect(sources.first.name, '可导入源');
    expect(sources.last.supportStatus, BookSourceSupportStatus.scriptBlocked);
  });
}
