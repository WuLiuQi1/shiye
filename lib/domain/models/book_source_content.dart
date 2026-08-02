/// Normalised data returned by a declarative book source.
///
/// These models intentionally contain no source-specific selector syntax, so
/// the search UI and reader can work with ORSP and 阅读/Legado sources alike.
class BookSearchResult {
  const BookSearchResult({
    required this.sourceId,
    required this.title,
    required this.author,
    required this.detailUrl,
    this.coverUrl,
    this.latestChapter,
  });

  final String sourceId;
  final String title;
  final String author;
  final Uri detailUrl;
  final Uri? coverUrl;
  final String? latestChapter;
}

class BookDetails {
  const BookDetails({
    required this.sourceId,
    required this.title,
    required this.author,
    required this.detailUrl,
    required this.tocUrl,
    this.coverUrl,
    this.introduction,
  });

  final String sourceId;
  final String title;
  final String author;
  final Uri detailUrl;
  final Uri tocUrl;
  final Uri? coverUrl;
  final String? introduction;
}

class BookChapter {
  const BookChapter({
    required this.sourceId,
    required this.title,
    required this.url,
    required this.index,
  });

  final String sourceId;
  final String title;
  final Uri url;
  final int index;
}

class ChapterContent {
  const ChapterContent({
    required this.sourceId,
    required this.chapterUrl,
    required this.text,
  });

  final String sourceId;
  final Uri chapterUrl;
  final String text;
}
