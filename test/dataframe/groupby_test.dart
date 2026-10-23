import 'dart:math' as math;

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
          Agg.variance,
          Agg.median,
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
      check(result['v_variance'][0]).equals(100.0);
      check(result['v_median'][0]).equals(20.0);

      // Group B (only null value)
      check(result['v_count'][1]).equals(0);
      check(result['v_sum'][1]).equals(0);
      check(result['v_mean'][1]).isNull();
      check(result['v_min'][1]).isNull();
      check(result['v_max'][1]).isNull();
      check(result['v_first'][1]).isNull();
      check(result['v_last'][1]).isNull();
      check(result['v_std'][1]).equals(0.0);
      check(result['v_variance'][1]).isNull();
      check(result['v_median'][1]).isNull();
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

    test('count() counts non-null entries for every non-key column', () {
      final df = DataFrame.fromColumns({
        'group': ['A', 'A', 'B'],
        'v1': [1, null, 3],
        'v2': ['x', 'y', 'z'],
      });
      final countDf = df.groupBy(['group']).count();
      check(countDf.columnNames).deepEquals(['group', 'v1_count', 'v2_count']);
      check(countDf['v1_count'].toList()).deepEquals([1, 1]);
      check(countDf['v2_count'].toList()).deepEquals([2, 1]);
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

  group('GroupBy - Median & Variance Aggregations', () {
    test('computes median across odd and even group sizes', () {
      final df = DataFrame.fromColumns({
        'group': [
          'odd_3',
          'odd_3',
          'odd_3',
          'odd_5',
          'odd_5',
          'odd_5',
          'odd_5',
          'odd_5',
          'even_2',
          'even_2',
          'even_4',
          'even_4',
          'even_4',
          'even_4',
          'even_6',
          'even_6',
          'even_6',
          'even_6',
          'even_6',
          'even_6',
          'dupes',
          'dupes',
          'dupes',
          'dupes',
        ],
        'val': [
          30.0,
          10.0,
          20.0,
          50.0,
          10.0,
          40.0,
          20.0,
          30.0,
          100.0,
          200.0,
          40.0,
          10.0,
          30.0,
          20.0,
          60.0,
          10.0,
          50.0,
          20.0,
          40.0,
          30.0,
          5.0,
          5.0,
          5.0,
          5.0,
        ],
      });

      final res = df.groupBy(['group']).aggregate({
        'val': [Agg.median],
      });

      final map = <String, double>{};
      for (var row = 0; row < res.rowCount; row++) {
        map[res['group'][row] as String] = res['val_median'][row] as double;
      }

      check(map['odd_3']).equals(20.0);
      check(map['odd_5']).equals(30.0);
      check(map['even_2']).equals(150.0);
      check(map['even_4']).equals(25.0);
      check(map['even_6']).equals(35.0);
      check(map['dupes']).equals(5.0);
    });

    test('returns null for variance on single-element groups', () {
      final dfWithPair = DataFrame.fromColumns({
        'group': ['single_a', 'single_b', 'pair', 'pair'],
        'val': [42.0, 99.0, 10.0, 20.0],
      });

      final res = dfWithPair.groupBy(['group']).aggregate({
        'val': [Agg.count, Agg.variance, Agg.median],
      });

      for (var row = 0; row < res.rowCount; row++) {
        final g = res['group'][row];
        if (g == 'single_a') {
          check(res['val_count'][row]).equals(1);
          check(res['val_variance'][row]).isNull();
          check(res['val_median'][row]).equals(42.0);
        } else if (g == 'single_b') {
          check(res['val_count'][row]).equals(1);
          check(res['val_variance'][row]).isNull();
          check(res['val_median'][row]).equals(99.0);
        } else if (g == 'pair') {
          check(res['val_count'][row]).equals(2);
          check(res['val_variance'][row]).equals(50.0);
          check(res['val_median'][row]).equals(15.0);
        }
      }
    });

    test('handles missing and null values in variance and median', () {
      final df = DataFrame.fromColumns({
        'cat': [
          'all_null',
          'all_null',
          'one_valid',
          'one_valid',
          'mixed',
          'mixed',
          'mixed',
          'mixed',
          'mixed',
        ],
        'x': [null, null, null, 100.0, 10.0, null, 20.0, null, 30.0],
      });

      final res = df.groupBy(['cat']).aggregate({
        'x': [Agg.count, Agg.variance, Agg.median],
      });

      for (var row = 0; row < res.rowCount; row++) {
        final cat = res['cat'][row];
        if (cat == 'all_null') {
          check(res['x_count'][row]).equals(0);
          check(res['x_variance'][row]).isNull();
          check(res['x_median'][row]).isNull();
        } else if (cat == 'one_valid') {
          check(res['x_count'][row]).equals(1);
          check(res['x_variance'][row]).isNull();
          check(res['x_median'][row]).equals(100.0);
        } else if (cat == 'mixed') {
          check(res['x_count'][row]).equals(3);
          check(res['x_variance'][row]).equals(100.0);
          check(res['x_median'][row]).equals(20.0);
        }
      }
    });

    test('validates variance against known statistical baselines (Bessel correction n - 1)', () {
      final df = DataFrame.fromColumns({
        'set': [
          'b1',
          'b1',
          'b1',
          'b1',
          'b1',
          'b1',
          'b1',
          'b1',
          'b2',
          'b2',
          'b2',
          'b2',
          'b2',
        ],
        'v': [
          2.0,
          4.0,
          4.0,
          4.0,
          5.0,
          5.0,
          7.0,
          9.0,
          10.0,
          20.0,
          30.0,
          40.0,
          50.0,
        ],
      });

      final res = df.groupBy(['set']).aggregate({
        'v': [Agg.mean, Agg.variance, Agg.std, Agg.median],
      });

      for (var row = 0; row < res.rowCount; row++) {
        final s = res['set'][row];
        if (s == 'b1') {
          check(res['v_mean'][row]).equals(5.0);
          final var1 = res['v_variance'][row] as double;
          check(var1).isCloseTo(32.0 / 7.0, 1e-12);
          final std1 = res['v_std'][row] as double;
          check(std1).isCloseTo(math.sqrt(32.0 / 7.0), 1e-12);
          check(res['v_median'][row]).equals(4.5);
        } else if (s == 'b2') {
          check(res['v_mean'][row]).equals(30.0);
          check(res['v_variance'][row]).equals(250.0);
          final std2 = res['v_std'][row] as double;
          check(std2).isCloseTo(math.sqrt(250.0), 1e-12);
          check(res['v_median'][row]).equals(30.0);
        }
      }
    });

    test('multi-column groupings with combined aggregations', () {
      final df = DataFrame.fromColumns({
        'dept': ['IT', 'IT', 'IT', 'HR', 'HR'],
        'role': ['dev', 'dev', 'qa', 'recruiter', 'recruiter'],
        'salary': [100.0, 120.0, 90.0, 50.0, 70.0],
      });

      final res = df.groupBy(['dept', 'role']).aggregate({
        'salary': [Agg.count, Agg.mean, Agg.variance, Agg.median, Agg.std],
      });

      check(res.rowCount).equals(3);

      for (var row = 0; row < res.rowCount; row++) {
        final dept = res['dept'][row];
        final role = res['role'][row];
        if (dept == 'IT' && role == 'dev') {
          check(res['salary_count'][row]).equals(2);
          check(res['salary_mean'][row]).equals(110.0);
          check(res['salary_variance'][row]).equals(200.0);
          check(res['salary_median'][row]).equals(110.0);
          final stdVal = res['salary_std'][row] as double;
          check(stdVal).isCloseTo(math.sqrt(200.0), 1e-12);
        } else if (dept == 'IT' && role == 'qa') {
          check(res['salary_count'][row]).equals(1);
          check(res['salary_mean'][row]).equals(90.0);
          check(res['salary_variance'][row]).isNull();
          check(res['salary_median'][row]).equals(90.0);
          check(res['salary_std'][row]).equals(0.0);
        } else if (dept == 'HR' && role == 'recruiter') {
          check(res['salary_count'][row]).equals(2);
          check(res['salary_mean'][row]).equals(60.0);
          check(res['salary_variance'][row]).equals(200.0);
          check(res['salary_median'][row]).equals(60.0);
          final stdVal = res['salary_std'][row] as double;
          check(stdVal).isCloseTo(math.sqrt(200.0), 1e-12);
        }
      }
    });

    test(
      'handles negative values, all-identical values, and non-numeric columns',
      () {
        final df = DataFrame.fromColumns({
          'group': [
            'neg',
            'neg',
            'neg',
            'ident',
            'ident',
            'ident',
            'str',
            'str',
          ],
          'val': [-30.0, -10.0, -20.0, 7.0, 7.0, 7.0, 'a', 'b'],
        });

        final res = df.groupBy(['group']).aggregate({
          'val': [Agg.median, Agg.variance],
        });

        for (var row = 0; row < res.rowCount; row++) {
          final g = res['group'][row];
          if (g == 'neg') {
            check(res['val_median'][row]).equals(-20.0);
            check(res['val_variance'][row]).equals(100.0);
          } else if (g == 'ident') {
            check(res['val_median'][row]).equals(7.0);
            check(res['val_variance'][row]).equals(0.0);
          } else if (g == 'str') {
            check(res['val_median'][row]).isNull();
            check(res['val_variance'][row]).isNull();
          }
        }
      },
    );

    test('propagates NaN in median and variance', () {
      final df = DataFrame.fromColumns({
        'group': ['nan_grp', 'nan_grp', 'nan_grp'],
        'val': [1.0, double.nan, 3.0],
      });

      final res = df.groupBy(['group']).aggregate({
        'val': [Agg.median, Agg.variance],
      });

      check((res['val_median'][0] as double).isNaN).isTrue();
      check((res['val_variance'][0] as double).isNaN).isTrue();
    });

    test(
      'computes median across randomized permutations of odd and even sizes',
      () {
        final rnd = math.Random(12345);
        for (final n in [1, 2, 3, 4, 5, 7, 8, 10, 15, 16, 25, 30]) {
          final values = List.generate(n, (_) => rnd.nextDouble() * 100.0);
          final sorted = List<double>.from(values)..sort();
          final expectedMedian = (sorted[(n - 1) ~/ 2] + sorted[n ~/ 2]) / 2.0;

          final df = DataFrame.fromColumns({
            'k': List.filled(n, 'g'),
            'v': values,
          });
          final res = df.groupBy(['k']).aggregate({
            'v': [Agg.median],
          });
          check(res['v_median'][0] as double).isCloseTo(expectedMedian, 1e-12);
        }
      },
    );
  });
}
