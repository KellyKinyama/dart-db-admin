import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Persists recent SQL per connection name (most-recent first, capped).
class QueryHistoryStore {
  QueryHistoryStore({this.max = 50});

  final int max;

  String _key(String connection) => 'dart_db_admin.history.$connection';

  Future<List<String>> load(String connection) async {
    final prefs = await SharedPreferences.getInstance();
    return decode(prefs.getString(_key(connection)));
  }

  /// Prepends [sql] (de-duplicated), caps the list, persists, and returns it.
  Future<List<String>> add(String connection, String sql) async {
    final prefs = await SharedPreferences.getInstance();
    final list = decode(prefs.getString(_key(connection)))
      ..remove(sql)
      ..insert(0, sql);
    if (list.length > max) list.removeRange(max, list.length);
    await prefs.setString(_key(connection), jsonEncode(list));
    return list;
  }

  Future<void> clear(String connection) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(connection));
  }

  /// Parses a stored JSON string list; tolerant of null/garbage.
  static List<String> decode(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      final data = jsonDecode(raw);
      if (data is List) return data.map((e) => '$e').toList();
    } catch (_) {}
    return [];
  }
}
