enum ReaderTheme { paper, sepia, night }

enum ReaderLayout { scroll, page }

enum AppAppearance { system, light, dark }

class ReaderFont {
  const ReaderFont({required this.family, required this.path, required this.name});

  final String family;
  final String path;
  final String name;
}

class ContentFilterRule {
  const ContentFilterRule({
    required this.pattern,
    this.replacement = '',
    this.isRegExp = false,
  });

  final String pattern;
  final String replacement;
  final bool isRegExp;
}

class ReaderSettings {
  const ReaderSettings({
    this.fontSize = 19,
    this.lineHeight = 1.85,
    this.horizontalPadding = 28,
    this.theme = ReaderTheme.paper,
    this.layout = ReaderLayout.scroll,
    this.appAppearance = AppAppearance.system,
    this.font,
    this.contentFilters = const [],
  });

  final double fontSize;
  final double lineHeight;
  final double horizontalPadding;
  final ReaderTheme theme;
  final ReaderLayout layout;
  final AppAppearance appAppearance;
  final ReaderFont? font;
  final List<ContentFilterRule> contentFilters;

  ReaderSettings copyWith({
    double? fontSize,
    double? lineHeight,
    double? horizontalPadding,
    ReaderTheme? theme,
    ReaderLayout? layout,
    AppAppearance? appAppearance,
    ReaderFont? font,
    List<ContentFilterRule>? contentFilters,
  }) => ReaderSettings(
        fontSize: fontSize ?? this.fontSize,
        lineHeight: lineHeight ?? this.lineHeight,
        horizontalPadding: horizontalPadding ?? this.horizontalPadding,
        theme: theme ?? this.theme,
        layout: layout ?? this.layout,
        appAppearance: appAppearance ?? this.appAppearance,
        font: font ?? this.font,
        contentFilters: contentFilters ?? this.contentFilters,
      );

  ReaderSettings withoutCustomFont() => ReaderSettings(
        fontSize: fontSize,
        lineHeight: lineHeight,
        horizontalPadding: horizontalPadding,
        theme: theme,
        layout: layout,
        appAppearance: appAppearance,
        contentFilters: contentFilters,
      );
}
