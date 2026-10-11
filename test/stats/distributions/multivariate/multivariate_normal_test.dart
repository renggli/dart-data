import 'dart:math';

import 'package:checks/checks.dart';
import 'package:data/linear.dart';
import 'package:data/src/stats/distributions/multivariate/multivariate_normal.dart';
import 'package:data/type.dart';
import 'package:test/test.dart';

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
}
