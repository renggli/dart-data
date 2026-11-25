import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/linear.dart';
import 'package:data/stats.dart';
import 'package:data/type.dart';
import 'package:test/scaffolding.dart';

void main() {
  final mean = Vector<double>.fromList(type: DataType.float, const [1.0, 2.0]);
  final covariance = Matrix<double>.fromRows(type: DataType.float, const [
    [2.0, 0.5],
    [0.5, 1.0],
  ]);
  final mvn = MultivariateNormalDistribution(mean, covariance);
  final standard = MultivariateNormalDistribution.standard(2);

  group(
    'MultivariateNormalDistribution parameters, moments, and immutability',
    () {
      test('exposes dimensions, mean, and covariance', () {
        check(mvn.dimensions).equals(2);
        check(mvn.mean[0]).equals(1.0);
        check(mvn.mean[1]).equals(2.0);
        check(mvn.covariance[0][0]).equals(2.0);
        check(mvn.covariance[0][1]).equals(0.5);
        check(mvn.covariance[1][1]).equals(1.0);

        check(standard.dimensions).equals(2);
        check(standard.mean[0]).equals(0.0);
        check(standard.covariance[0][0]).equals(1.0);
        check(standard.covariance[0][1]).equals(0.0);
      });

      test('defensively copies constructor inputs and getter outputs', () {
        final m = Vector<double>.fromList(type: DataType.float, [1.0, 2.0]);
        final c = Matrix<double>.fromRows(type: DataType.float, [
          [2.0, 0.0],
          [0.0, 2.0],
        ]);
        final dist = MultivariateNormalDistribution(m, c);
        m[0] = 99.0;
        c[0][0] = 99.0;
        check(dist.mean[0]).equals(1.0);
        check(dist.covariance[0][0]).equals(2.0);

        final exposedMean = dist.mean;
        final exposedCov = dist.covariance;
        exposedMean[1] = -99.0;
        exposedCov[1][1] = 99.0;
        check(dist.mean[1]).equals(2.0);
        check(dist.covariance[1][1]).equals(2.0);
      });
    },
  );

  group('MultivariateNormalDistribution probabilities', () {
    test('probability and logProbability evaluate exact Gaussian density', () {
      // At x = mu, density = 1 / (2*pi * sqrt(det(Sigma))) with det = 1.75.
      final expectedPeak = 1.0 / (2.0 * math.pi * math.sqrt(1.75));
      check(mvn.probability(mean)).isCloseTo(expectedPeak, 1e-12);
      check(mvn.logProbability(mean)).isCloseTo(math.log(expectedPeak), 1e-12);

      final atZero = standard.logProbability(
        Vector<double>.fromList(type: DataType.float, const [0.0, 0.0]),
      );
      check(atZero).isCloseTo(-math.log(2.0 * math.pi), 1e-12);
    });

    test('handles non-finite coordinates and validates vector length', () {
      check(
        mvn.probability(
          Vector<double>.fromList(type: DataType.float, const [
            double.infinity,
            2.0,
          ]),
        ),
      ).equals(0.0);
      check(
        mvn.logProbability(
          Vector<double>.fromList(type: DataType.float, const [
            double.infinity,
            2.0,
          ]),
        ),
      ).equals(double.negativeInfinity);
      check(
        mvn
            .logProbability(
              Vector<double>.fromList(type: DataType.float, const [
                double.nan,
                2.0,
              ]),
            )
            .isNaN,
      ).isTrue;
      check(
        () => mvn.probability(
          Vector<double>.fromList(type: DataType.float, const [1.0]),
        ),
      ).throws<ArgumentError>();
    });
  });

  group(
    'MultivariateNormalDistribution sampling, validation, and equality',
    () {
      test('samples reproduce correlated empirical mean and covariance', () {
        final draws = mvn.samples(random: math.Random(42)).take(3000).toList();
        var sum0 = 0.0;
        var sum1 = 0.0;
        for (final d in draws) {
          sum0 += d[0];
          sum1 += d[1];
        }
        final m0 = sum0 / draws.length;
        final m1 = sum1 / draws.length;
        var s00 = 0.0;
        var s01 = 0.0;
        var s11 = 0.0;
        for (final d in draws) {
          final d0 = d[0] - m0;
          final d1 = d[1] - m1;
          s00 += d0 * d0;
          s01 += d0 * d1;
          s11 += d1 * d1;
        }
        check(m0).isCloseTo(1.0, 0.1);
        check(m1).isCloseTo(2.0, 0.1);
        check(s00 / draws.length).isCloseTo(2.0, 0.2);
        check(s01 / draws.length).isCloseTo(0.5, 0.15);
        check(s11 / draws.length).isCloseTo(1.0, 0.15);

        // Odd dimension exercises leftover paired normal state.
        final mvn3 = MultivariateNormalDistribution.standard(3);
        final s3 = mvn3.sample(random: math.Random(1));
        check(s3.length).equals(3);
      });

      test('constructor validation', () {
        check(() => MultivariateNormalDistribution.standard(0))
            .throws<ArgumentError>();
        check(
          () => MultivariateNormalDistribution(
            Vector<double>.fromList(type: DataType.float, const [0.0]),
            covariance,
          ),
        ).throws<ArgumentError>();
        // Non-symmetric covariance matrix.
        check(
          () => MultivariateNormalDistribution(
            mean,
            Matrix<double>.fromRows(type: DataType.float, const [
              [1.0, 0.5],
              [0.0, 1.0],
            ]),
          ),
        ).throws<ArgumentError>();
        // Empty dimensions.
        check(
          () => MultivariateNormalDistribution(
            Vector<double>.fromList(type: DataType.float, const <double>[]),
            Matrix.identity(type: DataType.float, 0),
          ),
        ).throws<ArgumentError>();
        // Infinite covariance entry.
        check(
          () => MultivariateNormalDistribution(
            mean,
            Matrix<double>.fromRows(type: DataType.float, const [
              [double.infinity, 0.0],
              [0.0, 1.0],
            ]),
          ),
        ).throws<ArgumentError>();
        // Non-positive-definite covariance matrix.
        check(
          () => MultivariateNormalDistribution(
            mean,
            Matrix<double>.fromRows(type: DataType.float, const [
              [1.0, 2.0],
              [2.0, 1.0],
            ]),
          ),
        ).throws<ArgumentError>();
        // Non-finite mean.
        check(
          () => MultivariateNormalDistribution(
            Vector<double>.fromList(type: DataType.float, const [
              double.nan,
              0.0,
            ]),
            Matrix.identity(type: DataType.float, 2),
          ),
        ).throws<ArgumentError>();
      });

      test('equality, hashCode, and string representation', () {
        final same = MultivariateNormalDistribution(mean, covariance);
        check(mvn == same).isTrue;
        check(mvn.hashCode).equals(same.hashCode);
        check(mvn == standard).isFalse;
        check(mvn.toString()).contains('MultivariateNormalDistribution');
      });
    },
  );
}
