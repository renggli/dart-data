import 'dart:math';

import 'package:checks/checks.dart';
import 'package:data/linear.dart';
import 'package:data/src/stats/distributions/multivariate/multinomial.dart';
import 'package:test/test.dart';

void main() {
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

    test('argument validation', () {
      final p = Vector<double>.fromList([0.5, 0.5]);
      check(() => MultinomialDistribution(-1, p)).throws<ArgumentError>();
      check(() => MultinomialDistribution(5, Vector<double>.fromList([1.0])))
          .throws<ArgumentError>();
      check(
        () => MultinomialDistribution(5, Vector<double>.fromList([-0.2, 1.2])),
      ).throws<ArgumentError>();
      check(
        () => MultinomialDistribution(5, Vector<double>.fromList([0.3, 0.3])),
      ).throws<ArgumentError>();

      final dist = MultinomialDistribution(5, p);
      check(() => dist.logProbability(Vector<int>.fromList([5])))
          .throws<ArgumentError>();
    });

    test('sample with default random', () {
      final dist = MultinomialDistribution(
        10,
        Vector<double>.fromList([0.5, 0.5]),
      );
      final s = dist.sample();
      check(s.getUnchecked(0) + s.getUnchecked(1)).equals(10);
    });

    test('equality, hashCode, and toString', () {
      final p1 = Vector<double>.fromList([0.4, 0.6]);
      final p3 = Vector<double>.fromList([0.5, 0.5]);

      final dist1 = MultinomialDistribution(5, p1);
      final dist2 = MultinomialDistribution(5, p1);
      final dist3 = MultinomialDistribution(5, p3);

      check(dist1 == dist2).isTrue();
      check(dist1 == dist3).isFalse();
      check(dist1.hashCode).equals(dist2.hashCode);
      check(dist1.toString()).contains('MultinomialDistribution');
    });
  });
}
