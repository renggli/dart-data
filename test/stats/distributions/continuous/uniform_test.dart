import 'package:checks/checks.dart';
import 'package:data/stats.dart';
import 'package:test/test.dart';

void main() {
  group('UniformDistribution moments and probabilities', () {
    final dist = UniformDistribution(10.0, 20.0);

    test('moments and bounds', () {
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
    });

    test('probability density function', () {
      check(dist.probability(15.0)).equals(0.1);
      check(dist.probability(5.0)).equals(0.0);
      check(dist.probability(25.0)).equals(0.0);
    });

    test('cumulative probability', () {
      check(dist.cumulativeProbability(5.0)).equals(0.0);
      check(dist.cumulativeProbability(15.0)).equals(0.5);
      check(dist.cumulativeProbability(25.0)).equals(1.0);
    });

    test('inverse cumulative probability', () {
      check(dist.inverseCumulativeProbability(0.5)).equals(15.0);
      check(() => dist.inverseCumulativeProbability(-0.1))
          .throws<InvalidProbability>();
    });

    test('standard constructor', () {
      const stdUniform = UniformDistribution.standard();
      check(stdUniform.min).equals(0.0);
      check(stdUniform.max).equals(1.0);
    });
  });

  group('UniformDistribution estimation and validation', () {
    final dist = UniformDistribution(10.0, 20.0);

    test('fit', () {
      final samples = [10.5, 12.0, 15.0, 19.5];
      final fitted = UniformDistribution.fit(samples);
      check(fitted.min).equals(10.5);
      check(fitted.max).equals(19.5);
      check(UniformDistribution.fit(const [5.0]).max).equals(6.0);
    });

    test('fit errors', () {
      check(() => UniformDistribution.fit(const [])).throws<ArgumentError>();
    });

    test('constructor validation', () {
      check(() => UniformDistribution(20.0, 10.0)).throws<ArgumentError>();
      check(() => UniformDistribution(10.0, 10.0)).throws<ArgumentError>();
    });

    test('equality and hashCode', () {
      check(dist == UniformDistribution(10.0, 20.0)).isTrue();
      check(dist.hashCode).equals(UniformDistribution(10.0, 20.0).hashCode);
    });

    test('string conversion', () {
      check(dist.toString()).contains('UniformDistribution');
    });
  });
}
