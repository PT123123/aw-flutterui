import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/aw_client.dart';
import '../models/aw.dart';
import '../state/settings.dart';
import '../theme.dart';

/// 设置页，对应 aw-webui/src/views/settings/Settings.vue。
/// 本页只放 Flutter 客户端自身的设置；同步设置属于「局域网同步」页。
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _ConnectionSection(settings: settings),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('深色模式'),
                  subtitle: const Text('时间线与图表场景深色更护眼'),
                  value: settings.darkMode,
                  onChanged: (v) => settings.darkMode = v,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ConnectionSection extends StatefulWidget {
  const _ConnectionSection({required this.settings});

  final AppSettings settings;

  @override
  State<_ConnectionSection> createState() => _ConnectionSectionState();
}

class _ConnectionSectionState extends State<_ConnectionSection> {
  late final TextEditingController _url;
  String? _result;
  bool _ok = false;
  bool _testing = false;

  @override
  void initState() {
    super.initState();
    _url = TextEditingController(text: widget.settings.baseUrl);
  }

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('服务地址', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _url,
                decoration: const InputDecoration(
                  hintText: 'http://127.0.0.1:5600',
                  helperText: 'aw-server 的 HTTP 地址，Android 端固定为 127.0.0.1:5600',
                ),
                keyboardType: TextInputType.url,
                onSubmitted: (_) => _save(),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(onPressed: _save, child: const Text('保存')),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: _testing ? null : _test,
              child: _testing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('测试连接'),
            ),
          ],
        ),
        if (_result != null) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                _ok ? Icons.check_circle_outline : Icons.error_outline,
                size: 16,
                color: _ok ? StatusColors.success : StatusColors.danger,
              ),
              const SizedBox(width: 6),
              Expanded(child: Text(_result!)),
            ],
          ),
        ],
        const SizedBox(height: 10),
        TextButton.icon(
          onPressed: () {
            widget.settings.resetBaseUrl();
            _url.text = AppSettings.defaultBaseUrl;
            setState(() => _result = null);
          },
          icon: const Icon(Icons.restart_alt, size: 16),
          label: const Text('恢复默认地址'),
        ),
      ],
    );
  }

  void _save() {
    final v = _url.text.trim();
    if (v.isEmpty) return;
    widget.settings.baseUrl = v;
    setState(() => _result = null);
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('服务地址已保存')));
  }

  Future<void> _test() async {
    setState(() {
      _testing = true;
      _result = null;
    });
    try {
      // 用当前输入框里的地址测，不必先保存
      final candidate = _url.text.trim();
      final client = AwClientProbe(candidate);
      final info = await client.getInfo();
      if (!mounted) return;
      setState(() {
        _testing = false;
        _ok = true;
        _result = '连接成功：${info.hostname}（v${info.version}）';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _testing = false;
        _ok = false;
        _result = e.toString();
      });
    }
  }
}

/// 测试连接用的临时客户端，避免污染 Provider 里的实例。
class AwClientProbe {
  AwClientProbe(String baseUrl) : _client = AwClient(baseUrl: baseUrl);

  final AwClient _client;

  Future<ServerInfo> getInfo() => _client.getInfo();
}
