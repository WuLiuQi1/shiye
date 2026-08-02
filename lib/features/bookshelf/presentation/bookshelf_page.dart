import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../../domain/models/book.dart';
import '../../../design_system/shiye_theme.dart';
import 'bookshelf_view_model.dart';

class BookshelfPage extends StatefulWidget {
  const BookshelfPage({
    required this.viewModel,
    required this.onOpenBook,
    required this.onSearch,
    required this.onImportLocalBook,
    required this.onManageSources,
    required this.onManageCache,
    required this.onReadingStatistics,
    super.key,
  });

  final BookshelfViewModel viewModel;
  final ValueChanged<Book> onOpenBook;
  final VoidCallback onSearch;
  final VoidCallback onImportLocalBook;
  final VoidCallback onManageSources;
  final VoidCallback onManageCache;
  final VoidCallback onReadingStatistics;

  @override
  State<BookshelfPage> createState() => _BookshelfPageState();
}

class _BookshelfPageState extends State<BookshelfPage> {
  @override
  void initState() {
    super.initState();
    widget.viewModel.load();
  }

  @override
  void dispose() {
    widget.viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: SafeArea(
        bottom: false,
        child: AnimatedBuilder(
          animation: widget.viewModel,
          builder: (context, _) {
            final books = widget.viewModel.books;
            final recent = books.isEmpty
                ? null
                : books.reduce((a, b) => a.lastReadAt.isAfter(b.lastReadAt) ? a : b);
            return CustomScrollView(
              slivers: [
                CupertinoSliverNavigationBar(
                  largeTitle: const Text('书库'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: _showAddMenu,
                        child: const Icon(CupertinoIcons.plus_circle),
                      ),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: _showMoreMenu,
                        child: const Icon(CupertinoIcons.ellipsis_circle),
                      ),
                    ],
                  ),
                ),
                if (recent != null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                      child: _ContinueReadingCard(
                        book: recent,
                        onTap: () => widget.onOpenBook(recent),
                      ),
                    ),
                  ),
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
                    child: Text(
                      '全部图书',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                  sliver: widget.viewModel.isLoading
                      ? const SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(child: CupertinoActivityIndicator()),
                        )
                      : books.isEmpty
                      ? SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(CupertinoIcons.book, size: 42, color: CupertinoColors.tertiaryLabel),
                                const SizedBox(height: 12),
                                const Text('还没有图书\n搜索并加入书架后会显示在这里', textAlign: TextAlign.center),
                                const SizedBox(height: 8),
                                CupertinoButton(
                                  onPressed: _showAddMenu,
                                  child: const Text('添加图书'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : SliverGrid.builder(
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            mainAxisSpacing: 22,
                            crossAxisSpacing: 16,
                            childAspectRatio: .55,
                          ),
                          itemCount: books.length,
                          itemBuilder: (context, index) => _BookTile(
                            book: books[index],
                            onTap: () => widget.onOpenBook(books[index]),
                          ),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _showAddMenu() async {
    HapticFeedback.selectionClick();
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        title: const Text('添加图书'),
        message: const Text('可以从书源搜索，也可以像 Apple Books 一样导入本地文件。'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(sheetContext);
              widget.onSearch();
            },
            child: const Text('搜索网络书源'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(sheetContext);
              widget.onImportLocalBook();
            },
            child: const Text('导入本地书籍'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(sheetContext),
          child: const Text('取消'),
        ),
      ),
    );
  }

  Future<void> _showMoreMenu() async {
    HapticFeedback.selectionClick();
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            onPressed: () { Navigator.pop(sheetContext); widget.onReadingStatistics(); },
            child: const Text('阅读统计'),
          ),
          CupertinoActionSheetAction(
            onPressed: () { Navigator.pop(sheetContext); widget.onManageSources(); },
            child: const Text('管理书源'),
          ),
          CupertinoActionSheetAction(
            onPressed: () { Navigator.pop(sheetContext); widget.onManageCache(); },
            child: const Text('缓存管理'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(sheetContext),
          child: const Text('取消'),
        ),
      ),
    );
  }
}

class _ContinueReadingCard extends StatelessWidget {
  const _ContinueReadingCard({required this.book, required this.onTap});

  final Book book;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: CupertinoColors.systemBackground.resolveFrom(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ShiyeTheme.separator),
          ),
          child: Row(
            children: [
              _MiniCover(book: book),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('继续阅读', style: TextStyle(color: CupertinoColors.secondaryLabel, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text(book.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text(book.readingChapterTitle ?? book.author,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: CupertinoColors.secondaryLabel, fontSize: 13)),
                    const SizedBox(height: 10),
                    _ProgressBar(progress: book.progress),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(CupertinoIcons.chevron_forward, color: CupertinoColors.tertiaryLabel, size: 18),
            ],
          ),
        ),
      );
}

class _BookTile extends StatelessWidget {
  const _BookTile({required this.book, required this.onTap});

  final Book book;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '打开《${book.title}》',
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _Cover(book: book)),
            const SizedBox(height: 8),
            if (book.isLocal) ...[
              Text(
                book.localFormat?.label ?? '本地',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: CupertinoColors.secondaryLabel, fontSize: 11),
              ),
              const SizedBox(height: 2),
            ],
            Text(book.title, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            if (book.progress > 0) ...[
              const SizedBox(height: 5),
              _ProgressBar(progress: book.progress),
            ],
          ],
        ),
      ),
    );
  }
}

class _Cover extends StatelessWidget {
  const _Cover({required this.book});

  final Book book;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: Color(book.coverColor),
          borderRadius: BorderRadius.circular(7),
          boxShadow: const [
            BoxShadow(color: Color(0x30000000), blurRadius: 12, offset: Offset(0, 7)),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(width: 24, height: 3, color: const Color(0x55FFFFFF)),
              const Spacer(),
              Text(book.title,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFFFFFFFF), fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(book.author,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xDFFFFFFF), fontSize: 11)),
              if (book.isLocal) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0x30FFFFFF),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    book.localFormat?.label ?? 'LOCAL',
                    style: const TextStyle(
                      color: Color(0xFFFFFFFF),
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
}

class _MiniCover extends StatelessWidget {
  const _MiniCover({required this.book});

  final Book book;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 48,
        height: 68,
        child: _Cover(book: book),
      );
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          height: 3,
          child: Stack(
            children: [
              const Positioned.fill(child: ColoredBox(color: ShiyeTheme.separator)),
              FractionallySizedBox(
                widthFactor: progress.clamp(0, 1).toDouble(),
                child: const ColoredBox(color: CupertinoColors.activeGreen),
              ),
            ],
          ),
        ),
      );
}
