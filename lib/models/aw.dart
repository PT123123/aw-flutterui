/// ActivityWatch 核心数据模型。
/// 字段对应 aw-server-rust/aw-models/src/{bucket,event,info}.rs 的 JSON 序列化结果。
library;

import '../util/dt.dart';

/// GET /api/0/buckets/{id}
class Bucket {
  const Bucket({
    required this.id,
    required this.type,
    required this.client,
    required this.hostname,
    this.created,
    this.data = const {},
  });

  final String id;
  final String type;
  final String client;
  final String hostname;
  final DateTime? created;

  /// bucket-type 相关配置，如 afk bucket 的 timeout
  final Map<String, dynamic> data;

  factory Bucket.fromJson(Map<String, dynamic> j) => Bucket(
        id: j['id']?.toString() ?? '',
        type: j['type']?.toString() ?? '',
        client: j['client']?.toString() ?? '',
        hostname: j['hostname']?.toString() ?? '',
        created: parseTs(j['created']),
        data: (j['data'] as Map?)?.cast<String, dynamic>() ?? const {},
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'client': client,
        'hostname': hostname,
        if (created != null) 'created': created!.toUtc().toIso8601String(),
        'data': data,
      };

  /// 展示名：`aw-watcher-window_ted-host`
  String get displayName {
    final shortClient = client.startsWith('aw-watcher-')
        ? client.substring('aw-watcher-'.length)
        : client;
    return '${shortClient}_$hostname';
  }

  bool get isAfk => type == 'afkstatus';
}

/// aw-models::Event。注意 duration 序列化为 f64 **秒**（DurationSerialization）。
class Event {
  const Event({
    this.id,
    required this.timestamp,
    required this.durationSeconds,
    this.data = const {},
  });

  final int? id;
  final DateTime timestamp;

  /// 秒，可能为 0
  final double durationSeconds;
  final Map<String, dynamic> data;

  Duration get duration =>
      Duration(milliseconds: (durationSeconds * 1000).round());

  DateTime get end => timestamp.add(duration);

  factory Event.fromJson(Map<String, dynamic> j) => Event(
        id: j['id'] is int ? j['id'] as int : int.tryParse(j['id'].toString()),
        timestamp: parseTs(j['timestamp']) ?? DateTime.fromMillisecondsSinceEpoch(0),
        durationSeconds: (j['duration'] as num?)?.toDouble() ?? 0,
        data: (j['data'] as Map?)?.cast<String, dynamic>() ?? const {},
      );

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'timestamp': timestamp.toUtc().toIso8601String(),
        'duration': durationSeconds,
        'data': data,
      };
}

/// GET /api/0/info
class ServerInfo {
  const ServerInfo({
    required this.hostname,
    required this.version,
    this.testing = false,
    this.deviceId,
  });

  final String hostname;
  final String version;
  final bool testing;
  final String? deviceId;

  factory ServerInfo.fromJson(Map<String, dynamic> j) => ServerInfo(
        hostname: j['hostname']?.toString() ?? 'unknown',
        version: j['version']?.toString() ?? 'unknown',
        testing: j['testing'] == true,
        deviceId: j['device_id']?.toString(),
      );
}
