import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/query_result.dart';
import '../services/admin_api_client.dart';
import '../services/history_store.dart';
import '../services/sql_tools.dart';
import '../state/app_state.dart';
import '../widgets/results_grid.dart';

/// SQL console: an editor, a Run button, and a results area.
class SqlConsoleScreen extends StatefulWidget {
  const SqlConsoleScreen({super.key});

  @override
  State<SqlConsoleScreen> createState() => _SqlConsoleScreenState();
}

class _SqlConsoleScreenState extends State<SqlConsoleScreen> {
  final _controller = TextEditingController(
    text: 'SELECT 1 AS answer;',
  );
  final _focus = FocusNode();

  bool _running = false;
  QueryResponse? _response;
  String? _error;
  final _historyStore = QueryHistoryStore();
  List<String> _history = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadHistory());
  }

  Future<void> _loadHistory() async {
    final conn = context.read<AppState>().active;
    if (conn == null) return;
    final history = await _historyStore.load(conn.name);
    if (!mounted) return;
    setState(() => _history = history);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    final state = context.read<AppState>();
    final client = state.client;
    if (client == null) {
      setState(() => _error = 'Not connected. Open the Connect tab first.');
      return;
    }
    final sql = _controller.text.trim();
    if (sql.isEmpty) return;

    if (isDestructiveSql(sql) && !await _confirmDestructive(sql)) return;
    if (!mounted) return;

    final conn = state.active;
    if (conn != null) {
      final updated = await _historyStore.add(conn.name, sql);
      if (mounted) setState(() => _history = updated);
    }

    setState(() {
      _running = true;
      _error = null;
    });

    try {
      final resp = await client.query(sql);
      if (!mounted) return;
      setState(() {
        _response = resp;
        _running = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is AdminApiException ? e.message : e.toString();
        _running = false;
      });
    }
  }

  Future<bool> _confirmDestructive(String sql) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.warning_amber, color: Colors.orange),
        title: const Text('Run destructive statement?'),
        content: SizedBox(
          width: 420,
          child: Text(
            'This query contains DROP/DELETE/TRUNCATE/ALTER/UPDATE and may '
            'modify or remove data:\n\n$sql',
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Run anyway'),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  QueryResult? get _exportable {
    final results = _response?.results;
    if (results == null) return null;
    for (final r in results) {
      if (r.columns.isNotEmpty) return r;
    }
    return null;
  }

  Future<void> _copy(String text, String what) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$what copied to clipboard')),
    );
  }

  Future<void> _save(String text, String ext) async {
    final location = await getSaveLocation(
      suggestedName: 'results.$ext',
      acceptedTypeGroups: [
        XTypeGroup(label: ext.toUpperCase(), extensions: [ext]),
      ],
    );
    if (location == null) return;
    await File(location.path).writeAsString(text);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Saved ${location.path}')),
    );
  }

  void _pickHistory() async {
    final chosen = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Query history'),
        children: [
          for (final sql in _history)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(sql),
              child: Text(
                sql.length > 120 ? '${sql.substring(0, 120)}…' : sql,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
        ],
      ),
    );
    if (chosen != null) {
      setState(() => _controller.text = chosen);
    }
  }

  @override
  Widget build(BuildContext context) {
    final connected = context.watch<AppState>().isConnected;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('SQL Console', style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
              if (_response != null)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Text('${_response!.elapsedMs} ms'),
                ),
              IconButton(
                tooltip: 'Query history',
                icon: const Icon(Icons.history),
                onPressed: _history.isEmpty ? null : _pickHistory,
              ),
              PopupMenuButton<String>(
                tooltip: 'Export results',
                enabled: _exportable != null,
                icon: const Icon(Icons.download),
                onSelected: (fmt) {
                  final r = _exportable;
                  if (r == null) return;
                  switch (fmt) {
                    case 'csv':
                      _copy(resultToCsv(r), 'CSV');
                    case 'json':
                      _copy(resultToJson(r), 'JSON');
                    case 'csv-file':
                      _save(resultToCsv(r), 'csv');
                    case 'json-file':
                      _save(resultToJson(r), 'json');
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'csv', child: Text('Copy as CSV')),
                  PopupMenuItem(value: 'json', child: Text('Copy as JSON')),
                  PopupMenuDivider(),
                  PopupMenuItem(value: 'csv-file', child: Text('Save as CSV file…')),
                  PopupMenuItem(value: 'json-file', child: Text('Save as JSON file…')),
                ],
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: connected && !_running ? _run : null,
                icon: _running
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.play_arrow),
                label: const Text('Run  (Ctrl+Enter)'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _Editor(
            controller: _controller,
            focusNode: _focus,
            onRun: connected && !_running ? _run : null,
          ),
          const SizedBox(height: 12),
          const Divider(),
          Expanded(child: _buildResults(context)),
        ],
      ),
    );
  }

  Widget _buildResults(BuildContext context) {
    if (_error != null) {
      return _Banner(
        color: Theme.of(context).colorScheme.errorContainer,
        child: SelectableText(_error!),
      );
    }
    final resp = _response;
    if (resp == null) {
      return const Center(child: Text('Run a query to see results.'));
    }
    if (resp.results.isEmpty) {
      return const Center(child: Text('Statement completed with no results.'));
    }
    if (resp.results.length == 1) {
      return ResultsGrid(result: resp.results.first);
    }
    return ListView.separated(
      itemCount: resp.results.length,
      separatorBuilder: (_, _) => const SizedBox(height: 16),
      itemBuilder: (context, i) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Statement ${i + 1}',
                style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 4),
            SizedBox(
              height: resp.results[i].columns.isEmpty ? 40 : 260,
              child: ResultsGrid(result: resp.results[i]),
            ),
          ],
        );
      },
    );
  }
}

class _Editor extends StatelessWidget {
  const _Editor({
    required this.controller,
    required this.focusNode,
    required this.onRun,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback? onRun;

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: {
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.enter):
            const _RunIntent(),
      },
      child: Actions(
        actions: {
          _RunIntent: CallbackAction<_RunIntent>(
            onInvoke: (_) {
              onRun?.call();
              return null;
            },
          ),
        },
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            maxLines: 8,
            minLines: 4,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.all(12),
              hintText: 'Enter SQL…',
            ),
          ),
        ),
      ),
    );
  }
}

class _RunIntent extends Intent {
  const _RunIntent();
}

class _Banner extends StatelessWidget {
  const _Banner({required this.color, required this.child});

  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: child,
    );
  }
}
