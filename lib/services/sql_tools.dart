import 'dart:convert';

import '../models/query_result.dart';

/// Returns true if [sql] contains a statement that mutates or drops data/schema
/// (DROP, DELETE, TRUNCATE, ALTER, UPDATE) and should be confirmed before running.
bool isDestructiveSql(String sql) {
  final stripped = sql.replaceAll(RegExp(r'--[^\n]*'), ' ');
  return RegExp(r'\b(drop|delete|truncate|alter|update)\b',
          caseSensitive: false)
      .hasMatch(stripped);
}

/// Serializes a [QueryResult]'s grid to CSV (RFC-4180 style quoting).
String resultToCsv(QueryResult r) {
  final buf = StringBuffer();
  buf.writeln(r.columns.map(_csvField).join(','));
  for (final row in r.rows) {
    buf.writeln(row.map((c) => _csvField(c == null ? '' : '$c')).join(','));
  }
  return buf.toString();
}

/// Serializes a [QueryResult]'s grid to a JSON array of row objects.
String resultToJson(QueryResult r) {
  final rows = [
    for (final row in r.rows)
      {
        for (var i = 0; i < r.columns.length; i++)
          r.columns[i]: i < row.length ? row[i] : null,
      },
  ];
  return const JsonEncoder.withIndent('  ').convert(rows);
}

String _csvField(String value) {
  if (value.contains(RegExp('[",\n\r]'))) {
    return '"${value.replaceAll('"', '""')}"';
  }
  return value;
}
