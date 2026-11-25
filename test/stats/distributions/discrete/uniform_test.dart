import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/stats.dart';
import 'package:test/scaffolding.dart';

void main() {
  final dist = UniformDiscreteDistribution(1, 6);
  final point = UniformDiscreteDistribution(3, 3);

  group('UniformDiscreteDistribution moments and bounds', () {
    test('parameters, bounds, and moments', () {
      check(dist.min).equals(1);
      check(dist.max).equals(6);
      check(dist.n).equals(6);
      check(dist.lowerBound).equals(1);
      check(dist.upperBound).equals(6);
      check(dist.isLowerBoundOpen).isFalse;
      check(dist.isUpperBoundOpen).isFalse;
      check(dist.mean).equals(3.5);
      check(dist.median).equals(3.5);
      check(dist.mode.isNaN).isTrue;
      check(dist.variance).isCloseTo(35.0 / 12.0, 1e-12);
      check(dist.standardDeviation).isCloseTo(math.sqrt(35.0 / 12.0), 1e-12);
      check(dist.skewness).equals(0.0);
      check(dist.excessKurtosis).isCloseTo(-1.2685714285714285, 1e-12);
    });

    test('degenerate single-point moments and large-range variance overflow safety', () {
      check(point.n).equals(1);
      check(point.variance).equals(0.0);
      check(point.skewness.isNaN).isTrue;
      check(point.excessKurtosis.isNaN).isTrue;

      // n = 4,000,000,001 > 2^32 avoids signed int64 multiplication overflow.
      final huge = UniformDiscreteDistribution(0, 4000000000);
      check(huge.variance).isGreaterThan(0.0);
      check(huge.variance.isFinite).isTrue;
      check(huge.excessKurtosis).isCloseTo(-1.2, 1e-12);
    });
  });

  group('UniformDiscreteDistribution probabilities', () {
    test('probability and logProbability across support and outside', () {
      check(dist.probability(0)).equals(0.0);
      check(dist.probability(1)).isCloseTo(1.0 / 6.0, 1e-12);
      check(dist.probability(6)).isCloseTo(1.0 / 6.0, 1e-12);
      check(dist.probability(7)).equals(0.0);

      check(dist.logProbability(0)).equals(double.negativeInfinity);
      check(dist.logProbability(1)).isCloseTo(-math.log(6.0), 1e-12);
      check(dist.logProbability(7)).equals(double.negativeInfinity);
    });

    test('cumulativeProbability and survival are complementary', () {
      check(dist.cumulativeProbability(0)).equals(0.0);
      check(dist.cumulativeProbability(3)).isCloseTo(0.5, 1e-12);
      check(dist.cumulativeProbability(6)).equals(1.0);
      check(dist.cumulativeProbability(7)).equals(1.0);

      check(dist.survival(0)).equals(1.0);
      check(dist.survival(3)).isCloseTo(0.5, 1e-12);
      check(dist.survival(6)).equals(0.0);
      check(dist.survival(7)).equals(0.0);
    });

    test('inverseCumulativeProbability and inverseSurvival', () {
      check(dist.inverseCumulativeProbability(0.0)).equals(1);
      check(dist.inverseCumulativeProbability(0.5)).equals(3);
      check(dist.inverseCumulativeProbability(1.0)).equals(6);

      check(dist.inverseSurvival(1.0)).equals(1);
      check(dist.inverseSurvival(0.5)).equals(3);
      check(dist.inverseSurvival(0.0)).equals(6);

      check(() => dist.inverseCumulativeProbability(-0.1))
          .throws<InvalidProbability>();
      check(() => dist.inverseSurvival(1.1)).throws<InvalidProbability>();
    });
  });

  group('UniformDiscreteDistribution sampling, fitting, and validation', () {
    test('samples work across normal and huge (> 2^32) ranges', () {
      final samples = dist.samples(random: math.Random(42)).take(100).toList();
      check(samples.every((x) => x >= 1 && x <= 6)).isTrue;
      check(point.sample()).equals(3);

      final huge = UniformDiscreteDistribution(0, 5000000000);
      final rng = math.Random(7);
      for (var i = 0; i < 50; i++) {
        final s = huge.sample(random: rng);
        check(s).isGreaterOrEqual(0);
        check(s).isLessOrEqual(5000000000);
      }
    });

    test('fit estimates integer bounds and rejects non-integer samples', () {
      final fitted = UniformDiscreteDistribution.fit(const [2, 5, 3, 6]);
      check(fitted.min).equals(2);
      check(fitted.max).equals(6);

      check(() => UniformDiscreteDistribution.fit(const []))
          .throws<ArgumentError>();
      check(() => UniformDiscreteDistribution.fit(const [1.5, 2]))
          .throws<ArgumentError>();
    });

    test('constructor validation', () {
      check(() => UniformDiscreteDistribution(5, 3)).throws<ArgumentError>();
    });

    test('equality, hashCode, and string representation', () {
      check(dist == UniformDiscreteDistribution(1, 6)).isTrue;
      check(dist.hashCode).equals(UniformDiscreteDistribution(1, 6).hashCode);
      check(dist == point).isFalse;
      check(dist.toString()).contains('UniformDiscreteDistribution');
    });
  });
}
