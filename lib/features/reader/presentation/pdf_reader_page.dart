import 'dart:io';
import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:pdfx/pdfx.dart';

import '../../../domain/models/book.dart';
import '../../../domain/repositories/reading_statistics_repository.dart';
import '../../bookshelf/presentation/bookshelf_view_model.dart';

/// Fixed-layout local PDF reader. PDF pages are intentionally rendered as the
/// document author created them: reader font, filtering and text themes apply
/// to reflowable TXT/EPUB content only.
class PdfReaderPage extends StatefulWidget {
  const PdfReaderPage({
    required this.book,
    required this.bookshelf,
    required this.readingStatistics,
    super.key,
  });

  final Book book;
  final BookshelfViewModel bookshelf;
  final ReadingStatisticsRepository readingStatistics;

  @override
  State<PdfReaderPage> createState() => _PdfReaderPageState();
}

class _PdfReaderPageState extends State<PdfReaderPage> with WidgetsBindingObserver {
  PdfControllerPinch? _controller;
  int _pageCount = 0;
  int _currentPage = 1;
  String? _error;
  Timer? _statisticsTimer;
  DateTime? _readingStartedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final path = widget.book.localPath;
    if (path == null || !File(path).existsSync()) {
      _error = '本地 PDF 文件不存在。';
      return;
    }
    _currentPage = widget.book.readingChapterIndex + 1;
    _controller = PdfControllerPinch(
      document: PdfDocument.openFile(path),
      initialPage: _currentPage,
    );
    _beginReading();
  }

  @override
  void dispose() {
    _controller?.dispose();
    _statisticsTimer?.cancel();
    _flushReadingTime();
    WidgetsBinding.instance.removeObserver(this);
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
      bookId: widget.book.id,
      startedAt: startedAt,
      endedAt: DateTime.now(),
      isCompleted: widget.book.progress >= .9,
    );
    if (restart && mounted) _beginReading();
  }

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          middle: Text(widget.book.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: _pageCount == 0 ? null : Text('$_currentPage / $_pageCount'),
        ),
        child: SafeArea(
          child: _controller == null || _error != null
              ? _errorView()
              : PdfViewPinch(
                  controller: _controller!,
                  onDocumentLoaded: (document) {
                    if (!mounted) return;
                    final safePage = _currentPage.clamp(1, document.pagesCount).toInt();
                    setState(() {
                      _pageCount = document.pagesCount;
                      _currentPage = safePage;
                    });
                  },
                  onPageChanged: (page) {
                    HapticFeedback.selectionClick();
                    _saveProgress(page);
                  },
                  onDocumentError: (_) =>
                      setState(() => _error = 'PDF 无法打开，请确认文件未损坏或受密码保护。'),
                ),
        ),
      );

  Widget _errorView({String? message}) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Text(message ?? _error ?? 'PDF 无法打开。', textAlign: TextAlign.center),
        ),
      );

  Future<void> _saveProgress(int page) async {
    final pageCount = _pageCount;
    final progress = pageCount == 0 ? 0.0 : (page / pageCount).clamp(0, 1).toDouble();
    final updated = widget.book.copyWith(
      readingChapterIndex: page - 1,
      readingChapterTitle: '第 $page 页',
      readingChapterOffset: 0,
      progress: progress,
      lastReadAt: DateTime.now(),
    );
    if (mounted) setState(() => _currentPage = page);
    await widget.bookshelf.updateReading(updated);
  }
}
