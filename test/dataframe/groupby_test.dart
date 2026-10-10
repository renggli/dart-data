import 'package:checks/checks.dart';
import 'package:data/dataframe.dart';
import 'package:test/test.dart';

void main() {
  group('GroupBy - Safe Composite Keys', () {
    test('distinguishes null and string "null" groups', () {
      final df = DataFrame.fromColumns({
        'key': [null, 'null', null, 'null', 'valid'],
        'val': [10, 20, 30, 40, 50],
      });

      final grouped = df.groupBy(['key']);
      final result = grouped.aggregate({
        'val': [Agg.count, Agg.sum],
      });

      check(result.rowCount).equals(3);

      for (var row = 0; row < result.rowCount; row++) {
        final key = result['key'][row];
        if (key == null) {
          check(result['val_count'][row]).equals(2);
          check(result['val_sum'][row]).equals(40);
        } else if (key == 'null') {
          check(result['val_count'][row]).equals(2);
          check(result['val_sum'][row]).equals(60);
        } else if (key == 'valid') {
          check(result['val_count'][row]).equals(1);
          check(result['val_sum'][row]).equals(50);
        }
      }
    });

    test('distinguishes integer and string values in group keys', () {
      final df = DataFrame.fromColumns({
        'id': [1, '1', 1, '1'],
        'val': [100, 200, 300, 400],
      });

      final grouped = df.groupBy(['id']);
      final result = grouped.aggregate({
        'val': [Agg.count, Agg.sum],
      });

      check(result.rowCount).equals(2);

      for (var row = 0; row < result.rowCount; row++) {
        final id = result['id'][row];
        if (id == 1) {
          check(result['val_count'][row]).equals(2);
          check(result['val_sum'][row]).equals(400);
        } else if (id == '1') {
          check(result['val_count'][row]).equals(2);
          check(result['val_sum'][row]).equals(600);
        }
      }
    });

    test('prevents delimiter injection across composite grouping keys', () {
      // Row 1: col1 = 'a__#_#__b', col2 = 'c'
      // Row 2: col1 = 'a', col2 = 'b__#_#__c'
      final df = DataFrame.fromColumns({
        'col1': ['a__#_#__b', 'a'],
        'col2': ['c', 'b__#_#__c'],
        'amount': [10, 20],
      });

      final grouped = df.groupBy(['col1', 'col2']);
      final result = grouped.aggregate({
        'amount': [Agg.count, Agg.sum],
      });

      // Must result in 2 distinct groups, not merged into 1
      check(result.rowCount).equals(2);
      check(result['amount_count'].toList()).deepEquals([1, 1]);
      check(result['amount_sum'].toList()).deepEquals([10, 20]);
    });

    test('groups with 2 columns (pair extractor)', () {
      final df = DataFrame.fromColumns({
        'dept': ['IT', 'IT', 'HR', 'HR'],
        'role': ['Dev', 'QA', 'Dev', 'QA'],
        'salary': [100, 80, 90, 70],
      });

      final grouped = df.groupBy(['dept', 'role']);
      final result = grouped.aggregate({
        'salary': [Agg.count],
      });

      check(result.rowCount).equals(4);
      check(result['salary_count'].toList()).deepEquals([1, 1, 1, 1]);
    });

    test('groups with 3 columns (triple extractor)', () {
      final df = DataFrame.fromColumns({
        'c1': [1, 1, 1, 2],
        'c2': ['a', 'a', 'b', 'a'],
        'c3': [true, true, false, true],
        'metric': [10.0, 20.0, 30.0, 40.0],
      });

      final grouped = df.groupBy(['c1', 'c2', 'c3']);
      final result = grouped.aggregate({
        'metric': [Agg.sum],
      });

      check(result.rowCount).equals(3);

      for (var row = 0; row < result.rowCount; row++) {
        if (result['c1'][row] == 1 &&
            result['c2'][row] == 'a' &&
            result['c3'][row] == true) {
          check(result['metric_sum'][row]).equals(30.0);
        }
      }
    });

    test('groups with 4+ columns (TupleKey extractor)', () {
      final df = DataFrame.fromColumns({
        'k1': [1, 1, 2],
        'k2': ['a', 'a', 'a'],
        'k3': [true, true, false],
        'k4': [10.5, 10.5, 20.5],
        'val': [1, 2, 3],
      });

      final grouped = df.groupBy(['k1', 'k2', 'k3', 'k4']);
      final result = grouped.aggregate({
        'val': [Agg.count, Agg.sum],
      });

      check(result.rowCount).equals(2);
      check(result['val_count'].toList()).deepEquals([2, 1]);
      check(result['val_sum'].toList()).deepEquals([3, 3]);
    });
  });

  group('GroupBy - Aggregations & Convenience Methods', () {
    test('computes all aggregation operations', () {
      final df = DataFrame.fromColumns({
        'g': ['A', 'A', 'A', 'B'],
        'v': [10.0, 20.0, 30.0, null],
      });

      final result = df.groupBy(['g']).aggregate({
        'v': [
          Agg.count,
          Agg.sum,
          Agg.mean,
          Agg.min,
          Agg.max,
          Agg.first,
          Agg.last,
          Agg.std,
        ],
      });

      check(result.rowCount).equals(2);

      // Group A
      check(result['v_count'][0]).equals(3);
      check(result['v_sum'][0]).equals(60.0);
      check(result['v_mean'][0]).equals(20.0);
      check(result['v_min'][0]).equals(10.0);
      check(result['v_max'][0]).equals(30.0);
      check(result['v_first'][0]).equals(10.0);
      check(result['v_last'][0]).equals(30.0);
      check(result['v_std'][0]).equals(10.0);

      // Group B (only null value)
      check(result['v_count'][1]).equals(0);
      check(result['v_sum'][1]).equals(0);
      check(result['v_mean'][1]).isNull();
      check(result['v_min'][1]).isNull();
      check(result['v_max'][1]).isNull();
      check(result['v_first'][1]).isNull();
      check(result['v_last'][1]).isNull();
      check(result['v_std'][1]).equals(0.0);
    });

    test('mean(), sum(), count() convenience methods', () {
      final df = DataFrame.fromColumns({
        'team': ['alpha', 'alpha', 'beta'],
        'score': [10.0, 20.0, 30.0],
      });

      final grouped = df.groupBy(['team']);

      final meanDf = grouped.mean();
      check(meanDf['team'].toList()).deepEquals(['alpha', 'beta']);
      check(meanDf['score_mean'].toList()).deepEquals([15.0, 30.0]);

      final sumDf = grouped.sum();
      check(sumDf['score_sum'].toList()).deepEquals([30.0, 30.0]);

      final countDf = grouped.count();
      check(countDf['score_count'].toList()).deepEquals([2, 1]);
    });
  });

  group('GroupBy - Validation & Errors', () {
    test('throws ArgumentError on empty byColumns', () {
      final df = DataFrame.fromColumns({
        'a': [1, 2],
      });
      check(() => df.groupBy([])).throws<ArgumentError>();
    });

    test('throws ArgumentError on missing column', () {
      final df = DataFrame.fromColumns({
        'a': [1, 2],
      });
      check(() => df.groupBy(['missing'])).throws<ArgumentError>();
    });

    test('preserves key column values without coercing them to double', () {
      final df = DataFrame([
        ObjectSeries<Object?>.fromList('k', [1, 2.5, 1]),
        Series.fromList('v', [10.0, 20.0, 30.0]),
      ]);

      final grouped = df.groupBy(['k']);
      final result = grouped.aggregate({
        'v': [Agg.sum],
      });

      check(result.rowCount).equals(2);
      // Key 1 must remain integer 1, not coerced to 1.0
      check(result['k'][0]).equals(1);
      check(result['k'][0]).isA<int>();
      check(result['v_sum'][0]).equals(40.0);
      check(result['k'][1]).equals(2.5);
      check(result['v_sum'][1]).equals(20.0);
    });

    test('handles 4+ column grouping with nulls and string nulls', () {
      final df = DataFrame.fromColumns({
        'k1': [1, 1, 1],
        'k2': ['a', 'a', 'a'],
        'k3': [true, true, true],
        'k4': [null, 'null', null],
        'v': [10, 20, 30],
      });

      final grouped = df.groupBy(['k1', 'k2', 'k3', 'k4']);
      final result = grouped.aggregate({
        'v': [Agg.count, Agg.sum],
      });

      // null and 'null' should form 2 distinct groups
      check(result.rowCount).equals(2);
      check(result['v_count'].toList()).deepEquals([2, 1]);
      check(result['v_sum'].toList()).deepEquals([40, 20]);
    });

    test('handles empty DataFrame grouping', () {
      final emptyDf = DataFrame.fromColumns({'k': [], 'v': []});
      final grouped = emptyDf.groupBy(['k']);
      final result = grouped.aggregate({
        'v': [Agg.count, Agg.sum],
      });

      check(result.rowCount).equals(0);
      check(result.columnNames).deepEquals(['k', 'v_count', 'v_sum']);
    });
  });
}
