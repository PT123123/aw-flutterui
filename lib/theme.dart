import 'package:flutter/material.dart';

/// 应用主题。深色为主——ActivityWatch 的 webui 默认也是深色，
/// 且长时间盯着时间线/图表的场景深色更友好。
class AppTheme {
  static const _seed = Color(0xFF4A9EFF);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData light() => _build(Brightness.light);

  static ThemeData _build(Brightness b) {
    final scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: b,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      // 桌面端以鼠标操作为主，控件稍微紧凑一些
      visualDensity: VisualDensity.compact,
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
        ),
      ),
      listTileTheme: const ListTileThemeData(dense: true),
      inputDecorationTheme: const InputDecorationTheme(
        isDense: true,
        border: OutlineInputBorder(),
      ),
    );
  }
}

/// 状态色：同步状态、日志状态等处复用
class StatusColors {
  static const success = Color(0xFF3FB950);
  static const warning = Color(0xFFD29922);
  static const danger = Color(0xFFF85149);
  static const info = Color(0xFF58A6FF);
  static const muted = Color(0xFF8B949E);
}
