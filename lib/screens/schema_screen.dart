import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/query_result.dart';
import '../state/app_state.dart';
import '../widgets/results_grid.dart';

/// Schema browser: tables + views on the left, column detail on the right.
class SchemaScreen extends StatefulWidget {
  const SchemaScreen({super.key});

  @override
  State<SchemaScreen> createState() => _SchemaScreenState();
}

class _SchemaScreenState extends State<SchemaScreen> {
  bool _loading = false;
  String? _error;
  List<String> _tables = const [];
  List<String> _views = const [];

  String? _selected;
  bool _loadingColumns = false;
  QueryResult? _columns;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    final client = context.read<AppState>().client;
    if (client == null) {
      setState(() => _error = 'Not connected.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final tables = await client.tables();
      final views = await client.views();
      if (!mounted) return;
      final viewSet = views.toSet();
      setState(() {
        _views = views;
        _tables = tables.where((t) => !viewSet.contains(t)).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _select(String name) async {
    final client = context.read<AppState>().client;
    if (client == null) return;
    setState(() {
      _selected = name;
      _loadingColumns = true;
      _columns = null;
    });
    try {
      final cols = await client.tableColumns(name);
      if (!mounted) return;
      setState(() {
        _columns = cols;
        _loadingColumns = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _columns = QueryResult(
          columns: const [],
          columnTypes: null,
          rows: const [],
          affected: 0,
          error: e.toString(),
        );
        _loadingColumns = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Schema', style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
              IconButton(
                onPressed: _loading ? null : _refresh,
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh',
              ),
            ],
          ),
          const Divider(),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(width: 240, child: _list(context)),
                const VerticalDivider(),
                Expanded(child: _detail(context)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _list(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Text(_error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error)),
      );
    }
    if (_tables.isEmpty && _views.isEmpty) {
      return const Center(child: Text('No tables.'));
    }
    return ListView(
      children: [
        if (_tables.isNotEmpty) _header(context, 'TABLES'),
        for (final t in _tables) _tile(t, Icons.table_chart_outlined),
        if (_views.isNotEmpty) _header(context, 'VIEWS'),
        for (final v in _views) _tile(v, Icons.visibility_outlined),
      ],
    );
  }

  Widget _header(BuildContext context, String label) => Padding(
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
        child: Text(label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  letterSpacing: 1,
                  color: Theme.of(context).colorScheme.outline,
                )),
      );

  Widget _tile(String name, IconData icon) => ListTile(
        dense: true,
        selected: _selected == name,
        leading: Icon(icon, size: 18),
        title: Text(name, style: const TextStyle(fontSize: 13)),
        onTap: () => _select(name),
      );

  Widget _detail(BuildContext context) {
    if (_selected == null) {
      return const Center(child: Text('Select a table or view.'));
    }
    if (_loadingColumns) {
      return const Center(child: CircularProgressIndicator());
    }
    final cols = _columns;
    if (cols == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child:
              Text(_selected!, style: Theme.of(context).textTheme.titleMedium),
        ),
        Expanded(child: ResultsGrid(result: cols)),
      ],
    );
  }
}
