// ignore_for_file: avoid_print
import 'package:dart_db_admin/models/connection.dart';
import 'package:dart_db_admin/services/oracle_client.dart';

/// Exercises the app's OracleClient against the running engine Oracle wire port.
Future<void> main() async {
  const conn = ServerConnection(
    name: 'ora',
    host: '127.0.0.1',
    port: 1521,
    kind: ConnectionKind.oracleWire,
    service: 'DARTDB',
    user: 'admin',
    password: 'admin',
  );
  final client = await OracleClient.connect(conn);
  final resp = await client.query('SELECT 42 AS answer, 7 AS lucky FROM DUAL');
  final r = resp.results.single;
  print('columns: ${r.columns}');
  print('types:   ${r.columnTypes}');
  print('rows:    ${r.rows}');
  print('elapsed: ${resp.elapsedMs}ms  error: ${resp.error}');
  await client.close();
}
