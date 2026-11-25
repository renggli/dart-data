import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/stats.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('jarqueBeraTest', () {
    test('does not reject standard normal sample', () {
      const normal = NormalDistribution.standard();
      final normalSample = normal
          .samples(random: math.Random(42))
          .take(200)
          .toList();

      final resNormal = jarqueBeraTest(normalSample);
      check(resNormal.isSignificant).isFalse;
      check(resNormal.degreesOfFreedom).equals(2.0);
      check(resNormal.pValue).isGreaterThan(0.05);
    });

    test('rejects uniform non-normal sample', () {
      const uniform = UniformDistribution.standard();
      final uniformSample = uniform
          .samples(random: math.Random(42))
          .take(200)
          .toList();

      final resUniform = jarqueBeraTest(uniformSample);
      check(resUniform.isSignificant).isTrue;
      check(resUniform.pValue).isLessThan(0.01);
    });

    test('is scale invariant under huge magnitudes', () {
      final base = jarqueBeraTest(const [1.0, 2.0, 2.0, 3.0, 10.0]);
      final scaled = jarqueBeraTest(const [1e100, 2e100, 2e100, 3e100, 1e101]);
      check(scaled.statistic).isCloseTo(base.statistic, 1e-12);
      check(scaled.pValue).isCloseTo(base.pValue, 1e-12);
    });

    test('returns NaN for constant or non-finite samples', () {
      final constRes = jarqueBeraTest(const [5.0, 5.0, 5.0, 5.0]);
      check(constRes.statistic.isNaN).isTrue;
      check(constRes.pValue.isNaN).isTrue;

      final nanRes = jarqueBeraTest(const [1.0, 2.0, double.nan, 4.0]);
      check(nanRes.statistic.isNaN).isTrue;
      check(nanRes.pValue.isNaN).isTrue;
    });

    test('validates minimum sample size and alpha', () {
      check(() => jarqueBeraTest(const [1.0, 2.0, 3.0]))
          .throws<ArgumentError>();
      check(() => jarqueBeraTest(const [1.0, 2.0, 3.0, 4.0], alpha: 1.0))
          .throws<ArgumentError>();
    });
  });
}
