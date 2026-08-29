import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/aw.dart';
import '../state/api_provider.dart';
import '../util/dt.dart';
import '../util/format.dart';

/// 计时器，对应 aw-webui/src/views/Stopwatch.vue（136 行）。
///
/// 事件写入名为 `aw-stopwatch_<hostname>` 的桶，与 webui 保持一致的命名，
/// 这样两端产生的记录可以混在一起统计。
class StopwatchPage extends StatefulWidget {
  const StopwatchPage({super.key});

  @override
  State<StopwatchPage> createState() => _StopwatchPageState();
}

class _StopwatchPageState extends State<StopwatchPage> {
  final _label = TextEditingController();

  String? _bucketId;
  DateTime? _startedAt;
  bool _saving = false;
  String? _error;
  List<Event> _history = const [];

  bool get _running => _startedAt != null;

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  Future<void> _ensureBucket() async {
    if (_bucketId != null) return;
    try {
      final api = context.read<ApiProvider>();
      final info = await api.aw.getInfo();
      final id = 'aw-stopwatch_${info.hostname}';
      // 桶不存在时创建（aw-client 的 createBucket 对应 PUT /buckets/{id}）
      await api.aw.ensureBucket(
        id,
        type: 'stopwatch',
        client: 'aw-flutter',
        hostname: info.hostname,
      );
      _bucketId = id;
    } catch (e) {
      _error = e.toString();
    }
  }

  Future<void> _start() async {
    setState(() {
      _error = null;
      _startedAt = DateTime.now();
    });
    await _ensureBucket();
  }

  Future<void> _stop() async {
    final start = _startedAt;
    if (start == null) return;
    setState(() => _saving = true);
    try {
      await _ensureBucket();
      final api = context.read<ApiProvider>();
      final end = DateTime.now();
      final seconds = end.difference(start).inMilliseconds / 1000.0;
      await api.aw.insertEvent(
        _bucketId!,
        Event(
          timestamp: start.toUtc(),
          durationSeconds: seconds,
          data: {'label': _label.text.trim()},
        ),
      );
      _startedAt = null;
      await _loadHistory();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _loadHistory() async {
    final id = _bucketId;
    if (id == null) return;
    try {
      final api = context.read<ApiProvider>();
      final list = await api.aw.getEvents(id, limit: 50);
      if (!mounted) return;
      setState(() => _history = list.reversed.toList());
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('计时器'),
        actions: [
          if (_bucketId != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: '刷新记录',
              onPressed: _loadHistory,
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      _running
                          ? formatDuration(
                              DateTime.now().difference(_startedAt!).inSeconds)
                          : '00s',
                      style: Theme.of(context).textTheme.displaySmall,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _label,
                      enabled: _running,
                      decoration: const InputDecoration(
                        labelText: '标签（可选）',
                        hintText: '在做什么',
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (!_running)
                          FilledButton.icon(
                            onPressed: _start,
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('开始'),
                          )
                        else
                          FilledButton.icon(
                            onPressed: _saving ? null : _stop,
                            icon: const Icon(Icons.stop),
                            label: const Text('停止并记录'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 16),
            Text('最近记录', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Expanded(
              child: _history.isEmpty
                  ? const Center(child: Text('暂无记录'))
                  : ListView.separated(
                      itemCount: _history.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final e = _history[i];
                        final label = e.data['label']?.toString() ?? '';
                        return ListTile(
                          dense: true,
                          title: Text(label.isEmpty ? '(无标签)' : label),
                          subtitle: Text(formatDateTime(e.timestamp)),
                          trailing: Text(formatDuration(e.durationSeconds)),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
