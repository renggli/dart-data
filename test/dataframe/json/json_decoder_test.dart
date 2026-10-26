import 'package:checks/checks.dart';
import 'package:data/dataframe.dart';
import 'package:data/src/dataframe/json/json_decoder.dart';
import 'package:data/type.dart';
import 'package:test/test.dart';

void main() {
  group('DataFrameJsonDecoder', () {
    test('decodes records format', () {
      const json = '[{"a": 1, "b": "x"}, {"a": 2, "b": "y"}]';
      final df = DataFrameJsonDecoder.decode(json);
      check(df.rowCount).equals(2);
      check(df.columnNames).deepEquals(['a', 'b']);
      check(df['a'].toList()).deepEquals([1, 2]);
      check(df['b'].toList()).deepEquals(['x', 'y']);
    });

    test('decodes split format', () {
      const json = '{"columns": ["x", "y"], "data": [[10, 20], [30, 40]]}';
      final df = DataFrameJsonDecoder.decode(json);
      check(df.rowCount).equals(2);
      check(df.columnNames).deepEquals(['x', 'y']);
      check(df['x'].toList()).deepEquals([10, 30]);
      check(df['y'].toList()).deepEquals([20, 40]);
    });

    test('decodes columns format', () {
      const json = '{"c1": [1.5, 2.5], "c2": ["a", "b"]}';
      final df = DataFrameJsonDecoder.decode(json);
      check(df.rowCount).equals(2);
      check(df.columnNames).deepEquals(['c1', 'c2']);
      check(df['c1'].toList()).deepEquals([1.5, 2.5]);
      check(df['c2'].toList()).deepEquals(['a', 'b']);
    });

    test('decodes array format with auto-generated names', () {
      const json = '[[1, 2], [3, 4]]';
      final df = DataFrameJsonDecoder.decode(json, orient: JsonOrient.array);
      check(df.rowCount).equals(2);
      check(df.columnNames).deepEquals(['col_0', 'col_1']);
      check(df['col_0'].toList()).deepEquals([1, 3]);
      check(df['col_1'].toList()).deepEquals([2, 4]);
    });

    test('fromRecords with empty list and explicit columnTypes', () {
      final df = DataFrameJsonDecoder.fromRecords(
        const [],
        columnTypes: {'id': DataType.int32, 'name': DataType.string},
      );
      check(df.rowCount).equals(0);
      check(df.columnNames).deepEquals(['id', 'name']);
    });

    test('detectOrient detects formats accurately', () {
      check(
        DataFrameJsonDecoder.detectOrient([
          {'a': 1},
        ]),
      ).equals(JsonOrient.records);
      check(
        DataFrameJsonDecoder.detectOrient([
          [1, 2],
        ]),
      ).equals(JsonOrient.array);
      check(
        DataFrameJsonDecoder.detectOrient({
          'columns': ['a'],
          'data': [
            [1],
          ],
        }),
      ).equals(JsonOrient.split);
      check(
        DataFrameJsonDecoder.detectOrient({
          'a': [1, 2],
        }),
      ).equals(JsonOrient.columns);
    });

    test('throws FormatException on malformed JSON', () {
      check(() => DataFrameJsonDecoder.decode('invalid json'))
          .throws<FormatException>();
    });

    test('empty json payloads with explicit columnTypes', () {
      final dfCols = DataFrameJsonDecoder.decode(
        '{}',
        orient: JsonOrient.columns,
        columnTypes: {'c1': DataType.int32, 'c2': DataType.string},
      );
      check(dfCols.rowCount).equals(0);
      check(dfCols.columnNames).deepEquals(['c1', 'c2']);

      final dfVals = DataFrameJsonDecoder.decode(
        '[]',
        orient: JsonOrient.array,
        columnTypes: {'v1': DataType.int32, 'v2': DataType.string},
      );
      check(dfVals.rowCount).equals(0);
      check(dfVals.columnNames).deepEquals(['v1', 'v2']);

      // values with columnTypes length exceeding row length
      final dfPadded = DataFrameJsonDecoder.decode(
        '[[10]]',
        orient: JsonOrient.array,
        columnTypes: {'v1': DataType.int32, 'v2': DataType.string},
      );
      check(dfPadded.rowCount).equals(1);
      check(dfPadded.columnNames).deepEquals(['v1', 'v2']);
      check(dfPadded['v1'].toList()).deepEquals([10]);
      check(dfPadded['v2'].toList()).deepEquals([null]);

      // columns orient with index map with int and string keys
      final dfMapIndex = DataFrameJsonDecoder.decode(
        '{"c1": {"0": 100, "1": 200}, "c2": {"0": 300, "1": 400}}',
        orient: JsonOrient.columns,
      );
      check(dfMapIndex.rowCount).equals(2);
      check(dfMapIndex['c1'].toList()).deepEquals([100, 200]);
    });
  });

  group('DataFrame.fromJson orientations and edge cases', () {
    test('handles missing keys in records by inserting null', () {
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

    test('decodes row-indexed maps with non-zero integer labels', () {
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
    });

    test('explicit columnTypes casts and preserves order', () {
      const jsonStr =
          '[{"first": "Alice", "score": "95.5"}, {"first": "Bob", "score": "88.0"}]';
      final df = DataFrame.fromJson(
        jsonStr,
        columnTypes: {'first': DataType.string, 'score': DataType.float64},
      );
      check(df.rowCount).equals(2);
      check(df.columnNames).deepEquals(['first', 'score']);
      check(df['score'].dataType).equals(DataType.float64);
      check(df['score'].toList()).deepEquals([95.5, 88.0]);
    });

    test('error handling on malformed JSON structure', () {
      check(() => DataFrame.fromJson('{bad json')).throws<FormatException>();
      check(() => DataFrame.fromJson('[1, 2]', orient: JsonOrient.split))
          .throws<FormatException>();
      check(
        () =>
            DataFrame.fromJson('{"columns": ["a"]}', orient: JsonOrient.split),
      ).throws<FormatException>();
      check(
        () => DataFrame.fromJson(
          '{"columns": "not_a_list", "data": []}',
          orient: JsonOrient.split,
        ),
      ).throws<FormatException>();
      check(
        DataFrame.fromJson(
          '{"columns": ["a", "b"], "data": [[1]]}',
          orient: JsonOrient.split,
        )['b'].toList(),
      ).deepEquals([null]);
      check(
        () => DataFrame.fromJson(
          '{"columns": ["a"], "data": "not_a_list"}',
          orient: JsonOrient.split,
        ),
      ).throws<FormatException>();
      check(
        () => DataFrame.fromJson(
          '{"columns": ["a"], "data": ["not_a_row_list"]}',
          orient: JsonOrient.split,
        ),
      ).throws<FormatException>();
      check(() => DataFrame.fromJson('[123, 456]', orient: JsonOrient.records))
          .throws<FormatException>();
      check(() => DataFrame.fromJson('{}', orient: JsonOrient.records))
          .throws<FormatException>();
      check(() => DataFrame.fromJson('[]', orient: JsonOrient.columns))
          .throws<FormatException>();
      check(() => DataFrame.fromJson('{"a": 123}', orient: JsonOrient.columns))
          .throws<FormatException>();
      check(
        DataFrame.fromJson(
          '{"a": {"r1": 1, "r2": 2}, "b": {"r1": 10}}',
          orient: JsonOrient.columns,
        )['b'].toList(),
      ).deepEquals([10, null]);
      check(() => DataFrame.fromJson('{}', orient: JsonOrient.array))
          .throws<FormatException>();
      check(() => DataFrame.fromJson('[123]', orient: JsonOrient.array))
          .throws<FormatException>();
      check(() => DataFrame.fromJson('"string"')).throws<FormatException>();

      // Empty inputs without columnTypes
      check(DataFrame.fromJson('[]', orient: JsonOrient.records).rowCount)
          .equals(0);
      check(DataFrame.fromJson('[]', orient: JsonOrient.array).rowCount)
          .equals(0);
      check(DataFrame.fromJson('{}', orient: JsonOrient.columns).rowCount)
          .equals(0);
      check(
        DataFrame.fromJson(
          '{"columns": ["a"], "data": []}',
          orient: JsonOrient.split,
          columnTypes: {'a': DataType.int32},
        ).columnNames,
      ).deepEquals(['a']);
    });
  });
}
