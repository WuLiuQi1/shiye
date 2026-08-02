import '../models/reader_settings.dart';

/// Applies user-owned text cleanup rules. Rules never run scripts and affect
/// only the chapter text stored on this device.
class ReaderContentFilter {
  const ReaderContentFilter();

  String apply(String text, Iterable<ContentFilterRule> rules) {
    var result = text;
    for (final rule in rules) {
      final pattern = rule.pattern.trim();
      if (pattern.isEmpty) continue;
      result = rule.isRegExp
          ? result.replaceAll(RegExp(pattern, multiLine: true), rule.replacement)
          : result.replaceAll(pattern, rule.replacement);
    }
    return result;
  }

  bool isValid(ContentFilterRule rule) {
    if (rule.pattern.trim().isEmpty) return false;
    if (!rule.isRegExp) return true;
    try {
      RegExp(rule.pattern);
      return true;
    } on FormatException {
      return false;
    }
  }
}
