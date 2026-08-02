/// Parsed metadata and reading data for a device-local book.
///
/// Keeping this interface in domain means the reader never needs to know which
/// archive/XML implementation is used for EPUB files.
class LocalBookMetadata {
  const LocalBookMetadata({required this.title, required this.author});

  final String title;
  final String author;
}

class LocalBookChapterInfo {
  const LocalBookChapterInfo({required this.index, required this.title});

  final int index;
  final String title;
}

class LocalBookChapterContent extends LocalBookChapterInfo {
  const LocalBookChapterContent({
    required super.index,
    required super.title,
    required this.text,
    required this.chapterCount,
  });

  final String text;
  final int chapterCount;
}

abstract interface class LocalBookParser {
  Future<LocalBookMetadata> inspectEpub(String path);

  Future<List<LocalBookChapterInfo>> epubToc(String path);

  Future<LocalBookChapterContent> readEpubChapter(String path, int index);

}
