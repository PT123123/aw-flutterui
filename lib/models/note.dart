/// Inbox 笔记模型。
/// 对应 aw-server-rust/aw-inbox-rust/src/models.rs 的 Note。
///
/// 内容格式统一为 **Markdown**——与 Android 原生端
/// (mobile/.../inbox/NoteEditorFragment.kt) 保持一致。
/// webui 版本用的是 tiptap 存 HTML，属历史遗留，本客户端不再沿用。
library;

import '../util/dt.dart';

class Note {
  const Note({
    required this.id,
    required this.content,
    required this.tags,
    required this.createdAt,
    required this.updatedAt,
    required this.version,
    this.deviceId,
    this.deleted = false,
    this.syncedAt,
  });

  final int id;
  final String content;

  /// 后端序列化为 JSON 数组的字符串标签
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int version;
  final String? deviceId;
  final bool deleted;
  final DateTime? syncedAt;

  factory Note.fromJson(Map<String, dynamic> j) => Note(
        id: (j['id'] as num?)?.toInt() ?? 0,
        content: j['content']?.toString() ?? '',
        tags: _asTags(j['tags']),
        createdAt: parseTs(j['created_at']) ?? DateTime.now(),
        updatedAt: parseTs(j['updated_at']) ?? DateTime.now(),
        version: (j['version'] as num?)?.toInt() ?? 0,
        deviceId: j['device_id']?.toString(),
        deleted: j['deleted'] == true,
        syncedAt: parseTs(j['synced_at']),
      );

  /// 后端 tags 可能是 JSON 数组（新）或逗号分隔串（旧），都兼容
  static List<String> _asTags(Object? v) {
    if (v == null) return const [];
    if (v is List) return v.map((e) => e.toString()).toList();
    final s = v.toString().trim();
    if (s.isEmpty || s == '[]') return const [];
    if (s.startsWith('[')) {
      return s
          .substring(1, s.length - 1)
          .split(',')
          .map((e) => e.trim().replaceAll('"', '').replaceAll("'", ''))
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return s.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }

  /// 列表展示用首行
  String get title {
    final line = content
        .split('\n')
        .map((l) => l.trim())
        .firstWhere((l) => l.isNotEmpty, orElse: () => '');
    if (line.isEmpty) return '(空笔记)';
    return line.replaceAll(RegExp(r'^#+\s*'), '');
  }

  /// 标题之外的正文，用于列表副标题
  String get excerpt {
    final lines = content.split('\n').skip(1).map((l) => l.trim());
    final body = lines.where((l) => l.isNotEmpty).join(' ');
    return body.length > 120 ? '${body.substring(0, 120)}…' : body;
  }
}
