import 'package:data/dataframe.dart';
import 'package:data/type.dart';
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

      final fromBytes = ValidityMask.fromBytes(16, mask.bytes);
      expect(fromBytes.nullCount, 1);
      expect(fromBytes.isValid(3), isTrue);
      expect(fromBytes.isNull(11), isTrue);

      expect(() => mask.isNull(-1), throwsRangeError);
      expect(() => mask.isNull(20), throwsRangeError);
      expect(() => mask.setNull(-1), throwsRangeError);
      expect(() => mask.setNull(20), throwsRangeError);
      expect(() => mask.setValid(-1), throwsRangeError);
      expect(() => mask.setValid(20), throwsRangeError);
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
      expect(() => s.filter([true]), throwsArgumentError);

      final sliced = s.slice(-1, 3);
      expect(sliced.length, 3);

      final sorted = s.sort(ascending: false);
      expect(sorted.toList().first, 40.0);
      final sortedAsc = s.sort(ascending: true);
      expect(sortedAsc.toList().first, 10.0);

      final renamed = s.rename('temperature');
      expect(renamed.name, 'temperature');
      expect(s.toString(), contains('Series<double>'));

      // All null series
      final allNull = TypedSeries<double>.fromList('all_null', [null, null]);
      expect(allNull.min, isNull);
      expect(allNull.max, isNull);
      expect(allNull.sum, isNull);
      expect(allNull.mean, isNull);
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
      expect(strCol.min, 'Alice');
      expect(strCol.max, 'Charlie');
      expect(strCol.sum, isNull);
      expect(strCol.mean, isNull);

      final strFiltered = strCol.filter([true, false, true, false]);
      expect(strFiltered.length, 2);
      final strSliced = strCol.slice(1, 3);
      expect(strSliced.length, 2);
      final strSorted = strCol.sort(ascending: true);
      expect(strSorted[0], 'Alice');
      final strRenamed = strCol.rename('full_names');
      expect(strRenamed.name, 'full_names');

      final boolCol = BoolSeries.fromList('active', [true, false, true, null]);
      expect(boolCol.nullCount, 1);
      expect(boolCol[0], isTrue);
      expect(boolCol[1], isFalse);
      expect(boolCol.min, isNull);
      expect(boolCol.max, isNull);
      expect(boolCol.sum, 2);
      expect(boolCol.mean, closeTo(2.0 / 3.0, 1e-4));

      final boolFiltered = boolCol.filter([true, false, true, false]);
      expect(boolFiltered.length, 2);
      final boolSliced = boolCol.slice(0, 2);
      expect(boolSliced.length, 2);
      final boolSorted = boolCol.sort(ascending: true);
      expect(boolSorted[0], isFalse);
      final boolRenamed = boolCol.rename('is_active');
      expect(boolRenamed.name, 'is_active');
    });

    test('ObjectSeries and Series.fromList factory', () {
      final objSeries = Series<DateTime?>.fromList('items', [
        DateTime(2025, 1, 1),
        null,
        DateTime(2025, 1, 3),
      ]);
      expect(objSeries.length, 3);
      expect(objSeries.nullCount, 1);
      expect(objSeries.min, isNull);
      expect(objSeries.max, isNull);
      expect(objSeries.sum, isNull);
      expect(objSeries.mean, isNull);

      final objFiltered = objSeries.filter([true, false, true]);
      expect(objFiltered.length, 2);
      final objSliced = objSeries.slice(0, 2);
      expect(objSliced.length, 2);
      final objRenamed = objSeries.rename('dates');
      expect(objRenamed.name, 'dates');

      // Explicit type factory
      final numSeries = Series<num>.fromList('num_col', [
        1,
        2,
        3,
      ], type: DataType.int32);
      expect(numSeries, isA<TypedSeries<num>>());
      final sSeries = Series.fromList('str_col', [
        'a',
        'b',
      ], type: DataType.string);
      expect(sSeries, isA<StringSeries>());
      final bSeries = Series.fromList('b_col', [
        true,
        false,
      ], type: DataType.boolean);
      expect(bSeries, isA<BoolSeries>());
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

      // Access helpers
      expect(df.typedColumn<num>('id')[0], 1);
      expect(df.rows.length, 3);
      expect(() => df.column('nonexistent'), throwsArgumentError);
      expect(() => df.getRow(-1), throwsRangeError);
      expect(() => df.getRow(10), throwsRangeError);

      // Empty fromRows
      final emptyDf = DataFrame.fromRows([]);
      expect(emptyDf.rowCount, 0);
      expect(emptyDf.columnCount, 0);

      // Constructor column length mismatch
      expect(
        () => DataFrame([
          Series.fromList('a', [1, 2]),
          Series.fromList('b', [1]),
        ]),
        throwsArgumentError,
      );
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

      // Replace existing column
      final replaced = df.withColumn(Series.fromList('a', [10, 20]));
      expect(replaced.columnCount, 3);
      expect(replaced['a'][0], 10);
    });

    test('filtering, slicing, sorting, and toString', () {
      final df = DataFrame.fromColumns({
        'val': [10, 50, 20, 40, 30, 60],
        'label': ['v1', 'v2', 'v3', 'v4', 'v5', 'v6'],
      });

      final filtered = df.filterBy((row) => (row['val'] as int) > 25);
      expect(filtered.rowCount, 4);
      expect(filtered['val'].toList(), [50, 40, 30, 60]);
      expect(() => df.filter([true]), throwsArgumentError);

      final sorted = df.sortBy('val', ascending: true);
      expect(sorted['val'].toList(), [10, 20, 30, 40, 50, 60]);
      final sortedDesc = df.sortBy('val', ascending: false);
      expect(sortedDesc['val'].toList().first, 60);

      final head2 = sorted.head(2);
      expect(head2.rowCount, 2);
      expect(head2['val'].toList(), [10, 20]);

      final tail2 = sorted.tail(2);
      expect(tail2.rowCount, 2);
      expect(tail2['val'].toList(), [50, 60]);

      // toString with > 5 rows
      final repr = df.toString();
      expect(repr, contains('DataFrame(6 rows x 2 columns)'));
      expect(repr, contains('... and 1 more rows'));
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

      final ten = df.toTensor(columns: ['x']);
      expect(ten.shape, [2, 1]);
    });
  });

  group('GroupBy and Aggregations', () {
    test('single and multi-column group-by', () {
      final df = DataFrame.fromColumns({
        'dept': ['IT', 'HR', 'IT', 'HR', 'IT'],
        'salary': [100.0, 80.0, 120.0, 90.0, 110.0],
      });

      expect(() => df.groupBy([]), throwsArgumentError);

      final grouped = df.groupBy(['dept']);
      final summary = grouped.aggregate({
        'salary': [
          Agg.count,
          Agg.mean,
          Agg.sum,
          Agg.min,
          Agg.max,
          Agg.std,
          Agg.first,
          Agg.last,
        ],
      });

      expect(summary.rowCount, 2);
      expect(summary.columnNames, [
        'dept',
        'salary_count',
        'salary_mean',
        'salary_sum',
        'salary_min',
        'salary_max',
        'salary_std',
        'salary_first',
        'salary_last',
      ]);

      for (var r = 0; r < summary.rowCount; r++) {
        if (summary['dept'][r] == 'IT') {
          expect(summary['salary_count'][r], 3);
          expect(summary['salary_sum'][r], 330.0);
          expect(summary['salary_mean'][r], 110.0);
          expect(summary['salary_min'][r], 100.0);
          expect(summary['salary_max'][r], 120.0);
          expect(summary['salary_first'][r], 100.0);
          expect(summary['salary_last'][r], 110.0);
        } else if (summary['dept'][r] == 'HR') {
          expect(summary['salary_count'][r], 2);
          expect(summary['salary_sum'][r], 170.0);
          expect(summary['salary_mean'][r], 85.0);
        }
      }

      // Convenience methods
      final meanDf = grouped.mean();
      expect(meanDf.columnNames, ['dept', 'salary_mean']);

      final sumDf = grouped.sum();
      expect(sumDf.columnNames, ['dept', 'salary_sum']);

      final countDf = grouped.count();
      expect(countDf.rowCount, 2);
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

    test('DataFrame.fromRows, CSV edge cases, Joins, and Series sorting', () {
      // 1. DataFrame.fromRows
      final dfRows = DataFrame.fromRows([
        {'id': 1, 'name': 'Alice'},
        {'id': 2, 'name': 'Bob'},
      ]);
      expect(dfRows.rowCount, 2);
      expect(dfRows['name'].toList(), ['Alice', 'Bob']);
      expect(DataFrame.fromRows([]).rowCount, 0);

      // 2. sortBy on non-Comparable objects
      final dfCustom = DataFrame.fromColumns({
        'obj': [Object(), Object()],
      });
      final sortedCustom = dfCustom.sortBy('obj');
      expect(sortedCustom.rowCount, 2);

      // 3. CSV header: false, CRLF, only nulls column, and escaping
      const noHeaderCsv = '10,foo\r\n20,bar';
      final dfNoHeader = CsvReader.parse(noHeaderCsv, header: false);
      expect(dfNoHeader.columnNames, ['col_0', 'col_1']);
      expect(dfNoHeader.rowCount, 2);

      const nullColCsv = 'a,b\n1,\n2,null\n';
      final dfNullCol = CsvReader.parse(nullColCsv);
      expect(dfNullCol['b'].nullCount, 2);

      final dfEscaped = DataFrame.fromColumns({
        'text': ['hello, world', 'quote "test"', 'line1\nline2'],
      });
      final csvOut = CsvWriter.write(dfEscaped);
      expect(csvOut, contains('"hello, world"'));
      expect(csvOut, contains('"quote ""test"""'));

      // 4. Join column errors & left join with null key
      final dfA = DataFrame.fromColumns({
        'k': [1, null],
      });
      final dfB = DataFrame.fromColumns({
        'k': [1],
      });
      expect(() => dfA.join(dfB, on: ['missing']), throwsArgumentError);
      expect(() => dfA.join(dfB, on: ['k'], suffix: '_b'), returnsNormally);
      final dfBNoK = DataFrame.fromColumns({
        'other': [1],
      });
      expect(() => dfA.join(dfBNoK, on: ['k']), throwsArgumentError);

      final leftWithNull = dfA.join(dfB, on: ['k'], type: JoinType.left);
      expect(leftWithNull.rowCount, 2);
      expect(leftWithNull['k'][1], isNull);

      // 5. StringSeries, BoolSeries, and ObjectSeries descending / custom sorts
      final strSeries = Series<String?>.fromList('s', [
        'banana',
        'apple',
        null,
      ]);
      final strDesc = strSeries.sort(ascending: false);
      expect(strDesc[0], 'banana');
      expect(strDesc[1], 'apple');
      expect(strDesc[2], isNull);

      final boolSeries = Series<bool?>.fromList('b', [false, true, null]);
      final boolDesc = boolSeries.sort(ascending: false);
      expect(boolDesc[0], true);
      expect(boolDesc[1], false);

      final objSeries = ObjectSeries<int>.fromList('obj', [
        30,
        10,
        null,
        20,
      ], type: DataType.int32);
      final objAsc = objSeries.sort(ascending: true);
      expect(objAsc.toList(), [10, 20, 30, null]);
      final objDesc = objSeries.sort(ascending: false);
      expect(objDesc.toList(), [30, 20, 10, null]);
    });
  });
}
