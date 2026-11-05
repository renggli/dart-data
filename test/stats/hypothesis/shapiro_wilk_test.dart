import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/stats.dart';
import 'package:test/test.dart';

void main() {
  group('shapiro-wilk', () {
    test('standard normal sample has high W and non-significant p-value', () {
      const normal = NormalDistribution.standard();
      final sample = normal.samples(random: math.Random(123)).take(50).toList();

      final res = shapiroWilkTest(sample);
      check(res.testName).equals('Shapiro-Wilk Normality Test');
      check(res.statistic).isGreaterThan(0.90);
      check(res.pValue).isGreaterThan(0.05);
      check(res.isSignificant).isFalse();
    });

    test(
      'strongly non-normal uniform sample has lower W and significant p-value',
      () {
        const uniform = UniformDistribution.standard();
        final sample = uniform
            .samples(random: math.Random(456))
            .take(100)
            .toList();

        final res = shapiroWilkTest(sample);
        check(res.statistic).isLessThan(0.98);
        check(res.pValue).isLessThan(0.05);
        check(res.isSignificant).isTrue();
      },
    );

    test('sample size 3 exact branch', () {
      final res = shapiroWilkTest([1.0, 2.0, 3.0]);
      check(res.statistic).isCloseTo(1.0, 1e-12);
      check(res.pValue).isCloseTo(1.0, 1e-12);

      final resSkewed = shapiroWilkTest([1.0, 1.0, 10.0]);
      check(resSkewed.statistic).isLessThan(0.8);
      check(resSkewed.pValue).isLessThan(0.5);
    });

    test('small sample sizes (4 <= n <= 11) match Royston AS R94', () {
      final res4 = shapiroWilkTest([1.0, 2.0, 3.0, 4.0]);
      check(res4.statistic).isCloseTo(0.99291, 1e-4);
      check(res4.pValue).isCloseTo(0.97188, 1e-4);

      final res5 = shapiroWilkTest([1.0, 2.0, 3.0, 4.0, 5.0]);
      check(res5.statistic).isCloseTo(0.98676, 1e-4);
      check(res5.pValue).isCloseTo(0.96717, 1e-4);

      final res10 = shapiroWilkTest([
        1.0,
        2.0,
        3.0,
        4.0,
        5.0,
        6.0,
        7.0,
        8.0,
        9.0,
        10.0,
      ]);
      check(res10.statistic).isCloseTo(0.97016, 1e-4);
      check(res10.pValue).isCloseTo(0.89237, 1e-4);
    });

    test('small sample with extreme outlier reaches low p-value', () {
      final res = shapiroWilkTest([1.0, 1.1, 1.2, 1000.0]);
      check(res.statistic).isLessThan(0.7);
      check(res.pValue).isLessThan(0.01);
      check(res.isSignificant).isTrue();
    });

    test('edge cases and argument validation', () {
      check(() => shapiroWilkTest([1.0, 2.0])).throws<ArgumentError>();
      check(
        () => shapiroWilkTest(
          Iterable<double>.generate(5001, (i) => i.toDouble()),
        ),
      ).throws<ArgumentError>();

      final nanRes = shapiroWilkTest([1.0, double.nan, 3.0]);
      check(nanRes.statistic.isNaN).isTrue();
      check(nanRes.pValue.isNaN).isTrue();

      final constRes = shapiroWilkTest([4.0, 4.0, 4.0, 4.0]);
      check(constRes.statistic.isNaN).isTrue();
      check(constRes.pValue.isNaN).isTrue();
    });
  });
}
