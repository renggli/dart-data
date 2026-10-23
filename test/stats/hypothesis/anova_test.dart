import 'package:checks/checks.dart';
import 'package:data/stats.dart';
import 'package:test/test.dart';

void main() {
  group('ANOVA', () {
    test('one-way ANOVA', () {
      // 3 groups with clearly separated means
      final g1 = [1.0, 2.0, 3.0, 2.5, 1.5];
      final g2 = [10.0, 11.0, 9.5, 10.5, 11.2];
      final g3 = [20.0, 19.5, 21.0, 20.5, 19.8];

      final res = oneWayAnova([g1, g2, g3]);
      check(res.isSignificant).isTrue();
      check(res.pValue).isLessThan(1e-6);
      check(res.statistic).isGreaterThan(100.0);

      // Errors
      check(() => oneWayAnova([g1])).throws<ArgumentError>();
      check(() => oneWayAnova([g1, <double>[]])).throws<ArgumentError>();
      check(
        () => oneWayAnova([
          [1.0],
          [2.0],
        ]),
      ).throws<ArgumentError>();
    });

    test('one-way ANOVA with zero within-group variance', () {
      // Different means with 0 within-group variance
      final resDiff = oneWayAnova([
        [1.0, 1.0],
        [2.0, 2.0],
      ]);
      check(resDiff.statistic).equals(double.infinity);
      check(resDiff.pValue).equals(0.0);
      check(resDiff.isSignificant).isTrue();

      // Identical means with 0 within-group variance
      final resSame = oneWayAnova([
        [1.0, 1.0],
        [1.0, 1.0],
      ]);
      check(resSame.statistic).equals(0.0);
      check(resSame.pValue).equals(1.0);
      check(resSame.isSignificant).isFalse();
    });
  });
}
