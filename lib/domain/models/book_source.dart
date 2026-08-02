enum BookSourceFormat { legado, orsp }

enum BookSourceSupportStatus { usable, partial, scriptBlocked, loginRequired }

/// A declarative source definition. Rules are data only: the app never
/// evaluates JavaScript or loads executable code from an imported source.
class BookSource {
  const BookSource({
    required this.id,
    required this.name,
    required this.baseUrl,
    required this.format,
    required this.rules,
    this.isEnabled = true,
    this.supportStatus = BookSourceSupportStatus.usable,
    this.supportNote,
  });

  final String id;
  final String name;
  final Uri baseUrl;
  final BookSourceFormat format;
  final Map<String, Object?> rules;
  final bool isEnabled;
  final BookSourceSupportStatus supportStatus;
  final String? supportNote;

  bool get canBrowse =>
      isEnabled &&
      (supportStatus == BookSourceSupportStatus.usable ||
          supportStatus == BookSourceSupportStatus.partial);

  BookSource copyWith({
    bool? isEnabled,
    BookSourceSupportStatus? supportStatus,
    String? supportNote,
  }) =>
      BookSource(
        id: id,
        name: name,
        baseUrl: baseUrl,
        format: format,
        rules: rules,
        isEnabled: isEnabled ?? this.isEnabled,
        supportStatus: supportStatus ?? this.supportStatus,
        supportNote: supportNote ?? this.supportNote,
      );
}
