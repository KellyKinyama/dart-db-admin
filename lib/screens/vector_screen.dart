import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/query_result.dart';
import '../services/sql_tools.dart';
import '../state/app_state.dart';
import '../widgets/results_grid.dart';

/// Vector manager: list registered vector indexes and run k-NN / filtered /
/// range / hybrid searches against the engine's vector store.
class VectorScreen extends StatefulWidget {
  const VectorScreen({super.key});

  @override
  State<VectorScreen> createState() => _VectorScreenState();
}

class _VectorScreenState extends State<VectorScreen> {
  bool _loading = false;
  String? _error;
  QueryResult? _indexes;

  VecSearchMode _mode = VecSearchMode.knn;
  final _table = TextEditingController();
  final _column = TextEditingController();
  final _vector = TextEditingController(text: '[0.1, 0.2]');
  final _k = TextEditingController(text: '10');
  final _radius = TextEditingController(text: '1.0');
  final _filter = TextEditingController(text: '{"tenant": 1}');
  final _textColumn = TextEditingController();
  final _queryText = TextEditingController();

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
    for (final c in [
      _table, _column, _vector, _k, _radius, _filter, _textColumn, _queryText,
    ]) {
      c.dispose();
    }
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
      sql = buildVectorQuery(
        mode: _mode,
        table: _table.text.trim(),
        column: _column.text.trim(),
        vector: _vector.text.trim(),
        k: int.tryParse(_k.text.trim()) ?? 10,
        radius: double.tryParse(_radius.text.trim()) ?? 1.0,
        filterJson: _filter.text,
        textColumn: _textColumn.text.trim(),
        queryText: _queryText.text,
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
          SizedBox(height: 150, child: _indexList(context)),
          const SizedBox(height: 12),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (tblCol >= 0 && colCol >= 0)
          Wrap(
            spacing: 6,
            children: [
              for (final row in idx.rows)
                ActionChip(
                  avatar: const Icon(Icons.scatter_plot, size: 16),
                  label: Text('${row[tblCol]}.${row[colCol]}'),
                  onPressed: () => _useIndex('${row[tblCol]}', '${row[colCol]}'),
                ),
            ],
          ),
        const SizedBox(height: 6),
        Expanded(child: ResultsGrid(result: idx)),
      ],
    );
  }

  Widget _searchForm(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SegmentedButton<VecSearchMode>(
          segments: const [
            ButtonSegment(value: VecSearchMode.knn, label: Text('k-NN')),
            ButtonSegment(value: VecSearchMode.filtered, label: Text('Filtered')),
            ButtonSegment(value: VecSearchMode.range, label: Text('Range')),
            ButtonSegment(value: VecSearchMode.hybrid, label: Text('Hybrid')),
          ],
          selected: {_mode},
          onSelectionChanged: (s) => setState(() => _mode = s.first),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _table,
                decoration:
                    const InputDecoration(labelText: 'Table', isDense: true),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _column,
                decoration: const InputDecoration(
                    labelText: 'Vector column', isDense: true),
              ),
            ),
            const SizedBox(width: 8),
            if (_mode == VecSearchMode.range)
              SizedBox(
                width: 90,
                child: TextField(
                  controller: _radius,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'radius', isDense: true),
                ),
              )
            else
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
        if (_mode == VecSearchMode.filtered)
          TextField(
            controller: _filter,
            decoration: const InputDecoration(
              labelText: 'Filter JSON  e.g. {"tenant": 1}',
              isDense: true,
            ),
            style: const TextStyle(fontFamily: 'monospace'),
          ),
        if (_mode == VecSearchMode.hybrid)
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _textColumn,
                  decoration: const InputDecoration(
                      labelText: 'Text column', isDense: true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _queryText,
                  decoration: const InputDecoration(
                      labelText: 'Query text', isDense: true),
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
