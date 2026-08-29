import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/aw.dart';
import '../state/api_provider.dart';
import '../util/dt.dart';

/// 趋势，对应 aw-webui/src/views/Trends.vue（105 行）。
/// 按天汇总所选数据桶的活跃时长，折线展示。
class TrendsPage extends StatefulWidget {
  const TrendsPage({super.key});

  @override
  State<TrendsPage> createState() => _TrendsPageState();
}

class _TrendsPageState extends State<TrendsPage> {
  List<Bucket> _buckets = const [];
  String? _selectedId;
  List<_DayPoint> _points = const [];
  String? _error;
  bool _loading = true;
  int _days = 14;

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
      final id = _selectedId ?? (all.isEmpty ? null : all.first.id);

      if (id == null) {
        if (!mounted) return;
        setState(() {
          _buckets = all;
          _loading = false;
        });
        return;
      }

      final events = await api.aw.getEvents(id, limit: 20000);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final from = today.subtract(Duration(days: _days - 1));

      final perDay = <int, double>{
        for (var i = 0; i < _days; i++) i: 0,
      };
      for (final e in events) {
        final diff = DateTime(e.timestamp.year, e.timestamp.month, e.timestamp.day)
            .difference(from)
            .inDays;
        if (diff < 0 || diff >= _days) continue;
        perDay[diff] = (perDay[diff] ?? 0) + e.durationSeconds;
      }

      if (!mounted) return;
      setState(() {
        _buckets = all;
        _selectedId = id;
        _points = [
          for (var i = 0; i < _days; i++)
            _DayPoint(from.add(Duration(days: i)), perDay[i] ?? 0),
        ];
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('趋势'),
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
                      labelText: '天数',
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: 7, child: Text('7 天')),
                      DropdownMenuItem(value: 14, child: Text('14 天')),
                      DropdownMenuItem(value: 30, child: Text('30 天')),
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
    if (_points.isEmpty) return const Center(child: Text('暂无数据'));

    final max = _points.fold(0.0, (m, p) => p.seconds > m ? p.seconds : m);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 24, 16),
      child: LineChart(
        LineChartData(
          maxY: max <= 0 ? 1 : max * 1.15,
          minY: 0,
          lineBarsData: [
            LineChartBarData(
              spots: [
                for (var i = 0; i < _points.length; i++)
                  FlSpot(i.toDouble(), _points[i].seconds),
              ],
              isCurved: true,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
              ),
            ),
          ],
          titlesData: FlTitlesData(
            rightTitles: const AxisTitles(),
            topTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 56,
                getTitlesWidget: (v, _) => Text(
                  formatDuration(v),
                  style: const TextStyle(fontSize: 10),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                interval: (_points.length / 7).ceilToDouble(),
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i < 0 || i >= _points.length) return const SizedBox.shrink();
                  final d = _points[i].day;
                  return Text(
                    '${d.month}/${d.day}',
                    style: const TextStyle(fontSize: 10),
                  );
                },
              ),
            ),
          ),
          gridData: const FlGridData(drawVerticalLine: false),
          borderData: FlBorderData(show: false),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (spots) => spots
                  .map((s) => LineTooltipItem(
                        formatDuration(s.y),
                        const TextStyle(fontSize: 12),
                      ))
                  .toList(),
            ),
          ),
        ),
      ),
    );
  }
}

class _DayPoint {
  const _DayPoint(this.day, this.seconds);

  final DateTime day;
  final double seconds;
}
