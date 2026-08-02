import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/repositories/shared_preferences_bookshelf_repository.dart';
import '../data/repositories/shared_preferences_book_source_repository.dart';
import '../data/repositories/shared_preferences_chapter_content_cache.dart';
import '../data/repositories/shared_preferences_reader_settings_repository.dart';
import '../data/repositories/device_local_book_storage.dart';
import '../data/repositories/device_reader_font_storage.dart';
import '../data/repositories/shared_preferences_reading_statistics_repository.dart';
import '../data/sources/http_book_source_gateway.dart';
import '../data/sources/json_book_source_importer.dart';
import '../data/sources/epub_local_book_parser.dart';
import '../platform/shared_book_intent_service.dart';
import '../domain/services/declarative_rule_engine.dart';
import '../domain/models/reader_settings.dart';
import '../domain/repositories/reading_statistics_repository.dart';
import '../domain/use_cases/browse_book_source.dart';
import '../domain/use_cases/import_book_sources.dart';
import '../domain/use_cases/import_local_book.dart';
import '../domain/use_cases/import_reader_font.dart';
import '../domain/use_cases/match_book_sources.dart';
import '../domain/use_cases/read_book_chapter.dart';
import '../domain/use_cases/read_book_toc.dart';
import '../domain/use_cases/read_local_book.dart';
import '../domain/use_cases/switch_reader_source.dart';
import '../features/bookshelf/presentation/bookshelf_page.dart';
import '../features/bookshelf/presentation/bookshelf_view_model.dart';
import '../features/reader/application/reader_session.dart';
import '../features/reader/presentation/pdf_reader_page.dart';
import '../features/reader/presentation/cache_management_page.dart';
import '../features/search/presentation/book_search_page.dart';
import '../features/search/presentation/book_search_view_model.dart';
import '../features/sources/presentation/book_sources_page.dart';
import '../features/sources/presentation/book_sources_view_model.dart';
import '../features/statistics/presentation/reading_statistics_page.dart';
import '../design_system/shiye_theme.dart';

Future<void> runShiyeApp() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferences = await SharedPreferences.getInstance();
  final bookshelf =
      BookshelfViewModel(SharedPreferencesBookshelfRepository(preferences));
  final importLocalBook = ImportLocalBook(
    bookshelf.repository,
    const DeviceLocalBookStorage(),
    const EpubLocalBookParser(),
  );
  final sources = SharedPreferencesBookSourceRepository(preferences);
  final browse = BrowseBookSource(HttpBookSourceGateway(), const DeclarativeRuleEngine());
  final cache = SharedPreferencesChapterContentCache(preferences);
  final readerSettings = SharedPreferencesReaderSettingsRepository(preferences);
  final readingStatistics = SharedPreferencesReadingStatisticsRepository(preferences);
  final readChapter = ReadBookChapter(
    sources,
    browse,
    cache,
    readerSettings,
  );
  final importBooks = ImportBookSources(JsonBookSourceImporter(), sources);
  runApp(ShiyeApp(
    bookshelf: bookshelf,
    sources: sources,
    browse: browse,
    importBooks: importBooks,
    importLocalBook: importLocalBook,
    matchSources: MatchBookSources(sources, browse),
    switchSource: SwitchReaderSource(sources, browse),
    readChapter: readChapter,
    readToc: ReadBookToc(sources, browse, cache),
    readLocalBook: const ReadLocalBookChapter(EpubLocalBookParser()),
    readLocalToc: const ReadLocalBookToc(EpubLocalBookParser()),
    readerSettings: readerSettings,
    cache: cache,
    importReaderFont: ImportReaderFont(const DeviceReaderFontStorage()),
    readingStatistics: readingStatistics,
  ));
}

class ShiyeApp extends StatefulWidget {
  const ShiyeApp({
    required this.bookshelf,
    required this.sources,
    required this.browse,
    required this.importBooks,
    required this.importLocalBook,
    required this.matchSources,
    required this.switchSource,
    required this.readChapter,
    required this.readToc,
    required this.readLocalBook,
    required this.readLocalToc,
    required this.readerSettings,
    required this.cache,
    required this.importReaderFont,
    required this.readingStatistics,
    super.key,
  });

  final BookshelfViewModel bookshelf;
  final SharedPreferencesBookSourceRepository sources;
  final BrowseBookSource browse;
  final ImportBookSources importBooks;
  final ImportLocalBook importLocalBook;
  final MatchBookSources matchSources;
  final SwitchReaderSource switchSource;
  final ReadBookChapter readChapter;
  final ReadBookToc readToc;
  final ReadLocalBookChapter readLocalBook;
  final ReadLocalBookToc readLocalToc;
  final SharedPreferencesReaderSettingsRepository readerSettings;
  final SharedPreferencesChapterContentCache cache;
  final ImportReaderFont importReaderFont;
  final ReadingStatisticsRepository readingStatistics;

  @override
  State<ShiyeApp> createState() => _ShiyeAppState();
}

class _ShiyeAppState extends State<ShiyeApp> with WidgetsBindingObserver {
  final _navigatorKey = GlobalKey<NavigatorState>();
  final _sharedBooks = SharedBookIntentService();
  StreamSubscription<List<String>>? _sharedBookSubscription;
  AppAppearance _appearance = AppAppearance.system;
  Brightness _platformBrightness =
      WidgetsBinding.instance.platformDispatcher.platformBrightness;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadAppearance();
    _sharedBookSubscription = _sharedBooks.paths.listen(_importSharedBooks);
    Future<void>.delayed(Duration.zero, () async {
      final paths = await _sharedBooks.initialPaths();
      if (mounted) await _importSharedBooks(paths);
    });
  }

  @override
  void dispose() {
    _sharedBookSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    setState(() {
      _platformBrightness =
          WidgetsBinding.instance.platformDispatcher.platformBrightness;
    });
  }

  Future<void> _loadAppearance() async {
    final settings = await widget.readerSettings.load();
    if (mounted) setState(() => _appearance = settings.appAppearance);
  }

  void _handleSettingsChanged(ReaderSettings settings) {
    setState(() => _appearance = settings.appAppearance);
  }

  Future<void> _importSharedBooks(List<String> paths) async {
    final context = _navigatorKey.currentContext;
    if (context == null) return;
    for (final path in paths) {
      try {
        final book = await widget.importLocalBook(path);
        await widget.bookshelf.load();
        if (!mounted) return;
        await Navigator.of(context).push(
          CupertinoPageRoute<void>(
            builder: (_) => book.localFormat == LocalBookFormat.pdf
                ? PdfReaderPage(
                    book: book,
                    bookshelf: widget.bookshelf,
                    readingStatistics: widget.readingStatistics,
                  )
                : ReaderSession(
                    book: book,
                    bookshelf: widget.bookshelf,
                    switchSource: widget.switchSource,
                    readChapter: widget.readChapter,
                    readToc: widget.readToc,
                    readLocalBook: widget.readLocalBook,
                    readLocalToc: widget.readLocalToc,
                    settings: widget.readerSettings,
                    onSettingsChanged: _handleSettingsChanged,
                    cache: widget.cache,
                    importReaderFont: widget.importReaderFont,
                    readingStatistics: widget.readingStatistics,
                  ),
          ),
        );
      } catch (error) {
        if (!mounted) return;
        await showCupertinoDialog<void>(
          context: context,
          builder: (_) => CupertinoAlertDialog(
            title: const Text('无法导入共享的书籍'),
            content: Text(error.toString()),
            actions: [CupertinoDialogAction(onPressed: () => Navigator.pop(context), child: const Text('好'))],
          ),
        );
      }
    }
  }

  Brightness get _effectiveBrightness => switch (_appearance) {
        AppAppearance.system => _platformBrightness,
        AppAppearance.light => Brightness.light,
        AppAppearance.dark => Brightness.dark,
      };

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      title: '拾页',
      navigatorKey: _navigatorKey,
      theme: _effectiveBrightness == Brightness.dark
          ? ShiyeTheme.dark
          : ShiyeTheme.light,
      debugShowCheckedModeBanner: false,
      home: _HomeShell(
        bookshelf: widget.bookshelf,
        sources: widget.sources,
        browse: widget.browse,
        importBooks: widget.importBooks,
        importLocalBook: widget.importLocalBook,
        matchSources: widget.matchSources,
        switchSource: widget.switchSource,
        readChapter: widget.readChapter,
        readToc: widget.readToc,
        readLocalBook: widget.readLocalBook,
        readLocalToc: widget.readLocalToc,
        readerSettings: widget.readerSettings,
        cache: widget.cache,
        importReaderFont: widget.importReaderFont,
        readingStatistics: widget.readingStatistics,
        onReaderSettingsChanged: _handleSettingsChanged,
      ),
    );
  }
}

class _HomeShell extends StatelessWidget {
  const _HomeShell({
    required this.bookshelf,
    required this.sources,
    required this.browse,
    required this.importBooks,
    required this.importLocalBook,
    required this.matchSources,
    required this.switchSource,
    required this.readChapter,
    required this.readToc,
    required this.readLocalBook,
    required this.readLocalToc,
    required this.readerSettings,
    required this.onReaderSettingsChanged,
    required this.cache,
    required this.importReaderFont,
    required this.readingStatistics,
  });

  final BookshelfViewModel bookshelf;
  final SharedPreferencesBookSourceRepository sources;
  final BrowseBookSource browse;
  final ImportBookSources importBooks;
  final ImportLocalBook importLocalBook;
  final MatchBookSources matchSources;
  final SwitchReaderSource switchSource;
  final ReadBookChapter readChapter;
  final ReadBookToc readToc;
  final ReadLocalBookChapter readLocalBook;
  final ReadLocalBookToc readLocalToc;
  final SharedPreferencesReaderSettingsRepository readerSettings;
  final ValueChanged<ReaderSettings> onReaderSettingsChanged;
  final SharedPreferencesChapterContentCache cache;
  final ImportReaderFont importReaderFont;
  final ReadingStatisticsRepository readingStatistics;

  @override
  Widget build(BuildContext context) => BookshelfPage(
        viewModel: bookshelf,
        onOpenBook: (book) => _openBook(context, book),
        onImportLocalBook: () => _importLocalBook(context),
        onSearch: () => Navigator.of(context).push(
          CupertinoPageRoute<void>(
            builder: (_) => BookSearchPage(
              viewModel: BookSearchViewModel(sources, browse),
              sources: sources,
              browse: browse,
              bookshelf: bookshelf,
              matchSources: matchSources,
            ),
          ),
        ),
        onManageSources: () => Navigator.of(context).push(
          CupertinoPageRoute<void>(
            builder: (_) => BookSourcesPage(
              viewModel: BookSourcesViewModel(sources, importBooks),
            ),
          ),
        ),
        onManageCache: () => Navigator.of(context).push(
          CupertinoPageRoute<void>(builder: (_) => CacheManagementPage(cache: cache)),
        ),
        onReadingStatistics: () => Navigator.of(context).push(
          CupertinoPageRoute<void>(
            builder: (_) => ReadingStatisticsPage(
              repository: readingStatistics,
              books: bookshelf.books,
            ),
          ),
        ),
      );

  Future<void> _importLocalBook(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['txt', 'epub', 'pdf', 'mobi', 'azw', 'azw3'],
      withData: false,
    );
    final path = result?.files.single.path;
    if (path == null) return;
    try {
      final book = await importLocalBook(path);
      await bookshelf.load();
      if (!context.mounted) return;
      await _openBook(context, book);
    } catch (error) {
      if (!context.mounted) return;
      await showCupertinoDialog<void>(
        context: context,
        builder: (_) => CupertinoAlertDialog(
          title: const Text('无法导入'),
          content: Text(error.toString()),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(context),
              child: const Text('好'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _openBook(BuildContext context, Book book) =>
      Navigator.of(context).push(
        CupertinoPageRoute<void>(
          builder: (_) => book.localFormat == LocalBookFormat.pdf
              ? PdfReaderPage(
                  book: book,
                  bookshelf: bookshelf,
                  readingStatistics: readingStatistics,
                )
              : ReaderSession(
                  book: book,
                  bookshelf: bookshelf,
                  switchSource: switchSource,
                  readChapter: readChapter,
                  readToc: readToc,
                  readLocalBook: readLocalBook,
                  readLocalToc: readLocalToc,
                  settings: readerSettings,
                  onSettingsChanged: onReaderSettingsChanged,
                  cache: cache,
                  importReaderFont: importReaderFont,
                  readingStatistics: readingStatistics,
                ),
        ),
      );
}
