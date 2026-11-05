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
      check(res.pValue).isGreaterThan(0.5);
    });

    test('edge cases and argument validation', () {
      check(() => shapiroWilkTest([1.0, 2.0])).throws<ArgumentError>();

      final nanRes = shapiroWilkTest([1.0, double.nan, 3.0]);
      check(nanRes.statistic.isNaN).isTrue();
      check(nanRes.pValue.isNaN).isTrue();

      final constRes = shapiroWilkTest([4.0, 4.0, 4.0, 4.0]);
      check(constRes.statistic.isNaN).isTrue();
      check(constRes.pValue.isNaN).isTrue();
    });
  });
}
