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

final _identifier = RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$');
final _vectorLiteral = RegExp(r'^\[\s*-?\d');

/// True if [s] is a safe SQL identifier (table/column name).
bool isIdentifier(String s) => _identifier.hasMatch(s);

/// True if [s] looks like a numeric JSON array, e.g. `[0.1, 0.4, -2]`.
bool isVectorLiteral(String s) {
  final t = s.trim();
  if (!_vectorLiteral.hasMatch(t) || !t.endsWith(']')) return false;
  final inner = t.substring(1, t.length - 1).trim();
  if (inner.isEmpty) return false;
  return inner.split(',').every((p) => double.tryParse(p.trim()) != null);
}

/// Builds a `vec_search` k-NN query. Throws [ArgumentError] on invalid input.
String buildVecSearchSql({
  required String table,
  required String column,
  required String vector,
  required int k,
}) {
  if (!isIdentifier(table)) throw ArgumentError('invalid table: $table');
  if (!isIdentifier(column)) throw ArgumentError('invalid column: $column');
  if (!isVectorLiteral(vector)) throw ArgumentError('invalid vector: $vector');
  if (k < 1) throw ArgumentError('k must be >= 1');
  final v = vector.trim();
  return "SELECT rowid, distance FROM vec_search('$table', '$column', "
      "VEC('$v'), $k) ORDER BY distance";
}
