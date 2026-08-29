/// 时间解析工具。
///
/// 后端三种时间格式混用，必须容错：
/// 1. RFC3339      '2026-08-29T05:20:00.123Z'   —— aw-models 的 DateTime<Utc>
/// 2. SQLite 裸串   `2026-08-29 05:20:00`       —— sync 的 DeviceSyncStats / ConflictSummary
/// 3. 纯日期        '2026-08-29'
library;

DateTime? parseTs(Object? v, {bool toLocal = true}) {
  if (v == null) return null;
  final s = v.toString();
  if (s.isEmpty) return null;

  DateTime? d = DateTime.tryParse(s);
  // SQLite 裸串：'2026-08-29 05:20:00' -> '2026-08-29T05:20:00Z'
  d ??= DateTime.tryParse('${s.replaceFirst(' ', 'T')}Z');
  // 纯日期：'2026-08-29'
  d ??= DateTime.tryParse('${s}T00:00:00Z');
  if (d == null) return null;

  return toLocal ? d.toLocal() : d;
}

/// 秒 -> 人类可读时长（用于 event.duration 展示）
String formatDuration(num seconds) {
  if (seconds <= 0) return '0s';
  final d = Duration(milliseconds: (seconds * 1000).round());
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);
  if (h > 0) return '${h}h ${m}m';
  if (m > 0) return '${m}m ${s}s';
  return '${s}s';
}

/// 事件标题：优先取 data 里的可读字段，退化到类型名。
String eventTitle(Map<String, dynamic> data) {
  for (final key in const ['title', 'app', 'name', 'url', 'file', 'status']) {
    final v = data[key];
    if (v is String && v.trim().isNotEmpty) return v.trim();
  }
  return '(无标题)';
}
