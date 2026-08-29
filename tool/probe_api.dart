// 用真实 aw-server 验证 API 层与数据模型的解析。
// 纯 Dart 运行，不需要 GUI：
//   dart run tool/probe_api.dart [baseUrl]
import 'dart:convert';

import '../lib/api/aw_client.dart';
import '../lib/api/inbox_api.dart';
import '../lib/api/sync_api.dart';
import '../lib/models/note.dart';

int _pass = 0;
int _fail = 0;

void ok(String name, Object? detail) {
  _pass++;
  print('  [OK]   $name${detail == null ? '' : ' -> $detail'}');
}

void bad(String name, Object e) {
  _fail++;
  print('  [FAIL] $name -> $e');
}

Future<void> check(String name, Future<Object?> Function() fn) async {
  try {
    final r = await fn();
    ok(name, r);
  } catch (e) {
    bad(name, e);
  }
}

void main(List<String> args) async {
  final base = args.isNotEmpty ? args[0] : 'http://127.0.0.1:5600';
  print('目标服务: $base\n');

  final aw = AwClient(baseUrl: base);
  final inbox = InboxApi(baseUrl: base);
  final sync = SyncApi(baseUrl: base);

  print('--- aw-client（8 个方法）---');
  await check('getInfo', () async {
    final i = await aw.getInfo();
    if (i.hostname == 'unknown') throw 'hostname 解析失败';
    return '${i.hostname} / v${i.version}';
  });

  Map<String, dynamic> buckets = {};
  await check('getBuckets', () async {
    final b = await aw.getBuckets();
    buckets = {for (final e in b.entries) e.key: e.value};
    if (b.isEmpty) throw '没有数据桶（服务可能刚启动）';
    return '${b.length} 个: ${b.keys.take(3).join(", ")}';
  });

  if (buckets.isNotEmpty) {
    final first = buckets.values.first;
    await check('getEvents(${first.id})', () async {
      final ev = await aw.getEvents(first.id, limit: 5);
      if (ev.isEmpty) return '0 条（空桶）';
      final e = ev.first;
      if (e.durationSeconds <= 0) throw 'duration 解析失败: ${e.durationSeconds}';
      return '${ev.length} 条, 首条 duration=${e.durationSeconds}s, data keys=${e.data.keys.take(4).join(",")}';
    });

    await check('countEvents(${first.id})', () async {
      final c = await aw.countEvents(first.id);
      return '$c';
    });
  }

  print('\n--- inbox（挂载于 /inbox）---');
  await check('GET /inbox/notes', () async {
    final notes = await inbox.getNotes();
    return '${notes.length} 条';
  });

  await check('GET /inbox/tags', () async {
    final tags = await inbox.getTags();
    return '${tags.length} 个: ${tags.take(5).join(", ")}';
  });

  // 写入 → 更新 → 删除 全链路（会留一条瞬时的测试笔记）
  Note? created;
  await check('POST /inbox/notes（Markdown）', () async {
    created = await inbox.createNote(
      '# 探活标题\n\n这是 **aw_flutter** 的联调测试。\n\n- 项 1\n- 项 2\n',
      tags: ['probe'],
    );
    if (created!.id <= 0) throw '返回的 id 无效';
    if (created!.title != '探活标题') throw 'title 提取异常: ${created!.title}';
    return 'id=${created!.id} title="${created!.title}" tags=${created!.tags}';
  });

  if (created != null) {
    await check('PUT /inbox/notes/<id>', () async {
      final updated = await inbox.updateNote(
        created!.id,
        content: '## 已更新\n\n内容已改写。',
      );
      if (updated.title != '已更新') throw 'title 未更新: ${updated.title}';
      return 'title="${updated.title}" version=${updated.version}';
    });

    await check('GET /inbox/notes/<id>', () async {
      final one = await inbox.getNote(created!.id);
      if (!one.content.contains('已更新')) throw '内容未持久化';
      return 'content 长度 ${one.content.length}';
    });

    await check('DELETE /inbox/notes/<id>', () async {
      await inbox.deleteNote(created!.id);
      // 后端是软删除，这里只确认调用未抛错
      return 'ok（软删除）';
    });
  }

  print('\n--- sync（17 个端点）---');
  await check('GET /api/0/sync/status', () async {
    final s = await sync.getStatus();
    return 'enabled=${s.enabled} running=${s.discoveryRunning} '
        'udp=${s.udpPort} http=${s.listenPort}';
  });

  await check('GET /api/0/sync/config', () async {
    final c = await sync.getConfig();
    return 'enabled=${c.enabled} method=${c.discoveryMethod} '
        'udp=${c.udpPort} probe=${c.probeInterval}s inbox=${c.syncInbox}';
  });

  await check('GET /api/0/sync/info', () async {
    final d = await sync.getInfo();
    if (d.ip.isEmpty) throw 'ip 为空';
    return '${d.name} ${d.ip}:${d.port} kind=${d.deviceKind} iface=${d.ipIface}';
  });

  await check('GET /api/0/sync/devices', () async {
    final list = await sync.getDevices();
    return '${list.length} 台'
        '${list.isEmpty ? "" : " 首台=${list.first.name} paired=${list.first.paired}"}';
  });

  await check('GET /api/0/sync/log', () async {
    final page = await sync.getLogs(limit: 5);
    return '${page.logs.length} 条 / 共 ${page.total}'
        '${page.logs.isEmpty ? "" : " 最新=${page.logs.first.message}"}';
  });

  await check('GET /api/0/sync/debuglog', () async {
    final e = await sync.getDebugLog();
    return '${e.length} 条调试日志'
        '${e.isEmpty ? "" : " 最新=${e.last.msg}"}';
  });

  // 设备统计需要一个已配对设备；没有则跳过
  await check('GET /api/0/sync/devices/<id>/stats', () async {
    final list = await sync.getDevices();
    final peer = list.where((d) => !d.isSelf).toList();
    if (peer.isEmpty) return '跳过（无对端设备）';
    final st = await sync.getDeviceStats(peer.first.id);
    return 'local=${st.localNoteCount} remote=${st.remoteNoteCount} '
        'synced=${st.totalSyncedCount} lastSync=${st.lastSyncAt}';
  });

  print('\n--- 时间格式容错（坑 #6 回归）---');
  await check('SQLite 裸串解析', () async {
    final s = await sync.getStatus();
    final dev = s.selfDevice;
    if (dev == null) return '跳过（无本机设备信息）';
    // lastSeenAt 由后端以 RFC3339 输出；此处确认非空且可解析
    if (dev.lastSeenAt == null) throw 'lastSeenAt 为 null';
    return 'lastSeenAt=${dev.lastSeenAt!.toIso8601String()}';
  });

  print('\n============================');
  print('通过 $_pass 项，失败 $_fail 项');
  print('============================');

  if (_fail > 0) {
    print(jsonEncode({'result': 'FAILED', 'pass': _pass, 'fail': _fail}));
    return;
  }
  print('全部通过');
}
