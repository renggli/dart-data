import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/stats.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('continuous distributions', () {
    test('normal distribution', () {
      const dist = NormalDistribution.standard();
      check(dist.mean).equals(0.0);
      check(dist.standardDeviation).equals(1.0);
      check(dist.variance).equals(1.0);

      // PDF at x = 0 is 1 / sqrt(2*pi) ≈ 0.39894228
      check(dist.pdf(0.0)).isCloseTo(1.0 / math.sqrt(2 * math.pi), 1e-6);
      check(dist.cdf(0.0)).isCloseTo(0.5, 1e-6);
      check(dist.quantile(0.5)).isCloseTo(0.0, 1e-6);
      check(dist.quantile(0.975)).isCloseTo(1.95996, 1e-4);
      check(dist.quantile(0.025)).isCloseTo(-1.95996, 1e-4);

      // Sample & fit
      final samples = dist.samples(random: math.Random(42)).take(1000).toList();
      final fitted = NormalDistribution.fit(samples);
      check(fitted.mean).isCloseTo(0.0, 0.1);
      check(fitted.standardDeviation).isCloseTo(1.0, 0.1);
    });

    test('Student t-distribution', () {
      const dist = StudentDistribution(10.0);
      check(dist.mean).equals(0.0);
      check(dist.variance).isCloseTo(10.0 / 8.0, 1e-6);
      check(dist.cdf(0.0)).isCloseTo(0.5, 1e-6);
      check(dist.quantile(0.5)).isCloseTo(0.0, 1e-6);
      // For df = 10, t_0.975 ≈ 2.2281
      check(dist.quantile(0.975)).isCloseTo(2.2281, 1e-3);

      // Fit
      final samples = dist.samples(random: math.Random(42)).take(2000).toList();
      final fitted = StudentDistribution.fit(samples);
      check(fitted.dof).isCloseTo(10.0, 3.5);
    });

    test('Chi-squared distribution', () {
      const dist = ChiSquaredDistribution(5.0);
      check(dist.mean).equals(5.0);
      check(dist.variance).equals(10.0);
      check(dist.cdf(0.0)).equals(0.0);
      check(dist.cdf(5.0)).isGreaterThan(0.4);
      check(dist.cdf(5.0)).isLessThan(0.6);

      // Quantile roundtrip
      const p = 0.95;
      final q = dist.quantile(p);
      check(dist.cdf(q)).isCloseTo(p, 1e-5);

      // Fit
      final samples = dist.samples(random: math.Random(42)).take(1000).toList();
      final fitted = ChiSquaredDistribution.fit(samples);
      check(fitted.dof).isCloseTo(5.0, 0.5);
    });

    test('F-distribution', () {
      const dist = FDistribution(10.0, 20.0);
      check(dist.mean).isCloseTo(20.0 / 18.0, 1e-6);
      check(dist.cdf(0.0)).equals(0.0);
      check(dist.cdf(1.0)).isGreaterThan(0.4);
      check(dist.cdf(1.0)).isLessThan(0.6);

      // Quantile roundtrip
      const p = 0.90;
      final q = dist.quantile(p);
      check(dist.cdf(q)).isCloseTo(p, 1e-4);

      // Fit
      final samples = dist.samples(random: math.Random(42)).take(2000).toList();
      final fitted = FDistribution.fit(samples);
      check(fitted.d1).isCloseTo(10.0, 6.0);
      check(fitted.d2).isCloseTo(20.0, 8.0);
    });

    test('exponential distribution', () {
      const dist = ExponentialDistribution(2.0);
      check(dist.mean).equals(0.5);
      check(dist.variance).equals(0.25);
      check(dist.pdf(0.0)).equals(2.0);
      check(dist.cdf(0.0)).equals(0.0);
      check(dist.cdf(0.5)).isCloseTo(1.0 - math.exp(-1.0), 1e-6);
      check(dist.quantile(0.5)).isCloseTo(dist.median, 1e-6);

      // Fit
      final samples = dist.samples(random: math.Random(42)).take(1000).toList();
      final fitted = ExponentialDistribution.fit(samples);
      check(fitted.rate).isCloseTo(2.0, 0.2);
    });

    test('gamma distribution', () {
      const dist = GammaDistribution(3.0, 2.0);
      check(dist.mean).equals(6.0);
      check(dist.variance).equals(12.0);
      check(dist.cdf(0.0)).equals(0.0);

      // Quantile roundtrip
      const p = 0.8;
      final q = dist.quantile(p);
      check(dist.cdf(q)).isCloseTo(p, 1e-5);

      // Fit
      final samples = dist.samples(random: math.Random(42)).take(1000).toList();
      final fitted = GammaDistribution.fit(samples);
      check(fitted.shape).isCloseTo(3.0, 0.5);
      check(fitted.scale).isCloseTo(2.0, 0.5);
    });

    test('beta distribution', () {
      const dist = BetaDistribution(2.0, 5.0);
      check(dist.mean).isCloseTo(2.0 / 7.0, 1e-6);
      check(dist.cdf(0.0)).equals(0.0);
      check(dist.cdf(1.0)).equals(1.0);

      // Quantile roundtrip
      const p = 0.75;
      final q = dist.quantile(p);
      check(dist.cdf(q)).isCloseTo(p, 1e-5);

      // Fit
      final samples = dist.samples(random: math.Random(42)).take(1000).toList();
      final fitted = BetaDistribution.fit(samples);
      check(fitted.alpha).isCloseTo(2.0, 0.4);
      check(fitted.beta).isCloseTo(5.0, 1.0);
    });

    test('uniform distribution', () {
      const dist = UniformDistribution(10.0, 20.0);
      check(dist.mean).equals(15.0);
      check(dist.variance).isCloseTo(100.0 / 12.0, 1e-6);
      check(dist.pdf(15.0)).equals(0.1);
      check(dist.pdf(5.0)).equals(0.0);
      check(dist.cdf(15.0)).equals(0.5);
      check(dist.quantile(0.5)).equals(15.0);

      // Fit
      final samples = [10.5, 12.0, 15.0, 19.5];
      final fitted = UniformDistribution.fit(samples);
      check(fitted.min).equals(10.5);
      check(fitted.max).equals(19.5);
    });

    test('inverse gamma distribution', () {
      const dist = InverseGammaDistribution(4.0, 6.0);
      check(dist.mean).isCloseTo(2.0, 1e-6);
      check(dist.mode).isCloseTo(1.2, 1e-6);
      check(dist.cdf(0.0)).equals(0.0);

      const p = 0.5;
      final q = dist.quantile(p);
      check(dist.cdf(q)).isCloseTo(p, 1e-5);
    });
  });
}
