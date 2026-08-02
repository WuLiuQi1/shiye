import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../../domain/repositories/chapter_content_cache.dart';

class CacheManagementPage extends StatefulWidget {
  const CacheManagementPage({required this.cache, super.key});

  final ChapterContentCache cache;

  @override
  State<CacheManagementPage> createState() => _CacheManagementPageState();
}

class _CacheManagementPageState extends State<CacheManagementPage> {
  ChapterCacheSummary? _summary;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final summary = await widget.cache.summary();
    if (mounted) setState(() => _summary = summary);
  }

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
        navigationBar: const CupertinoNavigationBar(middle: Text('缓存管理')),
        child: SafeArea(
          child: _summary == null
              ? const Center(child: CupertinoActivityIndicator())
              : ListView(
                  children: [
                    CupertinoListSection.insetGrouped(
                      header: const Text('网络章节缓存'),
                      footer: const Text('缓存仅保存已打开或预取的网络书源章节；本地 TXT 与 EPUB 不在此处清理。'),
                      children: [
                        CupertinoListTile.notched(
                          title: const Text('已缓存章节'),
                          additionalInfo: Text('${_summary!.entryCount} 章'),
                        ),
                        CupertinoListTile.notched(
                          title: const Text('缓存占用'),
                          additionalInfo: Text(_sizeLabel(_summary!.byteCount)),
                        ),
                      ],
                    ),
                    CupertinoListSection.insetGrouped(
                      header: const Text('清理'),
                      children: [
                        CupertinoListTile.notched(
                          title: const Text('清理全部章节缓存', style: TextStyle(color: CupertinoColors.destructiveRed)),
                          leading: const Icon(CupertinoIcons.trash, color: CupertinoColors.destructiveRed),
                          onTap: _summary!.entryCount == 0 ? null : _clearAll,
                        ),
                      ],
                    ),
                  ],
                ),
        ),
      );

  String _sizeLabel(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }

  Future<void> _clearAll() async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('清理全部缓存？'),
        content: const Text('已缓存的网络章节会被移除，阅读进度不会受影响。'),
        actions: [
          CupertinoDialogAction(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          CupertinoDialogAction(isDestructiveAction: true, onPressed: () => Navigator.pop(context, true), child: const Text('清理')),
        ],
      ),
    );
    if (confirmed != true) return;
    HapticFeedback.selectionClick();
    await widget.cache.clearAll();
    await _load();
  }
}
