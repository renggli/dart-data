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
  });
}
