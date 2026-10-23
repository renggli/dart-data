import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/stats.dart';
import 'package:test/test.dart';

void main() {
  group('StudentDistribution moments and probabilities', () {
    test('moments, pdf, cdf, and quantile', () {
      final dist = StudentDistribution(10.0);
      check(dist.dof).equals(10.0);
      check(dist.mean).equals(0.0);
      check(dist.median).equals(0.0);
      check(dist.mode).equals(0.0);
      check(dist.variance).isCloseTo(10.0 / 8.0, 1e-6);
      check(dist.skewness).equals(0.0);
      check(dist.excessKurtosis).isCloseTo(6.0 / 6.0, 1e-6);
      check(dist.probability(0.0)).isGreaterThan(0.3);
      check(dist.cumulativeProbability(0.0)).isCloseTo(0.5, 1e-6);
      check(dist.inverseCumulativeProbability(0.5)).isCloseTo(0.0, 1e-6);
      // For df = 10, t_0.975 ≈ 2.2281
      check(dist.inverseCumulativeProbability(0.975)).isCloseTo(2.2281, 1e-3);
      check(() => dist.inverseCumulativeProbability(-0.1))
          .throws<InvalidProbability>();

      // Degenerate moments for small dof
      final distDof1 = StudentDistribution(1.0);
      check(distDof1.mean.isNaN).isTrue();
      check(distDof1.variance.isNaN).isTrue();
      check(distDof1.skewness.isNaN).isTrue();
      check(distDof1.excessKurtosis.isNaN).isTrue();

      final distDof2 = StudentDistribution(2.0);
      check(distDof2.mean).equals(0.0);
      check(distDof2.variance.isInfinite).isTrue();

      final distDof3 = StudentDistribution(3.0);
      check(distDof3.skewness.isNaN).isTrue();
      check(distDof3.excessKurtosis.isInfinite).isTrue();
    });
  });

  group('StudentDistribution estimation and validation', () {
    test('samples, fit, errors, and equality', () {
      final dist = StudentDistribution(10.0);
      // Fit
      final samples = dist.samples(random: math.Random(42)).take(2000).toList();
      final fitted = StudentDistribution.fit(samples);
      check(fitted.dof).isCloseTo(10.0, 3.5);
      check(() => StudentDistribution.fit(const [1.0, 2.0]))
          .throws<ArgumentError>();

      // Constructor validation
      check(() => StudentDistribution(0.0)).throws<ArgumentError>();
      check(() => StudentDistribution(-1.0)).throws<ArgumentError>();

      // Equality and toString
      check(dist == StudentDistribution(10.0)).isTrue();
      check(dist.hashCode).equals(StudentDistribution(10.0).hashCode);
      check(dist.toString()).contains('StudentDistribution');
    });
  });
}
