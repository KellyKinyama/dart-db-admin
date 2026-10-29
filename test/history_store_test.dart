import 'package:dart_db_admin/services/history_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('QueryHistoryStore.decode', () {
    test('parses a JSON string list', () {
      expect(QueryHistoryStore.decode('["a","b"]'), ['a', 'b']);
    });
    test('tolerates null and garbage', () {
      expect(QueryHistoryStore.decode(null), isEmpty);
      expect(QueryHistoryStore.decode(''), isEmpty);
      expect(QueryHistoryStore.decode('not json'), isEmpty);
      expect(QueryHistoryStore.decode('{"a":1}'), isEmpty);
    });
  });

  group('QueryHistoryStore persistence', () {
    test('add prepends, de-duplicates, and caps', () async {
      final store = QueryHistoryStore(max: 3);
      await store.add('local', 'SELECT 1');
      await store.add('local', 'SELECT 2');
      var list = await store.add('local', 'SELECT 1'); // move to front
      expect(list, ['SELECT 1', 'SELECT 2']);

      await store.add('local', 'SELECT 3');
      list = await store.add('local', 'SELECT 4'); // over cap of 3
      expect(list.length, 3);
      expect(list.first, 'SELECT 4');
      expect(list.contains('SELECT 2'), isFalse);
    });

    test('history is isolated per connection', () async {
      final store = QueryHistoryStore();
      await store.add('a', 'SELECT 1');
      await store.add('b', 'SELECT 2');
      expect(await store.load('a'), ['SELECT 1']);
      expect(await store.load('b'), ['SELECT 2']);
    });

    test('clear removes a connection history', () async {
      final store = QueryHistoryStore();
      await store.add('a', 'SELECT 1');
      await store.clear('a');
      expect(await store.load('a'), isEmpty);
    });
  });
}
