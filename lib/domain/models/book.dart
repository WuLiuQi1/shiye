class Book {
  const Book({
    required this.id,
    required this.title,
    required this.author,
    required this.progress,
    required this.coverColor,
    required this.lastReadAt,
    this.sourceId,
    this.sourceName,
    this.introduction,
    this.coverUrl,
    this.sourceLinks = const [],
    this.readingChapterIndex = 0,
    this.readingChapterTitle,
    this.readingChapterOffset = 0,
    this.localFormat,
    this.localPath,
    this.localImportedAt,
  });

  final String id;
  final String title;
  final String author;
  final double progress;
  final int coverColor;
  final DateTime lastReadAt;
  final String? sourceId;
  final String? sourceName;
  final String? introduction;
  final Uri? coverUrl;
  final List<BookSourceLink> sourceLinks;
  final int readingChapterIndex;
  final String? readingChapterTitle;
  /// Fractional vertical position within [readingChapterIndex], from 0 to 1.
  final double readingChapterOffset;
  final LocalBookFormat? localFormat;
  final String? localPath;
  final DateTime? localImportedAt;

  bool get isLocal => localPath != null && localFormat != null;

  Book copyWith({
    double? progress,
    DateTime? lastReadAt,
    String? sourceId,
    String? sourceName,
    List<BookSourceLink>? sourceLinks,
    int? readingChapterIndex,
    String? readingChapterTitle,
    double? readingChapterOffset,
    LocalBookFormat? localFormat,
    String? localPath,
    DateTime? localImportedAt,
  }) =>
      Book(
        id: id,
        title: title,
        author: author,
        progress: progress ?? this.progress,
        coverColor: coverColor,
        lastReadAt: lastReadAt ?? this.lastReadAt,
        sourceId: sourceId ?? this.sourceId,
        sourceName: sourceName ?? this.sourceName,
        introduction: introduction,
        coverUrl: coverUrl,
        sourceLinks: sourceLinks ?? this.sourceLinks,
        readingChapterIndex: readingChapterIndex ?? this.readingChapterIndex,
        readingChapterTitle: readingChapterTitle ?? this.readingChapterTitle,
        readingChapterOffset: readingChapterOffset ?? this.readingChapterOffset,
        localFormat: localFormat ?? this.localFormat,
        localPath: localPath ?? this.localPath,
        localImportedAt: localImportedAt ?? this.localImportedAt,
      );
}

enum LocalBookFormat {
  txt('TXT'),
  epub('EPUB'),
  pdf('PDF'),
  mobi('MOBI'),
  azw3('AZW3');

  const LocalBookFormat(this.label);

  final String label;
}

/// A source that has already been verified as representing this book.
/// The reader must never offer arbitrary sources as a switch target.
class BookSourceLink {
  const BookSourceLink({required this.sourceId, required this.sourceName, required this.detailUrl});

  final String sourceId;
  final String sourceName;
  final Uri detailUrl;
}
