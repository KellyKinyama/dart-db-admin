import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/connection.dart';
import '../models/query_result.dart';

/// Thrown when the admin API returns a non-success response or is unreachable.
class AdminApiException implements Exception {
  AdminApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'AdminApiException($statusCode): $message';
}

/// HTTP client for the dart-db-server management (admin) API.
///
/// Depends only on HTTP/JSON — it has no reference to the engine package.
class AdminApiClient {
  AdminApiClient(this.connection, {http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  final ServerConnection connection;
  final http.Client _http;

  Map<String, String> get _headers => {
        'content-type': 'application/json',
        if (connection.token case final t? when t.isNotEmpty)
          'authorization': 'Bearer $t',
      };
  Uri _uri(String path) => Uri.parse('${connection.baseUrl}$path');

  Future<Map<String, Object?>> _get(String path) async {
    final http.Response res;
    try {
      res = await _http
          .get(_uri(path), headers: _headers)
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      throw AdminApiException('Request failed: $e');
    }
    return _decode(res);
  }

  Map<String, Object?> _decode(http.Response res) {
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw AdminApiException(
        res.body.isEmpty ? res.reasonPhrase ?? 'HTTP error' : res.body,
        statusCode: res.statusCode,
      );
    }
    if (res.body.isEmpty) return const {};
    final decoded = jsonDecode(res.body);
    if (decoded is Map) return decoded.cast<String, Object?>();
    return {'value': decoded};
  }

  /// GET /api/health — liveness probe.
  Future<bool> health() async {
    final json = await _get('/health');
    return json['ok'] == true;
  }

  /// GET /api/info — engine metadata.
  Future<Map<String, Object?>> info() => _get('/info');

  /// GET /api/status — HA / replication status.
  Future<Map<String, Object?>> status() => _get('/status');

  /// GET /api/metrics — admin API uptime + request counters.
  Future<Map<String, Object?>> metrics() => _get('/metrics');

  /// GET /api/stats — table / view counts.
  Future<Map<String, Object?>> stats() => _get('/stats');

  /// GET /api/sessions — active connection counts.
  Future<Map<String, Object?>> sessions() => _get('/sessions');

  /// GET /api/oplog — recent op-log records.
  Future<Map<String, Object?>> oplog({int limit = 100}) =>
      _get('/oplog?limit=$limit');

  /// POST /api/oplog/enable — turn on the op-log (file-backed DBs only).
  Future<Map<String, Object?>> enableOplog() async {
    final http.Response res;
    try {
      res = await _http
          .post(_uri('/oplog/enable'), headers: _headers)
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      throw AdminApiException('Enable op-log failed: $e');
    }
    return _decode(res);
  }

  /// GET /api/oracle — Oracle wire status.
  Future<Map<String, Object?>> oracleStatus() => _get('/oracle');
  /// GET /api/oracle/users — list Oracle users.
  Future<List<String>> oracleUsers() async {
    final json = await _get('/oracle/users');
    final raw = (json['users'] as List?)?.cast<Object?>() ?? const [];
    return raw.map((u) => u?.toString() ?? '').toList();
  }

  /// POST /api/oracle/users — add an Oracle user; returns the updated list.
  Future<List<String>> addOracleUser(
    String username,
    String password, {
    bool pbkdf2 = true,
  }) async {
    final http.Response res;
    try {
      res = await _http
          .post(
            _uri('/oracle/users'),
            headers: _headers,
            body: jsonEncode({
              'username': username,
              'password': password,
              'pbkdf2': pbkdf2,
            }),
          )
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      throw AdminApiException('Add user failed: $e');
    }
    final json = _decode(res);
    final raw = (json['users'] as List?)?.cast<Object?>() ?? const [];
    return raw.map((u) => u?.toString() ?? '').toList();
  }

  /// GET /api/tables — list of table names.
  Future<List<String>> tables() async {
    final json = await _get('/tables');
    final raw = (json['tables'] as List?)?.cast<Object?>() ?? const [];
    return raw.map((t) => t?.toString() ?? '').toList();
  }

  /// GET /api/views — list of view names.
  Future<List<String>> views() async {
    final json = await _get('/views');
    final raw = (json['views'] as List?)?.cast<Object?>() ?? const [];
    return raw.map((t) => t?.toString() ?? '').toList();
  }

  /// GET /api/tables/{name} — column metadata for a table.
  Future<QueryResult> tableColumns(String name) async {
    final json = await _get('/tables/${Uri.encodeComponent(name)}');
    final cols = json['columns'];
    if (cols is Map) {
      return QueryResult.fromJson(cols.cast<String, Object?>());
    }
    return QueryResult(columns: const [], columnTypes: null, rows: const [], affected: 0);
  }

  /// GET /api/vector/indexes — registered vector indexes.
  Future<QueryResult> vectorIndexes() async {
    final json = await _get('/vector/indexes');
    final idx = json['indexes'];
    if (idx is Map) return QueryResult.fromJson(idx.cast<String, Object?>());
    return QueryResult(columns: const [], columnTypes: null, rows: const [], affected: 0);
  }

  /// GET /api/vector/stats — per-binding vector index statistics.
  Future<QueryResult> vectorStats() async {
    final json = await _get('/vector/stats');
    final stats = json['stats'];
    if (stats is Map) return QueryResult.fromJson(stats.cast<String, Object?>());
    return QueryResult(columns: const [], columnTypes: null, rows: const [], affected: 0);
  }

  /// POST /api/query — run one or more SQL statements.
  Future<QueryResponse> query(String sql, {int? maxRows}) async {
    final http.Response res;
    try {
      res = await _http
          .post(
            _uri('/query'),
            headers: _headers,
            body: jsonEncode({
              'sql': sql,
              'maxRows': ?maxRows,
            }),
          )
          .timeout(const Duration(seconds: 60));
    } catch (e) {
      throw AdminApiException('Query failed: $e');
    }
    return QueryResponse.fromJson(_decode(res));
  }

  /// GET /api/routes — self-describing endpoint catalog for the probe UI.
  Future<List<ApiRoute>> routes() async {
    final json = await _get('/routes');
    final raw = (json['routes'] as List?)?.cast<Object?>() ?? const [];
    return raw
        .whereType<Map>()
        .map((m) => ApiRoute.fromJson(m.cast<String, Object?>()))
        .toList();
  }

  /// Sends an arbitrary request to the admin API and returns the raw outcome.
  ///
  /// [path] is the full API path (e.g. `/api/health`); [body] is sent as-is for
  /// non-GET methods. Never throws for HTTP errors — the status is in the result.
  Future<ProbeResult> probe(
    String method,
    String path, {
    String? body,
  }) async {
    final uri = Uri.parse('${connection.origin}$path');
    final request = http.Request(method.toUpperCase(), uri);
    request.headers.addAll(_headers);
    if (body != null && body.isNotEmpty && method.toUpperCase() != 'GET') {
      request.body = body;
    }
    final sw = Stopwatch()..start();
    try {
      final streamed =
          await _http.send(request).timeout(const Duration(seconds: 60));
      final res = await http.Response.fromStream(streamed);
      sw.stop();
      return ProbeResult(
        statusCode: res.statusCode,
        elapsedMs: sw.elapsedMilliseconds,
        body: res.body,
      );
    } catch (e) {
      sw.stop();
      return ProbeResult(
        statusCode: 0,
        elapsedMs: sw.elapsedMilliseconds,
        body: '',
        error: '$e',
      );
    }
  }

  void close() => _http.close();
}

/// A single endpoint descriptor from GET /api/routes.
class ApiRoute {
  ApiRoute({
    required this.method,
    required this.path,
    this.description,
    this.sampleBody,
  });

  final String method;
  final String path;
  final String? description;
  final Object? sampleBody;

  factory ApiRoute.fromJson(Map<String, Object?> json) => ApiRoute(
        method: json['method'] as String? ?? 'GET',
        path: json['path'] as String? ?? '',
        description: json['description'] as String?,
        sampleBody: json['sampleBody'],
      );
}

/// The outcome of a raw [AdminApiClient.probe] call.
class ProbeResult {
  ProbeResult({
    required this.statusCode,
    required this.elapsedMs,
    required this.body,
    this.error,
  });

  final int statusCode;
  final int elapsedMs;
  final String body;
  final String? error;

  bool get ok => error == null && statusCode >= 200 && statusCode < 300;
}
