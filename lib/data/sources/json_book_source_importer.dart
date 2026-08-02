import 'dart:convert';

import '../../domain/models/book_source.dart';
import '../../domain/use_cases/import_book_sources.dart';

/// Imports the non-executable subset shared by 阅读/Legado and ORSP sources.
/// Network requests and rule evaluation deliberately belong to a later engine.
class JsonBookSourceImporter implements BookSourceImporter {
  static const _blockedKeyParts = ['javascript', 'java', 'script', 'eval', 'exec', 'js'];
  static const _loginKeyParts = ['cookie', 'login', 'auth', 'token'];
  static const _criticalRuleKeys = [
    'bookSourceUrl',
    'baseUrl',
    'url',
    'searchUrl',
    'ruleSearch',
    'ruleBookInfo',
    'ruleToc',
    'ruleContent',
    'ruleChapter',
  ];
  static final _executableExpression = RegExp(
    r'(@js\s*:|<js>|\bjavascript\s*:|\bjava\s*:|\beval\s*\(|\bexec\s*\()',
    caseSensitive: false,
  );

  @override
  List<BookSource> importJson(String content) {
    final decoded = jsonDecode(content);
    if (decoded is List) {
      var skipped = 0;
      final sources = <BookSource>[];
      for (final entry in decoded) {
        try {
          sources.add(_parse(entry));
        } on FormatException {
          skipped += 1;
        }
      }
      if (sources.isEmpty) {
        throw FormatException('未找到可导入的书源，已跳过 $skipped 个格式错误的条目。');
      }
      return sources;
    }
    if (decoded is Map) {
      final sources = decoded['sources'];
      if (sources is List) {
        final imported = <BookSource>[];
        for (final entry in sources) {
          try {
            imported.add(_parse(entry));
          } on FormatException {
            // Keep large source bundles useful: malformed entries are ignored,
            // while script-dependent entries are imported with an unsupported status.
          }
        }
        if (imported.isEmpty) throw const FormatException('未找到可导入的书源。');
        return imported;
      }
      return [_parse(decoded)];
    }
    throw const FormatException('书源文件必须是 JSON 对象或数组。');
  }

  BookSource _parse(Object? entry) {
    if (entry is! Map) throw const FormatException('书源条目必须是 JSON 对象。');
    final value = Map<String, Object?>.from(entry);
    final audit = _auditRules(value);
    final legacyUrl = _text(value['bookSourceUrl']);
    final url = legacyUrl ?? _text(value['baseUrl']) ?? _text(value['url']);
    if (url == null) throw const FormatException('书源缺少地址。');
    // 阅读/Legado may append a static header JSON object to bookSourceUrl.
    // This app does not import or send that object (in particular, never a
    // Cookie); the address before it is the safe base URL.
    final baseUrl = Uri.tryParse(_baseAddress(url));
    if (baseUrl == null || !baseUrl.hasScheme || !['http', 'https'].contains(baseUrl.scheme)) {
      throw const FormatException('书源地址必须使用 http 或 https。');
    }
    final name = _text(value['bookSourceName']) ?? _text(value['name']);
    if (name == null || name.trim().isEmpty) throw const FormatException('书源缺少名称。');

    final format = legacyUrl != null || value.containsKey('ruleSearch')
        ? BookSourceFormat.legado
        : BookSourceFormat.orsp;
    final id = legacyUrl == null
        ? (_text(value['id']) ?? baseUrl.toString())
        : _baseAddress(legacyUrl);
    final rules = Map<String, Object?>.unmodifiable(value);
    return BookSource(
      id: id,
      name: name,
      baseUrl: baseUrl,
      format: format,
      rules: rules,
      isEnabled: audit.status == BookSourceSupportStatus.usable ||
          audit.status == BookSourceSupportStatus.partial,
      supportStatus: audit.status,
      supportNote: audit.note,
    );
  }

  _RuleAudit _auditRules(Map<String, Object?> value) {
    var hasScript = false;
    var hasCriticalScript = false;
    var hasLogin = false;

    void visit(Object? current, String key, bool critical) {
      final lowerKey = key.toLowerCase();
      final nextCritical = critical || _criticalRuleKeys.any((part) => lowerKey.contains(part.toLowerCase()));
      if (_loginKeyParts.any(lowerKey.contains)) hasLogin = true;
      if (_blockedKeyParts.any(lowerKey.contains)) {
        hasScript = true;
        if (nextCritical) hasCriticalScript = true;
      }
      if (current is String && _executableExpression.hasMatch(current)) {
        hasScript = true;
        if (nextCritical) hasCriticalScript = true;
      }
      if (current is Map) {
        for (final entry in current.entries) {
          visit(entry.value, entry.key.toString(), nextCritical);
        }
      } else if (current is List) {
        for (final item in current) {
          visit(item, key, nextCritical);
        }
      }
    }

    for (final entry in value.entries) {
      visit(entry.value, entry.key.toString(), false);
    }

    if (hasLogin) {
      return const _RuleAudit(
        BookSourceSupportStatus.loginRequired,
        '需要登录、Cookie 或鉴权信息，拾页不会自动携带这些数据。',
      );
    }
    if (hasCriticalScript) {
      return const _RuleAudit(
        BookSourceSupportStatus.scriptBlocked,
        '搜索、目录或正文依赖脚本规则，拾页已导入但不会执行。',
      );
    }
    if (hasScript) {
      return const _RuleAudit(
        BookSourceSupportStatus.partial,
        '包含脚本辅助字段，拾页会忽略脚本，仅使用声明式规则。',
      );
    }
    return const _RuleAudit(BookSourceSupportStatus.usable, null);
  }

  String? _text(Object? value) => value is String ? value.trim() : null;

  String _baseAddress(String value) => value
      .split(RegExp(r',\s*(?=\{)'))
      .first
      .trim();
}

class _RuleAudit {
  const _RuleAudit(this.status, this.note);
  final BookSourceSupportStatus status;
  final String? note;
}
