import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 应用设置。服务地址是唯一必须持久化的项——
/// Android 端固定为 127.0.0.1:5600，Windows 端可能指向本机或远程服务。
class AppSettings extends ChangeNotifier {
  AppSettings._(this._prefs);

  static const _kBaseUrl = 'aw.baseUrl';
  static const _kHostname = 'aw.hostname';
  static const _kDarkMode = 'aw.darkMode';

  static const String defaultBaseUrl = 'http://127.0.0.1:5600';

  final SharedPreferences _prefs;

  static Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return AppSettings._(prefs);
  }

  String get baseUrl => _prefs.getString(_kBaseUrl) ?? defaultBaseUrl;

  set baseUrl(String v) {
    _prefs.setString(_kBaseUrl, v);
    notifyListeners();
  }

  /// 本地设备名，用于同步页面展示与广播别名
  String get hostname => _prefs.getString(_kHostname) ?? '';

  set hostname(String v) {
    _prefs.setString(_kHostname, v);
    notifyListeners();
  }

  bool get darkMode => _prefs.getBool(_kDarkMode) ?? true;

  set darkMode(bool v) {
    _prefs.setBool(_kDarkMode, v);
    notifyListeners();
  }

  void resetBaseUrl() => baseUrl = defaultBaseUrl;
}
