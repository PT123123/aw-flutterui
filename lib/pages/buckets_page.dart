import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/aw.dart';
import '../state/api_provider.dart';
import '../util/dt.dart';
import '../util/format.dart';
import '../widgets/async_view.dart';

/// 对应 aw-webui/src/views/Buckets.vue（283 行）+ Bucket.vue（100 行）。
/// 左侧数据桶列表，右侧选中桶的事件流。
class BucketsPage extends StatefulWidget {
  const BucketsPage({super.key});

  @override
  State<BucketsPage> createState() => _BucketsPageState();
}

class _BucketsPageState extends State<BucketsPage> {
  AsyncValue<List<Bucket>> _buckets = const AsyncValue.loading();
  String? _selectedId;
  final Map<String, int> _eventCounts = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _buckets = const AsyncValue.loading());
    try {
      final api = context.read<ApiProvider>();
      final map = await api.aw.getBuckets();
      final list = map.values.toList()
        ..sort((a, b) => a.displayName.compareTo(b.displayName));

      // 事件计数是附加信息，失败不影响主列表
      for (final b in list) {
        try {
          _eventCounts[b.id] = await api.aw.countEvents(b.id);
        } catch (_) {
          _eventCounts[b.id] = -1;
        }
      }

      if (!mounted) return;
      setState(() {
        _buckets = AsyncValue.data(list);
        _selectedId ??= list.isEmpty ? null : list.first.id;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _buckets = AsyncValue.error(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('数据桶'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '刷新',
            onPressed: _load,
          ),
        ],
      ),
      body: AsyncView<List<Bucket>>(
        value: _buckets,
        emptyBuilder: (_) => const Center(child: Text('暂无数据桶')),
        builder: (context, buckets) {
          final selected = buckets
              .where((b) => b.id == _selectedId)
              .cast<Bucket?>()
              .firstWhere((b) => b != null, orElse: () => null);

          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 280,
                child: ListView(
                  children: [
                    for (final b in buckets)
                      ListTile(
                        selected: b.id == _selectedId,
                        leading: Icon(b.isAfk
                            ? Icons.bedtime_outlined
                            : Icons.storage_outlined),
                        title: Text(b.displayName, overflow: TextOverflow.ellipsis),
                        subtitle: Text(b.type),
                        onTap: () => setState(() => _selectedId = b.id),
                      ),
                  ],
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: selected == null
                    ? const Center(child: Text('选择一个数据桶'))
                    : _BucketDetail(
                        key: ValueKey(selected.id),
                        bucket: selected,
                        eventCount: _eventCounts[selected.id] ?? -1,
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _BucketDetail extends StatefulWidget {
  const _BucketDetail({super.key, required this.bucket, required this.eventCount});

  final Bucket bucket;
  final int eventCount;

  @override
  State<_BucketDetail> createState() => _BucketDetailState();
}

class _BucketDetailState extends State<_BucketDetail> {
  AsyncValue<List<Event>> _events = const AsyncValue.loading();
  int _limit = 100;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _BucketDetail old) {
    super.didUpdateWidget(old);
    if (old.bucket.id != widget.bucket.id) _load();
  }

  Future<void> _load() async {
    setState(() => _events = const AsyncValue.loading());
    try {
      final api = context.read<ApiProvider>();
      final list = await api.aw.getEvents(widget.bucket.id, limit: _limit);
      if (!mounted) return;
      setState(() => _events = AsyncValue.data(list));
    } catch (e) {
      if (!mounted) return;
      setState(() => _events = AsyncValue.error(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _BucketHeader(bucket: widget.bucket, eventCount: widget.eventCount),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const Text('显示条数'),
              const SizedBox(width: 12),
              DropdownButton<int>(
                value: _limit,
                items: const [
                  DropdownMenuItem(value: 50, child: Text('50')),
                  DropdownMenuItem(value: 100, child: Text('100')),
                  DropdownMenuItem(value: 500, child: Text('500')),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _limit = v);
                  _load();
                },
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _load,
                tooltip: '刷新',
              ),
            ],
          ),
        ),
        Expanded(
          child: AsyncView<List<Event>>(
            value: _events,
            emptyBuilder: (_) => const Center(child: Text('该数据桶暂无事件')),
            builder: (context, events) => ListView.separated(
              itemCount: events.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) => _EventTile(event: events[i]),
            ),
          ),
        ),
      ],
    );
  }
}

class _BucketHeader extends StatelessWidget {
  const _BucketHeader({required this.bucket, required this.eventCount});

  final Bucket bucket;
  final int eventCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(bucket.displayName, style: theme.textTheme.titleMedium),
          const SizedBox(height: 6),
          Wrap(
            spacing: 16,
            runSpacing: 4,
            children: [
              Text('ID: ${bucket.id}', style: theme.textTheme.bodySmall),
              Text('类型: ${bucket.type}', style: theme.textTheme.bodySmall),
              Text('客户端: ${bucket.client}', style: theme.textTheme.bodySmall),
              Text('主机: ${bucket.hostname}', style: theme.textTheme.bodySmall),
              Text(
                eventCount < 0 ? '事件: 未知' : '事件: $eventCount 条',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
          if (bucket.data.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              '配置: ${bucket.data.entries.map((e) => '${e.key}=${e.value}').join(', ')}',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({required this.event});

  final Event event;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      dense: true,
      title: Text(eventTitle(event.data)),
      subtitle: Text(formatDateTime(event.timestamp)),
      trailing: Text(
        formatDuration(event.durationSeconds),
        style: theme.textTheme.bodySmall,
      ),
      onTap: () => showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('事件详情'),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: SelectableText(
                const JsonEncoder().convert(event.toJson()),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('关闭'),
            ),
          ],
        ),
      ),
    );
  }
}
