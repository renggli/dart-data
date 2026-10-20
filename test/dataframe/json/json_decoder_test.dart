import 'package:checks/checks.dart';
import 'package:data/dataframe.dart';
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

    test('decodes values_ format with auto-generated names', () {
      const json = '[[1, 2], [3, 4]]';
      final df = DataFrameJsonDecoder.decode(json, orient: JsonOrient.values_);
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
      ).equals(JsonOrient.values_);
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
        orient: JsonOrient.values_,
        columnTypes: {'v1': DataType.int32, 'v2': DataType.string},
      );
      check(dfVals.rowCount).equals(0);
      check(dfVals.columnNames).deepEquals(['v1', 'v2']);

      // values with columnTypes length exceeding row length
      final dfPadded = DataFrameJsonDecoder.decode(
        '[[10]]',
        orient: JsonOrient.values_,
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
}
