import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../domain/repositories/book_source_gateway.dart';

/// Bounded, plain HTTP fetching for declarative sources. Imported rules are
/// never evaluated as code; this gateway only returns response text.
class HttpBookSourceGateway implements BookSourceGateway {
  HttpBookSourceGateway({HttpClient? client}) : _client = client ?? HttpClient();

  final HttpClient _client;
  static const _maximumResponseBytes = 5 * 1024 * 1024;

  @override
  Future<String> get(Uri url) async {
    if (!url.hasScheme || !const {'http', 'https'}.contains(url.scheme)) {
      throw const FormatException('书源请求地址必须使用 http 或 https。');
    }
    final request = await _client.getUrl(url).timeout(const Duration(seconds: 12));
    request.followRedirects = true;
    final response = await request.close().timeout(const Duration(seconds: 15));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('书源返回 HTTP ${response.statusCode}', uri: url);
    }
    final bytes = <int>[];
    await for (final chunk in response) {
      bytes.addAll(chunk);
      if (bytes.length > _maximumResponseBytes) {
        throw HttpException('书源响应过大，已取消加载。', uri: url);
      }
    }
    return utf8.decode(bytes);
  }

  void close() => _client.close(force: true);
}
