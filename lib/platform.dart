import 'package:flutter/foundation.dart';

/// 平台判定与桌面端窗口初始化。
///
/// 刻意不引入 window_manager：它在 Android 上不可用，
/// 而窗口尺寸本就可以在平台层配置（linux/my_application.cc、
/// windows/runner/win32_window.cpp），没必要为此增加一条依赖风险。
bool get isDesktop => const <TargetPlatform>{
      TargetPlatform.linux,
      TargetPlatform.macOS,
      TargetPlatform.windows,
    }.contains(defaultTargetPlatform);

bool get isMobile => const <TargetPlatform>{
      TargetPlatform.android,
      TargetPlatform.iOS,
    }.contains(defaultTargetPlatform);

/// 桌面端窗口初始化钩子。当前为空实现，尺寸由平台层决定。
Future<void> initPlatformWindow() async {}
