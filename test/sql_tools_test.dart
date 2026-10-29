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

  group('vector helpers', () {
    test('isIdentifier', () {
      expect(isIdentifier('docs'), isTrue);
      expect(isIdentifier('_x1'), isTrue);
      expect(isIdentifier('1bad'), isFalse);
      expect(isIdentifier("a';DROP"), isFalse);
    });

    test('isVectorLiteral', () {
      expect(isVectorLiteral('[0.1, 0.4]'), isTrue);
      expect(isVectorLiteral('[-1, 2, 3.5]'), isTrue);
      expect(isVectorLiteral('[]'), isFalse);
      expect(isVectorLiteral('[a, b]'), isFalse);
      expect(isVectorLiteral('0.1, 0.4'), isFalse);
    });

    test('buildVecSearchSql builds a valid query', () {
      final sql = buildVecSearchSql(
          table: 'docs', column: 'embedding', vector: '[0.1, 0.4]', k: 5);
      expect(
        sql,
        "SELECT rowid, distance FROM vec_search('docs', 'embedding', "
        "VEC('[0.1, 0.4]'), 5) ORDER BY distance",
      );
    });

    test('buildVecSearchSql rejects bad input', () {
      expect(
        () => buildVecSearchSql(
            table: '1bad', column: 'e', vector: '[1]', k: 1),
        throwsArgumentError,
      );
      expect(
        () => buildVecSearchSql(
            table: 't', column: 'c', vector: 'nope', k: 1),
        throwsArgumentError,
      );
      expect(
        () => buildVecSearchSql(
            table: 't', column: 'c', vector: '[1]', k: 0),
        throwsArgumentError,
      );
    });
  });

  group('buildVectorQuery modes', () {
    test('knn', () {
      expect(
        buildVectorQuery(
            mode: VecSearchMode.knn,
            table: 'docs',
            column: 'e',
            vector: '[1,0]',
            k: 3),
        "SELECT rowid, distance FROM vec_search('docs', 'e', VEC('[1,0]'), 3) "
        'ORDER BY distance',
      );
    });

    test('filtered embeds filter JSON and escapes quotes', () {
      final sql = buildVectorQuery(
        mode: VecSearchMode.filtered,
        table: 'docs',
        column: 'e',
        vector: '[1,0]',
        k: 5,
        filterJson: '{"tenant": 2}',
      );
      expect(sql, contains('vec_search_filtered('));
      expect(sql, contains('\'{"tenant": 2}\''));
    });

    test('filtered requires filter JSON', () {
      expect(
        () => buildVectorQuery(
            mode: VecSearchMode.filtered,
            table: 'd',
            column: 'e',
            vector: '[1]'),
        throwsArgumentError,
      );
    });

    test('range uses radius', () {
      final sql = buildVectorQuery(
        mode: VecSearchMode.range,
        table: 'docs',
        column: 'e',
        vector: '[1,0]',
        radius: 2.5,
      );
      expect(sql,
          "SELECT rowid, distance FROM vec_range_search('docs', 'e', VEC('[1,0]'), 2.5) ORDER BY distance");
    });

    test('hybrid needs text column + query, escapes quotes', () {
      final sql = buildVectorQuery(
        mode: VecSearchMode.hybrid,
        table: 'docs',
        column: 'e',
        vector: '[1,0]',
        k: 3,
        textColumn: 'body',
        queryText: "o'brien",
      );
      expect(sql, contains('vec_hybrid_search('));
      expect(sql, contains("'o''brien'"));
      expect(sql, contains('rrf_score'));
    });

    test('hybrid rejects missing text column', () {
      expect(
        () => buildVectorQuery(
            mode: VecSearchMode.hybrid,
            table: 'd',
            column: 'e',
            vector: '[1]',
            queryText: 'q'),
        throwsArgumentError,
      );
    });
  });
}
