import 'package:dart_db_admin/models/query_result.dart';
import 'package:dart_db_admin/services/sql_tools.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isDestructiveSql', () {
    test('flags DROP/DELETE/TRUNCATE/ALTER/UPDATE', () {
      expect(isDestructiveSql('DROP TABLE t'), isTrue);
      expect(isDestructiveSql('delete from t where id = 1'), isTrue);
      expect(isDestructiveSql('TRUNCATE TABLE t'), isTrue);
      expect(isDestructiveSql('ALTER TABLE t ADD c INT'), isTrue);
      expect(isDestructiveSql('update t set x = 1'), isTrue);
    });

    test('allows read-only statements', () {
      expect(isDestructiveSql('SELECT * FROM t'), isFalse);
      expect(isDestructiveSql('INSERT INTO t VALUES (1)'), isFalse);
      expect(isDestructiveSql('CREATE TABLE t(id INT)'), isFalse);
    });

    test('ignores keywords inside comments', () {
      expect(isDestructiveSql('SELECT 1 -- drop table t'), isFalse);
    });

    test('does not match substrings of identifiers', () {
      expect(isDestructiveSql('SELECT updated_at FROM t'), isFalse);
    });
  });

  group('resultToCsv', () {
    test('emits header + rows with quoting', () {
      final r = QueryResult(
        columns: ['id', 'name'],
        columnTypes: null,
        rows: [
          [1, 'Ann'],
          [2, 'a,b'],
          [3, 'he said "hi"'],
        ],
        affected: 3,
      );
      final csv = resultToCsv(r);
      final lines = csv.trim().split('\n');
      expect(lines[0], 'id,name');
      expect(lines[1], '1,Ann');
      expect(lines[2], '2,"a,b"');
      expect(lines[3], '3,"he said ""hi"""');
    });

    test('null cells become empty', () {
      final r = QueryResult(
        columns: ['a', 'b'],
        columnTypes: null,
        rows: [
          [null, 1],
        ],
        affected: 1,
      );
      expect(resultToCsv(r).trim().split('\n')[1], ',1');
    });
  });

  group('resultToJson', () {
    test('emits array of row objects keyed by column', () {
      final r = QueryResult(
        columns: ['id', 'name'],
        columnTypes: null,
        rows: [
          [1, 'Ann'],
        ],
        affected: 1,
      );
      final json = resultToJson(r);
      expect(json, contains('"id": 1'));
      expect(json, contains('"name": "Ann"'));
    });
  });
}
