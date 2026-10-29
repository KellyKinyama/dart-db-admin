import 'dart:convert';

/// A saved connection to a dart-db-server admin API endpoint.
class ServerConnection {
  const ServerConnection({
    required this.name,
    required this.host,
    required this.port,
    this.token,
    this.useTls = false,
  });

  final String name;
  final String host;
  final int port;
  final String? token;
  final bool useTls;

  String get baseUrl => '${useTls ? 'https' : 'http'}://$host:$port/api';

  String get origin => '${useTls ? 'https' : 'http'}://$host:$port';

  String get wsUrl => '${useTls ? 'wss' : 'ws'}://$host:$port/api/events';

  ServerConnection copyWith({
    String? name,
    String? host,
    int? port,
    String? token,
    bool? useTls,
  }) {
    return ServerConnection(
      name: name ?? this.name,
      host: host ?? this.host,
      port: port ?? this.port,
      token: token ?? this.token,
      useTls: useTls ?? this.useTls,
    );
  }

  Map<String, Object?> toJson() => {
        'name': name,
        'host': host,
        'port': port,
        'token': token,
        'useTls': useTls,
      };

  factory ServerConnection.fromJson(Map<String, Object?> json) {
    return ServerConnection(
      name: json['name'] as String? ?? 'unnamed',
      host: json['host'] as String? ?? '127.0.0.1',
      port: (json['port'] as num?)?.toInt() ?? 8088,
      token: json['token'] as String?,
      useTls: json['useTls'] as bool? ?? false,
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
