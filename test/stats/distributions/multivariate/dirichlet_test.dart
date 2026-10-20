import 'dart:math';

import 'package:checks/checks.dart';
import 'package:data/linear.dart';
import 'package:data/src/stats/distributions/multivariate/dirichlet.dart';
import 'package:test/test.dart';

void main() {
  group('DirichletDistribution', () {
    test('uniform Dirichlet (alpha = 1, 1, 1)', () {
      final dist = DirichletDistribution.symmetric(3, 1.0);
      check(dist.dimensions).equals(3);

      final pt = Vector<double>.fromList([1.0 / 3, 1.0 / 3, 1.0 / 3]);
      // B(1, 1, 1) = Gamma(1)^3 / Gamma(3) = 1 / 2! = 0.5.
      // pdf = 1 / 0.5 = 2.0.
      check(dist.probability(pt)).isCloseTo(2.0, 1e-6);

      // Outside simplex
      final bad = Vector<double>.fromList([0.5, 0.5, 0.5]);
      check(dist.probability(bad)).equals(0.0);
      check(dist.logProbability(bad)).equals(double.negativeInfinity);
    });

    test('mean and covariance', () {
      final alpha = Vector<double>.fromList([2.0, 3.0, 5.0]);
      final dist = DirichletDistribution(alpha);
      check(dist.mean.getUnchecked(0)).isCloseTo(0.2, 1e-6);
      check(dist.mean.getUnchecked(1)).isCloseTo(0.3, 1e-6);
      check(dist.mean.getUnchecked(2)).isCloseTo(0.5, 1e-6);

      // alpha0 = 10, denom = 100 * 11 = 1100
      // var(0) = 2 * 8 / 1100 = 16 / 1100
      check(dist.covariance.getUnchecked(0, 0)).isCloseTo(16.0 / 1100.0, 1e-6);
      // cov(0, 1) = -2 * 3 / 1100 = -6 / 1100
      check(dist.covariance.getUnchecked(0, 1)).isCloseTo(-6.0 / 1100.0, 1e-6);
    });

    test('sampling empirical moments', () {
      final alpha = Vector<double>.fromList([2.0, 3.0, 5.0]);
      final dist = DirichletDistribution(alpha);
      final rng = Random(123);
      const sampleCount = 3000;
      var sumX0 = 0.0;
      var sumX1 = 0.0;
      var sumX2 = 0.0;
      for (var i = 0; i < sampleCount; i++) {
        final s = dist.sample(random: rng);
        // Elements must sum to 1.0
        check(s.getUnchecked(0) + s.getUnchecked(1) + s.getUnchecked(2))
            .isCloseTo(1.0, 1e-6);
        sumX0 += s.getUnchecked(0);
        sumX1 += s.getUnchecked(1);
        sumX2 += s.getUnchecked(2);
      }
      check(sumX0 / sampleCount).isCloseTo(0.2, 0.02);
      check(sumX1 / sampleCount).isCloseTo(0.3, 0.02);
      check(sumX2 / sampleCount).isCloseTo(0.5, 0.02);
    });

    test('argument validation', () {
      check(() => DirichletDistribution(Vector<double>.fromList([1.0])))
          .throws<ArgumentError>();
      check(() => DirichletDistribution(Vector<double>.fromList([1.0, -0.5])))
          .throws<ArgumentError>();
      check(() => DirichletDistribution.symmetric(1, 1.0))
          .throws<ArgumentError>();
      check(() => DirichletDistribution.symmetric(2, -1.0))
          .throws<ArgumentError>();

      final dist = DirichletDistribution.symmetric(2, 1.0);
      check(() => dist.logProbability(Vector<double>.fromList([1.0])))
          .throws<ArgumentError>();
    });

    test('boundary evaluations where xi == 0', () {
      final distSmall = DirichletDistribution(
        Vector<double>.fromList([0.5, 1.5]),
      );
      check(distSmall.logProbability(Vector<double>.fromList([0.0, 1.0])))
          .equals(double.infinity);

      final distLarge = DirichletDistribution(
        Vector<double>.fromList([1.5, 0.5]),
      );
      check(distLarge.logProbability(Vector<double>.fromList([0.0, 1.0])))
          .equals(double.negativeInfinity);
    });

    test('equality, hashCode, and toString', () {
      final alpha = Vector<double>.fromList([2.0, 3.0]);
      final dist1 = DirichletDistribution(alpha);
      final dist2 = DirichletDistribution(alpha);
      final dist3 = DirichletDistribution.symmetric(3, 3.0);

      check(dist1 == dist2).isTrue();
      check(dist1 == dist3).isFalse();
      check(dist1.hashCode).equals(dist2.hashCode);
      check(dist1.toString()).contains('DirichletDistribution');
    });
  });
}
