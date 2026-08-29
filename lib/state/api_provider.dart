import 'package:flutter/foundation.dart';

import '../api/aw_client.dart';
import '../api/inbox_api.dart';
import '../api/sync_api.dart';
import 'settings.dart';

/// 依据 [AppSettings.baseUrl] 持有两个 API 客户端。
/// baseUrl 变更时重建实例，页面通过 Provider 取用。
class ApiProvider extends ChangeNotifier {
  ApiProvider(this._settings) {
    _rebuild();
    _settings.addListener(_onSettingsChanged);
  }

  final AppSettings _settings;

  AwClient? _aw;
  SyncApi? _sync;
  InboxApi? _inbox;

  AwClient get aw => _aw!;
  SyncApi get sync => _sync!;
  InboxApi get inbox => _inbox!;

  void _onSettingsChanged() {
    _rebuild();
    notifyListeners();
  }

  void _rebuild() {
    final base = _settings.baseUrl;
    _aw = AwClient(baseUrl: base);
    _sync = SyncApi(baseUrl: base);
    _inbox = InboxApi(baseUrl: base);
  }

  @override
  void dispose() {
    _settings.removeListener(_onSettingsChanged);
    super.dispose();
  }
}

/// 统一的异步数据状态，避免每个页面各写一套 loading/error。
class AsyncValue<T> {
  const AsyncValue._(this.state, {this.data, this.error});

  const AsyncValue.loading() : this._(AsyncState.loading);
  const AsyncValue.data(T value) : this._(AsyncState.ready, data: value);
  const AsyncValue.error(Object e) : this._(AsyncState.error, error: e);

  final AsyncState state;
  final T? data;
  final Object? error;

  bool get isLoading => state == AsyncState.loading;
  bool get hasError => state == AsyncState.error;
  bool get hasData => state == AsyncState.ready && data != null;

  /// 是否「服务不可达」类错误——用于展示「去设置改地址」的引导
  bool get isConnectionError {
    final e = error;
    if (e == null) return false;
    final msg = e.toString();
    return msg.contains('无法连接') || msg.contains('超时');
  }
}

enum AsyncState { loading, ready, error }
