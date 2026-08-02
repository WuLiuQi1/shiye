import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../../domain/models/book.dart';
import '../../../domain/models/book_source.dart';
import '../../../domain/models/book_source_content.dart';
import '../../../domain/repositories/book_source_repository.dart';
import '../../../domain/use_cases/browse_book_source.dart';
import '../../../domain/use_cases/match_book_sources.dart';
import '../../bookshelf/presentation/bookshelf_view_model.dart';
import 'book_search_view_model.dart';

class BookSearchPage extends StatefulWidget {
  const BookSearchPage({
    required this.viewModel,
    required this.sources,
    required this.browse,
    required this.bookshelf,
    required this.matchSources,
    super.key,
  });

  final BookSearchViewModel viewModel;
  final BookSourceRepository sources;
  final BrowseBookSource browse;
  final BookshelfViewModel bookshelf;
  final MatchBookSources matchSources;

  @override
  State<BookSearchPage> createState() => _BookSearchPageState();
}

class _BookSearchPageState extends State<BookSearchPage> {
  final _keyword = TextEditingController();

  @override
  void dispose() {
    _keyword.dispose();
    widget.viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
        navigationBar: const CupertinoNavigationBar(middle: Text('搜索')),
        child: SafeArea(
          child: AnimatedBuilder(
            animation: widget.viewModel,
            builder: (context, _) => Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: CupertinoSearchTextField(
                    controller: _keyword,
                    onSubmitted: widget.viewModel.search,
                    placeholder: '搜索书名或作者',
                  ),
                ),
                if (widget.viewModel.isLoading)
                  const Padding(padding: EdgeInsets.all(8), child: CupertinoActivityIndicator()),
                if (widget.viewModel.message != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 10, 24, 4),
                    child: Text(
                      widget.viewModel.message!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: widget.viewModel.failedSourceCount > 0
                            ? CupertinoColors.systemOrange.resolveFrom(context)
                            : CupertinoColors.secondaryLabel.resolveFrom(context),
                      ),
                    ),
                  ),
                Expanded(
                  child: ListView.separated(
                    itemCount: widget.viewModel.results.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 1),
                    itemBuilder: (context, index) {
                      final result = widget.viewModel.results[index];
                      return CupertinoListSection.insetGrouped(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        children: [
                          CupertinoListTile.notched(
                            title: Text(result.title),
                            subtitle: Text('${result.author} · ${result.sourceId}'),
                            leading: _ResultCover(title: result.title),
                            trailing: const CupertinoListTileChevron(),
                            onTap: () {
                              HapticFeedback.selectionClick();
                              _openDetails(result);
                            },
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  Future<void> _openDetails(BookSearchResult result) async {
    final source = (await widget.sources.loadAll()).where((item) => item.id == result.sourceId).firstOrNull;
    if (source == null || !mounted) return;
    await Navigator.of(context).push<void>(CupertinoPageRoute<void>(
      builder: (_) => BookDetailsPage(
        result: result,
        source: source,
        browse: widget.browse,
        bookshelf: widget.bookshelf,
        matchSources: widget.matchSources,
      ),
    ));
  }
}

class _ResultCover extends StatelessWidget {
  const _ResultCover({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => Container(
        width: 38,
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: CupertinoTheme.of(context).primaryColor.withOpacity(.18),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text(
          title.isEmpty ? '书' : String.fromCharCode(title.runes.first),
          style: TextStyle(
            color: CupertinoTheme.of(context).primaryColor,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
}

class BookDetailsPage extends StatefulWidget {
  const BookDetailsPage({
    required this.result,
    required this.source,
    required this.browse,
    required this.bookshelf,
    required this.matchSources,
    super.key,
  });
  final BookSearchResult result;
  final BookSource source;
  final BrowseBookSource browse;
  final BookshelfViewModel bookshelf;
  final MatchBookSources matchSources;
  @override
  State<BookDetailsPage> createState() => _BookDetailsPageState();
}

class _BookDetailsPageState extends State<BookDetailsPage> {
  BookDetails? _details;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _details = await widget.browse.details(widget.source, widget.result.detailUrl);
    } catch (_) {
      _error = '书籍详情加载失败，请检查书源网络或规则。';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          middle: const Text('书籍详情'),
          trailing: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: _details == null ? null : _addToShelf,
            child: const Text('加入书架'),
          ),
        ),
        child: SafeArea(
          child: _loading
              ? const Center(child: CupertinoActivityIndicator())
              : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(CupertinoIcons.exclamationmark_circle, size: 38, color: CupertinoColors.systemOrange),
                      const SizedBox(height: 12),
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 8),
                      CupertinoButton(onPressed: _load, child: const Text('重新加载')),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(24),
                children: [
                    Center(child: _DetailCover(title: _details?.title ?? widget.result.title)),
                    const SizedBox(height: 18),
                    Text(_details?.title ?? widget.result.title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Text(_details?.author ?? widget.result.author,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: CupertinoColors.secondaryLabel)),
                    const SizedBox(height: 24),
                    Text(_details?.introduction ?? '暂无简介', style: const TextStyle(fontSize: 16, height: 1.65)),
                    const SizedBox(height: 32),
                    Text('来源：${widget.source.name}', style: const TextStyle(color: CupertinoColors.secondaryLabel)),
                  ],
                ),
        ),
      );

  Future<void> _addToShelf() async {
    final details = _details;
    if (details == null) return;
    final links = await widget.matchSources(details, widget.source);
    await widget.bookshelf.add(Book(
      id: '${details.sourceId}:${details.detailUrl}',
      title: details.title,
      author: details.author,
      progress: 0,
      coverColor: 0xFF4C6B82,
      lastReadAt: DateTime.now(),
      sourceId: details.sourceId,
      sourceName: widget.source.name,
      introduction: details.introduction,
      coverUrl: details.coverUrl,
      sourceLinks: links,
    ));
    if (mounted) Navigator.pop(context);
  }
}

class _DetailCover extends StatelessWidget {
  const _DetailCover({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => Container(
        width: 112,
        height: 156,
        padding: const EdgeInsets.all(14),
        alignment: Alignment.bottomLeft,
        decoration: BoxDecoration(
          color: const Color(0xFF4C6B82),
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [
            BoxShadow(color: Color(0x33000000), blurRadius: 18, offset: Offset(0, 10)),
          ],
        ),
        child: Text(
          title,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Color(0xFFFFFFFF), fontSize: 17, fontWeight: FontWeight.w700),
        ),
      );
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
