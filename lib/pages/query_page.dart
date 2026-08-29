import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/aw.dart';
import '../state/api_provider.dart';
import '../util/dt.dart';
import '../util/format.dart';

/// 查询浏览器，对应 aw-webui/src/views/QueryExplorer.vue（109 行）。
/// 直接编辑 aw-query DSL 并执行，是排查数据时最直接的工具。
class QueryPage extends StatefulWidget {
  const QueryPage({super.key});

  @override
  State<QueryPage> createState() => _QueryPageState();
}

class _QueryPageState extends State<QueryPage> {
  final _code = TextEditingController(
    text: 'events = query_bucket(find_bucket("aw-watcher-window_"));\n'
        'RETURN = merge_events_by_keys(events, ["app"]);',
  );
  final _period = TextEditingController();

  List<Event>? _results;
  String? _error;
  bool _loading = false;
  String? _elapsed;

  @override
  void initState() {
    super.initState();
    _setToday();
  }

  void _setToday() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    _period.text =
        '${_iso(start)}/${_iso(end)}';
  }

  static String _iso(DateTime d) {
    String two(int v) => v.toString().padLeft(2, '0');
    final off = d.timeZoneOffset;
    final sign = off.isNegative ? '-' : '+';
    return '${d.year}-${two(d.month)}-${two(d.day)}'
        'T${two(d.hour)}:${two(d.minute)}:${two(d.second)}'
        '$sign${two(off.inHours.abs())}:${two(off.inMinutes.remainder(60).abs())}';
  }

  @override
  void dispose() {
    _code.dispose();
    _period.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    setState(() {
      _loading = true;
      _error = null;
      _results = null;
    });
    final sw = Stopwatch()..start();
    try {
      final api = context.read<ApiProvider>();
      final statements = _code.text
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();
      final res = await api.aw.query([_period.text.trim()], statements);
      sw.stop();
      if (!mounted) return;
      setState(() {
        _loading = false;
        _results = res.isEmpty ? const [] : res.first;
        _elapsed = '${sw.elapsedMilliseconds} ms';
      });
    } catch (e) {
      sw.stop();
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
        title: const Text('查询浏览器'),
        actions: [
          IconButton(
            icon: const Icon(Icons.play_arrow),
            tooltip: '执行',
            onPressed: _loading ? null : _run,
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                TextField(
                  controller: _period,
                  decoration: const InputDecoration(
                    labelText: '时间区间',
                    helperText: '格式 start/end，各为 ISO8601 带时区偏移',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _code,
                  maxLines: 6,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: 'aw-query 语句',
                    alignLabelWithHint: true,
                    helperText: '每行一条语句，最后一条的返回值作为结果',
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    FilledButton.icon(
                      onPressed: _loading ? null : _run,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('执行查询'),
                    ),
                    const SizedBox(width: 12),
                    TextButton(
                      onPressed: _setToday,
                      child: const Text('重置为今天'),
                    ),
                    const Spacer(),
                    if (_elapsed != null) Text('耗时 $_elapsed'),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(child: _buildResults()),
        ],
      ),
    );
  }

  Widget _buildResults() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SelectableText(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      );
    }
    final results = _results;
    if (results == null) {
      return const Center(child: Text('执行查询后在此显示结果'));
    }
    if (results.isEmpty) return const Center(child: Text('查询无结果'));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text('共 ${results.length} 条事件'),
        ),
        Expanded(
          child: ListView.separated(
            itemCount: results.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final e = results[i];
              return ListTile(
                dense: true,
                title: Text(eventTitle(e.data)),
                subtitle: Text(formatDateTime(e.timestamp)),
                trailing: Text(formatDuration(e.durationSeconds)),
              );
            },
          ),
        ),
      ],
    );
  }
}
