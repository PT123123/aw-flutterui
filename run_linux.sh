#!/usr/bin/env bash
# 在 WSL2 + WSLg 下运行 aw_flutter 桌面版。
#
# 前置依赖（首次需要，缺一不可）：
#   sudo apt install -y cmake ninja-build build-essential libgtk-3-dev clang
#
# 注意 clang 是必需的：Flutter 3.47 的 Linux 构建在
#   flutter_tools/lib/src/linux/build_linux.dart:197
# 硬编码了 environment: {'CC': 'clang', 'CXX': 'clang++'}，
# 没有开关可以改用 g++，所以即使装了 build-essential 也还是编不过。
#
# ⚠️ 关于性能：WSL2 没有 /dev/dri，GPU 不透传，WSLg 的 D3D12 初始化失败后
# Flutter 会退回 CPU 软件光栅化（日志里的 "OpenGLESSDF" + "D3D12: Removing Device"）。
# 所以界面会明显发涩——这不是代码问题，是 WSL 跑 GUI 的先天限制。
# 两个缓解办法：
#   1) 用 release 模式（默认，去掉 JIT 与断言，快数倍）
#   2) 要真正流畅，就去 Windows 上跑 Windows 版（flutter run -d windows）
#
# 用法：
#   ./run_linux.sh              # release 模式（推荐）
#   ./run_linux.sh --debug      # debug 模式，支持热重载但很卡
#   ./run_linux.sh --release
set -euo pipefail

# flutter 不在默认 PATH 里
export PATH="$HOME/flutter/bin:$PATH"

# WSLg 下 DISPLAY 常常是空的，:0 是 WSLg 的默认显示号
export DISPLAY="${DISPLAY:-:0}"

cd "$(dirname "$(readlink -f "$0")")"

if ! command -v flutter >/dev/null 2>&1; then
  echo "找不到 flutter，请确认已安装在 ~/flutter" >&2
  exit 1
fi

# 提前检查编译器，避免只看到一屏 CMake 报错
if ! command -v clang++ >/dev/null 2>&1; then
  echo "缺少 clang++。Flutter 的 Linux 构建强制使用 clang（无法改用 g++）：" >&2
  echo "  sudo apt install -y clang" >&2
  exit 1
fi

# 默认 release：debug 模式在软件渲染下几乎不可用
MODE="--release"
if [[ "${1:-}" == "--debug" ]]; then
  MODE="--debug"
  shift
fi

echo "DISPLAY=$DISPLAY"
echo "编译器:  $(clang++ --version | head -1)"
echo "模式:    $MODE"
echo "服务:    http://127.0.0.1:5600（应用内「设置」页可改）"
echo
echo "提示：软件渲染下界面会发涩，属正常现象。按 q 退出。"
echo

exec flutter run -d linux "$MODE" "$@"
