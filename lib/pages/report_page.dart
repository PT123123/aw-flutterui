import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/aw.dart';
import '../state/api_provider.dart';
import '../util/dt.dart';

/// 报告，对应 aw-webui/src/views/Report.vue（194 行）。
/// 按时长占比展示 Top 应用，饼图 + 明细表。
class ReportPage extends StatefulWidget {
  const ReportPage({super.key});

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  List<Bucket> _buckets = const [];
  String? _selectedId;
  List<_Slice> _slices = const [];
  String? _error;
  bool _loading = true;

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

      final events = await api.aw.getEvents(id, limit: 5000);
      final agg = <String, double>{};
      for (final e in events) {
        final key = eventTitle(e.data);
        agg[key] = (agg[key] ?? 0) + e.durationSeconds;
      }
      final sorted = agg.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final top = sorted.take(8).toList();
      final rest = sorted.skip(8).fold(0.0, (s, e) => s + e.value);

      if (!mounted) return;
      setState(() {
        _buckets = all;
        _selectedId = id;
        _slices = [
          for (final e in top) _Slice(e.key, e.value),
          if (rest > 0) _Slice('其他', rest),
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

  double get _total => _slices.fold(0.0, (s, x) => s + x.seconds);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('报告'),
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
    if (_slices.isEmpty) return const Center(child: Text('暂无数据'));

    return Row(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: PieChart(
              PieChartData(
                sections: [
                  for (var i = 0; i < _slices.length; i++)
                    PieChartSectionData(
                      value: _slices[i].seconds,
                      title: _total == 0
                          ? ''
                          : '${(_slices[i].seconds / _total * 100).toStringAsFixed(0)}%',
                      radius: 110,
                      titleStyle: const TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                      color: HSVColor.fromAHSV(
                        1,
                        (i * 47) % 360,
                        0.55,
                        0.75,
                      ).toColor(),
                    ),
                ],
                sectionsSpace: 2,
                centerSpaceRadius: 40,
              ),
            ),
          ),
        ),
        const VerticalDivider(width: 1),
        SizedBox(
          width: 320,
          child: ListView(
            children: [
              for (var i = 0; i < _slices.length; i++)
                ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 6,
                    backgroundColor: HSVColor.fromAHSV(1, (i * 47) % 360, 0.55, 0.75)
                        .toColor(),
                  ),
                  title: Text(
                    _slices[i].name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Text(formatDuration(_slices[i].seconds)),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Slice {
  const _Slice(this.name, this.seconds);

  final String name;
  final double seconds;
}
