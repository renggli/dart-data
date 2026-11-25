import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/linear.dart';
import 'package:data/stats.dart';
import 'package:data/type.dart';
import 'package:test/scaffolding.dart';

void main() {
  final probs = Vector<double>.fromList(type: DataType.float, const [
    0.2,
    0.3,
    0.5,
  ]);
  final dist = MultinomialDistribution(10, probs);

  group('MultinomialDistribution parameters, moments, and immutability', () {
    test('computes dimensions, mean, and covariance', () {
      check(dist.trials).equals(10);
      check(dist.dimensions).equals(3);
      check(dist.mean[0]).isCloseTo(2.0, 1e-12);
      check(dist.mean[1]).isCloseTo(3.0, 1e-12);
      check(dist.mean[2]).isCloseTo(5.0, 1e-12);

      final cov = dist.covariance;
      check(cov[0][0]).isCloseTo(10.0 * 0.2 * 0.8, 1e-12);
      check(cov[0][1]).isCloseTo(-10.0 * 0.2 * 0.3, 1e-12);
      check(cov[1][0]).isCloseTo(cov[0][1], 1e-12);
    });

    test('defensively copies constructor input and getter output', () {
      final mutable = Vector<double>.fromList(type: DataType.float, [0.4, 0.6]);
      final m = MultinomialDistribution(5, mutable);
      mutable[0] = 0.9;
      check(m.probabilities[0]).equals(0.4);
      final exposed = m.probabilities;
      exposed[1] = 0.1;
      check(m.probabilities[1]).equals(0.6);
    });
  });

  group('MultinomialDistribution probabilities', () {
    test('probability and logProbability evaluate exact PMF and zero/invalid counts', () {
      final outcome = Vector<int>.fromList(type: DataType.integer, const [
        2,
        3,
        5,
      ]);
      // 10!/(2!3!5!) * 0.2^2 * 0.3^3 * 0.5^5 = 2520 * 0.04 * 0.027 * 0.03125
      const expected = 2520.0 * 0.04 * 0.027 * 0.03125;
      check(dist.probability(outcome)).isCloseTo(expected, 1e-12);
      check(dist.logProbability(outcome)).isCloseTo(math.log(expected), 1e-12);

      // Zero probability category with zero count succeeds; with positive count is 0.
      final boundary = MultinomialDistribution(
        4,
        Vector<double>.fromList(type: DataType.float, const [0.0, 0.5, 0.5]),
      );
      check(
        boundary.probability(
          Vector<int>.fromList(type: DataType.integer, const [0, 2, 2]),
        ),
      ).isCloseTo(0.375, 1e-12);
      check(
        boundary.probability(
          Vector<int>.fromList(type: DataType.integer, const [1, 1, 2]),
        ),
      ).equals(0.0);
      check(
        boundary.logProbability(
          Vector<int>.fromList(type: DataType.integer, const [1, 1, 2]),
        ),
      ).equals(double.negativeInfinity);

      // Invalid sum or negative count.
      check(
        dist.probability(
          Vector<int>.fromList(type: DataType.integer, const [2, 3, 4]),
        ),
      ).equals(0.0);
      check(
        dist.probability(
          Vector<int>.fromList(type: DataType.integer, const [-1, 6, 5]),
        ),
      ).equals(0.0);
      check(
        () => dist.probability(
          Vector<int>.fromList(type: DataType.integer, const [10]),
        ),
      ).throws<ArgumentError>();
    });
  });

  group('MultinomialDistribution sampling, validation, and equality', () {
    test('O(d) sampler matches empirical moments for large n', () {
      final large = MultinomialDistribution(100000, probs);
      final draws = large.samples(random: math.Random(42)).take(200).toList();
      final totals = [0.0, 0.0, 0.0];
      for (final draw in draws) {
        check(draw[0] + draw[1] + draw[2]).equals(100000);
        for (var i = 0; i < 3; i++) {
          check(draw[i]).isGreaterOrEqual(0);
          totals[i] += draw[i];
        }
      }
      check(totals[0] / draws.length).isCloseTo(20000.0, 250.0);
      check(totals[1] / draws.length).isCloseTo(30000.0, 250.0);
      check(totals[2] / draws.length).isCloseTo(50000.0, 250.0);

      final zeroTrials = MultinomialDistribution(0, probs);
      final z = zeroTrials.sample();
      check(z[0] == 0 && z[1] == 0 && z[2] == 0).isTrue;
    });

    test('constructor validation', () {
      check(() => MultinomialDistribution(-1, probs)).throws<ArgumentError>();
      check(
        () => MultinomialDistribution(
          1,
          Vector<double>.fromList(type: DataType.float, const <double>[]),
        ),
      ).throws<ArgumentError>();
      check(
        () => MultinomialDistribution(
          1,
          Vector<double>.fromList(type: DataType.float, const [-0.1, 1.1]),
        ),
      ).throws<ArgumentError>();
      check(
        () => MultinomialDistribution(
          1,
          Vector<double>.fromList(type: DataType.float, const [0.4, 0.4]),
        ),
      ).throws<ArgumentError>();
    });

    test('equality, hashCode, and string representation', () {
      final same = MultinomialDistribution(
        10,
        Vector<double>.fromList(type: DataType.float, const [0.2, 0.3, 0.5]),
      );
      check(dist == same).isTrue;
      check(dist.hashCode).equals(same.hashCode);
      check(dist == MultinomialDistribution(11, probs)).isFalse;
      check(dist.toString()).contains('MultinomialDistribution');
    });
  });
}
