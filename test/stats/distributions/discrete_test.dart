import 'dart:math' as math;

import 'package:data/stats.dart';
import 'package:test/test.dart';

void main() {
  group('discrete distributions', () {
    test('Bernoulli distribution', () {
      const dist = BernoulliDistribution(0.7);
      expect(dist.mean, 0.7);
      expect(dist.variance, closeTo(0.21, 1e-6));
      expect(dist.pmf(1), closeTo(0.7, 1e-6));
      expect(dist.pmf(0), closeTo(0.3, 1e-6));
      expect(dist.pmf(2), 0.0);
      expect(dist.cdf(0), closeTo(0.3, 1e-6));
      expect(dist.cdf(1), 1.0);

      // Fit
      final samples = [1, 1, 1, 0, 1, 0, 1, 1, 0, 1]; // 7 ones, 3 zeros
      final fitted = BernoulliDistribution.fit(samples);
      expect(fitted.p, closeTo(0.7, 1e-6));
    });

    test('Binomial distribution', () {
      const dist = BinomialDistribution(10, 0.5);
      expect(dist.mean, 5.0);
      expect(dist.variance, 2.5);
      expect(dist.pmf(5), closeTo(252.0 / 1024.0, 1e-6));
      expect(dist.cdf(10), 1.0);
      expect(dist.cdf(0), closeTo(1.0 / 1024.0, 1e-6));

      // Fit
      final samples = dist.samples(random: math.Random(42)).take(1000).toList();
      final fitted = BinomialDistribution.fit(samples, n: 10);
      expect(fitted.n, 10);
      expect(fitted.p, closeTo(0.5, 0.05));
    });

    test('Poisson distribution', () {
      const dist = PoissonDistribution(4.0);
      expect(dist.mean, 4.0);
      expect(dist.variance, 4.0);
      // PMF at k = 0: exp(-4)
      expect(dist.pmf(0), closeTo(math.exp(-4.0), 1e-6));
      expect(dist.cdf(0), closeTo(math.exp(-4.0), 1e-6));
      expect(dist.cdf(4), greaterThan(0.5));

      // Fit
      final samples = dist.samples(random: math.Random(42)).take(1000).toList();
      final fitted = PoissonDistribution.fit(samples);
      expect(fitted.rate, closeTo(4.0, 0.2));
    });

    test('discrete uniform distribution', () {
      const dist = UniformDiscreteDistribution(1, 6);
      expect(dist.mean, 3.5);
      expect(dist.variance, closeTo(35.0 / 12.0, 1e-6));
      for (var k = 1; k <= 6; k++) {
        expect(dist.pmf(k), closeTo(1.0 / 6.0, 1e-6));
      }
      expect(dist.pmf(0), 0.0);
      expect(dist.pmf(7), 0.0);
      expect(dist.cdf(3), closeTo(0.5, 1e-6));
      expect(dist.cdf(6), 1.0);

      // Fit
      final samples = [2, 3, 5, 1, 4, 6];
      final fitted = UniformDiscreteDistribution.fit(samples);
      expect(fitted.min, 1);
      expect(fitted.max, 6);
    });
  });
}
