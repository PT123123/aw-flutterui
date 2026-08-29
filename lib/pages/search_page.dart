import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/aw.dart';
import '../state/api_provider.dart';
import '../util/dt.dart';
import '../util/format.dart';

/// 事件搜索，对应 aw-webui/src/views/Search.vue（101 行）。
/// 在所选数据桶的最近事件里按关键字过滤（匹配任意 data 字段）。
class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _q = TextEditingController();
  List<Bucket> _buckets = const [];
  String? _selected;
  List<Event> _events = const [];
  String? _error;
  bool _loadingBuckets = true;
  bool _loadingEvents = false;
  int _limit = 500;

  @override
  void initState() {
    super.initState();
    _loadBuckets();
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _loadBuckets() async {
    try {
      final api = context.read<ApiProvider>();
      final map = await api.aw.getBuckets();
      final list = map.values.toList()
        ..sort((a, b) => a.displayName.compareTo(b.displayName));
      if (!mounted) return;
      setState(() {
        _buckets = list;
        _loadingBuckets = false;
        _selected ??= list.isEmpty ? null : list.first.id;
      });
      if (_selected != null) await _loadEvents();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingBuckets = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _loadEvents() async {
    final id = _selected;
    if (id == null) return;
    setState(() {
      _loadingEvents = true;
      _error = null;
    });
    try {
      final api = context.read<ApiProvider>();
      final list = await api.aw.getEvents(id, limit: _limit);
      if (!mounted) return;
      setState(() {
        _events = list;
        _loadingEvents = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingEvents = false;
        _error = e.toString();
      });
    }
  }

  List<Event> get _filtered {
    final kw = _q.text.trim().toLowerCase();
    if (kw.isEmpty) return _events;
    return _events.where((e) {
      if (eventTitle(e.data).toLowerCase().contains(kw)) return true;
      return e.data.values.any(
        (v) => v.toString().toLowerCase().contains(kw),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('搜索')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _q,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: '关键字',
                      prefixIcon: Icon(Icons.search),
                      hintText: '匹配事件标题或任意数据字段',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _loadingBuckets
                      ? const SizedBox.shrink()
                      : DropdownButtonFormField<String>(
                          initialValue: _selected,
                          decoration: const InputDecoration(
                            labelText: '数据桶',
                          ),
                          items: [
                            for (final b in _buckets)
                              DropdownMenuItem(
                                value: b.id,
                                child: Text(
                                  b.displayName,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: (v) {
                            setState(() => _selected = v);
                            _loadEvents();
                          },
                        ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 110,
                  child: DropdownButtonFormField<int>(
                    initialValue: _limit,
                    decoration: const InputDecoration(labelText: '扫描条数'),
                    items: const [
                      DropdownMenuItem(value: 200, child: Text('200')),
                      DropdownMenuItem(value: 500, child: Text('500')),
                      DropdownMenuItem(value: 2000, child: Text('2000')),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _limit = v);
                      _loadEvents();
                    },
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loadingBuckets || _loadingEvents) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      );
    }
    final list = _filtered;
    if (list.isEmpty) {
      return Center(
        child: Text(_events.isEmpty ? '该数据桶暂无事件' : '没有匹配的事件'),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text('匹配 ${list.length} 条 / 共扫描 ${_events.length} 条'),
        ),
        Expanded(
          child: ListView.separated(
            itemCount: list.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final e = list[i];
              return ListTile(
                dense: true,
                title: Text(eventTitle(e.data)),
                subtitle: Text(formatDateTime(e.timestamp)),
                trailing: Text(formatDuration(e.durationSeconds)),
                onTap: () => showDialog<void>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('事件数据'),
                    content: SingleChildScrollView(
                      child: SelectableText(
                        e.data.entries
                            .map((x) => '${x.key}: ${x.value}')
                            .join('\n'),
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('关闭'),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
