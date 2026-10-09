import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/stats.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('discrete distributions', () {
    test('Bernoulli distribution', () {
      const dist = BernoulliDistribution(0.7);
      check(dist.mean).equals(0.7);
      check(dist.variance).isCloseTo(0.21, 1e-6);
      check(dist.pmf(1)).isCloseTo(0.7, 1e-6);
      check(dist.pmf(0)).isCloseTo(0.3, 1e-6);
      check(dist.pmf(2)).equals(0.0);
      check(dist.cdf(0)).isCloseTo(0.3, 1e-6);
      check(dist.cdf(1)).equals(1.0);

      // Fit
      final samples = [1, 1, 1, 0, 1, 0, 1, 1, 0, 1]; // 7 ones, 3 zeros
      final fitted = BernoulliDistribution.fit(samples);
      check(fitted.p).isCloseTo(0.7, 1e-6);
    });

    test('Binomial distribution', () {
      const dist = BinomialDistribution(10, 0.5);
      check(dist.mean).equals(5.0);
      check(dist.variance).equals(2.5);
      check(dist.pmf(5)).isCloseTo(252.0 / 1024.0, 1e-6);
      check(dist.cdf(10)).equals(1.0);
      check(dist.cdf(0)).isCloseTo(1.0 / 1024.0, 1e-6);

      // Fit
      final samples = dist.samples(random: math.Random(42)).take(1000).toList();
      final fitted = BinomialDistribution.fit(samples, n: 10);
      check(fitted.n).equals(10);
      check(fitted.p).isCloseTo(0.5, 0.05);
    });

    test('Poisson distribution', () {
      const dist = PoissonDistribution(4.0);
      check(dist.mean).equals(4.0);
      check(dist.variance).equals(4.0);
      // PMF at k = 0: exp(-4)
      check(dist.pmf(0)).isCloseTo(math.exp(-4.0), 1e-6);
      check(dist.cdf(0)).isCloseTo(math.exp(-4.0), 1e-6);
      check(dist.cdf(4)).isGreaterThan(0.5);

      // Fit
      final samples = dist.samples(random: math.Random(42)).take(1000).toList();
      final fitted = PoissonDistribution.fit(samples);
      check(fitted.rate).isCloseTo(4.0, 0.2);
    });

    test('discrete uniform distribution', () {
      const dist = UniformDiscreteDistribution(1, 6);
      check(dist.mean).equals(3.5);
      check(dist.variance).isCloseTo(35.0 / 12.0, 1e-6);
      for (var k = 1; k <= 6; k++) {
        check(dist.pmf(k)).isCloseTo(1.0 / 6.0, 1e-6);
      }
      check(dist.pmf(0)).equals(0.0);
      check(dist.pmf(7)).equals(0.0);
      check(dist.cdf(3)).isCloseTo(0.5, 1e-6);
      check(dist.cdf(6)).equals(1.0);

      // Fit
      final samples = [2, 3, 5, 1, 4, 6];
      final fitted = UniformDiscreteDistribution.fit(samples);
      check(fitted.min).equals(1);
      check(fitted.max).equals(6);
    });
  });
}
