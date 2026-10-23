import 'dart:convert';

import 'package:checks/checks.dart';
import 'package:data/dataframe.dart';
import 'package:data/src/dataframe/json/json_encoder.dart';
import 'package:test/test.dart';

void main() {
  group('DataFrameJsonEncoder', () {
    final df = DataFrame([
      Series.fromList('id', [1, 2]),
      Series.fromList('name', ['Alice', 'Bob']),
    ]);

    test('encodes records orientation', () {
      final jsonStr = DataFrameJsonEncoder.encode(
        df,
        orient: JsonOrient.records,
      );
      final decoded = (jsonDecode(jsonStr) as List<dynamic>)
          .cast<Map<String, dynamic>>();
      check(decoded.length).equals(2);
      check(decoded[0]).deepEquals({'id': 1, 'name': 'Alice'});
      check(decoded[1]).deepEquals({'id': 2, 'name': 'Bob'});
    });

    test('encodes split orientation', () {
      final jsonStr = DataFrameJsonEncoder.encode(df, orient: JsonOrient.split);
      final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
      check((decoded['columns'] as List<dynamic>).cast<String>())
          .deepEquals(['id', 'name']);
      check((decoded['data'] as List<dynamic>).cast<List<dynamic>>())
          .deepEquals([
            [1, 'Alice'],
            [2, 'Bob'],
          ]);
    });

    test('encodes columns orientation', () {
      final jsonStr = DataFrameJsonEncoder.encode(
        df,
        orient: JsonOrient.columns,
      );
      final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
      check((decoded['id'] as List<dynamic>).cast<int>()).deepEquals([1, 2]);
      check((decoded['name'] as List<dynamic>).cast<String>())
          .deepEquals(['Alice', 'Bob']);
    });

    test('encodes values_ orientation', () {
      final jsonStr = DataFrameJsonEncoder.encode(
        df,
        orient: JsonOrient.values_,
      );
      final decoded = (jsonDecode(jsonStr) as List<dynamic>)
          .cast<List<dynamic>>();
      check(decoded).deepEquals([
        [1, 'Alice'],
        [2, 'Bob'],
      ]);
    });

    test('toRecords returns list of maps', () {
      final records = DataFrameJsonEncoder.toRecords(df);
      check(records.length).equals(2);
      check(records[0]).deepEquals({'id': 1, 'name': 'Alice'});
      check(records[1]).deepEquals({'id': 2, 'name': 'Bob'});
    });
  });
}
