import 'dart:math';

import 'package:checks/checks.dart';
import 'package:data/linear.dart';
import 'package:data/stats.dart';
import 'package:data/type.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('MultivariateNormalDistribution', () {
    test('standard normal', () {
      final dist = MultivariateNormalDistribution.standard(2);
      check(dist.dimensions).equals(2);
      check(dist.mean.getUnchecked(0)).equals(0.0);
      check(dist.mean.getUnchecked(1)).equals(0.0);

      final origin = Vector<double>.fromList([0.0, 0.0]);
      const expectedPdf = 1.0 / (2.0 * pi);
      check(dist.probability(origin)).isCloseTo(expectedPdf, 1e-6);
      check(dist.logProbability(origin)).isCloseTo(log(expectedPdf), 1e-6);

      final p1 = Vector<double>.fromList([1.0, 0.0]);
      final expectedP1 = expectedPdf * exp(-0.5);
      check(dist.probability(p1)).isCloseTo(expectedP1, 1e-6);
    });

    test('correlated normal', () {
      final mean = Vector<double>.fromList([1.0, 2.0]);
      final cov = Matrix<double>.generate(2, 2, (r, c) {
        if (r == c) return r == 0 ? 2.0 : 1.0;
        return 0.6;
      }, type: DataType.float64);

      final dist = MultivariateNormalDistribution(mean, cov);
      check(dist.dimensions).equals(2);
      check(dist.mean.getUnchecked(0)).equals(1.0);
      check(dist.mean.getUnchecked(1)).equals(2.0);
      check(dist.covariance.getUnchecked(0, 1)).equals(0.6);

      // Value at mean
      const det = 2.0 * 1.0 - 0.6 * 0.6; // 1.64
      final expectedPeak = 1.0 / (2.0 * pi * sqrt(det));
      check(dist.probability(mean)).isCloseTo(expectedPeak, 1e-6);
    });

    test('invalid inputs throw ArgumentError', () {
      final mean = Vector<double>.fromList([1.0, 2.0]);
      // Non-square cov
      final nonSquare = Matrix<double>.filled(
        2,
        3,
        1.0,
        type: DataType.float64,
      );
      check(() => MultivariateNormalDistribution(mean, nonSquare))
          .throws<ArgumentError>();

      // Non-positive definite
      final nonPd = Matrix<double>.generate(2, 2, (r, c) {
        if (r == c) return 1.0;
        return 2.0; // Det = 1 - 4 = -3 < 0
      }, type: DataType.float64);
      check(() => MultivariateNormalDistribution(mean, nonPd))
          .throws<ArgumentError>();

      // Asymmetric
      final asym = Matrix<double>.generate(2, 2, (r, c) {
        if (r == c) return 1.0;
        return r == 0 ? 0.2 : 0.8;
      }, type: DataType.float64);
      check(() => MultivariateNormalDistribution(mean, asym))
          .throws<ArgumentError>();
    });

    test('sampling empirical moments', () {
      final mean = Vector<double>.fromList([3.0, -1.0]);
      final cov = Matrix<double>.generate(2, 2, (r, c) {
        if (r == c) return r == 0 ? 1.5 : 0.8;
        return 0.4;
      }, type: DataType.float64);

      final dist = MultivariateNormalDistribution(mean, cov);
      final rng = Random(42);
      const sampleCount = 4000;
      var sumX = 0.0;
      var sumY = 0.0;
      final samples = <Vector<double>>[];
      for (var i = 0; i < sampleCount; i++) {
        final s = dist.sample(random: rng);
        samples.add(s);
        sumX += s.getUnchecked(0);
        sumY += s.getUnchecked(1);
      }
      final meanX = sumX / sampleCount;
      final meanY = sumY / sampleCount;
      check(meanX).isCloseTo(3.0, 0.1);
      check(meanY).isCloseTo(-1.0, 0.1);

      var sumSqDiffX = 0.0;
      var sumSqDiffY = 0.0;
      var sumCross = 0.0;
      for (final s in samples) {
        final dx = s.getUnchecked(0) - meanX;
        final dy = s.getUnchecked(1) - meanY;
        sumSqDiffX += dx * dx;
        sumSqDiffY += dy * dy;
        sumCross += dx * dy;
      }
      check(sumSqDiffX / (sampleCount - 1)).isCloseTo(1.5, 0.15);
      check(sumSqDiffY / (sampleCount - 1)).isCloseTo(0.8, 0.1);
      check(sumCross / (sampleCount - 1)).isCloseTo(0.4, 0.1);
    });
  });

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
  });

  group('MultinomialDistribution', () {
    test('exact probabilities and moments', () {
      final p = Vector<double>.fromList([0.2, 0.5, 0.3]);
      final dist = MultinomialDistribution(10, p);
      check(dist.dimensions).equals(3);
      check(dist.mean.getUnchecked(0)).isCloseTo(2.0, 1e-6);
      check(dist.mean.getUnchecked(1)).isCloseTo(5.0, 1e-6);
      check(dist.mean.getUnchecked(2)).isCloseTo(3.0, 1e-6);

      // Covariance: Var(0) = 10 * 0.2 * 0.8 = 1.6
      check(dist.covariance.getUnchecked(0, 0)).isCloseTo(1.6, 1e-6);
      // Cov(0, 1) = -10 * 0.2 * 0.5 = -1.0
      check(dist.covariance.getUnchecked(0, 1)).isCloseTo(-1.0, 1e-6);

      // x = [2, 5, 3] -> 10! / (2! * 5! * 3!) * 0.2^2 * 0.5^5 * 0.3^3 = 0.08505
      final x = Vector<int>.fromList([2, 5, 3]);
      check(dist.probability(x)).isCloseTo(0.08505, 1e-5);

      // Outside support (sum != 10)
      final bad = Vector<int>.fromList([2, 5, 4]);
      check(dist.probability(bad)).equals(0.0);
      check(dist.logProbability(bad)).equals(double.negativeInfinity);
    });

    test('sampling empirical distribution', () {
      final p = Vector<double>.fromList([0.1, 0.6, 0.3]);
      final dist = MultinomialDistribution(20, p);
      final rng = Random(999);
      const sampleCount = 3000;
      var sumX0 = 0;
      var sumX1 = 0;
      var sumX2 = 0;
      for (var i = 0; i < sampleCount; i++) {
        final s = dist.sample(random: rng);
        check(s.getUnchecked(0) + s.getUnchecked(1) + s.getUnchecked(2))
            .equals(20);
        sumX0 += s.getUnchecked(0);
        sumX1 += s.getUnchecked(1);
        sumX2 += s.getUnchecked(2);
      }
      check((sumX0 / sampleCount).toDouble()).isCloseTo(2.0, 0.15);
      check((sumX1 / sampleCount).toDouble()).isCloseTo(12.0, 0.2);
      check((sumX2 / sampleCount).toDouble()).isCloseTo(6.0, 0.2);
    });
  });
}
