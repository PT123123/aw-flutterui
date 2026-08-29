import 'package:flutter/material.dart';

/// 提醒，对应 aw-webui/src/views/Alerts.vue（190 行）。
///
/// 暂未迁移。原因：webui 的 Alerts 依赖浏览器 Notification API，
/// 后端（aw-server-rust）没有独立的 alerts 存储与推送接口，
/// 桌面/移动端需要重新设计一套常驻提醒机制（本地通知 + 定时检查），
/// 属于新功能而非移植，放在数据类页面完成统一之后再单独做。
class AlertsPage extends StatelessWidget {
  const AlertsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('提醒')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Card(
            margin: const EdgeInsets.all(24),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: scheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        '提醒功能尚未迁移',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'webui 版本依赖浏览器的 Notification API，'
                    '而后端没有独立的提醒存储与推送接口。\n\n'
                    '在 Flutter 客户端里这需要重新设计：本地通知插件 + 后台定时检查 '
                    'aw-server 数据，属于新增能力而非页面移植。',
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '建议排期：数据类页面（活动/报告/趋势/查询）迁移完成后再单独设计。',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: scheme.outline),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
