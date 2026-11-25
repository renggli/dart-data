import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/linear.dart';
import 'package:data/stats.dart';
import 'package:data/type.dart';
import 'package:test/scaffolding.dart';

void main() {
  final alpha = Vector<double>.fromList(type: DataType.float, const [
    2.0,
    3.0,
    5.0,
  ]);
  final dirichlet = DirichletDistribution(alpha);
  final symmetric = DirichletDistribution.symmetric(3, 1.0);

  group('DirichletDistribution parameters, moments, and immutability', () {
    test('computes dimensions, mean, and covariance', () {
      check(dirichlet.dimensions).equals(3);
      check(dirichlet.alpha[0]).equals(2.0);
      check(dirichlet.alpha[1]).equals(3.0);
      check(dirichlet.alpha[2]).equals(5.0);

      check(dirichlet.mean[0]).isCloseTo(0.2, 1e-12);
      check(dirichlet.mean[1]).isCloseTo(0.3, 1e-12);
      check(dirichlet.mean[2]).isCloseTo(0.5, 1e-12);

      final cov = dirichlet.covariance;
      check(cov[0][0]).isCloseTo((0.2 * 0.8) / 11.0, 1e-12);
      check(cov[0][1]).isCloseTo(-(0.2 * 0.3) / 11.0, 1e-12);
      check(cov[1][0]).equals(cov[0][1]);
    });

    test('defensively copies constructor input and getter output', () {
      final mutable = Vector<double>.fromList(type: DataType.float, [1.0, 2.0]);
      final dist = DirichletDistribution(mutable);
      mutable[0] = 99.0;
      check(dist.alpha[0]).equals(1.0);
      final exposed = dist.alpha;
      exposed[1] = 88.0;
      check(dist.alpha[1]).equals(2.0);
    });
  });

  group('DirichletDistribution probabilities', () {
    test('probability and logProbability on uniform symmetric simplex', () {
      final point = Vector<double>.fromList(type: DataType.float, const [
        0.2,
        0.3,
        0.5,
      ]);
      // For Dirichlet(1, 1, 1), density is 2! = 2 everywhere on the open simplex.
      check(symmetric.probability(point)).isCloseTo(2.0, 1e-12);
      check(symmetric.logProbability(point)).isCloseTo(math.ln2, 1e-12);
    });

    test(
      'handles zero coordinates permutation-invariantly when alpha_i != 1',
      () {
        // Permutation invariance when alpha_0 > 1 and alpha_1 > 1.
        final p0 = Vector<double>.fromList(type: DataType.float, const [
          0.0,
          0.5,
          0.5,
        ]);
        final p1 = Vector<double>.fromList(type: DataType.float, const [
          0.5,
          0.0,
          0.5,
        ]);
        check(dirichlet.probability(p0)).equals(0.0);
        check(dirichlet.logProbability(p0)).equals(double.negativeInfinity);
        check(dirichlet.probability(p1)).equals(0.0);
        check(dirichlet.logProbability(p1)).equals(double.negativeInfinity);

        // When alpha_i < 1 at x_i == 0, logProbability is +infinity regardless of order.
        final sparse = DirichletDistribution(
          Vector<double>.fromList(type: DataType.float, const [0.5, 0.5, 2.0]),
        );
        check(
          sparse.logProbability(
            Vector<double>.fromList(type: DataType.float, const [
              0.0,
              0.5,
              0.5,
            ]),
          ),
        ).equals(double.infinity);
        check(
          sparse.logProbability(
            Vector<double>.fromList(type: DataType.float, const [
              0.5,
              0.0,
              0.5,
            ]),
          ),
        ).equals(double.infinity);
        // Incompatible boundary conditions yield indeterminate NaN.
        check(
          sparse
              .logProbability(
                Vector<double>.fromList(type: DataType.float, const [
                  0.0,
                  1.0,
                  0.0,
                ]),
              )
              .isNaN,
        ).isTrue;
      },
    );

    test(
      'returns 0 / -infinity outside simplex and NaN on NaN coordinates',
      () {
        check(
          dirichlet.probability(
            Vector<double>.fromList(type: DataType.float, const [
              0.5,
              0.5,
              0.5,
            ]),
          ),
        ).equals(0.0);
        check(
          dirichlet.probability(
            Vector<double>.fromList(type: DataType.float, const [
              -0.1,
              0.6,
              0.5,
            ]),
          ),
        ).equals(0.0);
        check(
          dirichlet
              .logProbability(
                Vector<double>.fromList(type: DataType.float, const [
                  double.nan,
                  0.5,
                  0.5,
                ]),
              )
              .isNaN,
        ).isTrue;
        check(
          () => dirichlet.probability(
            Vector<double>.fromList(type: DataType.float, const [1.0]),
          ),
        ).throws<ArgumentError>();
      },
    );
  });

  group('DirichletDistribution sampling, validation, and equality', () {
    test('samples lie on simplex and handle extreme small alpha', () {
      check(dirichlet.sample().length).equals(3);
      final rng = math.Random(42);
      final draws = dirichlet.samples(random: rng).take(1000).toList();
      final sumMean = [0.0, 0.0, 0.0];
      for (final s in draws) {
        final total = s[0] + s[1] + s[2];
        check(total).isCloseTo(1.0, 1e-12);
        for (var i = 0; i < 3; i++) {
          check(s[i]).isGreaterOrEqual(0.0);
          sumMean[i] += s[i];
        }
      }
      check(sumMean[0] / draws.length).isCloseTo(0.2, 0.03);
      check(sumMean[1] / draws.length).isCloseTo(0.3, 0.03);

      // Extreme tiny alpha uses log-space normalized Gamma fallback on underflow.
      final mixed = DirichletDistribution(
        Vector<double>.fromList(type: DataType.float, const [1e-4, 2.0]),
      );
      final mixedDraws = mixed
          .samples(random: math.Random(9))
          .take(50)
          .toList();
      for (final s in mixedDraws) {
        check(s[0] + s[1]).isCloseTo(1.0, 1e-12);
        check(s[0].isFinite && s[1].isFinite).isTrue;
      }

      final allTiny = DirichletDistribution.symmetric(2, 1e-4);
      final allTinyDraws = allTiny
          .samples(random: math.Random(3))
          .take(100)
          .toList();
      for (final s in allTinyDraws) {
        check(s[0] + s[1]).isCloseTo(1.0, 1e-12);
        check(s[0].isFinite && s[1].isFinite).isTrue;
      }
    });

    test('constructor validation', () {
      check(
        () => DirichletDistribution(
          Vector<double>.fromList(type: DataType.float, const <double>[]),
        ),
      ).throws<ArgumentError>();
      check(
        () => DirichletDistribution(
          Vector<double>.fromList(type: DataType.float, const [1.0, 0.0]),
        ),
      ).throws<ArgumentError>();
      check(
        () => DirichletDistribution(
          Vector<double>.fromList(type: DataType.float, const [
            1.0,
            double.infinity,
          ]),
        ),
      ).throws<ArgumentError>();
      check(() => DirichletDistribution.symmetric(0, 1.0))
          .throws<ArgumentError>();
      check(() => DirichletDistribution.symmetric(2, 0.0))
          .throws<ArgumentError>();
    });

    test('equality, hashCode, and string representation', () {
      final same = DirichletDistribution(
        Vector<double>.fromList(type: DataType.float, const [2.0, 3.0, 5.0]),
      );
      check(dirichlet == same).isTrue;
      check(dirichlet.hashCode).equals(same.hashCode);
      check(dirichlet == symmetric).isFalse;
      check(dirichlet.toString()).contains('DirichletDistribution');
    });
  });
}
