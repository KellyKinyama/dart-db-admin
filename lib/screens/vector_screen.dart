import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/query_result.dart';
import '../services/sql_tools.dart';
import '../state/app_state.dart';
import '../widgets/results_grid.dart';

/// Vector manager: list registered vector indexes and run k-NN searches.
class VectorScreen extends StatefulWidget {
  const VectorScreen({super.key});

  @override
  State<VectorScreen> createState() => _VectorScreenState();
}

class _VectorScreenState extends State<VectorScreen> {
  bool _loading = false;
  String? _error;
  QueryResult? _indexes;

  final _table = TextEditingController();
  final _column = TextEditingController();
  final _vector = TextEditingController(text: '[0.1, 0.2]');
  final _k = TextEditingController(text: '10');

  bool _searching = false;
  String? _searchError;
  QueryResult? _searchResult;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  @override
  void dispose() {
    _table.dispose();
    _column.dispose();
    _vector.dispose();
    _k.dispose();
    super.dispose();
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
      final indexes = await client.vectorIndexes();
      if (!mounted) return;
      setState(() {
        _indexes = indexes;
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

  void _useIndex(String table, String column) {
    setState(() {
      _table.text = table;
      _column.text = column;
    });
  }

  Future<void> _search() async {
    final client = context.read<AppState>().client;
    if (client == null) return;
    final String sql;
    try {
      sql = buildVecSearchSql(
        table: _table.text.trim(),
        column: _column.text.trim(),
        vector: _vector.text.trim(),
        k: int.tryParse(_k.text.trim()) ?? 10,
      );
    } on ArgumentError catch (e) {
      setState(() => _searchError = e.message.toString());
      return;
    }
    setState(() {
      _searching = true;
      _searchError = null;
    });
    try {
      final resp = await client.query(sql);
      if (!mounted) return;
      setState(() {
        _searchResult = resp.results.isEmpty ? null : resp.results.last;
        _searchError = resp.isError ? resp.error : null;
        _searching = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _searchError = e.toString();
        _searching = false;
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
              Text('Vector', style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
              IconButton(
                onPressed: _loading ? null : _refresh,
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh indexes',
              ),
            ],
          ),
          const Divider(),
          Text('Indexes', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 4),
          SizedBox(height: 180, child: _indexList(context)),
          const SizedBox(height: 12),
          Text('Similarity search',
              style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          _searchForm(context),
          const SizedBox(height: 8),
          const Divider(),
          Expanded(child: _searchResults(context)),
        ],
      ),
    );
  }

  Widget _indexList(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Text(_error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error)),
      );
    }
    final idx = _indexes;
    if (idx == null || idx.rows.isEmpty) {
      return const Center(child: Text('No vector indexes registered.'));
    }
    final tblCol = idx.columns.indexOf('tbl');
    final colCol = idx.columns.indexOf('col');
    return Stack(
      children: [
        ResultsGrid(result: idx),
        if (tblCol >= 0 && colCol >= 0)
          Positioned(
            right: 0,
            top: 0,
            child: Wrap(
              spacing: 6,
              children: [
                for (final row in idx.rows)
                  ActionChip(
                    label: Text('${row[tblCol]}.${row[colCol]}'),
                    onPressed: () =>
                        _useIndex('${row[tblCol]}', '${row[colCol]}'),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _searchForm(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _table,
                decoration: const InputDecoration(
                    labelText: 'Table', isDense: true),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _column,
                decoration: const InputDecoration(
                    labelText: 'Column', isDense: true),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 80,
              child: TextField(
                controller: _k,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'k', isDense: true),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _vector,
                decoration: const InputDecoration(
                  labelText: 'Query vector  e.g. [0.1, 0.4, ...]',
                  isDense: true,
                ),
                style: const TextStyle(fontFamily: 'monospace'),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: _searching ? null : _search,
              icon: _searching
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.search),
              label: const Text('Search'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _searchResults(BuildContext context) {
    if (_searchError != null) {
      return Text(_searchError!,
          style: TextStyle(color: Theme.of(context).colorScheme.error));
    }
    final r = _searchResult;
    if (r == null) {
      return const Center(child: Text('Run a search to see nearest neighbors.'));
    }
    return ResultsGrid(result: r);
  }
}
