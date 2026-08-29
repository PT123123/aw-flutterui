import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/aw.dart';
import '../state/api_provider.dart';
import '../util/dt.dart';

/// 活动总览，对应 aw-webui/src/views/activity/Activity.vue（482 行）。
///
/// webui 版本通过 queries.ts 生成的 aw-query DSL 做分类聚合；
/// 本页先用「拉取窗口事件 + 本地聚合」的等价实现，
/// 待分类规则（categories）迁移完成后再接 DSL。
class ActivityPage extends StatefulWidget {
  const ActivityPage({super.key});

  @override
  State<ActivityPage> createState() => _ActivityPageState();
}

class _ActivityPageState extends State<ActivityPage> {
  static const _windowTypes = {'currentwindow', 'app', 'window'};

  List<Bucket> _buckets = const [];
  String? _selectedId;
  List<_Usage> _usage = const [];
  String? _error;
  bool _loading = true;
  int _days = 1;

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
      final api = context.read<ApiProvider>();
      final map = await api.aw.getBuckets();
      final all = map.values.toList()
        ..sort((a, b) => a.displayName.compareTo(b.displayName));

      // 优先挑窗口类桶
      var pick = all.where((b) => _windowTypes.contains(b.type)).toList();
      if (pick.isEmpty) pick = all;

      final id = _selectedId ?? (pick.isEmpty ? null : pick.first.id);
      _buckets = pick.isEmpty ? all : pick;
      _selectedId = id;

      if (id == null) {
        if (!mounted) return;
        setState(() {
          _usage = const [];
          _loading = false;
        });
        return;
      }

      final events = await api.aw.getEvents(id, limit: 5000);
      final now = DateTime.now();
      final from = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: _days - 1));

      final agg = <String, double>{};
      for (final e in events) {
        if (e.timestamp.isBefore(from)) continue;
        final key = eventTitle(e.data);
        agg[key] = (agg[key] ?? 0) + e.durationSeconds;
      }
      final usage = agg.entries
          .map((e) => _Usage(e.key, e.value))
          .toList()
        ..sort((a, b) => b.seconds.compareTo(a.seconds));

      if (!mounted) return;
      setState(() {
        _usage = usage.take(10).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  double get _total => _usage.fold(0.0, (s, u) => s + u.seconds);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('活动'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '刷新',
            onPressed: _load,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedId,
                    decoration: const InputDecoration(
                      labelText: '数据桶',
                      isDense: true,
                    ),
                    items: [
                      for (final b in _buckets)
                        DropdownMenuItem(
                          value: b.id,
                          child: Text(
                            b.displayName,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (v) {
                      setState(() => _selectedId = v);
                      _load();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 130,
                  child: DropdownButtonFormField<int>(
                    initialValue: _days,
                    decoration: const InputDecoration(
                      labelText: '时间范围',
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: 1, child: Text('今天')),
                      DropdownMenuItem(value: 2, child: Text('近 2 天')),
                      DropdownMenuItem(value: 7, child: Text('近 7 天')),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _days = v);
                      _load();
                    },
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      );
    }
    if (_usage.isEmpty) {
      return const Center(child: Text('该时间段内没有活动数据'));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.schedule, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '累计时长',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      formatDuration(_total),
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 260,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
              child: _UsageChart(usage: _usage),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text('明细', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        for (final u in _usage)
          ListTile(
            dense: true,
            title: Text(u.name),
            trailing: SizedBox(
              width: 160,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(formatDuration(u.seconds)),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 60,
                    child: LinearProgressIndicator(
                      value: _total == 0 ? 0 : u.seconds / _total,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _Usage {
  const _Usage(this.name, this.seconds);

  final String name;
  final double seconds;
}

class _UsageChart extends StatelessWidget {
  const _UsageChart({required this.usage});

  final List<_Usage> usage;

  @override
  Widget build(BuildContext context) {
    final max = usage.fold(0.0, (m, u) => u.seconds > m ? u.seconds : m);

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: max <= 0 ? 1 : max * 1.15,
        barGroups: [
          for (var i = 0; i < usage.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: usage[i].seconds,
                  width: 14,
                  borderRadius: BorderRadius.circular(3),
                ),
              ],
            ),
        ],
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(),
          topTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 52,
              getTitlesWidget: (v, _) => Text(
                formatDuration(v),
                style: const TextStyle(fontSize: 10),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 60,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= usage.length) return const SizedBox.shrink();
                final name = usage[i].name;
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: SizedBox(
                    width: 70,
                    child: Text(
                      name.length > 10 ? '${name.substring(0, 10)}…' : name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 10),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        gridData: const FlGridData(drawVerticalLine: false),
        borderData: FlBorderData(show: false),
      ),
    );
  }
}
