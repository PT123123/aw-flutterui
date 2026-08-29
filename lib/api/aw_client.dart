import 'package:dio/dio.dart';

import '../models/aw.dart';

/// ActivityWatch 服务 REST 客户端。
///
/// 对应 aw-webui 通过 aw-client npm 包使用的 8 个方法：
///   getInfo / getBuckets / getEvents / countEvents
///   insertEvents / deleteBucket / query / abort
///
/// 与 sync_api.dart 共享同一 baseUrl 约定。
class AwClient {
  AwClient({
    required this.baseUrl,
    Dio? dio,
    Duration timeout = const Duration(seconds: 15),
  }) : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: baseUrl,
              connectTimeout: const Duration(seconds: 5),
              receiveTimeout: timeout,
              // Rust 侧错误体是 Rocket 默认 HTML，不强求 JSON
              responseType: ResponseType.json,
            ));

  final String baseUrl;
  final Dio _dio;

  static const _prefix = '/api/0';

  CancelToken? _queryToken;

  // ---- 服务信息 ----

  /// GET /api/0/info
  Future<ServerInfo> getInfo() async =>
      ServerInfo.fromJson(_asMap(await _get('$_prefix/info')));

  // ---- Buckets ----

  /// GET /api/0/buckets/
  Future<Map<String, Bucket>> getBuckets() async {
    final raw = _asMap(await _get('$_prefix/buckets/'));
    return raw.map(
      (k, v) => MapEntry(k, Bucket.fromJson(_asMap(v))),
    );
  }

  /// GET /api/0/buckets/{id}
  Future<Bucket> getBucket(String bucketId) async =>
      Bucket.fromJson(_asMap(await _get('$_prefix/buckets/$bucketId')));

  /// DELETE /api/0/buckets/{id}
  Future<void> deleteBucket(String bucketId) async {
    await _delete('$_prefix/buckets/$bucketId');
  }

  /// 桶不存在时创建（PUT /api/0/buckets/{id}），已存在则直接返回。
  Future<void> ensureBucket(
    String bucketId, {
    required String type,
    required String client,
    required String hostname,
  }) async {
    try {
      await getBucket(bucketId);
      return; // 已存在
    } on AwApiException {
      // 继续创建
    }
    await _unwrap(_dio.put<dynamic>(
      '$_prefix/buckets/$bucketId',
      data: {'type': type, 'client': client, 'hostname': hostname},
    ));
  }

  // ---- Events ----

  /// GET /api/0/buckets/{id}/events
  ///
  /// [limit] 为 0 或负表示不限。默认取最新的 100 条。
  Future<List<Event>> getEvents(
    String bucketId, {
    int limit = 100,
    DateTime? start,
    DateTime? end,
  }) async {
    final r = await _get(
      '$_prefix/buckets/$bucketId/events',
      queryParameters: {
        if (limit > 0) 'limit': limit,
        if (start != null) 'start': _iso(start),
        if (end != null) 'end': _iso(end),
      },
    );
    return _asEventList(r);
  }

  /// POST /api/0/buckets/{id}/events  插入单条事件。
  /// 后端该路由收的是事件**数组**（data = "<events>"），故包装一层。
  Future<Event> insertEvent(String bucketId, Event event) async {
    await _post('$_prefix/buckets/$bucketId/events', [event.toJson()]);
    return event;
  }

  /// GET /api/0/buckets/{id}/events/count
  Future<int> countEvents(String bucketId) async {
    final r = await _get('$_prefix/buckets/$bucketId/events/count');
    if (r is num) return r.toInt();
    final v = int.tryParse(r.toString());
    if (v == null) throw const AwApiException('事件计数响应格式异常');
    return v;
  }

  // ---- Query ----

  /// POST /api/0/query
  ///
  /// [timeperiods] 形如 ['2026-08-29T00:00:00+08:00/2026-08-30T00:00:00+08:00']
  /// [query] 为 aw-query DSL 语句数组
  /// 返回：每个 timeperiod 对应一个事件列表
  Future<List<List<Event>>> query(
    List<String> timeperiods,
    List<String> query, {
    CancelToken? cancelToken,
  }) async {
    final r = await _post(
      '$_prefix/query',
      {'timeperiods': timeperiods, 'query': query},
      cancelToken: _queryToken ?? cancelToken,
    );
    if (r is! List) throw const AwApiException('query 响应不是数组');
    return r.map((period) {
      if (period is! List) return <Event>[];
      return period
          .whereType<Map<String, dynamic>>()
          .map(Event.fromJson)
          .toList();
    }).toList();
  }

  /// 取消进行中的 query（对应 aw-client 的 abort）
  void abort() {
    _queryToken?.cancel('用户取消');
    _queryToken = null;
  }

  void resetCancelToken() {
    _queryToken = CancelToken();
  }

  // ---- 内部 ----

  static String _iso(DateTime d) => d.toUtc().toIso8601String();

  List<Event> _asEventList(dynamic r) {
    if (r is! List) return const [];
    return r
        .whereType<Map<String, dynamic>>()
        .map(Event.fromJson)
        .toList();
  }

  Future<dynamic> _get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) =>
      _unwrap(_dio.get<dynamic>(path, queryParameters: queryParameters));

  Future<dynamic> _post(
    String path,
    Object? body, {
    CancelToken? cancelToken,
  }) =>
      _unwrap(_dio.post<dynamic>(path, data: body, cancelToken: cancelToken));

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

class AwApiException implements Exception {
  const AwApiException(this.message, {this.statusCode});

  factory AwApiException.fromDio(DioException e) {
    String msg;
    final data = e.response?.data;
    if (data is Map) {
      msg = (data['message'] ?? data['error'] ?? '请求失败').toString();
    } else if (e.response != null) {
      // Rust 侧多数错误只有状态码、body 是 Rocket 默认 HTML，给一句人话
      msg = '服务器错误 (${e.response!.statusCode})，详情见服务端日志';
    } else if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      msg = '请求超时（数据量可能较大）';
    } else if (e.type == DioExceptionType.connectionError) {
      msg = '无法连接服务，请确认 aw-server 已启动';
    } else {
      msg = e.message ?? e.toString();
    }
    return AwApiException(msg, statusCode: e.response?.statusCode);
  }

  final String message;
  final int? statusCode;

  @override
  String toString() => 'AwApiException(${statusCode ?? 'network'}): $message';
}
