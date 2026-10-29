import 'package:dart_db_admin/models/query_result.dart';
import 'package:dart_db_admin/widgets/results_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) =>
    MaterialApp(home: Scaffold(body: SizedBox(height: 400, child: child)));

void main() {
  testWidgets('renders columns, rows, and a row count', (tester) async {
    final r = QueryResult(
      columns: ['id', 'name'],
      columnTypes: null,
      rows: [
        [1, 'Ann'],
        [2, 'Bob'],
      ],
      affected: 2,
    );
    await tester.pumpWidget(_host(ResultsGrid(result: r)));
    expect(find.text('id'), findsOneWidget);
    expect(find.text('name'), findsOneWidget);
    expect(find.text('Ann'), findsOneWidget);
    expect(find.text('2 row(s)'), findsOneWidget);
  });

  testWidgets('shows a truncation note', (tester) async {
    final r = QueryResult(
      columns: ['x'],
      columnTypes: null,
      rows: [
        [1],
        [2],
      ],
      affected: 5,
      truncated: true,
      totalRows: 5,
    );
    await tester.pumpWidget(_host(ResultsGrid(result: r)));
    expect(find.text('2 of 5 row(s) — truncated'), findsOneWidget);
  });

  testWidgets('shows NULL for null cells', (tester) async {
    final r = QueryResult(
      columns: ['a'],
      columnTypes: null,
      rows: [
        [null],
      ],
      affected: 1,
    );
    await tester.pumpWidget(_host(ResultsGrid(result: r)));
    expect(find.text('NULL'), findsOneWidget);
  });

  testWidgets('renders an error result', (tester) async {
    final r = QueryResult(
      columns: const [],
      columnTypes: null,
      rows: const [],
      affected: 0,
      error: 'ORA-00942: table or view does not exist',
    );
    await tester.pumpWidget(_host(ResultsGrid(result: r)));
    expect(find.textContaining('ORA-00942'), findsOneWidget);
  });

  testWidgets('renders a DML status message', (tester) async {
    final r = QueryResult(
      columns: const [],
      columnTypes: null,
      rows: const [],
      affected: 3,
      message: '3 row(s) inserted',
    );
    await tester.pumpWidget(_host(ResultsGrid(result: r)));
    expect(find.text('3 row(s) inserted'), findsOneWidget);
  });
}
