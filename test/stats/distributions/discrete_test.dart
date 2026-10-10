import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/stats.dart';
import 'package:test/test.dart';

void main() {
  group('discrete distributions', () {
    test('Bernoulli distribution', () {
      const dist = BernoulliDistribution(0.7);
      check(dist.p).equals(0.7);
      check(dist.lowerBound).equals(0);
      check(dist.upperBound).equals(1);
      check(dist.isLowerBoundOpen).isFalse();
      check(dist.isUpperBoundOpen).isFalse();

      check(dist.mean).equals(0.7);
      check(dist.median).equals(1.0);
      check(dist.mode).equals(1.0);
      check(dist.variance).isCloseTo(0.21, 1e-6);
      check(dist.standardDeviation).isCloseTo(math.sqrt(0.21), 1e-6);
      check(dist.skewness).isCloseTo((1 - 2 * 0.7) / math.sqrt(0.21), 1e-6);
      check(dist.excessKurtosis).isCloseTo((1 - 6 * 0.7 * 0.3) / 0.21, 1e-6);
      check(dist.kurtosisExcess).equals(dist.excessKurtosis);

      // Quantile and CDF
      check(dist.quantile(0.0)).equals(0);
      check(dist.quantile(0.29)).equals(0);
      check(dist.quantile(0.31)).equals(1);
      check(dist.quantile(1.0)).equals(1);
      check(() => dist.quantile(-0.1)).throws<InvalidProbability>();
      check(() => dist.quantile(1.1)).throws<InvalidProbability>();

      check(dist.pmf(-1)).equals(0.0);
      check(dist.pmf(0)).isCloseTo(0.3, 1e-6);
      check(dist.pmf(1)).isCloseTo(0.7, 1e-6);
      check(dist.pmf(2)).equals(0.0);

      check(dist.cdf(-1)).equals(0.0);
      check(dist.cdf(0)).isCloseTo(0.3, 1e-6);
      check(dist.cdf(1)).equals(1.0);
      check(dist.cdf(2)).equals(1.0);

      // Median for p < 0.5 and p == 0.5
      const distLow = BernoulliDistribution(0.3);
      check(distLow.median).equals(0.0);
      check(distLow.mode).equals(0.0);

      const distHalf = BernoulliDistribution(0.5);
      check(distHalf.median).equals(0.5);

      // Samples
      final samples = dist.samples(random: math.Random(42)).take(100).toList();
      check(samples.every((sample) => sample == 0 || sample == 1)).isTrue();

      // Fit
      final fitted = BernoulliDistribution.fit(const [
        1,
        1,
        1,
        0,
        1,
        0,
        1,
        1,
        0,
        1,
      ]);
      check(fitted.p).isCloseTo(0.7, 1e-6);
      check(() => BernoulliDistribution.fit(const [])).throws<ArgumentError>();
      check(() => BernoulliDistribution.fit(const [0, 2]))
          .throws<ArgumentError>();

      // Constructor validation
      check(() => BernoulliDistribution(-0.1)).throws<AssertionError>();
      check(() => BernoulliDistribution(1.1)).throws<AssertionError>();

      // toString
      check(dist.toString()).contains('BernoulliDistribution');
    });

    test('Binomial distribution', () {
      const dist = BinomialDistribution(10, 0.5);
      check(dist.n).equals(10);
      check(dist.p).equals(0.5);
      check(dist.lowerBound).equals(0);
      check(dist.upperBound).equals(10);
      check(dist.isLowerBoundOpen).isFalse();
      check(dist.isUpperBoundOpen).isFalse();

      check(dist.mean).equals(5.0);
      check(dist.median).equals(5.0);
      check(dist.mode).equals(5.0);
      check(dist.variance).equals(2.5);
      check(dist.standardDeviation).isCloseTo(math.sqrt(2.5), 1e-6);
      check(dist.skewness).equals(0.0);
      check(dist.excessKurtosis).isCloseTo((1.0 - 6.0 * 0.5 * 0.5) / 2.5, 1e-6);

      check(dist.pmf(-1)).equals(0.0);
      check(dist.pmf(5)).isCloseTo(252.0 / 1024.0, 1e-6);
      check(dist.pmf(11)).equals(0.0);

      check(dist.cdf(-1)).equals(0.0);
      check(dist.cdf(0)).isCloseTo(1.0 / 1024.0, 1e-6);
      check(dist.cdf(10)).equals(1.0);
      check(dist.cdf(11)).equals(1.0);

      check(dist.quantile(0.0)).equals(0);
      check(dist.quantile(0.5)).equals(5);
      check(dist.quantile(1.0)).equals(10);
      check(() => dist.quantile(-0.1)).throws<InvalidProbability>();

      // Degenerate p = 0 and p = 1
      const dist0 = BinomialDistribution(5, 0.0);
      check(dist0.pmf(0)).equals(1.0);
      check(dist0.pmf(1)).equals(0.0);

      const dist1 = BinomialDistribution(5, 1.0);
      check(dist1.pmf(5)).equals(1.0);
      check(dist1.pmf(4)).equals(0.0);

      // Samples
      final samples = dist.samples(random: math.Random(42)).take(50).toList();
      check(samples.every((sample) => sample >= 0 && sample <= 10)).isTrue();

      // Fit
      final fitted = BinomialDistribution.fit(samples, n: 10);
      check(fitted.n).equals(10);
      check(fitted.p).isCloseTo(0.5, 0.1);
      check(() => BinomialDistribution.fit(const [], n: 10))
          .throws<ArgumentError>();
      check(() => BinomialDistribution.fit(const [-1], n: 10))
          .throws<ArgumentError>();
      check(() => BinomialDistribution.fit(const [1.5], n: 10))
          .throws<ArgumentError>();

      // Constructor validation
      check(() => BinomialDistribution(-1, 0.5)).throws<AssertionError>();
      check(() => BinomialDistribution(10, -0.1)).throws<AssertionError>();
      check(() => BinomialDistribution(10, 1.1)).throws<AssertionError>();

      check(dist.toString()).contains('BinomialDistribution');
    });

    test('Poisson distribution', () {
      const dist = PoissonDistribution(4.0);
      check(dist.rate).equals(4.0);
      check(dist.lowerBound).equals(0);
      check(dist.upperBound).equals(9007199254740991);
      check(dist.isLowerBoundOpen).isFalse();
      check(dist.isUpperBoundOpen).isTrue();

      check(dist.mean).equals(4.0);
      check(dist.variance).equals(4.0);
      check(dist.standardDeviation).equals(2.0);
      check(dist.mode).equals(4.0);
      check(dist.skewness).equals(0.5);
      check(dist.excessKurtosis).equals(0.25);
      check(dist.median).isA<double>();

      check(dist.pmf(-1)).equals(0.0);
      check(dist.pmf(0)).isCloseTo(math.exp(-4.0), 1e-6);
      check(dist.cdf(-1)).equals(0.0);
      check(dist.cdf(0)).isCloseTo(math.exp(-4.0), 1e-6);
      check(dist.cdf(4)).isGreaterThan(0.5);

      check(dist.quantile(0.0)).equals(0);
      check(dist.quantile(0.99)).isGreaterThan(5);
      check(() => dist.quantile(-0.1)).throws<InvalidProbability>();

      // Samples
      final samples = dist.samples(random: math.Random(42)).take(50).toList();
      check(samples.every((sample) => sample >= 0)).isTrue();

      // Fit
      final fitted = PoissonDistribution.fit(samples);
      check(fitted.rate).isCloseTo(4.0, 0.5);
      check(() => PoissonDistribution.fit(const [])).throws<ArgumentError>();
      check(() => PoissonDistribution.fit(const [-1])).throws<ArgumentError>();

      // Constructor validation
      check(() => PoissonDistribution(0.0)).throws<AssertionError>();
      check(() => PoissonDistribution(-2.0)).throws<AssertionError>();

      check(dist.toString()).contains('PoissonDistribution');
    });

    test('discrete uniform distribution', () {
      const dist = UniformDiscreteDistribution(1, 6);
      check(dist.min).equals(1);
      check(dist.max).equals(6);
      check(dist.lowerBound).equals(1);
      check(dist.upperBound).equals(6);
      check(dist.isLowerBoundOpen).isFalse();
      check(dist.isUpperBoundOpen).isFalse();

      check(dist.mean).equals(3.5);
      check(dist.variance).isCloseTo(35.0 / 12.0, 1e-6);
      check(dist.standardDeviation).isCloseTo(math.sqrt(35.0 / 12.0), 1e-6);
      check(dist.median).equals(3.5);
      check(dist.mode.isNaN).isTrue();
      check(dist.skewness).equals(0.0);
      check(dist.excessKurtosis).isCloseTo(-1.2685714, 1e-4);

      check(dist.pmf(0)).equals(0.0);
      check(dist.pmf(1)).isCloseTo(1.0 / 6.0, 1e-6);
      check(dist.pmf(7)).equals(0.0);

      check(dist.cdf(0)).equals(0.0);
      check(dist.cdf(3)).isCloseTo(0.5, 1e-6);
      check(dist.cdf(6)).equals(1.0);
      check(dist.cdf(7)).equals(1.0);

      check(dist.quantile(0.0)).equals(1);
      check(dist.quantile(0.5)).equals(4);
      check(dist.quantile(1.0)).equals(6);
      check(() => dist.quantile(-0.1)).throws<InvalidProbability>();

      // Samples
      final samples = dist.samples(random: math.Random(42)).take(50).toList();
      check(samples.every((sample) => sample >= 1 && sample <= 6)).isTrue();

      // Fit
      final fitted = UniformDiscreteDistribution.fit(samples);
      check(fitted.min).isGreaterThan(0);
      check(fitted.max).isLessThan(7);
      check(() => UniformDiscreteDistribution.fit(const []))
          .throws<ArgumentError>();

      // Constructor validation
      check(() => UniformDiscreteDistribution(5, 3)).throws<AssertionError>();

      check(dist.toString()).contains('UniformDiscreteDistribution');
    });

    test('Geometric distribution', () {
      const dist = GeometricDistribution(0.5);
      check(dist.p).equals(0.5);
      check(dist.lowerBound).equals(0);
      check(dist.upperBound).equals(9007199254740991);
      check(dist.isLowerBoundOpen).isFalse();
      check(dist.isUpperBoundOpen).isTrue();

      check(dist.mean).equals(1.0);
      check(dist.variance).equals(2.0);
      check(dist.standardDeviation).isCloseTo(math.sqrt(2.0), 1e-6);
      check(dist.mode).equals(0.0);
      check(dist.median).isA<double>();
      check(dist.skewness).isCloseTo((2.0 - 0.5) / math.sqrt(0.5), 1e-6);
      check(dist.excessKurtosis).isCloseTo(6.0 + 0.25 / 0.5, 1e-6);

      check(dist.pmf(-1)).equals(0.0);
      check(dist.pmf(0)).equals(0.5);
      check(dist.pmf(1)).equals(0.25);

      check(dist.cdf(-1)).equals(0.0);
      check(dist.cdf(0)).equals(0.5);
      check(dist.cdf(1)).equals(0.75);

      check(dist.quantile(0.0)).equals(0);
      check(dist.quantile(0.5)).equals(0);
      check(dist.quantile(0.75)).equals(1);
      check(() => dist.quantile(-0.1)).throws<InvalidProbability>();

      // Samples
      final samples = dist.samples(random: math.Random(42)).take(50).toList();
      check(samples.every((sample) => sample >= 0)).isTrue();

      // Constructor validation
      check(() => GeometricDistribution(0.0)).throws<AssertionError>();
      check(() => GeometricDistribution(-0.5)).throws<AssertionError>();
      check(() => GeometricDistribution(1.5)).throws<AssertionError>();

      check(dist.toString()).contains('GeometricDistribution');
    });

    test('Hypergeometric distribution', () {
      const dist = HypergeometricDistribution(50, 10, 5);
      check(dist.N).equals(50);
      check(dist.K).equals(10);
      check(dist.n).equals(5);
      check(dist.lowerBound).equals(0);
      check(dist.upperBound).equals(5);
      check(dist.isLowerBoundOpen).isFalse();
      check(dist.isUpperBoundOpen).isFalse();

      check(dist.mean).equals(1.0);
      check(dist.variance)
          .isCloseTo(5.0 * (10.0 / 50.0) * (40.0 / 50.0) * (45.0 / 49.0), 1e-6);
      check(dist.standardDeviation).isGreaterThan(0.0);
      check(dist.mode).isA<double>();
      check(dist.median).isA<double>();
      check(dist.skewness).isA<double>();
      check(dist.excessKurtosis).isA<double>();

      check(dist.pmf(-1)).equals(0.0);
      check(dist.pmf(0)).isGreaterThan(0.3);
      check(dist.pmf(6)).equals(0.0);

      check(dist.cdf(-1)).equals(0.0);
      check(dist.cdf(5)).equals(1.0);

      check(dist.quantile(0.0)).equals(0);
      check(dist.quantile(1.0)).equals(5);
      check(() => dist.quantile(-0.1)).throws<InvalidProbability>();

      // Samples
      final samples = dist.samples(random: math.Random(42)).take(50).toList();
      check(samples.every((sample) => sample >= 0 && sample <= 5)).isTrue();

      // Constructor validation
      check(() => HypergeometricDistribution(0, 5, 2)).throws<AssertionError>();
      check(() => HypergeometricDistribution(10, -1, 2))
          .throws<AssertionError>();
      check(() => HypergeometricDistribution(10, 11, 2))
          .throws<AssertionError>();
      check(() => HypergeometricDistribution(10, 5, -1))
          .throws<AssertionError>();
      check(() => HypergeometricDistribution(10, 5, 11))
          .throws<AssertionError>();

      check(dist.toString()).contains('HypergeometricDistribution');
    });

    test('Negative Binomial distribution', () {
      const dist = NegativeBinomialDistribution(1.0, 0.5);
      check(dist.r).equals(1.0);
      check(dist.p).equals(0.5);
      check(dist.lowerBound).equals(0);
      check(dist.upperBound).equals(9007199254740991);
      check(dist.isLowerBoundOpen).isFalse();
      check(dist.isUpperBoundOpen).isTrue();

      check(dist.mean).equals(1.0);
      check(dist.variance).equals(2.0);
      check(dist.standardDeviation).isCloseTo(math.sqrt(2.0), 1e-6);
      check(dist.mode).isA<double>();
      check(dist.median).isA<double>();
      check(dist.skewness).isCloseTo((2.0 - 0.5) / math.sqrt(1.0 * 0.5), 1e-6);
      check(dist.excessKurtosis).isCloseTo(6.0 / 1.0 + 0.25 / 0.5, 1e-6);

      check(dist.pmf(-1)).equals(0.0);
      check(dist.pmf(0)).isCloseTo(0.5, 1e-12);
      check(dist.pmf(1)).isCloseTo(0.25, 1e-12);

      check(dist.cdf(-1)).equals(0.0);
      check(dist.cdf(0)).isCloseTo(0.5, 1e-12);
      check(dist.cdf(1)).isCloseTo(0.75, 1e-12);

      check(dist.quantile(0.0)).equals(0);
      check(dist.quantile(0.5)).equals(0);
      check(() => dist.quantile(-0.1)).throws<InvalidProbability>();

      // Samples
      final samples = dist.samples(random: math.Random(42)).take(50).toList();
      check(samples.every((sample) => sample >= 0)).isTrue();

      // Constructor validation
      check(() => NegativeBinomialDistribution(0.0, 0.5))
          .throws<AssertionError>();
      check(() => NegativeBinomialDistribution(-1.0, 0.5))
          .throws<AssertionError>();
      check(() => NegativeBinomialDistribution(1.0, -0.1))
          .throws<AssertionError>();
      check(() => NegativeBinomialDistribution(1.0, 1.1))
          .throws<AssertionError>();

      check(dist.toString()).contains('NegativeBinomialDistribution');
    });

    test('Rademacher distribution', () {
      const dist = RademacherDistribution();
      check(dist.lowerBound).equals(-1);
      check(dist.upperBound).equals(1);
      check(dist.isLowerBoundOpen).isFalse();
      check(dist.isUpperBoundOpen).isFalse();

      check(dist.mean).equals(0.0);
      check(dist.median).equals(0.0);
      check(dist.mode.isNaN).isTrue();
      check(dist.variance).equals(1.0);
      check(dist.standardDeviation).equals(1.0);
      check(dist.skewness).equals(0.0);
      check(dist.excessKurtosis).equals(-2.0);

      check(dist.pmf(-2)).equals(0.0);
      check(dist.pmf(-1)).equals(0.5);
      check(dist.pmf(0)).equals(0.0);
      check(dist.pmf(1)).equals(0.5);
      check(dist.pmf(2)).equals(0.0);

      check(dist.cdf(-2)).equals(0.0);
      check(dist.cdf(-1)).equals(0.5);
      check(dist.cdf(0)).equals(0.5);
      check(dist.cdf(1)).equals(1.0);
      check(dist.cdf(2)).equals(1.0);

      check(dist.quantile(0.0)).equals(-1);
      check(dist.quantile(0.49)).equals(-1);
      check(dist.quantile(0.51)).equals(1);
      check(dist.quantile(1.0)).equals(1);
      check(() => dist.quantile(-0.1)).throws<InvalidProbability>();

      // Samples
      final samples = dist.samples(random: math.Random(42)).take(50).toList();
      check(samples.every((sample) => sample == -1 || sample == 1)).isTrue();

      check(dist.toString()).contains('RademacherDistribution');
    });

    test('InvalidProbability error', () {
      final err = InvalidProbability(1.5);
      check(err.probability).equals(1.5);
      check(err.toString()).contains('Invalid probability');
    });

    test('Discrete distributions equality, hashCode, default random, and sampling branches', () {
      // Bernoulli
      const b1 = BernoulliDistribution(0.4);
      const b2 = BernoulliDistribution(0.4);
      const b3 = BernoulliDistribution(0.6);
      check(b1 == b2).isTrue();
      check(b1 == b3).isFalse();
      check(b1.hashCode).equals(b2.hashCode);
      check(b1.sample()).isNotNull();

      // Binomial
      const bin1 = BinomialDistribution(10, 0.4);
      const bin2 = BinomialDistribution(10, 0.4);
      const bin3 = BinomialDistribution(10, 0.5);
      check(bin1 == bin2).isTrue();
      check(bin1 == bin3).isFalse();
      check(bin1.hashCode).equals(bin2.hashCode);
      check(bin1.sample()).isNotNull();

      // Poisson rate >= 30 (normal approximation)
      const p1 = PoissonDistribution(50.0);
      const p2 = PoissonDistribution(50.0);
      const p3 = PoissonDistribution(10.0);
      check(p1 == p2).isTrue();
      check(p1 == p3).isFalse();
      check(p1.hashCode).equals(p2.hashCode);
      check(p1.sample()).isNotNull();
      check(p3.sample()).isNotNull();

      // Geometric
      const g1 = GeometricDistribution(0.3);
      const g2 = GeometricDistribution(0.3);
      const g3 = GeometricDistribution(0.7);
      check(g1 == g2).isTrue();
      check(g1 == g3).isFalse();
      check(g1.hashCode).equals(g2.hashCode);
      check(g1.sample()).isNotNull();

      // Hypergeometric early breaks (K == 0, K == N)
      const h1 = HypergeometricDistribution(50, 20, 10);
      const h2 = HypergeometricDistribution(50, 20, 10);
      const h3 = HypergeometricDistribution(50, 25, 10);
      check(h1 == h2).isTrue();
      check(h1 == h3).isFalse();
      check(h1.hashCode).equals(h2.hashCode);
      check(h1.sample()).isNotNull();

      const hZeroK = HypergeometricDistribution(10, 0, 5);
      check(hZeroK.sample()).equals(0);

      const hAllK = HypergeometricDistribution(10, 10, 5);
      check(hAllK.sample()).equals(5);

      // Negative Binomial
      const nb1 = NegativeBinomialDistribution(5, 0.5);
      const nb2 = NegativeBinomialDistribution(5, 0.5);
      const nb3 = NegativeBinomialDistribution(5, 0.6);
      check(nb1 == nb2).isTrue();
      check(nb1 == nb3).isFalse();
      check(nb1.hashCode).equals(nb2.hashCode);
      check(nb1.sample()).isNotNull();

      // Rademacher
      const r1 = RademacherDistribution();
      const r2 = RademacherDistribution();
      check(r1 == r2).isTrue();
      check(r1.hashCode).equals(r2.hashCode);
      check(r1.sample()).isNotNull();

      // Uniform Discrete
      const u1 = UniformDiscreteDistribution(1, 6);
      const u2 = UniformDiscreteDistribution(1, 6);
      const u3 = UniformDiscreteDistribution(1, 10);
      check(u1 == u2).isTrue();
      check(u1 == u3).isFalse();
      check(u1.hashCode).equals(u2.hashCode);
      check(u1.sample()).isNotNull();
    });

    test('DiscreteDistribution default implementations', () {
      final custom = _TestDiscreteDist();
      check(custom.lowerBound).equals(-9007199254740991);
      check(custom.probability(0)).equals(0.5);
    });
  });
}

class _TestDiscreteDist extends DiscreteDistribution {
  @override
  double cumulativeProbability(int k) => k >= 0 ? 1.0 : 0.5;

  @override
  int sample({math.Random? random}) => 0;

  @override
  double get mean => 0.0;
  @override
  double get median => 0.0;
  @override
  double get mode => 0.0;
  @override
  double get variance => 0.0;
  @override
  double get skewness => 0.0;
  @override
  double get excessKurtosis => 0.0;
}
