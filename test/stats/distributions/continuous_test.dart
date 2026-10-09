import 'dart:math' as math;

import 'package:data/stats.dart';
import 'package:test/test.dart';

void main() {
  group('continuous distributions', () {
    test('normal distribution', () {
      const dist = NormalDistribution.standard();
      expect(dist.mean, 0.0);
      expect(dist.standardDeviation, 1.0);
      expect(dist.variance, 1.0);

      // PDF at x = 0 is 1 / sqrt(2*pi) ≈ 0.39894228
      expect(dist.pdf(0.0), closeTo(1.0 / math.sqrt(2 * math.pi), 1e-6));
      expect(dist.cdf(0.0), closeTo(0.5, 1e-6));
      expect(dist.quantile(0.5), closeTo(0.0, 1e-6));
      expect(dist.quantile(0.975), closeTo(1.95996, 1e-4));
      expect(dist.quantile(0.025), closeTo(-1.95996, 1e-4));

      // Sample & fit
      final samples = dist.samples(random: math.Random(42)).take(1000).toList();
      final fitted = NormalDistribution.fit(samples);
      expect(fitted.mean, closeTo(0.0, 0.1));
      expect(fitted.standardDeviation, closeTo(1.0, 0.1));
    });

    test('Student t-distribution', () {
      const dist = StudentDistribution(10.0);
      expect(dist.mean, 0.0);
      expect(dist.variance, closeTo(10.0 / 8.0, 1e-6));
      expect(dist.cdf(0.0), closeTo(0.5, 1e-6));
      expect(dist.quantile(0.5), closeTo(0.0, 1e-6));
      // For df = 10, t_0.975 ≈ 2.2281
      expect(dist.quantile(0.975), closeTo(2.2281, 1e-3));
    });

    test('Chi-squared distribution', () {
      const dist = ChiSquaredDistribution(5.0);
      expect(dist.mean, 5.0);
      expect(dist.variance, 10.0);
      expect(dist.cdf(0.0), 0.0);
      expect(dist.cdf(5.0), greaterThan(0.4));
      expect(dist.cdf(5.0), lessThan(0.6));

      // Quantile roundtrip
      const p = 0.95;
      final q = dist.quantile(p);
      expect(dist.cdf(q), closeTo(p, 1e-5));
    });

    test('F-distribution', () {
      const dist = FDistribution(10.0, 20.0);
      expect(dist.mean, closeTo(20.0 / 18.0, 1e-6));
      expect(dist.cdf(0.0), 0.0);
      expect(dist.cdf(1.0), greaterThan(0.4));
      expect(dist.cdf(1.0), lessThan(0.6));

      // Quantile roundtrip
      const p = 0.90;
      final q = dist.quantile(p);
      expect(dist.cdf(q), closeTo(p, 1e-4));
    });

    test('exponential distribution', () {
      const dist = ExponentialDistribution(2.0);
      expect(dist.mean, 0.5);
      expect(dist.variance, 0.25);
      expect(dist.pdf(0.0), 2.0);
      expect(dist.cdf(0.0), 0.0);
      expect(dist.cdf(0.5), closeTo(1.0 - math.exp(-1.0), 1e-6));
      expect(dist.quantile(0.5), closeTo(dist.median, 1e-6));

      // Fit
      final samples = dist.samples(random: math.Random(42)).take(1000).toList();
      final fitted = ExponentialDistribution.fit(samples);
      expect(fitted.rate, closeTo(2.0, 0.2));
    });

    test('gamma distribution', () {
      const dist = GammaDistribution(3.0, 2.0);
      expect(dist.mean, 6.0);
      expect(dist.variance, 12.0);
      expect(dist.cdf(0.0), 0.0);

      // Quantile roundtrip
      const p = 0.8;
      final q = dist.quantile(p);
      expect(dist.cdf(q), closeTo(p, 1e-5));

      // Fit
      final samples = dist.samples(random: math.Random(42)).take(1000).toList();
      final fitted = GammaDistribution.fit(samples);
      expect(fitted.shape, closeTo(3.0, 0.5));
      expect(fitted.scale, closeTo(2.0, 0.5));
    });

    test('beta distribution', () {
      const dist = BetaDistribution(2.0, 5.0);
      expect(dist.mean, closeTo(2.0 / 7.0, 1e-6));
      expect(dist.cdf(0.0), 0.0);
      expect(dist.cdf(1.0), 1.0);

      // Quantile roundtrip
      const p = 0.75;
      final q = dist.quantile(p);
      expect(dist.cdf(q), closeTo(p, 1e-5));

      // Fit
      final samples = dist.samples(random: math.Random(42)).take(1000).toList();
      final fitted = BetaDistribution.fit(samples);
      expect(fitted.alpha, closeTo(2.0, 0.4));
      expect(fitted.beta, closeTo(5.0, 1.0));
    });

    test('uniform distribution', () {
      const dist = UniformDistribution(10.0, 20.0);
      expect(dist.mean, 15.0);
      expect(dist.variance, closeTo(100.0 / 12.0, 1e-6));
      expect(dist.pdf(15.0), 0.1);
      expect(dist.pdf(5.0), 0.0);
      expect(dist.cdf(15.0), 0.5);
      expect(dist.quantile(0.5), 15.0);

      // Fit
      final samples = [10.5, 12.0, 15.0, 19.5];
      final fitted = UniformDistribution.fit(samples);
      expect(fitted.min, 10.5);
      expect(fitted.max, 19.5);
    });

    test('inverse gamma distribution', () {
      const dist = InverseGammaDistribution(4.0, 6.0);
      expect(dist.mean, closeTo(2.0, 1e-6));
      expect(dist.mode, closeTo(1.2, 1e-6));
      expect(dist.cdf(0.0), 0.0);

      const p = 0.5;
      final q = dist.quantile(p);
      expect(dist.cdf(q), closeTo(p, 1e-5));
    });
  });
}
