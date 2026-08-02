import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../../domain/models/book_source.dart';
import 'book_sources_view_model.dart';

class BookSourcesPage extends StatefulWidget {
  const BookSourcesPage({required this.viewModel, super.key});

  final BookSourcesViewModel viewModel;

  @override
  State<BookSourcesPage> createState() => _BookSourcesPageState();
}

class _BookSourcesPageState extends State<BookSourcesPage> {
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
  Widget build(BuildContext context) => CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          middle: const Text('书源管理'),
          trailing: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () {
              HapticFeedback.selectionClick();
              _showImport();
            },
            child: const Icon(CupertinoIcons.add),
          ),
        ),
        child: SafeArea(
          child: AnimatedBuilder(
            animation: widget.viewModel,
            builder: (context, _) {
              final sources = widget.viewModel.sources;
              return CustomScrollView(
                slivers: [
                  const CupertinoSliverNavigationBar(largeTitle: Text('书源管理')),
                  if (widget.viewModel.error != null)
                    SliverToBoxAdapter(child: _Notice(text: widget.viewModel.error!)),
                  if (widget.viewModel.lastImportMessage != null)
                    SliverToBoxAdapter(child: _Notice(text: widget.viewModel.lastImportMessage!, isError: false)),
                  if (sources.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: Text('还没有书源\n点击右上角导入 JSON 书源', textAlign: TextAlign.center)),
                    )
                  else
                    SliverList.builder(
                      itemCount: sources.length,
                      itemBuilder: (context, index) => _SourceRow(
                        source: sources[index],
                        onEnabled: (value) => widget.viewModel.setEnabled(sources[index], value),
                        onDelete: () => widget.viewModel.remove(sources[index]),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      );

  Future<void> _showImport() async {
    final controller = TextEditingController();
    final imported = await showCupertinoModalPopup<bool>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('导入 JSON 书源'),
        message: SizedBox(
          height: 180,
          child: CupertinoTextField(
            controller: controller,
            expands: true,
            maxLines: null,
            textAlignVertical: TextAlignVertical.top,
            placeholder: '粘贴阅读 / Legado 或 ORSP JSON',
          ),
        ),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () async {
              HapticFeedback.selectionClick();
              final succeeded = await widget.viewModel.importJson(controller.text);
              if (context.mounted) Navigator.pop(context, succeeded);
            },
            child: const Text('导入'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(context, false),
          child: const Text('取消'),
        ),
      ),
    );
    controller.dispose();
    if (imported == false && mounted && widget.viewModel.error != null) {
      await showCupertinoDialog<void>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('无法导入书源'),
          content: Text(widget.viewModel.error!),
          actions: [CupertinoDialogAction(onPressed: () => Navigator.pop(context), child: const Text('好'))],
        ),
      );
    }
  }
}

class _SourceRow extends StatelessWidget {
  const _SourceRow({required this.source, required this.onEnabled, required this.onDelete});

  final BookSource source;
  final ValueChanged<bool> onEnabled;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final canToggle = source.supportStatus == BookSourceSupportStatus.usable ||
        source.supportStatus == BookSourceSupportStatus.partial;
    return CupertinoListSection.insetGrouped(
        header: Text(source.format == BookSourceFormat.legado ? '阅读 / Legado' : 'ORSP'),
        children: [
          CupertinoListTile.notched(
            title: Text(source.name),
            subtitle: Text(_subtitle(source)),
            leading: Icon(
              _icon(source.supportStatus),
              color: _color(source.supportStatus),
            ),
            trailing: CupertinoSwitch(
              value: source.isEnabled && canToggle,
              onChanged: canToggle
                  ? (value) {
                      HapticFeedback.selectionClick();
                      onEnabled(value);
                    }
                  : null,
            ),
          ),
          CupertinoListTile.notched(
            title: const Text('删除书源', style: TextStyle(color: CupertinoColors.destructiveRed)),
            leading: const Icon(CupertinoIcons.delete, color: CupertinoColors.destructiveRed),
            onTap: () {
              HapticFeedback.selectionClick();
              onDelete();
            },
          ),
        ],
      );
  }

  String _subtitle(BookSource source) {
    final status = switch (source.supportStatus) {
      BookSourceSupportStatus.usable => '可用',
      BookSourceSupportStatus.partial => '部分可用',
      BookSourceSupportStatus.scriptBlocked => '需要脚本，已禁止运行',
      BookSourceSupportStatus.loginRequired => '需要登录或 Cookie，已禁用',
    };
    final note = source.supportNote;
    if (note == null || note.isEmpty) return '${source.baseUrl.host} · $status';
    return '${source.baseUrl.host} · $status\n$note';
  }

  IconData _icon(BookSourceSupportStatus status) => switch (status) {
        BookSourceSupportStatus.usable => CupertinoIcons.check_mark_circled_solid,
        BookSourceSupportStatus.partial => CupertinoIcons.info_circle_fill,
        BookSourceSupportStatus.scriptBlocked => CupertinoIcons.clear_circled_solid,
        BookSourceSupportStatus.loginRequired => CupertinoIcons.lock_fill,
      };

  Color _color(BookSourceSupportStatus status) => switch (status) {
        BookSourceSupportStatus.usable => CupertinoColors.activeGreen,
        BookSourceSupportStatus.partial => CupertinoColors.systemOrange,
        BookSourceSupportStatus.scriptBlocked => CupertinoColors.destructiveRed,
        BookSourceSupportStatus.loginRequired => CupertinoColors.secondaryLabel,
      };
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text, this.isError = true});
  final String text;
  final bool isError;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          text,
          style: TextStyle(color: isError ? CupertinoColors.destructiveRed : CupertinoColors.secondaryLabel),
        ),
      );
}
