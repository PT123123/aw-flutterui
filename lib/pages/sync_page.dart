import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/sync.dart';
import '../state/api_provider.dart';
import '../state/sync_controller.dart';
import '../theme.dart';
import '../util/format.dart';

/// 局域网同步页，对应 aw-webui/src/views/Sync.vue（863 行）。
///
/// 业务逻辑全部复用 [SyncController]。UI 上刻意规避了后端的几个已知行为：
/// - `pending_push_count` / `pending_conflict_count` 后端恒返回 0，故不展示
/// - `total_synced_count` 实为「同步次数」而非数据条数，文案已更正
/// - 未经 ≥2 次同步时 `sync_frequency_minutes` 为 null
class SyncPage extends StatelessWidget {
  const SyncPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<SyncController>(
      create: (context) =>
          SyncController(api: context.read<ApiProvider>().sync)..start(),
      child: const _SyncView(),
    );
  }
}

class _SyncView extends StatelessWidget {
  const _SyncView();

  @override
  Widget build(BuildContext context) {
    final c = context.watch<SyncController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('局域网同步'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '刷新',
            onPressed: () async {
              await c.loadConfig();
              await c.loadDevices();
              await c.loadLogs();
              await c.loadStatus();
            },
          ),
        ],
      ),
      body: c.initialLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: const [
                _StatusBanner(),
                SizedBox(height: 12),
                _PeersPanel(),
                SizedBox(height: 12),
                _SettingsPanel(),
                SizedBox(height: 12),
                _LogsPanel(),
              ],
            ),
    );
  }
}

// ---------------------------------------------------------------- 状态条

class _StatusBanner extends StatelessWidget {
  const _StatusBanner();

  @override
  Widget build(BuildContext context) {
    final c = context.watch<SyncController>();
    final s = c.status;
    final running = s?.discoveryRunning ?? false;
    final self = c.selfDevice;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  running ? Icons.wifi_tethering : Icons.wifi_tethering_off,
                  size: 18,
                  color: running ? StatusColors.success : StatusColors.warning,
                ),
                const SizedBox(width: 8),
                Text(
                  running ? 'UDP 广播发现运行中' : '局域网同步未开启',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const Spacer(),
                if (s != null)
                  Text(
                    'UDP ${s.udpPort} / HTTP ${s.listenPort}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
            if (!running) ...[
              const SizedBox(height: 6),
              Text(
                '请在下方「设置」中打开开关并保存',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: StatusColors.warning),
              ),
            ],
            const Divider(height: 18),
            _Row(
              label: '本机地址',
              value: self == null
                  ? '-'
                  : '${self.ip}:${self.port} (${self.ipIface ?? '未知网卡'})',
              warn: self == null || _isLoopback(self.ip),
            ),
            _Row(label: '本机 ID', value: self?.id ?? '-'),
          ],
        ),
      ),
    );
  }

  static bool _isLoopback(String ip) =>
      ip.isEmpty || ip == 'localhost' || ip.startsWith('127.');
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, this.warn = false});

  final String label;
  final String value;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(label,
                style: const TextStyle(color: StatusColors.muted)),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: TextStyle(
                fontFamily: 'monospace',
                color: warn ? StatusColors.warning : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- 设备面板

class _PeersPanel extends StatelessWidget {
  const _PeersPanel();

  @override
  Widget build(BuildContext context) {
    final c = context.watch<SyncController>();
    return Card(
      child: ExpansionTile(
        initiallyExpanded: true,
        title: const Text('配对与设备'),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle(context, '已发现未配对的设备'),
                if (c.discoveredDevices.isEmpty)
                  _hint('未发现设备 —— 确保双方已开启「局域网同步」并处于同一网络。')
                else
                  for (final d in c.discoveredDevices)
                    _DeviceTile(device: d, paired: false),
                const SizedBox(height: 12),
                _sectionTitle(context, '已配对设备'),
                if (c.pairedDevices.isEmpty)
                  _hint('尚无已配对设备。')
                else
                  for (final d in c.pairedDevices)
                    _DeviceTile(device: d, paired: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String t) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(t, style: Theme.of(context).textTheme.titleSmall),
      );

  Widget _hint(String t) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(t, style: const TextStyle(color: StatusColors.muted)),
      );
}

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({required this.device, required this.paired});

  final Device device;
  final bool paired;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<SyncController>();
    final expanded = c.expandedDevices.contains(device.id);
    final stats = c.deviceStats[device.id];

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${device.isSelf ? '(本机) ' : ''}${device.alias ?? device.name}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${device.ip}:${device.port} · '
                        '${deviceTypeLabel(device.deviceKind)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                _OnlineBadge(device: device),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                if (device.incomingPairRequest)
                  FilledButton(
                    onPressed: () => c.acceptPair(device.id),
                    child: const Text('接受配对'),
                  )
                else if (!paired && !device.isSelf)
                  FilledButton.tonal(
                    onPressed: () => c.initiatePair(device.id),
                    child: const Text('发起配对'),
                  ),
                if (paired && !device.isSelf) ...[
                  OutlinedButton(
                    onPressed: () => c.syncDevice(device.id),
                    child: const Text('立即同步'),
                  ),
                  OutlinedButton(
                    onPressed: () => _rename(context, c, device),
                    child: const Text('重命名'),
                  ),
                  OutlinedButton(
                    onPressed: () => _confirmDelete(context, c, device),
                    child: const Text('删除'),
                  ),
                ],
              ],
            ),
            if (stats != null && !device.isSelf) ...[
              const Divider(height: 16),
              Wrap(
                spacing: 16,
                children: [
                  // 注意：pending_push_count / pending_conflict_count 后端恒为 0，
                  // 展示无意义，此处只显示可信字段。
                  Text('累计同步 ${stats.totalSyncedCount} 次',
                      style: Theme.of(context).textTheme.bodySmall),
                  Text('${humanSize(stats.totalSyncedSize)}',
                      style: Theme.of(context).textTheme.bodySmall),
                  if (stats.lastSyncAt != null)
                    Text('上次同步 ${formatTime(stats.lastSyncAt)}',
                        style: Theme.of(context).textTheme.bodySmall),
                  TextButton(
                    onPressed: () => c.toggleDeviceDetails(device.id),
                    child: Text(expanded ? '收起详情' : '展开详情'),
                  ),
                ],
              ),
              if (expanded) _SyncDetails(device: device, stats: stats),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _rename(
      BuildContext context, SyncController c, Device device) async {
    final ctrl = TextEditingController(text: device.alias ?? device.name);
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('设置别名'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 20,
          decoration: const InputDecoration(hintText: '为空则清除别名'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    if (name == null || name == (device.alias ?? device.name)) return;
    // 空串后端会记为「清空别名」，这里允许传空（webui 版本做不到）
    await c.saveAlias(device.id, name);
  }

  Future<void> _confirmDelete(
      BuildContext context, SyncController c, Device device) async {
    final ok = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('删除设备'),
            content: Text('确定删除「${device.alias ?? device.name}」？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('删除'),
              ),
            ],
          ),
        ) ??
        false;
    if (ok) await c.removeDevice(device.id);
  }
}

class _OnlineBadge extends StatelessWidget {
  const _OnlineBadge({required this.device});

  final Device device;

  @override
  Widget build(BuildContext context) {
    // 与 webui 一致的判据：已配对设备信任后端 is_online；
    // 未配对设备看 last_seen_at 是否在 30s 内（webui 硬编码常量，非 probe_interval）
    final online = device.paired
        ? device.isOnline
        : (device.lastSeenAt != null &&
            DateTime.now().difference(device.lastSeenAt!).inSeconds < 30);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: (online ? StatusColors.success : StatusColors.muted)
            .withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        online ? '在线' : '离线',
        style: TextStyle(
          fontSize: 12,
          color: online ? StatusColors.success : StatusColors.muted,
        ),
      ),
    );
  }
}

class _SyncDetails extends StatelessWidget {
  const _SyncDetails({required this.device, required this.stats});

  final Device device;
  final DeviceSyncStats stats;

  @override
  Widget build(BuildContext context) {
    final c = context.read<SyncController>();
    final conflicts = c.deviceConflicts[device.id] ?? const [];
    final s = Theme.of(context).textTheme.bodySmall;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('本地 ${stats.localNoteCount} 条 · '
              '远端 ${stats.remoteNoteCount} 条', style: s),
          Text('上次全量同步: ${stats.lastFullSyncAt ?? '从未全量同步'}', style: s),
          Text('同步频率: ${syncFrequencyText(stats.syncFrequencyMinutes)}',
              style: s),
          if (conflicts.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('冲突 (${conflicts.length})', style: s),
            for (final cf in conflicts)
              Text(
                '  ${cf.resolved ? '[已解决]' : '[待解决]'} '
                '${cf.noteTitle} - ${formatTime(cf.detectedAt)}',
                style: s,
              ),
          ],
          if (stats.lastError != null) ...[
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('最近错误: ', style: s),
                Expanded(
                  child: Text(
                    stats.lastError!,
                    style: s?.copyWith(color: StatusColors.danger),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- 设置面板

class _SettingsPanel extends StatefulWidget {
  const _SettingsPanel();

  @override
  State<_SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends State<_SettingsPanel> {
  late TextEditingController _alias;
  late TextEditingController _udpPort;
  late TextEditingController _probeInterval;

  @override
  void initState() {
    super.initState();
    final cfg = context.read<SyncController>().config;
    _alias = TextEditingController(text: cfg?.selfAlias ?? '');
    _udpPort = TextEditingController(text: '${cfg?.udpPort ?? 46000}');
    _probeInterval =
        TextEditingController(text: '${cfg?.probeInterval ?? 10}');
  }

  @override
  void dispose() {
    _alias.dispose();
    _udpPort.dispose();
    _probeInterval.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<SyncController>();
    final cfg = c.config;
    if (cfg == null) return const SizedBox.shrink();

    return Card(
      child: ExpansionTile(
        title: const Text('设置'),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('开启局域网同步'),
                  value: cfg.enabled,
                  onChanged: (v) => _update((c) => c.enabled = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('使用 HTTP 同步'),
                  value: cfg.httpEnabled,
                  onChanged: (v) => _update((c) => c.httpEnabled = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('同步 Inbox 数据 (inbox.db)'),
                  value: cfg.syncInbox,
                  onChanged: (v) => _update((c) => c.syncInbox = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('同步 ActivityWatch 数据 (sqlite.db)'),
                  value: cfg.syncActivity,
                  onChanged: (v) => _update((c) => c.syncActivity = v),
                ),
                const Divider(),
                DropdownButtonFormField<String>(
                  initialValue: cfg.discoveryMethod,
                  decoration: const InputDecoration(
                    labelText: '设备发现方式',
                    helperText: '「轮询遍历」后端尚未实现',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'broadcast',
                      child: Text('广播 / mDNS + UDP（已实现）'),
                    ),
                    DropdownMenuItem(
                      value: 'poll',
                      child: Text('轮询遍历（待实现）'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) _update((c) => c.discoveryMethod = v);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _udpPort,
                  decoration: const InputDecoration(
                    labelText: 'UDP 发现端口',
                    helperText: '默认 46000，范围 10000-65535',
                  ),
                  keyboardType: TextInputType.number,
                  onSubmitted: (_) => _submitNumbers(cfg),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _probeInterval,
                  decoration: const InputDecoration(
                    labelText: '在线探测间隔 (秒)',
                    helperText: '已配对设备的心跳探测间隔，默认 10s',
                  ),
                  keyboardType: TextInputType.number,
                  onSubmitted: (_) => _submitNumbers(cfg),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _alias,
                  decoration: const InputDecoration(
                    labelText: '本机别名',
                    helperText: '广播时显示在对方设备列表中，为空则使用主机名',
                  ),
                  maxLength: 20,
                  onSubmitted: (_) => _submitNumbers(cfg),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    FilledButton(
                      onPressed: () => _submitNumbers(cfg),
                      child: const Text('保存同步设置'),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => _confirmClearAll(context),
                      style: TextButton.styleFrom(
                        foregroundColor: StatusColors.danger,
                      ),
                      child: const Text('清空所有配对信息'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '同步端口固定为 ${cfg.listenPort}（与服务器端口一致），不可修改。\n'
                  '关闭同步后广播线程不会立即停止，需重启应用生效。',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: StatusColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _update(void Function(SyncConfig cfg) fn) {
    final cfg = context.read<SyncController>().config;
    if (cfg == null) return;
    fn(cfg);
    // 触发重建以反映开关状态
    setState(() {});
  }

  Future<void> _submitNumbers(SyncConfig cfg) async {
    final udp = int.tryParse(_udpPort.text.trim());
    final probe = int.tryParse(_probeInterval.text.trim());
    cfg.selfAlias = _alias.text.trim();
    if (udp != null) cfg.udpPort = udp;
    if (probe != null) cfg.probeInterval = probe;
    final c = context.read<SyncController>();
    final err = await c.saveConfig(cfg);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(err ??
            (cfg.enabled
                ? '同步设置已保存，UDP 广播发现已启动'
                : '同步设置已保存（局域网同步处于关闭状态）')),
        backgroundColor: err != null ? StatusColors.danger : null,
      ),
    );
  }

  Future<void> _confirmClearAll(BuildContext context) async {
    final ok = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('清空所有配对信息'),
            content: const Text(
              '将移除全部已配对与已发现的设备，且不可恢复。\n'
              '同步设置与本机记录会保留。',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('确定清空'),
              ),
            ],
          ),
        ) ??
        false;
    if (!ok || !mounted) return;
    final c = context.read<SyncController>();
    final (count, err) = await c.clearAllDevices();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(err ?? '已清空 $count 台设备'),
        backgroundColor: err != null ? StatusColors.danger : null,
      ),
    );
  }
}

// ---------------------------------------------------------------- 日志面板

class _LogsPanel extends StatelessWidget {
  const _LogsPanel();

  @override
  Widget build(BuildContext context) {
    final c = context.watch<SyncController>();

    return Card(
      child: ExpansionTile(
        title: const Text('显示报文'),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: 130,
                      child: DropdownButtonFormField<int>(
                        initialValue: c.pageSize,
                        isDense: true,
                        decoration: const InputDecoration(
                          labelText: '显示条数',
                        ),
                        items: const [
                          DropdownMenuItem(value: 5, child: Text('5')),
                          DropdownMenuItem(value: 10, child: Text('10')),
                          DropdownMenuItem(value: 50, child: Text('50')),
                        ],
                        onChanged: (v) {
                          if (v == null) return;
                          c.setPageSize(v);
                        },
                      ),
                    ),
                    SizedBox(
                      width: 130,
                      child: DropdownButtonFormField<int>(
                        initialValue: c.refreshSeconds,
                        isDense: true,
                        decoration: const InputDecoration(labelText: '刷新(秒)'),
                        items: const [
                          DropdownMenuItem(value: 1, child: Text('1')),
                          DropdownMenuItem(value: 5, child: Text('5')),
                          DropdownMenuItem(value: 30, child: Text('30')),
                        ],
                        onChanged: (v) {
                          if (v != null) c.setRefreshSeconds(v);
                        },
                      ),
                    ),
                    for (final f in _filters)
                      SizedBox(
                        width: 130,
                        child: DropdownButtonFormField<String>(
                          initialValue: f.current(c),
                          isDense: true,
                          decoration: InputDecoration(labelText: f.label),
                          items: [
                            for (final o in f.options)
                              DropdownMenuItem(value: o.$1, child: Text(o.$2)),
                          ],
                          onChanged: (v) => f.apply(c, v ?? ''),
                        ),
                      ),
                    FilledButton.tonal(
                      onPressed: () => c.loadLogs(),
                      child: const Text('刷新'),
                    ),
                    TextButton(
                      onPressed: () => _confirmClearLogs(context),
                      child: const Text('清空日志'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (c.logError != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      '报文加载失败：${c.logError}',
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ),
                if (c.logPage.logs.isEmpty)
                  Text(
                    (c.status?.discoveryRunning ?? false)
                        ? '暂无报文记录（发现、配对、同步完成后会在这里显示）'
                        : '局域网同步未开启 —— 请在上方「设置」中开启并保存',
                    style: const TextStyle(color: StatusColors.muted),
                  )
                else
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columnSpacing: 20,
                      headingRowHeight: 34,
                      dataRowMinHeight: 32,
                      dataRowMaxHeight: 48,
                      columns: const [
                        DataColumn(label: Text('时间')),
                        DataColumn(label: Text('方向')),
                        DataColumn(label: Text('协议')),
                        DataColumn(label: Text('对端')),
                        DataColumn(label: Text('阶段')),
                        DataColumn(label: Text('状态')),
                        DataColumn(label: Text('消息')),
                        DataColumn(label: Text('大小')),
                      ],
                      rows: [
                        for (final l in c.logPage.logs)
                          DataRow(cells: [
                            DataCell(Text(formatTime(l.timestamp.toIso8601String()))),
                            DataCell(Text(directionLabel(l.direction))),
                            DataCell(Text(protocolLabel(l.protocol))),
                            DataCell(Text(l.peerId ?? '-')),
                            DataCell(Text(eventLabel(l.eventType))),
                            DataCell(_StatusChip(status: l.status)),
                            DataCell(
                              SizedBox(
                                width: 260,
                                child: Text(
                                  l.message ?? '-',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            DataCell(Text(humanSize(l.dataSize))),
                          ]),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static const _filters = [_LogFilter.direction, _LogFilter.event, _LogFilter.protocol];

  Future<void> _confirmClearLogs(BuildContext context) async {
    final ok = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('清空报文日志'),
            content: const Text(
              '仅清除「显示报文」里的调试记录，不影响设备与配对信息。',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('确定清空'),
              ),
            ],
          ),
        ) ??
        false;
    if (!ok || !context.mounted) return;
    final err = await context.read<SyncController>().clearLogs();
    if (!context.mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err), backgroundColor: StatusColors.danger),
      );
    }
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = status == 'success'
        ? StatusColors.success
        : status == 'failed'
            ? StatusColors.danger
            : StatusColors.muted;
    return Text(status, style: TextStyle(color: color, fontSize: 12));
  }
}

/// 日志筛选器定义，避免三段重复的下拉代码
class _LogFilter {
  const _LogFilter(this.label, this.options, this.current, this.apply);

  final String label;
  final List<(String, String)> options;
  final String Function(SyncController c) current;
  final void Function(SyncController c, String v) apply;

  static const direction = _LogFilter(
    '来向/去向',
    [('', '全部'), ('out', '去向'), ('in', '来向')],
    _curDirection,
    _setDirection,
  );
  static const event = _LogFilter(
    '报文阶段',
    [
      ('', '全部'),
      ('discovery', '发现'),
      ('pairing', '配对'),
      ('sync', '同步'),
      ('conflict', '冲突'),
    ],
    _curEvent,
    _setEvent,
  );
  static const protocol = _LogFilter(
    '协议',
    [
      ('', '全部'),
      ('http', 'HTTP'),
      ('udp_broadcast', 'UDP 广播'),
      ('mdns', 'mDNS'),
    ],
    _curProtocol,
    _setProtocol,
  );

  static String _curDirection(SyncController c) => c.filterDirection;
  static String _curEvent(SyncController c) => c.filterEventType;
  static String _curProtocol(SyncController c) => c.filterProtocol;

  static void _setDirection(SyncController c, String v) =>
      c.setFilters(direction: v);
  static void _setEvent(SyncController c, String v) =>
      c.setFilters(eventType: v);
  static void _setProtocol(SyncController c, String v) =>
      c.setFilters(protocol: v);
}
