import 'package:checks/checks.dart';
import 'package:data/stats.dart';
import 'package:test/test.dart';

void main() {
  group('DegenerateDistribution moments and probabilities', () {
    test('moments, pdf, cdf, and quantile', () {
      const dist = DegenerateDistribution(5.0);
      check(dist.k).equals(5.0);
      check(dist.mean).equals(5.0);
      check(dist.median).equals(5.0);
      check(dist.mode).equals(5.0);
      check(dist.variance).equals(0.0);
      check(dist.standardDeviation).equals(0.0);
      check(dist.skewness.isNaN).isTrue();
      check(dist.excessKurtosis.isNaN).isTrue();

      check(dist.probability(5.0)).equals(1.0);
      check(dist.probability(3.0)).equals(0.0);
      check(dist.cumulativeProbability(4.0)).equals(0.0);
      check(dist.cumulativeProbability(5.0)).equals(1.0);
      check(dist.cumulativeProbability(6.0)).equals(1.0);
      check(dist.inverseCumulativeProbability(0.5)).equals(5.0);
      check(() => dist.inverseCumulativeProbability(-0.1))
          .throws<InvalidProbability>();

      // Default constructor
      const defaultDegenerate = DegenerateDistribution();
      check(defaultDegenerate.k).equals(0.0);
    });
  });

  group('DegenerateDistribution estimation and validation', () {
    test('samples, fit, errors, and equality', () {
      const dist = DegenerateDistribution(5.0);
      // Samples
      final samples = dist.samples().take(10).toList();
      check(samples.every((sample) => sample == 5.0)).isTrue();

      // Equality and toString
      check(dist == const DegenerateDistribution(5.0)).isTrue();
      check(dist.hashCode).equals(const DegenerateDistribution(5.0).hashCode);
      check(dist.toString()).contains('DegenerateDistribution');
    });
  });
}
