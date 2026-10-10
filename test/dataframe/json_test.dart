import 'package:checks/checks.dart';
import 'package:data/dataframe.dart';
import 'package:data/type.dart';
import 'package:test/test.dart';

void main() {
  group('JsonOrient.records', () {
    test('round-trip serialization with heterogeneous data', () {
      final df = DataFrame([
        Series.fromList('id', [1, 2, 3]),
        Series.fromList('name', ['Alice', 'Bob', 'Charlie']),
        Series.fromList('score', [95.5, 88.0, 92.5]),
        Series.fromList('active', [true, false, true]),
      ]);

      final jsonStr = df.toJson(orient: JsonOrient.records);
      check(jsonStr).contains('"id":1');
      check(jsonStr).contains('"name":"Alice"');

      final decoded = DataFrame.fromJson(jsonStr, orient: JsonOrient.records);
      check(decoded.rowCount).equals(3);
      check(decoded.columnCount).equals(4);
      check(decoded.columnNames).deepEquals(['id', 'name', 'score', 'active']);
      check(decoded['id'].toList()).deepEquals([1, 2, 3]);
      check(decoded['name'].toList()).deepEquals(['Alice', 'Bob', 'Charlie']);
      check(decoded['score'].toList()).deepEquals([95.5, 88.0, 92.5]);
      check(decoded['active'].toList()).deepEquals([true, false, true]);
    });

    test('handles missing keys by inserting null', () {
      const jsonStr = '[{"a": 1, "b": 2}, {"a": 3}]';
      final df = DataFrame.fromJson(jsonStr, orient: JsonOrient.records);

      check(df.rowCount).equals(2);
      check(df.columnNames).deepEquals(['a', 'b']);
      check(df['a'].toList()).deepEquals([1, 3]);
      check(df['b'].toList()).deepEquals([2, null]);
      check(df['b'].nullCount).equals(1);
      check(df['b'].isNull(1)).isTrue();
    });

    test('handles out-of-order keys across rows', () {
      const jsonStr = '[{"b": 20, "a": 10}, {"a": 30, "b": 40}]';
      final df = DataFrame.fromJson(jsonStr, orient: JsonOrient.records);

      check(df.rowCount).equals(2);
      check(df.columnNames).deepEquals(['b', 'a']);
      check(df['b'].toList()).deepEquals([20, 40]);
      check(df['a'].toList()).deepEquals([10, 30]);
    });
  });

  group('JsonOrient.split', () {
    test('round-trip serialization', () {
      final df = DataFrame([
        Series.fromList('x', [10, 20]),
        Series.fromList('y', ['alpha', 'beta']),
      ]);

      final jsonStr = df.toJson(orient: JsonOrient.split);
      check(jsonStr).contains('"columns":["x","y"]');
      check(jsonStr).contains('"data":[[10,"alpha"],[20,"beta"]]');

      final decoded = DataFrame.fromJson(jsonStr, orient: JsonOrient.split);
      check(decoded.rowCount).equals(2);
      check(decoded.columnNames).deepEquals(['x', 'y']);
      check(decoded['x'].toList()).deepEquals([10, 20]);
      check(decoded['y'].toList()).deepEquals(['alpha', 'beta']);
    });

    test('preserves 0 rows with declared columns', () {
      final df = DataFrame([
        Series.fromList('col_a', <int>[]),
        Series.fromList('col_b', <String>[]),
      ]);

      final jsonStr = df.toJson(orient: JsonOrient.split);
      check(jsonStr).equals('{"columns":["col_a","col_b"],"data":[]}');

      final decoded = DataFrame.fromJson(jsonStr, orient: JsonOrient.split);
      check(decoded.rowCount).equals(0);
      check(decoded.columnCount).equals(2);
      check(decoded.columnNames).deepEquals(['col_a', 'col_b']);
    });

    test('handles row with fewer columns than declared', () {
      const jsonStr = '{"columns": ["a", "b"], "data": [[1], [2, "hello"]]}';
      final df = DataFrame.fromJson(jsonStr, orient: JsonOrient.split);

      check(df.rowCount).equals(2);
      check(df['a'].toList()).deepEquals([1, 2]);
      check(df['b'].toList()).deepEquals([null, 'hello']);
      check(df['b'].isNull(0)).isTrue();
    });

    test('supports pandas-style split format with optional index key', () {
      const jsonStr = '''
      {
        "columns": ["col_x", "col_y"],
        "index": [0, 1],
        "data": [[100, "foo"], [200, "bar"]]
      }
      ''';
      final df = DataFrame.fromJson(jsonStr, orient: JsonOrient.split);
      check(df.rowCount).equals(2);
      check(df.columnNames).deepEquals(['col_x', 'col_y']);
      check(df['col_x'].toList()).deepEquals([100, 200]);
      check(df['col_y'].toList()).deepEquals(['foo', 'bar']);
    });
  });

  group('JsonOrient.columns', () {
    test('round-trip serialization with column lists', () {
      final df = DataFrame([
        Series.fromList('nums', [100, 200, 300]),
        Series.fromList('tags', ['t1', 't2', 't3']),
      ]);

      final jsonStr = df.toJson(orient: JsonOrient.columns);
      check(jsonStr).contains('"nums":[100,200,300]');
      check(jsonStr).contains('"tags":["t1","t2","t3"]');

      final decoded = DataFrame.fromJson(jsonStr, orient: JsonOrient.columns);
      check(decoded.rowCount).equals(3);
      check(decoded.columnNames).deepEquals(['nums', 'tags']);
      check(decoded['nums'].toList()).deepEquals([100, 200, 300]);
      check(decoded['tags'].toList()).deepEquals(['t1', 't2', 't3']);
    });

    test('decodes row-indexed maps', () {
      const jsonStr = '''
      {
        "col1": {"0": 10, "1": 20, "2": 30},
        "col2": {"0": "a", "1": "b", "2": "c"}
      }
      ''';
      final df = DataFrame.fromJson(jsonStr, orient: JsonOrient.columns);

      check(df.rowCount).equals(3);
      check(df.columnNames).deepEquals(['col1', 'col2']);
      check(df['col1'].toList()).deepEquals([10, 20, 30]);
      check(df['col2'].toList()).deepEquals(['a', 'b', 'c']);
    });

    test('decodes row-indexed maps with missing indices and nulls', () {
      const jsonStr = '''
      {
        "col1": {"0": 10, "2": 30},
        "col2": {"0": "a", "1": "b", "2": "c"}
      }
      ''';
      final df = DataFrame.fromJson(jsonStr, orient: JsonOrient.columns);

      check(df.rowCount).equals(3);
      check(df['col1'].toList()).deepEquals([10, null, 30]);
      check(df['col1'].isNull(1)).isTrue();
      check(df['col2'].toList()).deepEquals(['a', 'b', 'c']);
    });

    test('decodes non-integer index-labeled maps', () {
      const jsonStr = '''
      {
        "col1": {"r0": 1, "r1": 2},
        "col2": {"r0": "x", "r1": "y"}
      }
      ''';
      final df = DataFrame.fromJson(jsonStr, orient: JsonOrient.columns);

      check(df.rowCount).equals(2);
      check(df['col1'].toList()).deepEquals([1, 2]);
      check(df['col2'].toList()).deepEquals(['x', 'y']);
    });

    test('handles empty column lists', () {
      const jsonStr = '{"a": [], "b": []}';
      final df = DataFrame.fromJson(jsonStr, orient: JsonOrient.columns);

      check(df.rowCount).equals(0);
      check(df.columnCount).equals(2);
      check(df.columnNames).deepEquals(['a', 'b']);
    });

    test('decodes row-indexed maps with non-zero or sparse integer labels without row explosion', () {
      const jsonStr = '''
        {
          "col1": {"10": "a", "20": "b"},
          "col2": {"10": 1, "20": 2}
        }
        ''';
      final df = DataFrame.fromJson(jsonStr, orient: JsonOrient.columns);
      check(df.rowCount).equals(2);
      check(df['col1'].toList()).deepEquals(['a', 'b']);
      check(df['col2'].toList()).deepEquals([1, 2]);

      const largeKeyJson = '{"col1": {"1000000": "val"}}';
      final largeDf = DataFrame.fromJson(
        largeKeyJson,
        orient: JsonOrient.columns,
      );
      check(largeDf.rowCount).equals(1);
      check(largeDf['col1'].toList()).deepEquals(['val']);
    });
  });

  group('JsonOrient.values_', () {
    test('round-trip serialization with default column names', () {
      final df = DataFrame([
        Series.fromList('a', [1, 2]),
        Series.fromList('b', [3, 4]),
      ]);

      final jsonStr = df.toJson(orient: JsonOrient.values_);
      check(jsonStr).equals('[[1,3],[2,4]]');

      final decoded = DataFrame.fromJson(jsonStr, orient: JsonOrient.values_);
      check(decoded.rowCount).equals(2);
      check(decoded.columnCount).equals(2);
      check(decoded.columnNames).deepEquals(['col_0', 'col_1']);
      check(decoded['col_0'].toList()).deepEquals([1, 2]);
      check(decoded['col_1'].toList()).deepEquals([3, 4]);
    });

    test('preserves column names and types with columnTypes', () {
      const jsonStr = '[[10, 20.5], [30, 40.5]]';
      final df = DataFrame.fromJson(
        jsonStr,
        orient: JsonOrient.values_,
        columnTypes: {'first': DataType.int32, 'second': DataType.float64},
      );

      check(df.rowCount).equals(2);
      check(df.columnNames).deepEquals(['first', 'second']);
      check(df['first'].dataType).equals(DataType.int32);
      check(df['second'].dataType).equals(DataType.float64);
      check(df['first'].toList()).deepEquals([10, 30]);
      check(df['second'].toList()).deepEquals([20.5, 40.5]);
    });

    test('handles empty values array', () {
      const jsonStr = '[]';
      final df = DataFrame.fromJson(jsonStr, orient: JsonOrient.values_);
      check(df.rowCount).equals(0);
      check(df.columnCount).equals(0);
    });

    test(
      'avoids column name collision when columnTypes specifies col_1 at start',
      () {
        const jsonStr = '[[1, 2], [3, 4]]';
        final df = DataFrame.fromJson(
          jsonStr,
          orient: JsonOrient.values_,
          columnTypes: {'col_1': DataType.int32},
        );
        check(df.columnCount).equals(2);
        check(df.columnNames).deepEquals(['col_1', 'col_2']);
      },
    );
  });

  group('Auto-detection', () {
    test('auto-detects records orientation', () {
      const jsonStr = '[{"x": 1, "y": 2}, {"x": 3, "y": 4}]';
      final df = DataFrame.fromJson(jsonStr);

      check(df.rowCount).equals(2);
      check(df.columnNames).deepEquals(['x', 'y']);
      check(df['x'].toList()).deepEquals([1, 3]);
      check(df['y'].toList()).deepEquals([2, 4]);
    });

    test('auto-detects values orientation', () {
      const jsonStr = '[[1, 2], [3, 4]]';
      final df = DataFrame.fromJson(jsonStr);

      check(df.rowCount).equals(2);
      check(df.columnNames).deepEquals(['col_0', 'col_1']);
      check(df['col_0'].toList()).deepEquals([1, 3]);
      check(df['col_1'].toList()).deepEquals([2, 4]);
    });

    test('auto-detects split orientation', () {
      const jsonStr = '{"columns": ["a", "b"], "data": [[10, "u"], [20, "v"]]}';
      final df = DataFrame.fromJson(jsonStr);

      check(df.rowCount).equals(2);
      check(df.columnNames).deepEquals(['a', 'b']);
      check(df['a'].toList()).deepEquals([10, 20]);
      check(df['b'].toList()).deepEquals(['u', 'v']);
    });

    test('auto-detects columns orientation with lists', () {
      const jsonStr = '{"a": [10, 20], "b": ["u", "v"]}';
      final df = DataFrame.fromJson(jsonStr);

      check(df.rowCount).equals(2);
      check(df.columnNames).deepEquals(['a', 'b']);
      check(df['a'].toList()).deepEquals([10, 20]);
      check(df['b'].toList()).deepEquals(['u', 'v']);
    });

    test('auto-detects columns orientation with row-indexed maps', () {
      const jsonStr = '{"a": {"0": 10, "1": 20}, "b": {"0": "u", "1": "v"}}';
      final df = DataFrame.fromJson(jsonStr);

      check(df.rowCount).equals(2);
      check(df.columnNames).deepEquals(['a', 'b']);
      check(df['a'].toList()).deepEquals([10, 20]);
      check(df['b'].toList()).deepEquals(['u', 'v']);
    });

    test('auto-detects empty list as records', () {
      const jsonStr = '[]';
      final df = DataFrame.fromJson(jsonStr);
      check(df.rowCount).equals(0);
      check(df.columnCount).equals(0);
    });

    test('auto-detects empty map as columns', () {
      const jsonStr = '{}';
      final df = DataFrame.fromJson(jsonStr);
      check(df.rowCount).equals(0);
      check(df.columnCount).equals(0);
    });

    test(
      'auto-detects split on columns and data keys and validates structure',
      () {
        const jsonStr = '{"columns": ["a"], "data": [1, 2]}';
        check(() => DataFrame.fromJson(jsonStr)).throws<FormatException>();
      },
    );
  });

  group('fromRecords & toRecords', () {
    test('toRecords outputs list of maps matching rows', () {
      final df = DataFrame([
        Series.fromList('a', [1, 2]),
        Series.fromList('b', ['x', 'y']),
      ]);

      final records = df.toRecords();
      check(records).deepEquals([
        {'a': 1, 'b': 'x'},
        {'a': 2, 'b': 'y'},
      ]);
    });

    test('fromRecords constructs DataFrame from Iterable of maps', () {
      final records = [
        {'colA': 100, 'colB': 1.5},
        {'colA': 200, 'colB': 2.5},
        {'colA': 300, 'colB': 3.5},
      ];

      final df = DataFrame.fromRecords(records);
      check(df.rowCount).equals(3);
      check(df.columnNames).deepEquals(['colA', 'colB']);
      check(df['colA'].toList()).deepEquals([100, 200, 300]);
      check(df['colB'].toList()).deepEquals([1.5, 2.5, 3.5]);
    });

    test('fromRecords with empty input', () {
      final df = DataFrame.fromRecords([]);
      check(df.rowCount).equals(0);
      check(df.columnCount).equals(0);

      final dfWithTypes = DataFrame.fromRecords(
        [],
        columnTypes: {'foo': DataType.string, 'bar': DataType.int32},
      );
      check(dfWithTypes.rowCount).equals(0);
      check(dfWithTypes.columnCount).equals(2);
      check(dfWithTypes.columnNames).deepEquals(['foo', 'bar']);
    });
  });

  group('Null and missing values', () {
    test('records with null and missing entries', () {
      const jsonStr = '[{"a": 1, "b": null}, {"a": null}]';
      final df = DataFrame.fromJson(jsonStr, orient: JsonOrient.records);

      check(df.rowCount).equals(2);
      check(df['a'].toList()).deepEquals([1, null]);
      check(df['a'].nullCount).equals(1);
      check(df['b'].toList()).deepEquals([null, null]);
      check(df['b'].nullCount).equals(2);
    });

    test('split with null entries', () {
      const jsonStr =
          '{"columns": ["a", "b"], "data": [[null, 10], [20, null]]}';
      final df = DataFrame.fromJson(jsonStr, orient: JsonOrient.split);

      check(df.rowCount).equals(2);
      check(df['a'].toList()).deepEquals([null, 20]);
      check(df['b'].toList()).deepEquals([10, null]);
      check(df['a'].isNull(0)).isTrue();
      check(df['b'].isNull(1)).isTrue();
    });

    test('columns with null entries', () {
      const jsonStr = '{"a": [null, 42], "b": ["val", null]}';
      final df = DataFrame.fromJson(jsonStr, orient: JsonOrient.columns);

      check(df.rowCount).equals(2);
      check(df['a'].toList()).deepEquals([null, 42]);
      check(df['b'].toList()).deepEquals(['val', null]);
      check(df['a'].isNull(0)).isTrue();
      check(df['b'].isNull(1)).isTrue();
    });

    test('values with null entries', () {
      const jsonStr = '[[null, "foo"], [10, null]]';
      final df = DataFrame.fromJson(jsonStr, orient: JsonOrient.values_);

      check(df.rowCount).equals(2);
      check(df['col_0'].toList()).deepEquals([null, 10]);
      check(df['col_1'].toList()).deepEquals(['foo', null]);
      check(df['col_0'].isNull(0)).isTrue();
      check(df['col_1'].isNull(1)).isTrue();
    });
  });

  group('Empty DataFrames', () {
    test('completely empty DataFrame round-trip', () {
      final df = DataFrame([]);
      check(df.rowCount).equals(0);
      check(df.columnCount).equals(0);

      check(df.toJson(orient: JsonOrient.records)).equals('[]');
      check(df.toJson(orient: JsonOrient.split))
          .equals('{"columns":[],"data":[]}');
      check(df.toJson(orient: JsonOrient.columns)).equals('{}');
      check(df.toJson(orient: JsonOrient.values_)).equals('[]');

      check(DataFrame.fromJson('[]').rowCount).equals(0);
      check(DataFrame.fromJson('{"columns":[],"data":[]}').rowCount).equals(0);
      check(DataFrame.fromJson('{}').rowCount).equals(0);
    });

    test('DataFrame with columns but 0 rows', () {
      final df = DataFrame([
        Series.fromList('a', <int>[]),
        Series.fromList('b', <String>[]),
      ]);

      final splitJson = df.toJson(orient: JsonOrient.split);
      check(splitJson).equals('{"columns":["a","b"],"data":[]}');
      final splitDf = DataFrame.fromJson(splitJson);
      check(splitDf.rowCount).equals(0);
      check(splitDf.columnNames).deepEquals(['a', 'b']);

      final colsJson = df.toJson(orient: JsonOrient.columns);
      check(colsJson).equals('{"a":[],"b":[]}');
      final colsDf = DataFrame.fromJson(colsJson);
      check(colsDf.rowCount).equals(0);
      check(colsDf.columnNames).deepEquals(['a', 'b']);
    });
  });

  group('Explicit columnTypes', () {
    test('casts integers to float64 and strings to int32', () {
      const jsonStr =
          '[{"val": 42, "code": "100"}, {"val": 50, "code": "200"}]';
      final df = DataFrame.fromJson(
        jsonStr,
        columnTypes: {'val': DataType.float64, 'code': DataType.int32},
      );

      check(df.rowCount).equals(2);
      check(df['val'].dataType).equals(DataType.float64);
      check(df['val'].toList()).deepEquals([42.0, 50.0]);
      check(df['code'].dataType).equals(DataType.int32);
      check(df['code'].toList()).deepEquals([100, 200]);
    });

    test('casts booleans and strings explicitly', () {
      const jsonStr = '{"flag": ["true", "false"], "num": [1, 2]}';
      final df = DataFrame.fromJson(
        jsonStr,
        orient: JsonOrient.columns,
        columnTypes: {'flag': DataType.boolean, 'num': DataType.string},
      );

      check(df['flag'].dataType).equals(DataType.boolean);
      check(df['flag'].toList()).deepEquals([true, false]);
      check(df['num'].dataType).equals(DataType.string);
      check(df['num'].toList()).deepEquals(['1', '2']);
    });

    test('creates empty typed columns when input has 0 rows', () {
      const jsonStr = '[]';
      final df = DataFrame.fromJson(
        jsonStr,
        columnTypes: {'x': DataType.float64, 'y': DataType.int32},
      );

      check(df.rowCount).equals(0);
      check(df.columnCount).equals(2);
      check(df.columnNames).deepEquals(['x', 'y']);
      check(df['x'].dataType).equals(DataType.float64);
      check(df['y'].dataType).equals(DataType.int32);
    });

    test(
      'preserves natural record column order when columnTypes is provided',
      () {
        const jsonStr = '[{"first": "Alice", "score": 95.5, "age": 30}]';
        final df = DataFrame.fromJson(
          jsonStr,
          columnTypes: {'score': DataType.float64},
        );
        check(df.columnNames).deepEquals(['first', 'score', 'age']);
      },
    );
  });

  group('Error handling & Malformed JSON', () {
    test('throws FormatException on invalid JSON syntax', () {
      check(() => DataFrame.fromJson('{bad json')).throws<FormatException>();
      check(() => DataFrame.fromJson('')).throws<FormatException>();
    });

    test('throws FormatException on orientation mismatch', () {
      // Split expects Map, got List
      check(() => DataFrame.fromJson('[1, 2]', orient: JsonOrient.split))
          .throws<FormatException>();

      // Records expects List, got Map
      check(() => DataFrame.fromJson('{"a": 1}', orient: JsonOrient.records))
          .throws<FormatException>();

      // Values expects List, got Map
      check(() => DataFrame.fromJson('{"a": 1}', orient: JsonOrient.values_))
          .throws<FormatException>();

      // Columns expects Map, got List
      check(() => DataFrame.fromJson('[1, 2]', orient: JsonOrient.columns))
          .throws<FormatException>();
    });

    test('throws FormatException on malformed split structure', () {
      // Missing data
      check(
        () =>
            DataFrame.fromJson('{"columns": ["a"]}', orient: JsonOrient.split),
      ).throws<FormatException>();

      // Columns is not a list
      check(
        () => DataFrame.fromJson(
          '{"columns": "a", "data": []}',
          orient: JsonOrient.split,
        ),
      ).throws<FormatException>();

      // Data is not a list
      check(
        () => DataFrame.fromJson(
          '{"columns": ["a"], "data": "invalid"}',
          orient: JsonOrient.split,
        ),
      ).throws<FormatException>();

      // Data row is not a list
      check(
        () => DataFrame.fromJson(
          '{"columns": ["a"], "data": [123]}',
          orient: JsonOrient.split,
        ),
      ).throws<FormatException>();
    });

    test('throws FormatException on malformed records structure', () {
      // Element is not a Map
      check(() => DataFrame.fromJson('[123, 456]', orient: JsonOrient.records))
          .throws<FormatException>();
    });

    test('throws FormatException on malformed values structure', () {
      // Element is not a List
      check(() => DataFrame.fromJson('[123, 456]', orient: JsonOrient.values_))
          .throws<FormatException>();
    });

    test('throws FormatException on malformed columns structure', () {
      // Column value is primitive (not List or Map)
      check(() => DataFrame.fromJson('{"a": 123}', orient: JsonOrient.columns))
          .throws<FormatException>();
    });

    test(
      'throws FormatException on non-container JSON root during auto-detection',
      () {
        check(() => DataFrame.fromJson('"just a string"'))
            .throws<FormatException>();
        check(() => DataFrame.fromJson('12345')).throws<FormatException>();
        check(() => DataFrame.fromJson('true')).throws<FormatException>();
        check(() => DataFrame.fromJson('[1, 2, 3]')).throws<FormatException>();
      },
    );
  });
}
