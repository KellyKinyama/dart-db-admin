import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';

import '../models/query_result.dart';

/// Renders a single [QueryResult] as either a data grid (for SELECTs) or a
/// status line (for DDL/DML/errors).
class ResultsGrid extends StatelessWidget {
  const ResultsGrid({super.key, required this.result});

  final QueryResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (result.isError) {
      return _StatusLine(
        icon: Icons.error_outline,
        color: theme.colorScheme.error,
        text: result.error!,
      );
    }

    if (result.columns.isEmpty) {
      return _StatusLine(
        icon: Icons.check_circle_outline,
        color: Colors.green,
        text: result.message ?? '${result.affected} row(s) affected',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: DataTable2(
            columnSpacing: 16,
            horizontalMargin: 12,
            minWidth: (result.columns.length * 140).toDouble(),
            headingRowColor: WidgetStatePropertyAll(
              theme.colorScheme.surfaceContainerHighest,
            ),
            columns: [
              for (var i = 0; i < result.columns.length; i++)
                DataColumn2(
                  label: Tooltip(
                    message: result.columnTypes != null &&
                            i < result.columnTypes!.length
                        ? result.columnTypes![i]
                        : '',
                    child: Text(
                      result.columns[i],
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
            rows: [
              for (final row in result.rows)
                DataRow2(
                  cells: [
                    for (var i = 0; i < result.columns.length; i++)
                      DataCell(Text(_fmt(i < row.length ? row[i] : null))),
                  ],
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            result.truncated
                ? '${result.rows.length} of ${result.totalRows} row(s) — truncated'
                : '${result.rows.length} row(s)',
            style: theme.textTheme.bodySmall?.copyWith(
              color: result.truncated ? Colors.orange : null,
            ),
          ),
        ),
      ],
    );
  }

  String _fmt(Object? v) {
    if (v == null) return 'NULL';
    return v.toString();
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({
    required this.icon,
    required this.color,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Expanded(child: SelectableText(text)),
      ],
    );
  }
}
