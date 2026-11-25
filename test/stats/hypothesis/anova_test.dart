import 'package:checks/checks.dart';
import 'package:data/stats.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('oneWayAnova', () {
    test('detects significant mean differences across groups', () {
      final g1 = [1.0, 2.0, 3.0, 2.5, 1.5];
      final g2 = [10.0, 11.0, 9.5, 10.5, 11.2];
      final g3 = [20.0, 19.5, 21.0, 20.5, 19.8];

      final res = oneWayAnova([g1, g2, g3]);
      check(res.isSignificant).isTrue;
      check(res.pValue).isLessThan(1e-6);
      check(res.statistic).isGreaterThan(100.0);
      check(res.degreesOfFreedom).equals(2.0);
      check(res.denominatorDegreesOfFreedom).equals(12.0);
    });

    test('preserves numerical stability under large constant offsets', () {
      final g1 = [1e9 + 1.0, 1e9 + 2.0, 1e9 + 3.0];
      final g2 = [1e9 + 4.0, 1e9 + 5.0, 1e9 + 6.0];
      final base = oneWayAnova([
        [1.0, 2.0, 3.0],
        [4.0, 5.0, 6.0],
      ]);
      final shifted = oneWayAnova([g1, g2]);
      check(shifted.statistic).isCloseTo(base.statistic, 1e-10);
      check(shifted.pValue).isCloseTo(base.pValue, 1e-10);
    });

    test('handles zero within-group variance cleanly', () {
      final resDiff = oneWayAnova([
        [1.0, 1.0],
        [2.0, 2.0],
      ]);
      check(resDiff.statistic).equals(double.infinity);
      check(resDiff.pValue).equals(0.0);
      check(resDiff.isSignificant).isTrue;

      final resSame = oneWayAnova([
        [1.0, 1.0],
        [1.0, 1.0],
      ]);
      check(resSame.statistic).equals(0.0);
      check(resSame.pValue).equals(1.0);
      check(resSame.isSignificant).isFalse;
    });

    test('returns NaN on non-finite observations', () {
      final nanRes = oneWayAnova([
        [1.0, double.nan],
        [2.0, 3.0],
      ]);
      check(nanRes.statistic.isNaN).isTrue;
      check(nanRes.pValue.isNaN).isTrue;
      check(nanRes.degreesOfFreedom).equals(1.0);
      check(nanRes.denominatorDegreesOfFreedom).equals(2.0);
    });

    test('validates group counts, sizes, and alpha', () {
      check(
        () => oneWayAnova([
          [1.0, 2.0],
        ]),
      ).throws<ArgumentError>();
      check(
        () => oneWayAnova([
          [1.0, 2.0],
          <double>[],
        ]),
      ).throws<ArgumentError>();
      check(
        () => oneWayAnova([
          [1.0],
          [2.0],
        ]),
      ).throws<ArgumentError>();
      check(
        () => oneWayAnova([
          [1.0, 2.0],
          [3.0, 4.0],
        ], alpha: 0.0),
      ).throws<ArgumentError>();
    });
  });
}
