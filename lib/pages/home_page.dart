import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/aw.dart';
import '../state/api_provider.dart';
import '../theme.dart';
import '../util/dt.dart';
import '../util/format.dart';
import '../widgets/async_view.dart';

/// 对应 aw-webui/src/views/Home.vue（76 行）。
/// 展示服务连接状态、数据桶概览、今日活动时长。
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  AsyncValue<_HomeData> _value = const AsyncValue.loading();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 服务地址变更时重新加载
    context.watch<ApiProvider>();
  }

  Future<void> _load() async {
    setState(() => _value = const AsyncValue.loading());
    try {
      final api = context.read<ApiProvider>();
      final results = await Future.wait<Object>([
        api.aw.getInfo(),
        api.aw.getBuckets(),
      ]);
      final info = results[0] as ServerInfo;
      final buckets = results[1] as Map<String, Bucket>;
      if (!mounted) return;
      setState(() => _value = AsyncValue.data(_HomeData(info, buckets)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _value = AsyncValue.error(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('概览'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '刷新',
            onPressed: _load,
          ),
        ],
      ),
      body: AsyncView<_HomeData>(
        value: _value,
        builder: (context, data) => _HomeBody(data: data),
      ),
    );
  }
}

class _HomeData {
  const _HomeData(this.info, this.buckets);

  final ServerInfo info;
  final Map<String, Bucket> buckets;
}

class _HomeBody extends StatelessWidget {
  const _HomeBody({required this.data});

  final _HomeData data;

  @override
  Widget build(BuildContext context) {
    final buckets = data.buckets.values.toList()
      ..sort((a, b) => a.displayName.compareTo(b.displayName));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _InfoCard(info: data.info, bucketCount: buckets.length),
        const SizedBox(height: 12),
        Text(
          '数据桶（${buckets.length}）',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        if (buckets.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('暂无数据桶，请先在客户端启动一个 watcher')),
            ),
          )
        else
          for (final b in buckets) _BucketTile(bucket: b),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.info, required this.bucketCount});

  final ServerInfo info;
  final int bucketCount;

  @override
  Widget build(BuildContext context) {
    final settings = context.read<ApiProvider>();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.check_circle_outline,
                    size: 18, color: StatusColors.success),
                const SizedBox(width: 8),
                Text(
                  '服务已连接',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const Divider(height: 20),
            _kv('主机名', info.hostname),
            _kv('版本', info.version),
            _kv('地址', settings.aw.baseUrl),
            if (info.testing) _kv('模式', 'testing'),
          ],
        ),
      ),
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 72,
              child: Text(
                k,
                style: const TextStyle(color: StatusColors.muted),
              ),
            ),
            Expanded(
              child: SelectableText(
                v,
                style: const TextStyle(fontFamily: 'monospace'),
              ),
            ),
          ],
        ),
      );
}

class _BucketTile extends StatelessWidget {
  const _BucketTile({required this.bucket});

  final Bucket bucket;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(
          bucket.isAfk ? Icons.bedtime_outlined : Icons.storage_outlined,
        ),
        title: Text(bucket.displayName),
        subtitle: Text(
          '${bucket.type} · ${bucket.hostname}'
          '${bucket.created == null ? '' : ' · 创建于 ${formatDateTime(bucket.created!)}'}',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _showEvents(context),
      ),
    );
  }

  Future<void> _showEvents(BuildContext context) async {
    final api = context.read<ApiProvider>();
    final events = await api.aw.getEvents(bucket.id, limit: 20);
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(bucket.displayName),
        content: SizedBox(
          width: 560,
          child: events.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('暂无事件'),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: events.length,
                  itemBuilder: (context, i) {
                    final e = events[i];
                    return ListTile(
                      dense: true,
                      title: Text(eventTitle(e.data)),
                      subtitle: Text(formatDateTime(e.timestamp)),
                      trailing: Text(formatDuration(e.durationSeconds)),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }
}
