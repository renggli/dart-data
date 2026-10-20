import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/stats.dart';
import 'package:test/test.dart';

void main() {
  group('jarque-bera', () {
    test('Jarque-Bera normality test', () {
      const normal = NormalDistribution.standard();
      final normalSample = normal
          .samples(random: math.Random(42))
          .take(200)
          .toList();

      final resNormal = jarqueBeraTest(normalSample);
      check(resNormal.isSignificant).isFalse();
      check(resNormal.degreesOfFreedom).equals(2.0);
      check(resNormal.pValue).isGreaterThan(0.05);

      const uniform = UniformDistribution(0.0, 1.0);
      final uniformSample = uniform
          .samples(random: math.Random(42))
          .take(200)
          .toList();

      final resUniform = jarqueBeraTest(uniformSample);
      check(resUniform.isSignificant).isTrue();
      check(resUniform.pValue).isLessThan(0.01);

      check(() => jarqueBeraTest([1.0, 2.0, 3.0])).throws<ArgumentError>();
    });
  });
}
