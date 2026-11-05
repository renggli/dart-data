import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/stats.dart';
import 'package:test/test.dart';

void main() {
  group('jarque-bera', () {
    test('normal distribution sample is not significant', () {
      const normal = NormalDistribution.standard();
      final normalSample = normal
          .samples(random: math.Random(42))
          .take(200)
          .toList();

      final resNormal = jarqueBeraTest(normalSample);
      check(resNormal.isSignificant).isFalse();
      check(resNormal.degreesOfFreedom).equals(2.0);
      check(resNormal.pValue).isGreaterThan(0.05);
    });

    test('uniform distribution sample is significant', () {
      const uniform = UniformDistribution.standard();
      final uniformSample = uniform
          .samples(random: math.Random(42))
          .take(200)
          .toList();

      final resUniform = jarqueBeraTest(uniformSample);
      check(resUniform.isSignificant).isTrue();
      check(resUniform.pValue).isLessThan(0.01);
    });

    test('insufficient sample size throws ArgumentError', () {
      check(() => jarqueBeraTest([1.0, 2.0, 3.0])).throws<ArgumentError>();
    });

    test('constant sample yields NaN statistic and p-value', () {
      final constRes = jarqueBeraTest([5.0, 5.0, 5.0, 5.0]);
      check(constRes.statistic.isNaN).isTrue();
      check(constRes.pValue.isNaN).isTrue();
    });
  });
}
