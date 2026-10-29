/// Result of a single SQL statement returned by the admin API.
class QueryResult {
  QueryResult({
    required this.columns,
    required this.columnTypes,
    required this.rows,
    required this.affected,
    this.message,
    this.error,
    this.truncated = false,
    this.totalRows,
  });

  final List<String> columns;
  final List<String>? columnTypes;
  final List<List<Object?>> rows;
  final int affected;
  final String? message;
  final String? error;

  /// True when the server capped the returned rows (see [totalRows]).
  final bool truncated;
  final int? totalRows;

  bool get isError => error != null;

  factory QueryResult.fromJson(Map<String, Object?> json) {
    final cols = (json['columns'] as List?)?.cast<Object?>() ?? const [];
    final rawRows = (json['rows'] as List?)?.cast<Object?>() ?? const [];
    final types = (json['columnTypes'] as List?)?.cast<Object?>();
    return QueryResult(
      columns: cols.map((c) => c?.toString() ?? '').toList(),
      columnTypes: types?.map((t) => t?.toString() ?? '').toList(),
      rows: rawRows
          .map((r) => (r as List?)?.cast<Object?>().toList() ?? <Object?>[])
          .toList(),
      affected: (json['affected'] as num?)?.toInt() ?? 0,
      message: json['message'] as String?,
      error: json['error'] as String?,
      truncated: json['truncated'] == true,
      totalRows: (json['totalRows'] as num?)?.toInt(),
    );
  }
}

/// The full response of POST /api/query (one or more statements).
class QueryResponse {
  QueryResponse({
    required this.elapsedMs,
    required this.results,
    this.error,
  });

  final int elapsedMs;
  final List<QueryResult> results;
  final String? error;

  bool get isError => error != null;

  factory QueryResponse.fromJson(Map<String, Object?> json) {
    final raw = (json['results'] as List?)?.cast<Object?>() ?? const [];
    return QueryResponse(
      elapsedMs: (json['elapsedMs'] as num?)?.toInt() ?? 0,
      results: raw
          .map((r) => QueryResult.fromJson((r as Map).cast<String, Object?>()))
          .toList(),
      error: json['error'] as String?,
    );
  }
}
