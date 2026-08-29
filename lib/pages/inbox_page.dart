import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';

import '../models/note.dart';
import '../state/api_provider.dart';
import '../util/format.dart';

/// Inbox，对应 aw-webui 的 components/InboxView.vue（1176 行）
/// + NoteEditor.vue（776 行）+ NoteList.vue（661 行）。
///
/// 内容格式统一为 **Markdown**，与 Android 原生端一致
/// （见 mobile/.../inbox/NoteEditorFragment.kt 的 MarkdownTextActions）。
/// webui 用 tiptap 存 HTML，本客户端不沿用。
class InboxPage extends StatefulWidget {
  const InboxPage({super.key});

  @override
  State<InboxPage> createState() => _InboxPageState();
}

class _InboxPageState extends State<InboxPage> {
  final _search = TextEditingController();

  List<Note> _notes = const [];
  List<String> _tags = const [];
  String? _tagFilter;
  String? _error;
  bool _loading = true;
  Note? _selected;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = context.read<ApiProvider>();
      final results = await Future.wait<Object>([
        api.inbox.getNotes(tag: _tagFilter),
        api.inbox.getTags(),
      ]);
      var notes = results[0] as List<Note>;
      final tags = results[1] as List<String>;

      // 后端不带搜索参数时本地过滤
      final kw = _search.text.trim().toLowerCase();
      if (kw.isNotEmpty) {
        notes = notes
            .where((n) => n.content.toLowerCase().contains(kw))
            .toList();
      }
      notes = notes.where((n) => !n.deleted).toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

      if (!mounted) return;
      setState(() {
        _notes = notes;
        _tags = tags;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _create() async {
    try {
      final api = context.read<ApiProvider>();
      final note = await api.inbox.createNote('');
      if (!mounted) return;
      setState(() => _selected = note);
      await _load();
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString());
    }
  }

  Future<void> _delete(Note note) async {
    final ok = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('删除笔记'),
            content: Text('确定删除「${note.title}」？可在回收站恢复。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('删除'),
              ),
            ],
          ),
        ) ??
        false;
    if (!ok) return;
    try {
      await context.read<ApiProvider>().inbox.deleteNote(note.id);
      if (_selected?.id == note.id) setState(() => _selected = null);
      await _load();
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString());
    }
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inbox'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '新建笔记',
            onPressed: _create,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '刷新',
            onPressed: _load,
          ),
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 320,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    controller: _search,
                    decoration: const InputDecoration(
                      labelText: '搜索',
                      prefixIcon: Icon(Icons.search),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _load(),
                  ),
                ),
                if (_tags.isNotEmpty)
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: FilterChip(
                            label: const Text('全部'),
                            selected: _tagFilter == null,
                            onSelected: (_) {
                              setState(() => _tagFilter = null);
                              _load();
                            },
                          ),
                        ),
                        for (final t in _tags)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: FilterChip(
                              label: Text(t),
                              selected: _tagFilter == t,
                              onSelected: (_) {
                                setState(() => _tagFilter = t);
                                _load();
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                const Divider(height: 1),
                Expanded(child: _buildList()),
              ],
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: _selected == null
                ? const Center(child: Text('选择或新建一条笔记'))
                : _NoteEditor(
                    key: ValueKey(_selected!.id),
                    note: _selected!,
                    onChanged: _load,
                    onDeleted: () {
                      setState(() => _selected = null);
                      _load();
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      );
    }
    if (_notes.isEmpty) return const Center(child: Text('暂无笔记'));

    return ListView.separated(
      itemCount: _notes.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final n = _notes[i];
        return ListTile(
          selected: _selected?.id == n.id,
          title: Text(
            n.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (n.excerpt.isNotEmpty)
                Text(
                  n.excerpt,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              Text(
                formatDateTime(n.updatedAt),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          isThreeLine: n.excerpt.isNotEmpty,
          onTap: () => setState(() => _selected = n),
          onLongPress: () => _delete(n),
        );
      },
    );
  }
}

/// 编辑区：纯文本编辑 + Markdown 工具条 + 预览切换。
class _NoteEditor extends StatefulWidget {
  const _NoteEditor({
    super.key,
    required this.note,
    required this.onChanged,
    required this.onDeleted,
  });

  final Note note;
  final Future<void> Function() onChanged;
  final VoidCallback onDeleted;

  @override
  State<_NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends State<_NoteEditor> {
  late final TextEditingController _text;
  bool _preview = false;
  bool _dirty = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _text = TextEditingController(text: widget.note.content);
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await context.read<ApiProvider>().inbox.updateNote(
            widget.note.id,
            content: _text.text,
          );
      if (!mounted) return;
      setState(() => _dirty = false);
      await widget.onChanged();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// 在选区两侧包裹标记，无选区时插入并定位光标
  void _wrap(String mark) {
    final sel = _text.selection;
    final text = _text.text;
    final start = sel.start < 0 ? text.length : sel.start;
    final end = sel.end < 0 ? text.length : sel.end;
    final selected = start < end ? text.substring(start, end) : '';
    final before = text.substring(0, start);
    final after = text.substring(end);
    _text.text = '$before$mark$selected$mark$after';
    final cursor = start + mark.length + selected.length;
    _text.selection = TextSelection.collapsed(offset: cursor);
    setState(() => _dirty = true);
  }

  void _prefixLine(String prefix) {
    final sel = _text.selection;
    final text = _text.text;
    final start = sel.start < 0 ? text.length : sel.start;
    // 找到该行行首
    final lineStart = text.lastIndexOf('\n', start - 1 < 0 ? 0 : start - 1) + 1;
    _text.text = text.replaceRange(lineStart, lineStart, prefix);
    _text.selection =
        TextSelection.collapsed(offset: start + prefix.length);
    setState(() => _dirty = true);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Row(
            children: [
              SegmentedButton<bool>(
                selected: {_preview},
                onSelectionChanged: (s) => setState(() => _preview = s.first),
                segments: const [
                  ButtonSegment(value: false, label: Text('编辑'), icon: Icon(Icons.edit)),
                  ButtonSegment(value: true, label: Text('预览'), icon: Icon(Icons.visibility)),
                ],
              ),
              const SizedBox(width: 12),
              if (!_preview) ...[
                _ToolButton(
                  icon: Icons.format_bold,
                  tooltip: '粗体',
                  onPressed: () => _wrap('**'),
                ),
                _ToolButton(
                  icon: Icons.format_italic,
                  tooltip: '斜体',
                  onPressed: () => _wrap('*'),
                ),
                _ToolButton(
                  icon: Icons.code,
                  tooltip: '行内代码',
                  onPressed: () => _wrap('`'),
                ),
                _ToolButton(
                  icon: Icons.format_list_bulleted,
                  tooltip: '无序列表',
                  onPressed: () => _prefixLine('- '),
                ),
                _ToolButton(
                  icon: Icons.format_list_numbered,
                  tooltip: '有序列表',
                  onPressed: () => _prefixLine('1. '),
                ),
                _ToolButton(
                  icon: Icons.title,
                  tooltip: '标题',
                  onPressed: () => _prefixLine('# '),
                ),
              ],
              const Spacer(),
              if (_dirty) const Text('未保存'),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: (_dirty && !_saving) ? _save : null,
                child: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('保存'),
              ),
            ],
          ),
        ),
        const Divider(),
        Expanded(
          child: _preview
              ? Markdown(
                  data: _text.text.isEmpty ? '_(空笔记)_' : _text.text,
                  padding: const EdgeInsets.all(16),
                )
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: TextField(
                    controller: _text,
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    decoration: const InputDecoration(
                      hintText: '用 Markdown 记录…',
                      border: InputBorder.none,
                    ),
                    onChanged: (_) {
                      if (!_dirty) setState(() => _dirty = true);
                    },
                  ),
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Text(
                '更新于 ${formatDateTime(widget.note.updatedAt)} · v${widget.note.version}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () async {
                  final api = context.read<ApiProvider>();
                  await api.inbox.deleteNote(widget.note.id);
                  widget.onDeleted();
                },
                icon: const Icon(Icons.delete_outline, size: 16),
                label: const Text('删除'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 18),
      tooltip: tooltip,
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
    );
  }
}
