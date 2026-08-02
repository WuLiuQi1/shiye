import 'package:flutter_test/flutter_test.dart';
import 'package:reader/domain/models/reader_settings.dart';
import 'package:reader/domain/services/reader_content_filter.dart';

void main() {
  const filter = ReaderContentFilter();

  test('applies keyword and regular-expression cleanup rules', () {
    final result = filter.apply('正文\n广告：请关注\n第 12 页', const [
      ContentFilterRule(pattern: '广告：请关注\n'),
      ContentFilterRule(pattern: r'第\s+\d+\s+页', isRegExp: true),
    ]);

    expect(result, '正文\n');
  });

  test('rejects invalid regular expressions before saving', () {
    expect(filter.isValid(const ContentFilterRule(pattern: '[', isRegExp: true)), isFalse);
  });
}
