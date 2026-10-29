import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/connection.dart';
import '../models/query_result.dart';
import '../services/admin_api_client.dart';
import '../services/oracle_client.dart';

/// One open connection: its endpoint, live client(s), and last-loaded info.
class ConnectionSession {
  ConnectionSession({
    required this.id,
    required this.connection,
    this.httpClient,
    this.oracleClient,
    this.info = const {},
  });

  final String id;
  final ServerConnection connection;
  final AdminApiClient? httpClient;
  final OracleClient? oracleClient;
  Map<String, Object?> info;

  bool get isOracle => oracleClient != null;

  Future<void> close() async {
    httpClient?.close();
    await oracleClient?.close();
  }
}

/// App-wide connection state: saved endpoints plus any number of open sessions,
/// one of which is active (drives the screens).
class AppState extends ChangeNotifier {
  static const _prefsKey = 'dart_db_admin.connections';
  static const _themeKey = 'dart_db_admin.themeMode';

  final List<ServerConnection> _connections = [];
  List<ServerConnection> get connections => List.unmodifiable(_connections);

  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  final List<ConnectionSession> _sessions = [];
  List<ConnectionSession> get sessions => List.unmodifiable(_sessions);

  String? _activeId;
  String? get activeSessionId => _activeId;

  ConnectionSession? get activeSession {
    for (final s in _sessions) {
      if (s.id == _activeId) return s;
    }
    return null;
  }

  ServerConnection? get active => activeSession?.connection;
  AdminApiClient? get client => activeSession?.httpClient;
  Map<String, Object?> get info => activeSession?.info ?? const {};
  bool get isConnected => activeSession != null;
  bool get isOracleActive => activeSession?.isOracle ?? false;

  /// Runs SQL against the active session, whichever transport it uses.
  Future<QueryResponse?> runQuery(String sql, {int? maxRows}) {
    final s = activeSession;
    if (s == null) return Future.value(null);
    if (s.oracleClient != null) {
      return s.oracleClient!.query(sql, maxRows: maxRows);
    }
    return s.httpClient!.query(sql, maxRows: maxRows);
  }

  bool _connecting = false;
  bool get connecting => _connecting;

  String? _lastError;
  String? get lastError => _lastError;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw != null) {
      _connections
        ..clear()
        ..addAll(ServerConnection.decodeList(raw));
    }
    final theme = prefs.getString(_themeKey);
    _themeMode = ThemeMode.values.asNameMap()[theme] ?? ThemeMode.system;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, mode.name);
  }

  /// Cycles system → light → dark → system.
  void cycleTheme() {
    const order = [ThemeMode.system, ThemeMode.light, ThemeMode.dark];
    setThemeMode(order[(order.indexOf(_themeMode) + 1) % order.length]);
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, ServerConnection.encodeList(_connections));
  }

  Future<void> saveConnection(ServerConnection conn) async {
    final idx = _connections.indexWhere((c) => c.name == conn.name);
    if (idx >= 0) {
      _connections[idx] = conn;
    } else {
      _connections.add(conn);
    }
    await _persist();
    notifyListeners();
  }

  Future<void> removeConnection(ServerConnection conn) async {
    _connections.removeWhere((c) => c.name == conn.name);
    for (final s
        in _sessions.where((s) => s.connection.name == conn.name).toList()) {
      closeSession(s.id);
    }
    await _persist();
    notifyListeners();
  }

  bool isOpen(ServerConnection conn) =>
      _sessions.any((s) => s.connection.name == conn.name);

  /// Open a session for [conn] (or focus the existing one), probing /health.
  Future<bool> connect(ServerConnection conn) async {
    for (final s in _sessions) {
      if (s.connection.name == conn.name) {
        _activeId = s.id;
        notifyListeners();
        return true;
      }
    }

    _connecting = true;
    _lastError = null;
    notifyListeners();

    final sessionId = '${conn.name}@${DateTime.now().microsecondsSinceEpoch}';
    try {
      final ConnectionSession session;
      if (conn.isOracle) {
        final oracle = await OracleClient.connect(conn);
        session = ConnectionSession(
          id: sessionId,
          connection: conn,
          oracleClient: oracle,
          info: {
            'kind': 'oracleWire',
            'connectString': conn.oracleConnectString,
            'user': conn.user,
          },
        );
      } else {
        final client = AdminApiClient(conn);
        final ok = await client.health();
        if (!ok) {
          client.close();
          throw AdminApiException('Server health check returned not-ok');
        }
        final info = await client.info();
        session = ConnectionSession(
          id: sessionId,
          connection: conn,
          httpClient: client,
          info: info,
        );
      }
      _sessions.add(session);
      _activeId = session.id;
      _connecting = false;
      notifyListeners();
      return true;
    } catch (e) {
      _lastError = e is AdminApiException ? e.message : e.toString();
      _connecting = false;
      notifyListeners();
      return false;
    }
  }

  void setActiveSession(String id) {
    if (_sessions.any((s) => s.id == id)) {
      _activeId = id;
      notifyListeners();
    }
  }

  void closeSession(String id) {
    final idx = _sessions.indexWhere((s) => s.id == id);
    if (idx < 0) return;
    _sessions[idx].close();
    _sessions.removeAt(idx);
    if (_activeId == id) {
      _activeId = _sessions.isEmpty
          ? null
          : _sessions[idx < _sessions.length ? idx : _sessions.length - 1].id;
    }
    notifyListeners();
  }

  /// Closes the active session.
  void disconnect() {
    final id = _activeId;
    if (id != null) closeSession(id);
  }

  @override
  void dispose() {
    for (final s in _sessions) {
      s.close();
    }
    super.dispose();
  }
}
