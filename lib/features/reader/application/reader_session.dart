import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show FontLoader;

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';

import '../../../domain/models/book.dart';
import '../../../domain/models/reader_settings.dart';
import '../../../domain/repositories/reader_settings_repository.dart';
import '../../../domain/repositories/chapter_content_cache.dart';
import '../../../domain/repositories/reading_statistics_repository.dart';
import '../../../domain/services/reader_content_filter.dart';
import '../../../domain/use_cases/import_reader_font.dart';
import '../../../domain/use_cases/read_book_chapter.dart';
import '../../../domain/use_cases/read_book_toc.dart';
import '../../../domain/use_cases/read_local_book.dart';
import '../../../domain/use_cases/switch_reader_source.dart';
import '../../bookshelf/presentation/bookshelf_view_model.dart';
import '../../listening/application/text_to_speech_controller.dart';

/// Reader view. Fetching, cache access and source rules are kept outside this
/// widget so text rendering and gestures remain responsive.
class ReaderSession extends StatefulWidget {
  const ReaderSession({
    required this.book,
    required this.bookshelf,
    required this.switchSource,
    required this.readChapter,
    required this.readToc,
    required this.readLocalBook,
    required this.readLocalToc,
    required this.settings,
    required this.onSettingsChanged,
    required this.cache,
    required this.importReaderFont,
    required this.readingStatistics,
    super.key,
  });

  final Book book;
  final BookshelfViewModel bookshelf;
  final SwitchReaderSource switchSource;
  final ReadBookChapter readChapter;
  final ReadBookToc readToc;
  final ReadLocalBookChapter readLocalBook;
  final ReadLocalBookToc readLocalToc;
  final ReaderSettingsRepository settings;
  final ValueChanged<ReaderSettings> onSettingsChanged;
  final ChapterContentCache cache;
  final ImportReaderFont importReaderFont;
  final ReadingStatisticsRepository readingStatistics;

  @override
  State<ReaderSession> createState() => _ReaderSessionState();
}

class _ReaderSessionState extends State<ReaderSession> with WidgetsBindingObserver {
  late final ScrollController _scrollController;
  late final TextToSpeechController _tts;
  StreamSubscription<void>? _speechCompletionSubscription;
  late Book _book;
  ReaderChapter? _chapter;
  ReaderSettings _settings = const ReaderSettings();
  Timer? _progressTimer;
  Timer? _statisticsTimer;
  DateTime? _readingStartedAt;
  bool _switching = false;
  bool _loading = true;
  bool _controlsVisible = true;
  String? _notice;
  String? _chapterError;
  static const _contentFilter = ReaderContentFilter();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _book = widget.book;
    _tts = TextToSpeechController()..configure();
    _tts.addListener(_refreshSpeechControls);
    _speechCompletionSubscription = _tts.chapterCompleted.listen((_) => _onChapterSpeechCompleted());
    _scrollController = ScrollController()..addListener(_onScroll);
    _loadSettings();
    _loadChapter(restoreOffset: _book.readingChapterOffset);
    _beginReading();
  }

  @override
  void dispose() {
    _speechCompletionSubscription?.cancel();
    _tts
      ..removeListener(_refreshSpeechControls)
      ..dispose();
    _progressTimer?.cancel();
    _statisticsTimer?.cancel();
    _flushReadingTime();
    WidgetsBinding.instance.removeObserver(this);
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _beginReading();
    } else if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      _flushReadingTime();
    }
  }

  void _beginReading() {
    if (_readingStartedAt != null) return;
    _readingStartedAt = DateTime.now();
    _statisticsTimer = Timer.periodic(const Duration(minutes: 1), (_) => _flushReadingTime(restart: true));
  }

  Future<void> _flushReadingTime({bool restart = false}) async {
    _statisticsTimer?.cancel();
    _statisticsTimer = null;
    final startedAt = _readingStartedAt;
    _readingStartedAt = null;
    if (startedAt == null) return;
    await widget.readingStatistics.record(
      bookId: _book.id,
      startedAt: startedAt,
      endedAt: DateTime.now(),
      isCompleted: _book.progress >= .9,
    );
    if (restart && mounted) _beginReading();
  }

  @override
  Widget build(BuildContext context) {
    final colors = _ReaderColors.fromTheme(_settings.theme);
    return CupertinoPageScaffold(
      navigationBar: _controlsVisible
          ? CupertinoNavigationBar(
              middle: Text(_book.title),
              leading: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => Navigator.of(context).pop(),
                child: const Icon(CupertinoIcons.back),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: _showToc,
                    child: const Icon(CupertinoIcons.list_bullet),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: _chapter == null ? null : _showListeningControls,
                    child: Icon(_tts.isActive ? CupertinoIcons.speaker_2_fill : CupertinoIcons.speaker_2),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: _showReadingOptions,
                    child: const Icon(CupertinoIcons.textformat),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: _book.isLocal || _switching || _book.sourceLinks.length < 2
                        ? null
                        : _showSourceChoices,
                    child: const Icon(CupertinoIcons.arrow_2_squarepath),
                  ),
                ],
              ),
            )
          : null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _controlsVisible = !_controlsVisible);
        },
        onHorizontalDragEnd: _settings.layout == ReaderLayout.page
            ? (details) {
                final velocity = details.primaryVelocity ?? 0;
                if (velocity < -180 && _canGoNext) {
                  HapticFeedback.selectionClick();
                  _loadChapter(index: _chapter!.chapter.index + 1);
                } else if (velocity > 180 && _canGoPrevious) {
                  HapticFeedback.selectionClick();
                  _loadChapter(index: _chapter!.chapter.index - 1);
                }
              }
            : null,
        child: SafeArea(
          child: Container(
            color: colors.paper,
            padding: EdgeInsets.fromLTRB(
              _settings.horizontalPadding,
              _controlsVisible ? 16 : 28,
              _settings.horizontalPadding,
              _controlsVisible ? 10 : 28,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_controlsVisible) ...[
                  Text(
                    _chapter?.chapter.title ?? _book.readingChapterTitle ?? '正在载入章节',
                    style: TextStyle(fontWeight: FontWeight.w600, color: colors.text),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _book.isLocal ? '${_book.localFormat?.label ?? '本地'} 文件' : _book.sourceName ?? '未选择书源',
                    style: TextStyle(color: colors.secondaryText),
                  ),
                  const SizedBox(height: 12),
                ],
                Expanded(child: _readerBody(colors)),
                if (_switching || _loading) const Center(child: CupertinoActivityIndicator()),
                if (_notice != null && _controlsVisible)
                  Text(_notice!, style: TextStyle(color: colors.secondaryText)),
                if (_controlsVisible) ...[
                  if (_tts.isActive) _listeningStatus(colors),
                  _bottomBar(colors),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _bottomBar(_ReaderColors colors) => Row(
        children: [
          Expanded(
            child: CupertinoButton(
              onPressed: _canGoPrevious
                  ? () {
                      HapticFeedback.selectionClick();
                      _loadChapter(index: _chapter!.chapter.index - 1);
                    }
                  : null,
              child: const Text('上一章'),
            ),
          ),
          Text(
            _chapter == null ? '—' : '${_chapter!.chapter.index + 1} / ${_chapter!.chapterCount}',
            style: TextStyle(color: colors.secondaryText),
          ),
          Expanded(
            child: CupertinoButton(
              onPressed: _canGoNext
                  ? () {
                      HapticFeedback.selectionClick();
                      _loadChapter(index: _chapter!.chapter.index + 1);
                    }
                  : null,
              child: const Text('下一章'),
            ),
          ),
        ],
      );

  Widget _listeningStatus(_ReaderColors colors) => Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Row(
          children: [
            Icon(CupertinoIcons.speaker_2_fill, size: 15, color: colors.secondaryText),
            const SizedBox(width: 5),
            Text(
              _tts.isPaused ? '听书已暂停' : '正在朗读本章',
              style: TextStyle(color: colors.secondaryText, fontSize: 12),
            ),
            const Spacer(),
            CupertinoButton(
              padding: EdgeInsets.zero,
              minSize: 28,
              onPressed: _tts.togglePause,
              child: Icon(_tts.isPaused ? CupertinoIcons.play_fill : CupertinoIcons.pause_fill, size: 17),
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              minSize: 28,
              onPressed: _tts.stop,
              child: const Icon(CupertinoIcons.stop_fill, size: 16),
            ),
          ],
        ),
      );

  void _refreshSpeechControls() {
    if (mounted) setState(() {});
  }

  Future<void> _showListeningControls() async {
    if (_chapter == null) return;
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => CupertinoActionSheet(
          title: const Text('听书'),
          message: const Text('使用手机系统语音朗读，正文不会上传到任何服务。朗读完当前章节后会自动进入下一章。'),
          actions: [
            CupertinoActionSheetAction(
              onPressed: () async {
                Navigator.pop(sheetContext);
                if (_tts.isActive) {
                  await _tts.togglePause();
                } else {
                  await _tts.speakChapter(_chapter!.content.text);
                }
              },
              child: Text(_tts.isPaused ? '继续朗读' : (_tts.isSpeaking ? '暂停朗读' : '朗读当前章节')),
            ),
            CupertinoActionSheetAction(
              onPressed: () => setSheetState(() {}),
              child: Column(
                children: [
                  Text('语速 ${_tts.speechRate.toStringAsFixed(1)}'),
                  CupertinoSlider(
                    value: _tts.speechRate,
                    min: .2,
                    max: .8,
                    onChanged: (value) async {
                      await _tts.setSpeechRate(value);
                      setSheetState(() {});
                    },
                  ),
                ],
              ),
            ),
            if (_tts.isActive)
              CupertinoActionSheetAction(
                isDestructiveAction: true,
                onPressed: () async {
                  await _tts.stop();
                  if (sheetContext.mounted) Navigator.pop(sheetContext);
                },
                child: const Text('停止听书'),
              ),
          ],
          cancelButton: CupertinoActionSheetAction(onPressed: () => Navigator.pop(sheetContext), child: const Text('取消')),
        ),
      ),
    );
  }

  Future<void> _onChapterSpeechCompleted() async {
    if (!mounted || !_canGoNext) return;
    final nextIndex = _chapter!.chapter.index + 1;
    await _loadChapter(index: nextIndex);
    if (mounted && _chapter?.chapter.index == nextIndex) {
      await _tts.speakChapter(_chapter!.content.text);
    }
  }

  bool get _canGoPrevious => _chapter != null && _chapter!.chapter.index > 0 && !_loading;
  bool get _canGoNext => _chapter != null && _chapter!.chapter.index + 1 < _chapter!.chapterCount && !_loading;

  Widget _readerBody(_ReaderColors colors) {
    if (_loading && _chapter == null) return const Center(child: CupertinoActivityIndicator());
    if (_chapterError != null && _chapter == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(CupertinoIcons.exclamationmark_circle, size: 40, color: CupertinoColors.systemOrange),
            const SizedBox(height: 12),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 28), child: Text(_chapterError!, textAlign: TextAlign.center)),
            const SizedBox(height: 10),
            CupertinoButton(onPressed: _retryChapter, child: const Text('重新加载')),
          ],
        ),
      );
    }
    final text = _chapter?.content.text;
    if (text == null) return const Center(child: Text('章节暂时无法加载。'));
    return CupertinoScrollbar(
      controller: _scrollController,
      child: SingleChildScrollView(
        key: PageStorageKey('${_book.sourceId}:${_chapter!.chapter.url}'),
        controller: _scrollController,
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        child: Text(
          text,
          style: TextStyle(
            fontSize: _settings.fontSize,
            height: _settings.lineHeight,
            color: colors.text,
            fontFamily: _settings.font?.family,
          ),
        ),
      ),
    );
  }

  Future<void> _loadSettings() async {
    final loaded = await widget.settings.load();
    var effective = loaded;
    if (loaded.font != null) {
      try {
        await _loadFont(loaded.font!);
      } on Object {
        effective = loaded.withoutCustomFont();
        await widget.settings.save(effective);
      }
    }
    if (mounted) setState(() => _settings = effective);
  }

  Future<void> _loadChapter({
    int? index,
    double restoreOffset = 0,
    bool ignoreCache = false,
  }) async {
    if (_tts.isActive) await _tts.stop();
    setState(() {
      _loading = true;
      _notice = null;
      _chapterError = null;
    });
    try {
      final fetched = _book.isLocal
          ? await widget.readLocalBook(_book, chapterIndex: index)
          : await widget.readChapter(
              _book,
              chapterIndex: index,
              ignoreCache: ignoreCache,
            );
      final loaded = _book.isLocal
          ? ReaderChapter(
              chapter: fetched.chapter,
              content: ChapterContent(
                sourceId: fetched.content.sourceId,
                chapterUrl: fetched.content.chapterUrl,
                text: _contentFilter.apply(fetched.content.text, _settings.contentFilters),
              ),
              chapterCount: fetched.chapterCount,
              fromCache: fetched.fromCache,
            )
          : fetched;
      final updated = _book.copyWith(
        readingChapterIndex: loaded.chapter.index,
        readingChapterTitle: loaded.chapter.title,
        readingChapterOffset: restoreOffset,
        progress: _overallProgress(loaded.chapter.index, loaded.chapterCount, restoreOffset),
        lastReadAt: DateTime.now(),
      );
      await widget.bookshelf.updateReading(updated);
      if (!mounted) return;
      setState(() {
        _book = updated;
        _chapter = loaded;
        _notice = loaded.fromCache ? '已从本地缓存打开。' : null;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scrollController.hasClients) return;
        final position = _scrollController.position;
        _scrollController.jumpTo(
          (position.maxScrollExtent * restoreOffset)
              .clamp(0, position.maxScrollExtent)
              .toDouble(),
        );
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _chapterError = _book.isLocal ? '本地书籍加载失败，请确认文件未损坏。' : '章节加载失败，请检查书源网络或规则。';
          _notice = _chapter == null ? null : '当前章节未切换，点击重试即可。';
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _retryChapter() => _loadChapter(
        index: _chapter?.chapter.index ?? _book.readingChapterIndex,
        restoreOffset: _book.readingChapterOffset,
        ignoreCache: true,
      );

  double _overallProgress(int chapterIndex, int chapterCount, double offset) =>
      chapterCount == 0
          ? 0
          : ((chapterIndex + offset) / chapterCount).clamp(0, 1).toDouble();

  void _onScroll() {
    if (_loading || _chapter == null || !_scrollController.hasClients) return;
    _progressTimer?.cancel();
    _progressTimer = Timer(const Duration(milliseconds: 500), _saveScrollProgress);
  }

  Future<void> _saveScrollProgress() async {
    if (_chapter == null || !_scrollController.hasClients) return;
    final position = _scrollController.position;
    final offset = position.maxScrollExtent <= 0
        ? 0.0
        : (position.pixels / position.maxScrollExtent).clamp(0, 1).toDouble();
    final updated = _book.copyWith(
      readingChapterOffset: offset,
      progress: _overallProgress(_chapter!.chapter.index, _chapter!.chapterCount, offset),
      lastReadAt: DateTime.now(),
    );
    _book = updated;
    await widget.bookshelf.updateReading(updated);
  }

  Future<void> _showToc() async {
    try {
      final toc = _book.isLocal ? await widget.readLocalToc(_book) : await widget.readToc(_book);
      if (!mounted) return;
      await showCupertinoModalPopup<void>(
        context: context,
        builder: (sheetContext) => CupertinoPopupSurface(
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: MediaQuery.sizeOf(sheetContext).height * .72,
              child: Column(children: [
                const Padding(padding: EdgeInsets.all(16), child: Text('目录', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600))),
                Expanded(child: ListView.separated(
                  itemCount: toc.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, index) {
                    final item = toc[index];
                    final current = item.chapter.index == _book.readingChapterIndex;
                    return CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        Navigator.pop(sheetContext);
                        _loadChapter(index: item.chapter.index);
                      },
                      child: Row(children: [
                        Icon(current ? CupertinoIcons.play_circle_fill : CupertinoIcons.circle, size: 18),
                        const SizedBox(width: 10),
                        Expanded(child: Text(item.chapter.title, textAlign: TextAlign.left, maxLines: 1, overflow: TextOverflow.ellipsis)),
                        if (item.isCached) const Icon(CupertinoIcons.arrow_down_circle_fill, size: 17),
                      ]),
                    );
                  },
                )),
              ]),
            ),
          ),
        ),
      );
    } catch (_) {
      if (mounted) setState(() => _notice = '目录加载失败，请检查书源网络或规则。');
    }
  }

  Future<void> _showReadingOptions() async {
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => CupertinoPopupSurface(
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 36, height: 5, decoration: BoxDecoration(color: const Color(0x33000000), borderRadius: BorderRadius.circular(99))),
                  const SizedBox(height: 18),
                  const Text('阅读设置', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 18),
                  _SettingsSlider(
                    label: '字号',
                    value: _settings.fontSize,
                    min: 15,
                    max: 28,
                    display: _settings.fontSize.toInt().toString(),
                    onChanged: (value) {
                      final next = _settings.copyWith(fontSize: value);
                      setSheetState(() => _settings = next);
                      _updateSettings(next);
                    },
                  ),
                  _SettingsSlider(
                    label: '行距',
                    value: _settings.lineHeight,
                    min: 1.4,
                    max: 2.4,
                    display: _settings.lineHeight.toStringAsFixed(1),
                    onChanged: (value) {
                      final next = _settings.copyWith(lineHeight: value);
                      setSheetState(() => _settings = next);
                      _updateSettings(next);
                    },
                  ),
                  const SizedBox(height: 12),
                  CupertinoListSection.insetGrouped(
                    margin: EdgeInsets.zero,
                    children: [
                      CupertinoListTile.notched(
                        title: const Text('阅读字体'),
                        additionalInfo: Text(_settings.font?.name ?? '系统字体'),
                        trailing: const CupertinoListTileChevron(),
                        onTap: _showFontOptions,
                      ),
                      CupertinoListTile.notched(
                        title: const Text('内容过滤'),
                        additionalInfo: Text(_settings.contentFilters.isEmpty ? '未启用' : '${_settings.contentFilters.length} 条规则'),
                        trailing: const CupertinoListTileChevron(),
                        onTap: _showContentFilters,
                      ),
                      if (!_book.isLocal)
                        CupertinoListTile.notched(
                          title: const Text('清理本书章节缓存'),
                          trailing: const CupertinoListTileChevron(),
                          onTap: _clearCurrentBookCache,
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const _SettingsLabel('阅读背景'),
                  const SizedBox(height: 8),
                  CupertinoSlidingSegmentedControl<ReaderTheme>(
                    groupValue: _settings.theme,
                    children: const {
                      ReaderTheme.paper: Text('纸张'),
                      ReaderTheme.sepia: Text('护眼'),
                      ReaderTheme.night: Text('夜间'),
                    },
                    onValueChanged: (value) {
                      if (value == null) return;
                      HapticFeedback.selectionClick();
                      final next = _settings.copyWith(theme: value);
                      setSheetState(() => _settings = next);
                      _updateSettings(next);
                    },
                  ),
                  const SizedBox(height: 12),
                  const _SettingsLabel('App 外观'),
                  const SizedBox(height: 8),
                  CupertinoSlidingSegmentedControl<AppAppearance>(
                    groupValue: _settings.appAppearance,
                    children: const {
                      AppAppearance.system: Text('跟随'),
                      AppAppearance.light: Text('日间'),
                      AppAppearance.dark: Text('夜间'),
                    },
                    onValueChanged: (value) {
                      if (value == null) return;
                      HapticFeedback.selectionClick();
                      final next = _settings.copyWith(appAppearance: value);
                      setSheetState(() => _settings = next);
                      _updateSettings(next);
                    },
                  ),
                  const SizedBox(height: 12),
                  CupertinoSlidingSegmentedControl<ReaderLayout>(
                    groupValue: _settings.layout,
                    children: const {
                      ReaderLayout.scroll: Text('滚动'),
                      ReaderLayout.page: Text('章节'),
                    },
                    onValueChanged: (value) {
                      if (value == null) return;
                      HapticFeedback.selectionClick();
                      final next = _settings.copyWith(layout: value);
                      setSheetState(() => _settings = next);
                      _updateSettings(next);
                    },
                  ),
                  const SizedBox(height: 8),
                  CupertinoButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    child: const Text('完成'),
                  ),
                ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _updateSettings(ReaderSettings settings) async {
    HapticFeedback.selectionClick();
    setState(() => _settings = settings);
    await widget.settings.save(settings);
    widget.onSettingsChanged(settings);
  }

  Future<void> _showFontOptions() async {
    final action = await showCupertinoModalPopup<String>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        title: const Text('阅读字体'),
        message: Text(_settings.font == null ? '当前使用系统字体。' : '当前使用：${_settings.font!.name}'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(sheetContext, 'import'),
            child: const Text('导入 .ttf / .otf 字体'),
          ),
          if (_settings.font != null)
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.pop(sheetContext, 'system'),
              child: const Text('恢复系统字体'),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(onPressed: () => Navigator.pop(sheetContext), child: const Text('取消')),
      ),
    );
    if (action == 'import') await _importFont();
    if (action == 'system') await _updateSettings(_settings.withoutCustomFont());
  }

  Future<void> _importFont() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['ttf', 'otf'],
      withData: false,
    );
    final path = result?.files.single.path;
    if (path == null) return;
    try {
      final font = await widget.importReaderFont(path);
      await _loadFont(font);
      await _updateSettings(_settings.copyWith(font: font));
      if (mounted) setState(() => _notice = '已切换到 ${font.name}。');
    } catch (error) {
      if (mounted) setState(() => _notice = '字体导入失败：$error');
    }
  }

  Future<void> _loadFont(ReaderFont font) async {
    final bytes = await File(font.path).readAsBytes();
    if (bytes.isEmpty) throw const FormatException('字体文件为空。');
    final loader = FontLoader(font.family);
    loader.addFont(Future.value(ByteData.sublistView(bytes)));
    await loader.load();
  }

  Future<void> _showContentFilters() async {
    final pattern = TextEditingController();
    final replacement = TextEditingController();
    var isRegExp = false;
    var rules = List<ContentFilterRule>.of(_settings.contentFilters);
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => CupertinoPopupSurface(
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: MediaQuery.sizeOf(context).height * .72,
              child: Column(children: [
                const Padding(padding: EdgeInsets.all(16), child: Text('内容过滤', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600))),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(children: [
                    CupertinoSlidingSegmentedControl<bool>(
                      groupValue: isRegExp,
                      children: const {false: Text('关键词'), true: Text('正则')},
                      onValueChanged: (value) => setSheetState(() => isRegExp = value ?? false),
                    ),
                    const SizedBox(height: 8),
                    CupertinoTextField(controller: pattern, placeholder: isRegExp ? '正则表达式' : '要过滤的文字'),
                    const SizedBox(height: 8),
                    CupertinoTextField(controller: replacement, placeholder: '替换为（留空即删除）'),
                    Align(
                      alignment: Alignment.centerRight,
                      child: CupertinoButton(
                        onPressed: () async {
                          final rule = ContentFilterRule(pattern: pattern.text, replacement: replacement.text, isRegExp: isRegExp);
                          if (!_contentFilter.isValid(rule)) {
                            setState(() => _notice = '过滤规则无效，请检查表达式。');
                            return;
                          }
                          rules.add(rule);
                          pattern.clear();
                          replacement.clear();
                          setSheetState(() {});
                          await _saveFilters(rules);
                        },
                        child: const Text('添加规则'),
                      ),
                    ),
                  ]),
                ),
                Expanded(
                  child: rules.isEmpty
                      ? const Center(child: Text('还没有过滤规则'))
                      : ListView.separated(
                          itemCount: rules.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, index) => CupertinoListTile.notched(
                            title: Text(rules[index].pattern),
                            subtitle: Text(rules[index].isRegExp ? '正则替换' : '关键词替换'),
                            additionalInfo: Text(rules[index].replacement.isEmpty ? '删除' : '替换'),
                            trailing: CupertinoButton(
                              padding: EdgeInsets.zero,
                              onPressed: () async {
                                rules.removeAt(index);
                                setSheetState(() {});
                                await _saveFilters(rules);
                              },
                              child: const Icon(CupertinoIcons.delete, color: CupertinoColors.destructiveRed),
                            ),
                          ),
                        ),
                ),
                CupertinoButton(onPressed: () => Navigator.pop(sheetContext), child: const Text('完成')),
              ]),
            ),
          ),
        ),
      ),
    );
    pattern.dispose();
    replacement.dispose();
  }

  Future<void> _saveFilters(List<ContentFilterRule> rules) async {
    final next = _settings.copyWith(contentFilters: List.unmodifiable(rules));
    await widget.cache.clearAll();
    await _updateSettings(next);
    if (mounted) setState(() => _notice = '过滤规则已保存，旧章节缓存已清理。');
  }

  Future<void> _clearCurrentBookCache() async {
    final sourceId = _book.sourceId;
    if (sourceId == null) return;
    await widget.cache.clearSource(sourceId);
    if (mounted) setState(() => _notice = '已清理当前书源的章节缓存。');
  }

  Future<void> _showSourceChoices() async {
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        title: const Text('手动换源'),
        message: const Text('仅显示已匹配为同一本书的来源。'),
        actions: _book.sourceLinks.where((link) => link.sourceId != _book.sourceId).map((link) => CupertinoActionSheetAction(
          onPressed: () { HapticFeedback.selectionClick(); Navigator.pop(sheetContext); _switchTo(link); }, child: Text(link.sourceName),
        )).toList(),
        cancelButton: CupertinoActionSheetAction(onPressed: () => Navigator.pop(sheetContext), child: const Text('取消')),
      ),
    );
  }

  Future<void> _switchTo(BookSourceLink link) async {
    setState(() { _switching = true; _notice = null; });
    try {
      final selection = await widget.switchSource(_book, link);
      final chapter = selection.chapter;
      final updated = _book.copyWith(
        sourceId: selection.source.id,
        sourceName: selection.source.name,
        readingChapterIndex: chapter?.index,
        readingChapterTitle: chapter?.title,
        // The source selector has matched the current chapter by title when
        // possible. Keep the reader's intra-chapter position in that case.
        readingChapterOffset: _book.readingChapterOffset,
        lastReadAt: DateTime.now(),
      );
      await widget.bookshelf.updateReading(updated);
      if (!mounted) return;
      setState(() {
        _book = updated;
        _notice = chapter == null ? '已切换到 ${selection.source.name}，该来源暂无目录。' : '已切换到 ${selection.source.name}，并定位到 ${chapter.title}。';
      });
      await _loadChapter(index: chapter?.index, restoreOffset: _book.readingChapterOffset);
    } catch (_) {
      if (mounted) setState(() => _notice = '切换失败，请检查书源网络或规则。');
    } finally {
      if (mounted) setState(() => _switching = false);
    }
  }
}

class _SettingsLabel extends StatelessWidget {
  const _SettingsLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: const TextStyle(
            color: CupertinoColors.secondaryLabel,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
}

class _SettingsSlider extends StatelessWidget {
  const _SettingsSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.display,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final String display;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          SizedBox(width: 42, child: Text(label)),
          Expanded(
            child: CupertinoSlider(
              value: value.clamp(min, max).toDouble(),
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
          SizedBox(
            width: 38,
            child: Text(display, textAlign: TextAlign.right, style: const TextStyle(color: CupertinoColors.secondaryLabel)),
          ),
        ],
      );
}

class _ReaderColors {
  const _ReaderColors(this.paper, this.text, this.secondaryText);
  final Color paper;
  final Color text;
  final Color secondaryText;

  factory _ReaderColors.fromTheme(ReaderTheme theme) => switch (theme) {
    ReaderTheme.paper => const _ReaderColors(Color(0xFFF9F6EE), Color(0xFF292827), CupertinoColors.secondaryLabel),
    ReaderTheme.sepia => const _ReaderColors(Color(0xFFF1E7D0), Color(0xFF4C3825), Color(0xFF806B55)),
    ReaderTheme.night => const _ReaderColors(Color(0xFF1C1C1E), Color(0xFFE8E6DF), Color(0xFF9B9B9F)),
  };
}
