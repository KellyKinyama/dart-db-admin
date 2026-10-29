import 'package:oracledb/oracledb.dart';

import '../models/connection.dart';
import '../models/query_result.dart';

/// Runs SQL against the engine over the Oracle wire protocol (pure-Dart driver).
///
/// Mirrors the parts of [AdminApiClient] the SQL console needs, so screens can
/// treat an Oracle session like an HTTP one for query execution.
class OracleClient {
  OracleClient._(this._conn);

  final OracleConnection _conn;

  static Future<OracleClient> connect(ServerConnection c) async {
    final conn = await OracleConnection.connect(
      c.oracleConnectString,
      user: c.user ?? '',
      password: c.password ?? '',
      timeout: const Duration(seconds: 15),
    );
    return OracleClient._(conn);
  }

  /// Executes [sql] and returns a single-statement [QueryResponse].
  Future<QueryResponse> query(String sql, {int? maxRows}) async {
    final sw = Stopwatch()..start();
    try {
      final result = await _conn.execute(_stripTrailingSemicolon(sql));
      sw.stop();
      return QueryResponse(
        elapsedMs: sw.elapsedMilliseconds,
        results: [oracleResultToQueryResult(result)],
      );
    } catch (e) {
      sw.stop();
      return QueryResponse(
        elapsedMs: sw.elapsedMilliseconds,
        results: const [],
        error: '$e',
      );
    }
  }

  Future<void> close() => _conn.close();

  static String _stripTrailingSemicolon(String sql) {
    final t = sql.trim();
    return t.endsWith(';') ? t.substring(0, t.length - 1) : t;
  }
}

/// Maps an [OracleResult] grid into the app's [QueryResult].
QueryResult oracleResultToQueryResult(OracleResult result) {
  final columns = result.columns.map((c) => c.name).toList();
  if (columns.isEmpty) {
    final n = result.rowsAffected ?? 0;
    return QueryResult(
      columns: const [],
      columnTypes: null,
      rows: const [],
      affected: n,
      message: '$n row(s) affected',
    );
  }
  return QueryResult(
    columns: columns,
    columnTypes: result.columns.map((c) => 'ora:${c.oracleType}').toList(),
    rows: [for (final row in result.rows) row.toList()],
    affected: result.rowsAffected ?? result.rows.length,
  );
}
