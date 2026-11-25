import 'package:checks/checks.dart';
import 'package:data/stats.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('kruskalWallisTest', () {
    test('detects location shift across three ordered groups', () {
      final g1 = [1.0, 2.0, 3.0, 4.0];
      final g2 = [5.0, 6.0, 7.0, 8.0];
      final g3 = [9.0, 10.0, 11.0, 12.0];

      final res = kruskalWallisTest([g1, g2, g3]);
      check(res.testName).equals('Kruskal-Wallis H Test');
      check(res.degreesOfFreedom).equals(2.0);
      // With 3 disjoint groups of size 4, H = 9.846153846...
      check(res.statistic).isCloseTo(9.846153846153847, 1e-10);
      check(res.isSignificant).isTrue;
      check(res.pValue).isLessThan(0.01);
    });

    test('applies tie correction accurately and handles all-equal samples', () {
      final tied = kruskalWallisTest([
        [1.0, 2.0, 2.0, 3.0],
        [2.0, 3.0, 3.0, 4.0],
      ]);
      check(tied.statistic).isGreaterThan(0.0);
      check(tied.pValue).isLessThan(1.0);

      final identical = kruskalWallisTest([
        [5.0, 5.0, 5.0],
        [5.0, 5.0, 5.0],
      ]);
      check(identical.statistic).equals(0.0);
      check(identical.pValue).equals(1.0);
      check(identical.isSignificant).isFalse;
    });

    test('returns NaN on NaN observations', () {
      final res = kruskalWallisTest([
        [1.0, double.nan],
        [2.0, 3.0],
      ]);
      check(res.statistic.isNaN).isTrue;
      check(res.pValue.isNaN).isTrue;
      check(res.degreesOfFreedom).equals(1.0);
    });

    test('validates group count, emptiness, and alpha', () {
      check(
        () => kruskalWallisTest([
          [1.0, 2.0],
        ]),
      ).throws<ArgumentError>();
      check(
        () => kruskalWallisTest([
          [1.0, 2.0],
          <double>[],
        ]),
      ).throws<ArgumentError>();
      check(
        () => kruskalWallisTest([
          [1.0, 2.0],
          [3.0, 4.0],
        ], alpha: 1.0),
      ).throws<ArgumentError>();
    });
  });
}
