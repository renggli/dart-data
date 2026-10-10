import 'package:checks/checks.dart';
import 'package:data/dataframe.dart';
import 'package:data/type.dart';
import 'package:test/test.dart';

void main() {
  group('ValidityMask', () {
    test('initializes all valid and sets null bits', () {
      final mask = ValidityMask(16);
      check(mask.nullCount).equals(0);
      check(mask.isValid(0)).isTrue();
      check(mask.isValid(15)).isTrue();

      mask.setNull(3);
      mask.setNull(11);
      check(mask.nullCount).equals(2);
      check(mask.isNull(3)).isTrue();
      check(mask.isValid(3)).isFalse();
      check(mask.isNull(11)).isTrue();
      check(mask.isValid(11)).isFalse();
      check(mask.isValid(4)).isTrue();

      mask.setValid(3);
      check(mask.nullCount).equals(1);
      check(mask.isValid(3)).isTrue();

      final fromBytes = ValidityMask.fromBytes(16, mask.bytes);
      check(fromBytes.nullCount).equals(1);
      check(fromBytes.isValid(3)).isTrue();
      check(fromBytes.isNull(11)).isTrue();

      check(() => mask.isNull(-1)).throws<RangeError>();
      check(() => mask.isNull(20)).throws<RangeError>();
      check(() => mask.setNull(-1)).throws<RangeError>();
      check(() => mask.setNull(20)).throws<RangeError>();
      check(() => mask.setValid(-1)).throws<RangeError>();
      check(() => mask.setValid(20)).throws<RangeError>();
    });
  });

  group('Series', () {
    test('TypedSeries with nulls and aggregations', () {
      final series = TypedSeries<double>.fromList('temp', [
        10.0,
        null,
        30.0,
        40.0,
      ]);
      check(series.length).equals(4);
      check(series.nullCount).equals(1);
      check(series[0]).equals(10.0);
      check(series[1]).isNull();
      check(series[2]).equals(30.0);
      check(series.sum).equals(80.0);
      check(series.mean).isNotNull().isCloseTo(80.0 / 3, 1e-10);
      check(series.min).equals(10.0);
      check(series.max).equals(40.0);

      final filtered = series.filter([true, true, false, true]);
      check(filtered.length).equals(3);
      check(filtered.toList()).deepEquals([10.0, null, 40.0]);
      check(() => series.filter([true])).throws<ArgumentError>();

      final sliced = series.slice(-1, 3);
      check(sliced.length).equals(3);

      final sorted = series.sort(ascending: false);
      check(sorted.toList().first).equals(40.0);
      final sortedAsc = series.sort(ascending: true);
      check(sortedAsc.toList().first).equals(10.0);

      final renamed = series.rename('temperature');
      check(renamed.name).equals('temperature');
      check(series.toString()).contains('Series<double>');

      // All null series
      final allNull = TypedSeries<double>.fromList('all_null', [null, null]);
      check(allNull.min).isNull();
      check(allNull.max).isNull();
      check(allNull.sum).isNull();
      check(allNull.mean).isNull();
    });

    test('StringSeries and BoolSeries', () {
      final strCol = StringSeries.fromList('names', [
        'Alice',
        'Bob',
        null,
        'Charlie',
      ]);
      check(strCol.nullCount).equals(1);
      check(strCol[1]).equals('Bob');
      check(strCol[2]).isNull();
      check(strCol.min).equals('Alice');
      check(strCol.max).equals('Charlie');
      check(strCol.sum).isNull();
      check(strCol.mean).isNull();

      final strFiltered = strCol.filter([true, false, true, false]);
      check(strFiltered.length).equals(2);
      final strSliced = strCol.slice(1, 3);
      check(strSliced.length).equals(2);
      final strSorted = strCol.sort(ascending: true);
      check(strSorted[0]).equals('Alice');
      final strRenamed = strCol.rename('full_names');
      check(strRenamed.name).equals('full_names');

      final boolCol = BoolSeries.fromList('active', [true, false, true, null]);
      check(boolCol.nullCount).equals(1);
      check(boolCol[0]).equals(true);
      check(boolCol[1]).equals(false);
      check(boolCol.min).isNull();
      check(boolCol.max).isNull();
      check(boolCol.sum).equals(2);
      check(boolCol.mean).isNotNull().isCloseTo(2.0 / 3.0, 1e-4);

      final boolFiltered = boolCol.filter([true, false, true, false]);
      check(boolFiltered.length).equals(2);
      final boolSliced = boolCol.slice(0, 2);
      check(boolSliced.length).equals(2);
      final boolSorted = boolCol.sort(ascending: true);
      check(boolSorted[0]).equals(false);
      final boolRenamed = boolCol.rename('is_active');
      check(boolRenamed.name).equals('is_active');
    });

    test('ObjectSeries and Series.fromList factory', () {
      final objSeries = Series<DateTime?>.fromList('items', [
        DateTime(2025, 1, 1),
        null,
        DateTime(2025, 1, 3),
      ]);
      check(objSeries.length).equals(3);
      check(objSeries.nullCount).equals(1);
      check(objSeries.min).isNull();
      check(objSeries.max).isNull();
      check(objSeries.sum).isNull();
      check(objSeries.mean).isNull();

      final objFiltered = objSeries.filter([true, false, true]);
      check(objFiltered.length).equals(2);
      final objSliced = objSeries.slice(0, 2);
      check(objSliced.length).equals(2);
      final objRenamed = objSeries.rename('dates');
      check(objRenamed.name).equals('dates');

      // Explicit type factory
      final numSeries = Series<num>.fromList('num_col', [
        1,
        2,
        3,
      ], type: DataType.int32);
      check(numSeries).isA<TypedSeries<num>>();
      final sSeries = Series.fromList('str_col', [
        'a',
        'b',
      ], type: DataType.string);
      check(sSeries).isA<StringSeries>();
      final bSeries = Series.fromList('b_col', [
        true,
        false,
      ], type: DataType.boolean);
      check(bSeries).isA<BoolSeries>();
    });
  });

  group('DataFrame core operations', () {
    test('creation and column access', () {
      final df = DataFrame.fromColumns({
        'id': [1, 2, 3],
        'name': ['A', 'B', 'C'],
        'score': [90.5, 80.0, 95.0],
      });
      check(df.rowCount).equals(3);
      check(df.columnCount).equals(3);
      check(df.columnNames).deepEquals(['id', 'name', 'score']);
      check(df['name'][1]).equals('B');

      final row1 = df.getRow(1);
      check(row1['id']).equals(2);
      check(row1['name']).equals('B');
      check(row1['score']).equals(80.0);

      // Access helpers
      check(df.typedColumn<num>('id')[0]).equals(1);
      check(df.rows.length).equals(3);
      check(() => df.column('nonexistent')).throws<ArgumentError>();
      check(() => df.getRow(-1)).throws<RangeError>();
      check(() => df.getRow(10)).throws<RangeError>();

      // Empty fromRows
      final emptyDf = DataFrame.fromRows([]);
      check(emptyDf.rowCount).equals(0);
      check(emptyDf.columnCount).equals(0);

      // Constructor column length mismatch
      check(
        () => DataFrame([
          Series.fromList('a', [1, 2]),
          Series.fromList('b', [1]),
        ]),
      ).throws<ArgumentError>();
    });

    test('select, drop, withColumn', () {
      final df = DataFrame.fromColumns({
        'a': [1, 2],
        'b': [3, 4],
        'c': [5, 6],
      });

      final sel = df.select(['a', 'c']);
      check(sel.columnNames).deepEquals(['a', 'c']);

      final dropped = df.drop(['b']);
      check(dropped.columnNames).deepEquals(['a', 'c']);

      final withNew = df.withColumn(Series.fromList('d', [7, 8]));
      check(withNew.columnCount).equals(4);
      check(withNew['d'][1]).equals(8);

      // Replace existing column
      final replaced = df.withColumn(Series.fromList('a', [10, 20]));
      check(replaced.columnCount).equals(3);
      check(replaced['a'][0]).equals(10);
    });

    test('filtering, slicing, sorting, and toString', () {
      final df = DataFrame.fromColumns({
        'val': [10, 50, 20, 40, 30, 60],
        'label': ['v1', 'v2', 'v3', 'v4', 'v5', 'v6'],
      });

      final filtered = df.filterBy((row) => (row['val'] as int) > 25);
      check(filtered.rowCount).equals(4);
      check(filtered['val'].toList()).deepEquals([50, 40, 30, 60]);
      check(() => df.filter([true])).throws<ArgumentError>();

      final sorted = df.sortBy('val', ascending: true);
      check(sorted['val'].toList()).deepEquals([10, 20, 30, 40, 50, 60]);
      final sortedDesc = df.sortBy('val', ascending: false);
      check(sortedDesc['val'].toList().first).equals(60);

      final head2 = sorted.head(2);
      check(head2.rowCount).equals(2);
      check(head2['val'].toList()).deepEquals([10, 20]);

      final tail2 = sorted.tail(2);
      check(tail2.rowCount).equals(2);
      check(tail2['val'].toList()).deepEquals([50, 60]);

      // toString with > 5 rows
      final repr = df.toString();
      check(repr).contains('DataFrame(6 rows x 2 columns)');
      check(repr).contains('... and 1 more rows');
    });

    test('conversion to Matrix and Tensor', () {
      final df = DataFrame.fromColumns({
        'x': [1.0, 2.0],
        'y': [3.0, 4.0],
      });

      final mat = df.toMatrix();
      check(mat.rowCount).equals(2);
      check(mat.colCount).equals(2);
      check(mat.get(0, 0)).equals(1.0);
      check(mat.get(0, 1)).equals(3.0);
      check(mat.get(1, 0)).equals(2.0);
      check(mat.get(1, 1)).equals(4.0);

      final ten = df.toTensor(columns: ['x']);
      check(ten.shape).deepEquals([2, 1]);
    });
  });

  group('GroupBy and Aggregations', () {
    test('single and multi-column group-by', () {
      final df = DataFrame.fromColumns({
        'dept': ['IT', 'HR', 'IT', 'HR', 'IT'],
        'salary': [100.0, 80.0, 120.0, 90.0, 110.0],
      });

      check(() => df.groupBy([])).throws<ArgumentError>();

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

      check(summary.rowCount).equals(2);
      check(summary.columnNames).deepEquals([
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

      for (var row = 0; row < summary.rowCount; row++) {
        if (summary['dept'][row] == 'IT') {
          check(summary['salary_count'][row]).equals(3);
          check(summary['salary_sum'][row]).equals(330.0);
          check(summary['salary_mean'][row]).equals(110.0);
          check(summary['salary_min'][row]).equals(100.0);
          check(summary['salary_max'][row]).equals(120.0);
          check(summary['salary_first'][row]).equals(100.0);
          check(summary['salary_last'][row]).equals(110.0);
        } else if (summary['dept'][row] == 'HR') {
          check(summary['salary_count'][row]).equals(2);
          check(summary['salary_sum'][row]).equals(170.0);
          check(summary['salary_mean'][row]).equals(85.0);
        }
      }

      // Convenience methods
      final meanDf = grouped.mean();
      check(meanDf.columnNames).deepEquals(['dept', 'salary_mean']);

      final sumDf = grouped.sum();
      check(sumDf.columnNames).deepEquals(['dept', 'salary_sum']);

      final countDf = grouped.count();
      check(countDf.rowCount).equals(2);
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
      check(inner.rowCount).equals(2);
      check(inner['id'].toList()).deepEquals([2, 3]);
      check(inner['name'].toList()).deepEquals(['Bob', 'Charlie']);
      check(inner['age'].toList()).deepEquals([25, 30]);

      // Left join
      final leftJoined = left.join(right, on: ['id'], type: JoinType.left);
      check(leftJoined.rowCount).equals(3);
      check(leftJoined['id'].toList()).deepEquals([1, 2, 3]);
      check(leftJoined['age'].toList()).deepEquals([null, 25, 30]);

      // Right join
      final rightJoined = left.join(right, on: ['id'], type: JoinType.right);
      check(rightJoined.rowCount).equals(3);
      check(rightJoined['id'].toList()).deepEquals([2, 3, 4]);
      check(rightJoined['name'].toList()).deepEquals(['Bob', 'Charlie', null]);

      // Outer join
      final outerJoined = left.join(right, on: ['id'], type: JoinType.outer);
      check(outerJoined.rowCount).equals(4);
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
      check(df.rowCount).equals(3);
      check(df.columnCount).equals(4);
      check(df.columnNames).deepEquals(['name', 'age', 'salary', 'active']);

      // Type inference
      check(df['age'].dataType.name).equals('int32');
      check(df['salary'].dataType.name).equals('float64');
      check(df['active'].dataType.name).equals('boolean');
      check(df['name'].dataType.name).equals('string');

      // Null handling
      check(df['age'][2]).isNull();
      check(df['salary'][2]).equals(60000.0);

      // Serialization
      final exportedCsv = df.toCsv();
      final df2 = DataFrame.fromCsv(exportedCsv);
      check(df2.rowCount).equals(3);
      check(df2['name'].toList()).deepEquals(['Alice', 'Bob', 'Charlie']);
      check(df2['salary'].toList()).deepEquals([75000.5, 50000.0, 60000.0]);
    });

    test('multiline CSV with embedded newlines and escaped quotes', () {
      const csv = '''
id,desc,val
1,"line 1
line 2",10
2,"say ""hello""",20
''';
      final df = DataFrame.fromCsv(csv);
      check(df.rowCount).equals(2);
      check(df['desc'][0]).equals('line 1\nline 2');
      check(df['desc'][1]).equals('say "hello"');
      check(df['val'].toList()).deepEquals([10, 20]);
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
      check(inner.rowCount).equals(1);
      check(inner['id'].toList()).deepEquals([1]);
    });

    test('sortBy boolean column', () {
      final df = DataFrame.fromColumns({
        'name': ['A', 'B', 'C'],
        'flag': [true, false, true],
      });
      final sorted = df.sortBy('flag', ascending: true);
      check(sorted['flag'].toList()).deepEquals([false, true, true]);
    });

    test('TypedSeries empty list creation without error', () {
      final emptySeries = TypedSeries<double>.fromList('empty', []);
      check(emptySeries.length).equals(0);
      check(emptySeries.dataType.name).equals('float64');
    });

    test('DataFrame.fromRows, CSV edge cases, Joins, and Series sorting', () {
      // 1. DataFrame.fromRows
      final dfRows = DataFrame.fromRows([
        {'id': 1, 'name': 'Alice'},
        {'id': 2, 'name': 'Bob'},
      ]);
      check(dfRows.rowCount).equals(2);
      check(dfRows['name'].toList()).deepEquals(['Alice', 'Bob']);
      check(DataFrame.fromRows([]).rowCount).equals(0);

      // 2. sortBy on non-Comparable objects
      final dfCustom = DataFrame.fromColumns({
        'obj': [Object(), Object()],
      });
      final sortedCustom = dfCustom.sortBy('obj');
      check(sortedCustom.rowCount).equals(2);

      // 3. CSV header: false, CRLF, only nulls column, and escaping
      const noHeaderCsv = '10,foo\r\n20,bar';
      final dfNoHeader = CsvReader.parse(noHeaderCsv, header: false);
      check(dfNoHeader.columnNames).deepEquals(['col_0', 'col_1']);
      check(dfNoHeader.rowCount).equals(2);

      const nullColCsv = 'a,b\n1,\n2,null\n';
      final dfNullCol = CsvReader.parse(nullColCsv);
      check(dfNullCol['b'].nullCount).equals(2);

      final dfEscaped = DataFrame.fromColumns({
        'text': ['hello, world', 'quote "test"', 'line1\nline2'],
      });
      final csvOut = CsvWriter.write(dfEscaped);
      check(csvOut).contains('"hello, world"');
      check(csvOut).contains('"quote ""test"""');

      // 4. Join column errors & left join with null key
      final dfA = DataFrame.fromColumns({
        'k': [1, null],
      });
      final dfB = DataFrame.fromColumns({
        'k': [1],
      });
      check(() => dfA.join(dfB, on: ['missing'])).throws<ArgumentError>();
      check(() => dfA.join(dfB, on: ['k'], suffix: '_b')).returnsNormally();
      final dfBNoK = DataFrame.fromColumns({
        'other': [1],
      });
      check(() => dfA.join(dfBNoK, on: ['k'])).throws<ArgumentError>();

      final leftWithNull = dfA.join(dfB, on: ['k'], type: JoinType.left);
      check(leftWithNull.rowCount).equals(2);
      check(leftWithNull['k'][1]).isNull();

      // 5. StringSeries, BoolSeries, and ObjectSeries descending / custom sorts
      final strSeries = Series<String?>.fromList('s', [
        'banana',
        'apple',
        null,
      ]);
      final strDesc = strSeries.sort(ascending: false);
      check(strDesc[0]).equals('banana');
      check(strDesc[1]).equals('apple');
      check(strDesc[2]).isNull();

      final boolSeries = Series<bool?>.fromList('b', [false, true, null]);
      final boolDesc = boolSeries.sort(ascending: false);
      check(boolDesc[0]).equals(true);
      check(boolDesc[1]).equals(false);

      final objSeries = ObjectSeries<int>.fromList('obj', [
        30,
        10,
        null,
        20,
      ], type: DataType.int32);
      final objAsc = objSeries.sort(ascending: true);
      check(objAsc.toList()).deepEquals([10, 20, 30, null]);
      final objDesc = objSeries.sort(ascending: false);
      check(objDesc.toList()).deepEquals([30, 20, 10, null]);
    });
  });
}
