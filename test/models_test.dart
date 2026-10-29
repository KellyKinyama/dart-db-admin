import 'package:dart_db_admin/models/connection.dart';
import 'package:dart_db_admin/models/query_result.dart';
import 'package:dart_db_admin/services/admin_api_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ServerConnection', () {
    test('url getters', () {
      const c = ServerConnection(name: 'local', host: '127.0.0.1', port: 8088);
      expect(c.baseUrl, 'http://127.0.0.1:8088/api');
      expect(c.origin, 'http://127.0.0.1:8088');
      expect(c.wsUrl, 'ws://127.0.0.1:8088/api/events');
    });

    test('TLS switches scheme', () {
      const c = ServerConnection(
          name: 'remote', host: 'db', port: 443, useTls: true);
      expect(c.baseUrl, 'https://db:443/api');
      expect(c.wsUrl, 'wss://db:443/api/events');
    });

    test('JSON list round-trip', () {
      final list = [
        const ServerConnection(name: 'a', host: 'h1', port: 1, token: 't'),
        const ServerConnection(name: 'b', host: 'h2', port: 2, useTls: true),
      ];
      final decoded = ServerConnection.decodeList(
          ServerConnection.encodeList(list));
      expect(decoded.length, 2);
      expect(decoded[0].name, 'a');
      expect(decoded[0].token, 't');
      expect(decoded[1].useTls, true);
    });

    test('decodeList tolerates garbage', () {
      expect(ServerConnection.decodeList('not json'), isEmpty);
      expect(ServerConnection.decodeList('{"not":"a list"}'), isEmpty);
    });
  });

  group('ServerConnection (Oracle wire)', () {
    test('oracleConnectString and endpointLabel', () {
      const c = ServerConnection(
        name: 'ora',
        host: '127.0.0.1',
        port: 1521,
        kind: ConnectionKind.oracleWire,
        service: 'DARTDB',
        user: 'admin',
        password: 'admin',
      );
      expect(c.isOracle, isTrue);
      expect(c.oracleConnectString, '127.0.0.1:1521/DARTDB');
      expect(c.endpointLabel, '127.0.0.1:1521/DARTDB');
    });

    test('password is NOT persisted; kind + service survive round-trip', () {
      const c = ServerConnection(
        name: 'ora',
        host: 'h',
        port: 1521,
        kind: ConnectionKind.oracleWire,
        service: 'DARTDB',
        user: 'admin',
        password: 'secret',
      );
      final decoded =
          ServerConnection.decodeList(ServerConnection.encodeList([c])).single;
      expect(decoded.kind, ConnectionKind.oracleWire);
      expect(decoded.service, 'DARTDB');
      expect(decoded.user, 'admin');
      expect(decoded.password, isNull);
    });
  });

  group('QueryResult', () {
    test('parses a SELECT result', () {
      final r = QueryResult.fromJson({
        'columns': ['id', 'name'],
        'rows': [
          [1, 'a'],
          [2, 'b'],
        ],
        'affected': 2,
      });
      expect(r.columns, ['id', 'name']);
      expect(r.rows.length, 2);
      expect(r.isError, isFalse);
    });

    test('flags an error result', () {
      final r = QueryResult.fromJson({'error': 'boom'});
      expect(r.isError, isTrue);
      expect(r.error, 'boom');
    });

    test('parses truncation markers', () {
      final r = QueryResult.fromJson({
        'columns': ['x'],
        'rows': [
          [1],
          [2],
        ],
        'affected': 5,
        'truncated': true,
        'totalRows': 5,
      });
      expect(r.truncated, isTrue);
      expect(r.totalRows, 5);
      expect(r.rows.length, 2);
    });
  });

  group('QueryResponse', () {
    test('parses elapsed + multiple results', () {
      final resp = QueryResponse.fromJson({
        'elapsedMs': 12,
        'results': [
          {'columns': [], 'rows': [], 'affected': 1, 'message': 'ok'},
          {
            'columns': ['x'],
            'rows': [
              [1]
            ],
            'affected': 1,
          },
        ],
      });
      expect(resp.elapsedMs, 12);
      expect(resp.results.length, 2);
      expect(resp.results.last.columns, ['x']);
    });

    test('top-level error', () {
      final resp = QueryResponse.fromJson({'elapsedMs': 1, 'error': 'nope'});
      expect(resp.isError, isTrue);
    });
  });

  group('ApiRoute', () {
    test('parses a route descriptor', () {
      final route = ApiRoute.fromJson({
        'method': 'POST',
        'path': '/api/query',
        'description': 'run sql',
        'sampleBody': {'sql': 'SELECT 1;'},
      });
      expect(route.method, 'POST');
      expect(route.path, '/api/query');
      expect(route.sampleBody, isA<Map>());
    });
  });

  group('ProbeResult', () {
    test('ok reflects 2xx without error', () {
      expect(
        ProbeResult(statusCode: 200, elapsedMs: 3, body: '{}').ok,
        isTrue,
      );
      expect(
        ProbeResult(statusCode: 404, elapsedMs: 3, body: '').ok,
        isFalse,
      );
      expect(
        ProbeResult(statusCode: 0, elapsedMs: 3, body: '', error: 'x').ok,
        isFalse,
      );
    });
  });
}
