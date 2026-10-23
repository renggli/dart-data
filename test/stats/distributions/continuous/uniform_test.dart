import 'package:checks/checks.dart';
import 'package:data/stats.dart';
import 'package:test/test.dart';

void main() {
  group('UniformDistribution moments and probabilities', () {
    test('moments, pdf, cdf, and quantile', () {
      final dist = UniformDistribution(10.0, 20.0);
      check(dist.min).equals(10.0);
      check(dist.max).equals(20.0);
      check(dist.lowerBound).equals(10.0);
      check(dist.upperBound).equals(20.0);
      check(dist.isLowerBoundOpen).isFalse();
      check(dist.isUpperBoundOpen).isFalse();
      check(dist.mean).equals(15.0);
      check(dist.median).equals(15.0);
      check(dist.mode.isNaN).isTrue();
      check(dist.variance).isCloseTo(100.0 / 12.0, 1e-6);
      check(dist.skewness).equals(0.0);
      check(dist.excessKurtosis).equals(-1.2);

      check(dist.probability(15.0)).equals(0.1);
      check(dist.probability(5.0)).equals(0.0);
      check(dist.probability(25.0)).equals(0.0);
      check(dist.cumulativeProbability(5.0)).equals(0.0);
      check(dist.cumulativeProbability(15.0)).equals(0.5);
      check(dist.cumulativeProbability(25.0)).equals(1.0);
      check(dist.inverseCumulativeProbability(0.5)).equals(15.0);
      check(() => dist.inverseCumulativeProbability(-0.1))
          .throws<InvalidProbability>();

      // Standard constructor
      const stdUniform = UniformDistribution.standard();
      check(stdUniform.min).equals(0.0);
      check(stdUniform.max).equals(1.0);
    });
  });

  group('UniformDistribution estimation and validation', () {
    test('samples, fit, errors, and equality', () {
      final dist = UniformDistribution(10.0, 20.0);
      // Fit
      final samples = [10.5, 12.0, 15.0, 19.5];
      final fitted = UniformDistribution.fit(samples);
      check(fitted.min).equals(10.5);
      check(fitted.max).equals(19.5);
      check(UniformDistribution.fit(const [5.0]).max).equals(6.0);
      check(() => UniformDistribution.fit(const [])).throws<ArgumentError>();

      // Constructor validation
      check(() => UniformDistribution(20.0, 10.0)).throws<ArgumentError>();
      check(() => UniformDistribution(10.0, 10.0)).throws<ArgumentError>();

      // Equality and toString
      check(dist == UniformDistribution(10.0, 20.0)).isTrue();
      check(dist.hashCode).equals(UniformDistribution(10.0, 20.0).hashCode);
      check(dist.toString()).contains('UniformDistribution');
    });
  });
}
