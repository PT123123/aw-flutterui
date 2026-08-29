import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../state/api_provider.dart';

/// 异步数据的三种状态渲染。
class AsyncView<T> extends StatelessWidget {
  const AsyncView({
    super.key,
    required this.value,
    required this.builder,
    this.emptyBuilder,
  });

  final AsyncValue<T> value;
  final Widget Function(BuildContext context, T data) builder;

  /// data 为空列表/空对象时的展示，不传则仍走 builder
  final WidgetBuilder? emptyBuilder;

  @override
  Widget build(BuildContext context) {
    if (value.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (value.hasError) {
      return _ErrorView(error: value.error!, isConnection: value.isConnectionError);
    }

    if (emptyBuilder != null) {
      final d = value.data;
      final empty = d == null ||
          (d is Iterable && d.isEmpty) ||
          (d is Map && d.isEmpty);
      if (empty) return emptyBuilder!(context);
    }

    if (!value.hasData) {
      return const Center(child: Text('暂无数据'));
    }

    return builder(context, value.data as T);
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.isConnection});

  final Object error;
  final bool isConnection;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 40, color: scheme.error),
            const SizedBox(height: 12),
            Text(
              error.toString(),
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.error),
            ),
            if (isConnection) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => context.go('/settings'),
                icon: const Icon(Icons.settings),
                label: const Text('检查服务地址'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
