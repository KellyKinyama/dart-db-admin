import 'dart:convert';

/// Transport a saved connection uses.
enum ConnectionKind { adminHttp, oracleWire }

/// A saved connection — either the HTTP admin API or the Oracle wire protocol.
class ServerConnection {
  const ServerConnection({
    required this.name,
    required this.host,
    required this.port,
    this.kind = ConnectionKind.adminHttp,
    this.token,
    this.useTls = false,
    this.service,
    this.user,
    this.password,
  });

  final String name;
  final String host;
  final int port;
  final ConnectionKind kind;

  // Admin HTTP.
  final String? token;
  final bool useTls;

  // Oracle wire.
  final String? service;
  final String? user;
  final String? password;

  bool get isOracle => kind == ConnectionKind.oracleWire;

  String get baseUrl => '${useTls ? 'https' : 'http'}://$host:$port/api';

  String get origin => '${useTls ? 'https' : 'http'}://$host:$port';

  String get wsUrl => '${useTls ? 'wss' : 'ws'}://$host:$port/api/events';

  /// EZConnect descriptor for the Oracle wire driver (`host:port/service`).
  String get oracleConnectString => service == null || service!.isEmpty
      ? '$host:$port'
      : '$host:$port/$service';

  String get endpointLabel => isOracle ? oracleConnectString : baseUrl;

  ServerConnection copyWith({
    String? name,
    String? host,
    int? port,
    ConnectionKind? kind,
    String? token,
    bool? useTls,
    String? service,
    String? user,
    String? password,
  }) {
    return ServerConnection(
      name: name ?? this.name,
      host: host ?? this.host,
      port: port ?? this.port,
      kind: kind ?? this.kind,
      token: token ?? this.token,
      useTls: useTls ?? this.useTls,
      service: service ?? this.service,
      user: user ?? this.user,
      password: password ?? this.password,
    );
  }

  /// Serialized form. The Oracle [password] is deliberately NOT persisted.
  Map<String, Object?> toJson() => {
        'name': name,
        'host': host,
        'port': port,
        'kind': kind.name,
        'token': token,
        'useTls': useTls,
        'service': service,
        'user': user,
      };

  factory ServerConnection.fromJson(Map<String, Object?> json) {
    return ServerConnection(
      name: json['name'] as String? ?? 'unnamed',
      host: json['host'] as String? ?? '127.0.0.1',
      port: (json['port'] as num?)?.toInt() ?? 8088,
      kind: ConnectionKind.values.asNameMap()[json['kind'] as String? ?? ''] ??
          ConnectionKind.adminHttp,
      token: json['token'] as String?,
      useTls: json['useTls'] as bool? ?? false,
      service: json['service'] as String?,
      user: json['user'] as String?,
    );
  }

  static String encodeList(List<ServerConnection> list) =>
      jsonEncode(list.map((c) => c.toJson()).toList());

  static List<ServerConnection> decodeList(String raw) {
    final Object? data;
    try {
      data = jsonDecode(raw);
    } catch (_) {
      return const [];
    }
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((m) => ServerConnection.fromJson(m.cast<String, Object?>()))
        .toList();
  }
}
