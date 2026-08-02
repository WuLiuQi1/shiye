import 'package:flutter/cupertino.dart';

import '../../../domain/models/book.dart';
import '../../../domain/models/reading_statistics.dart';
import '../../../domain/repositories/reading_statistics_repository.dart';

class ReadingStatisticsPage extends StatefulWidget {
  const ReadingStatisticsPage({required this.repository, required this.books, super.key});

  final ReadingStatisticsRepository repository;
  final List<Book> books;

  @override
  State<ReadingStatisticsPage> createState() => _ReadingStatisticsPageState();
}

class _ReadingStatisticsPageState extends State<ReadingStatisticsPage> {
  late Future<ReadingStatistics> _statistics = widget.repository.load();

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
        navigationBar: const CupertinoNavigationBar(middle: Text('阅读统计')),
        child: SafeArea(
          child: FutureBuilder<ReadingStatistics>(
            future: _statistics,
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CupertinoActivityIndicator());
              final statistics = snapshot.data!;
              final now = DateTime.now();
              final weekStart = now.subtract(Duration(days: now.weekday - 1));
              final monthStart = DateTime(now.year, now.month);
              final completed = widget.books.where((book) => book.progress >= .9).length;
              final perBook = widget.books
                  .where((book) => (statistics.bookSeconds[book.id] ?? 0) > 0)
                  .toList()
                ..sort((a, b) => (statistics.bookSeconds[b.id] ?? 0).compareTo(statistics.bookSeconds[a.id] ?? 0));
              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 36),
                children: [
                  const Text('阅读回顾', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  const Text('所有数据只保存在这台设备上。', style: TextStyle(color: CupertinoColors.secondaryLabel)),
                  const SizedBox(height: 24),
                  _MetricGrid(items: [
                    _Metric('今日', _duration(statistics.secondsForDay(now)), CupertinoIcons.calendar_today),
                    _Metric('连续阅读', '${statistics.readingStreakDays} 天', CupertinoIcons.flame),
                    _Metric('本周', _duration(statistics.secondsBetween(weekStart, now)), CupertinoIcons.chart_bar),
                    _Metric('本月', _duration(statistics.secondsBetween(monthStart, now)), CupertinoIcons.calendar),
                  ]),
                  const SizedBox(height: 28),
                  _Section(title: '已读完', value: '$completed 本', subtitle: '阅读进度达到 90% 即计入'),
                  const SizedBox(height: 22),
                  const Text('每本书阅读时长', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  if (perBook.isEmpty)
                    const _EmptyHint()
                  else
                    ...perBook.take(10).map((book) => _BookTimeRow(
                          book: book,
                          duration: _duration(statistics.bookSeconds[book.id] ?? 0),
                        )),
                ],
              );
            },
          ),
        ),
      );
}

String _duration(int seconds) {
  final minutes = seconds ~/ 60;
  if (minutes < 1) return '少于 1 分钟';
  if (minutes < 60) return '$minutes 分钟';
  return '${minutes ~/ 60} 小时${minutes % 60 == 0 ? '' : ' ${minutes % 60} 分'}';
}

class _Metric { const _Metric(this.title, this.value, this.icon); final String title; final String value; final IconData icon; }
class _MetricGrid extends StatelessWidget { const _MetricGrid({required this.items}); final List<_Metric> items;
  @override Widget build(BuildContext context) => Wrap(spacing: 12, runSpacing: 12, children: items.map((item) => SizedBox(width: (MediaQuery.sizeOf(context).width - 52) / 2, child: DecoratedBox(decoration: BoxDecoration(color: CupertinoColors.systemGrey6.resolveFrom(context), borderRadius: BorderRadius.circular(16)), child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(item.icon, color: CupertinoTheme.of(context).primaryColor), const SizedBox(height: 18), Text(item.value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)), const SizedBox(height: 2), Text(item.title, style: const TextStyle(color: CupertinoColors.secondaryLabel))])))).toList()); }
class _Section extends StatelessWidget { const _Section({required this.title, required this.value, required this.subtitle}); final String title; final String value; final String subtitle;
  @override Widget build(BuildContext context) => DecoratedBox(decoration: BoxDecoration(color: CupertinoColors.systemGrey6.resolveFrom(context), borderRadius: BorderRadius.circular(16)), child: Padding(padding: const EdgeInsets.all(18), child: Row(children: [const Icon(CupertinoIcons.check_mark_circled, color: CupertinoColors.activeGreen), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w600)), Text(subtitle, style: const TextStyle(fontSize: 13, color: CupertinoColors.secondaryLabel))])), Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700))]))); }
class _BookTimeRow extends StatelessWidget { const _BookTimeRow({required this.book, required this.duration}); final Book book; final String duration;
  @override Widget build(BuildContext context) => Container(margin: const EdgeInsets.only(top: 8), padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: CupertinoColors.systemGrey6.resolveFrom(context), borderRadius: BorderRadius.circular(14)), child: Row(children: [const Icon(CupertinoIcons.book, color: CupertinoColors.secondaryLabel), const SizedBox(width: 12), Expanded(child: Text(book.title, maxLines: 1, overflow: TextOverflow.ellipsis)), Text(duration, style: const TextStyle(fontWeight: FontWeight.w600))])); }
class _EmptyHint extends StatelessWidget { const _EmptyHint(); @override Widget build(BuildContext context) => const Padding(padding: EdgeInsets.symmetric(vertical: 28), child: Center(child: Text('开始阅读后，这里会记录每本书的时长。', style: TextStyle(color: CupertinoColors.secondaryLabel)))); }
