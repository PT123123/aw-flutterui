import 'package:dio/dio.dart';

import 'aw_client.dart' show AwApiException;
import '../models/note.dart';

/// Inbox REST 客户端。
///
/// 注意挂载点是 `/inbox` 而非 `/api/0/inbox`
/// （见 aw-inbox-rust/src/lib.rs 的 mount("/inbox", ...)）。
class InboxApi {
  InboxApi({required this.baseUrl, Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: baseUrl,
              connectTimeout: const Duration(seconds: 5),
              receiveTimeout: const Duration(seconds: 15),
            ));

  final String baseUrl;
  final Dio _dio;

  static const _p = '/inbox';

  /// GET /inbox/notes
  Future<List<Note>> getNotes({String? tag, String? search}) async {
    final r = await _get('$_p/notes', queryParameters: {
      if (tag != null && tag.isNotEmpty) 'tag': tag,
      if (search != null && search.isNotEmpty) 'search': search,
    });
    return _asNoteList(r);
  }

  /// GET /inbox/notes/<id>
  Future<Note> getNote(int id) async =>
      Note.fromJson(_asMap(await _get('$_p/notes/$id')));

  /// POST /inbox/notes
  Future<Note> createNote(String content, {List<String> tags = const []}) async {
    final r = await _post('$_p/notes', {
      'content': content,
      'tags': tags,
    });
    return Note.fromJson(_asMap(r));
  }

  /// PUT /inbox/notes/<id>
  Future<Note> updateNote(
    int id, {
    required String content,
    List<String>? tags,
  }) async {
    final r = await _put('$_p/notes/$id', {
      'content': content,
      if (tags != null) 'tags': tags,
    });
    return Note.fromJson(_asMap(r));
  }

  /// DELETE /inbox/notes/<id>
  Future<void> deleteNote(int id) async {
    await _delete('$_p/notes/$id');
  }

  /// PUT /inbox/notes/<id>/restore
  Future<Note> restoreNote(int id) async =>
      Note.fromJson(_asMap(await _put('$_p/notes/$id/restore', {})));

  /// GET /inbox/notes/<id>/history
  Future<List<Map<String, dynamic>>> getHistory(int id) async {
    final r = await _get('$_p/notes/$id/history');
    if (r is! List) return const [];
    return r.whereType<Map<String, dynamic>>().toList();
  }

  /// GET /inbox/tags
  Future<List<String>> getTags() async {
    final r = await _get('$_p/tags');
    if (r is! List) return const [];
    return r.map((e) => e.toString()).toList();
  }

  /// GET /inbox/notes/<id>/comments
  Future<List<Map<String, dynamic>>> getComments(int id) async {
    final r = await _get('$_p/notes/$id/comments');
    if (r is! List) return const [];
    return r.whereType<Map<String, dynamic>>().toList();
  }

  // ---- 内部 ----

  List<Note> _asNoteList(dynamic r) {
    if (r is! List) return const [];
    return r.whereType<Map<String, dynamic>>().map(Note.fromJson).toList();
  }

  Future<dynamic> _get(String path, {Map<String, dynamic>? queryParameters}) =>
      _unwrap(_dio.get<dynamic>(path, queryParameters: queryParameters));

  Future<dynamic> _post(String path, Object? body) =>
      _unwrap(_dio.post<dynamic>(path, data: body));

  Future<dynamic> _put(String path, Object? body) =>
      _unwrap(_dio.put<dynamic>(path, data: body));

  Future<dynamic> _delete(String path) => _unwrap(_dio.delete<dynamic>(path));

  Future<dynamic> _unwrap(Future<Response<dynamic>> f) async {
    try {
      final r = await f;
      return r.data;
    } on DioException catch (e) {
      throw AwApiException.fromDio(e);
    }
  }

  static Map<String, dynamic> _asMap(dynamic v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return v.cast<String, dynamic>();
    throw AwApiException('响应不是 JSON 对象: $v');
  }
}
