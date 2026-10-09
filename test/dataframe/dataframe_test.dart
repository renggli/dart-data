import 'package:data/dataframe.dart';
import 'package:test/test.dart';

void main() {
  group('ValidityMask', () {
    test('initializes all valid and sets null bits', () {
      final mask = ValidityMask(16);
      expect(mask.nullCount, 0);
      expect(mask.isValid(0), isTrue);
      expect(mask.isValid(15), isTrue);

      mask.setNull(3);
      mask.setNull(11);
      expect(mask.nullCount, 2);
      expect(mask.isNull(3), isTrue);
      expect(mask.isValid(3), isFalse);
      expect(mask.isNull(11), isTrue);
      expect(mask.isValid(11), isFalse);
      expect(mask.isValid(4), isTrue);

      mask.setValid(3);
      expect(mask.nullCount, 1);
      expect(mask.isValid(3), isTrue);
    });
  });

  group('Series', () {
    test('TypedSeries with nulls and aggregations', () {
      final s = TypedSeries<double>.fromList('temp', [10.0, null, 30.0, 40.0]);
      expect(s.length, 4);
      expect(s.nullCount, 1);
      expect(s[0], 10.0);
      expect(s[1], isNull);
      expect(s[2], 30.0);
      expect(s.sum, 80.0);
      expect(s.mean, closeTo(80.0 / 3, 1e-10));
      expect(s.min, 10.0);
      expect(s.max, 40.0);

      final filtered = s.filter([true, true, false, true]);
      expect(filtered.length, 3);
      expect(filtered.toList(), [10.0, null, 40.0]);

      final sorted = s.sort(ascending: false);
      expect(sorted.toList().first, 40.0);
    });

    test('StringSeries and BoolSeries', () {
      final strCol = StringSeries.fromList('names', [
        'Alice',
        'Bob',
        null,
        'Charlie',
      ]);
      expect(strCol.nullCount, 1);
      expect(strCol[1], 'Bob');
      expect(strCol[2], isNull);

      final boolCol = BoolSeries.fromList('active', [true, false, true, null]);
      expect(boolCol.nullCount, 1);
      expect(boolCol[0], isTrue);
      expect(boolCol[1], isFalse);
    });
  });

  group('DataFrame core operations', () {
    test('creation and column access', () {
      final df = DataFrame.fromColumns({
        'id': [1, 2, 3],
        'name': ['A', 'B', 'C'],
        'score': [90.5, 80.0, 95.0],
      });
      expect(df.rowCount, 3);
      expect(df.columnCount, 3);
      expect(df.columnNames, ['id', 'name', 'score']);
      expect(df['name'][1], 'B');

      final row1 = df.getRow(1);
      expect(row1['id'], 2);
      expect(row1['name'], 'B');
      expect(row1['score'], 80.0);
    });

    test('select, drop, withColumn', () {
      final df = DataFrame.fromColumns({
        'a': [1, 2],
        'b': [3, 4],
        'c': [5, 6],
      });

      final sel = df.select(['a', 'c']);
      expect(sel.columnNames, ['a', 'c']);

      final dropped = df.drop(['b']);
      expect(dropped.columnNames, ['a', 'c']);

      final withNew = df.withColumn(Series.fromList('d', [7, 8]));
      expect(withNew.columnCount, 4);
      expect(withNew['d'][1], 8);
    });

    test('filtering, slicing, sorting', () {
      final df = DataFrame.fromColumns({
        'val': [10, 50, 20, 40, 30],
        'label': ['v1', 'v2', 'v3', 'v4', 'v5'],
      });

      final filtered = df.filterBy((row) => (row['val'] as int) > 25);
      expect(filtered.rowCount, 3);
      expect(filtered['val'].toList(), [50, 40, 30]);

      final sorted = df.sortBy('val', ascending: true);
      expect(sorted['val'].toList(), [10, 20, 30, 40, 50]);

      final head2 = sorted.head(2);
      expect(head2.rowCount, 2);
      expect(head2['val'].toList(), [10, 20]);
    });

    test('conversion to Matrix and Tensor', () {
      final df = DataFrame.fromColumns({
        'x': [1.0, 2.0],
        'y': [3.0, 4.0],
      });

      final mat = df.toMatrix();
      expect(mat.rowCount, 2);
      expect(mat.colCount, 2);
      expect(mat.get(0, 0), 1.0);
      expect(mat.get(0, 1), 3.0);
      expect(mat.get(1, 0), 2.0);
      expect(mat.get(1, 1), 4.0);

      final ten = df.toTensor();
      expect(ten.shape, [2, 2]);
    });
  });

  group('GroupBy and Aggregations', () {
    test('single and multi-column group-by', () {
      final df = DataFrame.fromColumns({
        'dept': ['IT', 'HR', 'IT', 'HR', 'IT'],
        'salary': [100.0, 80.0, 120.0, 90.0, 110.0],
      });

      final grouped = df.groupBy(['dept']);
      final summary = grouped.aggregate({
        'salary': [Agg.count, Agg.mean, Agg.sum, Agg.min, Agg.max],
      });

      expect(summary.rowCount, 2);
      expect(summary.columnNames, [
        'dept',
        'salary_count',
        'salary_mean',
        'salary_sum',
        'salary_min',
        'salary_max',
      ]);

      for (var r = 0; r < summary.rowCount; r++) {
        if (summary['dept'][r] == 'IT') {
          expect(summary['salary_count'][r], 3);
          expect(summary['salary_sum'][r], 330.0);
          expect(summary['salary_mean'][r], 110.0);
          expect(summary['salary_min'][r], 100.0);
          expect(summary['salary_max'][r], 120.0);
        } else if (summary['dept'][r] == 'HR') {
          expect(summary['salary_count'][r], 2);
          expect(summary['salary_sum'][r], 170.0);
          expect(summary['salary_mean'][r], 85.0);
        }
      }
    });
  });

  group('Relational Joins', () {
    test('inner, left, right, outer hash joins', () {
      final left = DataFrame.fromColumns({
        'id': [1, 2, 3],
        'name': ['Alice', 'Bob', 'Charlie'],
      });

      final right = DataFrame.fromColumns({
        'id': [2, 3, 4],
        'age': [25, 30, 35],
      });

      // Inner join
      final inner = left.join(right, on: ['id'], type: JoinType.inner);
      expect(inner.rowCount, 2);
      expect(inner['id'].toList(), [2, 3]);
      expect(inner['name'].toList(), ['Bob', 'Charlie']);
      expect(inner['age'].toList(), [25, 30]);

      // Left join
      final leftJoined = left.join(right, on: ['id'], type: JoinType.left);
      expect(leftJoined.rowCount, 3);
      expect(leftJoined['id'].toList(), [1, 2, 3]);
      expect(leftJoined['age'].toList(), [null, 25, 30]);

      // Right join
      final rightJoined = left.join(right, on: ['id'], type: JoinType.right);
      expect(rightJoined.rowCount, 3);
      expect(rightJoined['id'].toList(), [2, 3, 4]);
      expect(rightJoined['name'].toList(), ['Bob', 'Charlie', null]);

      // Outer join
      final outerJoined = left.join(right, on: ['id'], type: JoinType.outer);
      expect(outerJoined.rowCount, 4);
    });
  });

  group('CSV IO', () {
    test('streaming parse and serialization roundtrip', () {
      const csv = '''
name,age,salary,active
Alice,30,75000.5,true
Bob,25,50000.0,false
Charlie,,60000.0,true
''';

      final df = DataFrame.fromCsv(csv);
      expect(df.rowCount, 3);
      expect(df.columnCount, 4);
      expect(df.columnNames, ['name', 'age', 'salary', 'active']);

      // Type inference
      expect(df['age'].dataType.name, 'int32');
      expect(df['salary'].dataType.name, 'float64');
      expect(df['active'].dataType.name, 'boolean');
      expect(df['name'].dataType.name, 'string');

      // Null handling
      expect(df['age'][2], isNull);
      expect(df['salary'][2], 60000.0);

      // Serialization
      final exportedCsv = df.toCsv();
      final df2 = DataFrame.fromCsv(exportedCsv);
      expect(df2.rowCount, 3);
      expect(df2['name'].toList(), ['Alice', 'Bob', 'Charlie']);
      expect(df2['salary'].toList(), [75000.5, 50000.0, 60000.0]);
    });

    test('multiline CSV with embedded newlines and escaped quotes', () {
      const csv = '''
id,desc,val
1,"line 1
line 2",10
2,"say ""hello""",20
''';
      final df = DataFrame.fromCsv(csv);
      expect(df.rowCount, 2);
      expect(df['desc'][0], 'line 1\nline 2');
      expect(df['desc'][1], 'say "hello"');
      expect(df['val'].toList(), [10, 20]);
    });

    test('join does not match null keys', () {
      final left = DataFrame.fromColumns({
        'id': [1, null, 3],
        'v1': ['a', 'b', 'c'],
      });
      final right = DataFrame.fromColumns({
        'id': [1, null, 4],
        'v2': ['x', 'y', 'z'],
      });
      final inner = left.join(right, on: ['id'], type: JoinType.inner);
      expect(inner.rowCount, 1);
      expect(inner['id'].toList(), [1]);
    });

    test('sortBy boolean column', () {
      final df = DataFrame.fromColumns({
        'name': ['A', 'B', 'C'],
        'flag': [true, false, true],
      });
      final sorted = df.sortBy('flag', ascending: true);
      expect(sorted['flag'].toList(), [false, true, true]);
    });

    test('TypedSeries empty list creation without error', () {
      final s = TypedSeries<double>.fromList('empty', []);
      expect(s.length, 0);
      expect(s.dataType.name, 'float64');
    });
  });
}
