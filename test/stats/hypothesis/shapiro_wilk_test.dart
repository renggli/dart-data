import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/stats.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('shapiroWilkTest', () {
    test('accepts normal samples and rejects skewed or uniform samples', () {
      const normal = NormalDistribution.standard();
      final normalSample = normal
          .samples(random: math.Random(123))
          .take(50)
          .toList();
      final resNormal = shapiroWilkTest(normalSample);
      check(resNormal.testName).equals('Shapiro-Wilk Normality Test');
      check(resNormal.degreesOfFreedom).isNull;
      check(resNormal.statistic).isGreaterThan(0.90);
      check(resNormal.pValue).isGreaterThan(0.05);
      check(resNormal.isSignificant).isFalse;

      const uniform = UniformDistribution.standard();
      final uniformSample = uniform
          .samples(random: math.Random(456))
          .take(100)
          .toList();
      final resUniform = shapiroWilkTest(uniformSample);
      check(resUniform.statistic).isLessThan(0.98);
      check(resUniform.pValue).isLessThan(0.05);
      check(resUniform.isSignificant).isTrue;
    });

    test('matches exact n=3 and AS R94 (4 <= n <= 11) reference values', () {
      final res3 = shapiroWilkTest(const [1.0, 2.0, 3.0]);
      check(res3.statistic).isCloseTo(1.0, 1e-12);
      check(res3.pValue).isCloseTo(1.0, 1e-12);

      final res3Skewed = shapiroWilkTest(const [1.0, 1.0, 10.0]);
      check(res3Skewed.statistic).isLessThan(0.8);
      check(res3Skewed.pValue).isLessThan(0.5);

      final res4 = shapiroWilkTest(const [1.0, 2.0, 3.0, 4.0]);
      check(res4.statistic).isCloseTo(0.99291, 1e-4);
      check(res4.pValue).isCloseTo(0.97188, 1e-4);

      final res5 = shapiroWilkTest(const [1.0, 2.0, 3.0, 4.0, 5.0]);
      check(res5.statistic).isCloseTo(0.98676, 1e-4);
      check(res5.pValue).isCloseTo(0.96717, 1e-4);

      final res10 = shapiroWilkTest(const [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
      check(res10.statistic).isCloseTo(0.97016, 1e-4);
      check(res10.pValue).isCloseTo(0.89237, 1e-4);

      final outlier = shapiroWilkTest(const [1.0, 1.1, 1.2, 1000.0]);
      check(outlier.statistic).isLessThan(0.7);
      check(outlier.pValue).isLessThan(0.01);
    });

    test('maintains translation invariance under huge constant offsets', () {
      final base = shapiroWilkTest(const [1.0, 2.0, 4.0, 7.0, 11.0]);
      final shifted = shapiroWilkTest(const [
        1e12 + 1.0,
        1e12 + 2.0,
        1e12 + 4.0,
        1e12 + 7.0,
        1e12 + 11.0,
      ]);
      check(shifted.statistic).isCloseTo(base.statistic, 1e-4);
      check(shifted.pValue).isCloseTo(base.pValue, 1e-4);
    });

    test('returns NaN on constant or non-finite inputs and validates sample size and alpha', () {
      final nanRes = shapiroWilkTest(const [1.0, double.nan, 3.0]);
      check(nanRes.statistic.isNaN).isTrue;
      check(nanRes.pValue.isNaN).isTrue;

      final infRes = shapiroWilkTest(const [1.0, double.infinity, 3.0]);
      check(infRes.statistic.isNaN).isTrue;
      check(infRes.pValue.isNaN).isTrue;

      final constRes = shapiroWilkTest(const [4.0, 4.0, 4.0, 4.0]);
      check(constRes.statistic.isNaN).isTrue;
      check(constRes.pValue.isNaN).isTrue;

      check(() => shapiroWilkTest(const [1.0, 2.0])).throws<ArgumentError>();
      check(
        () => shapiroWilkTest(
          Iterable<double>.generate(5001, (i) => i.toDouble()),
        ),
      ).throws<ArgumentError>();
      check(() => shapiroWilkTest(const [1.0, 2.0, 3.0], alpha: 0.0))
          .throws<ArgumentError>();
    });
  });
}
