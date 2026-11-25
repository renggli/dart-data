import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/stats.dart';
import 'package:test/scaffolding.dart';

void main() {
  const standard = UniformDistribution.standard();
  final dist = UniformDistribution(10.0, 20.0);

  group('UniformDistribution moments and bounds', () {
    test('parameters, bounds, and moments', () {
      check(standard.min).equals(0.0);
      check(standard.max).equals(1.0);
      check(dist.min).equals(10.0);
      check(dist.max).equals(20.0);
      check(dist.lowerBound).equals(10.0);
      check(dist.upperBound).equals(20.0);
      check(dist.isLowerBoundOpen).isFalse;
      check(dist.isUpperBoundOpen).isFalse;
      check(dist.mean).equals(15.0);
      check(dist.median).equals(15.0);
      check(dist.mode.isNaN).isTrue;
      check(dist.variance).isCloseTo(100.0 / 12.0, 1e-12);
      check(dist.skewness).equals(0.0);
      check(dist.excessKurtosis).equals(-1.2);

      // Overflow-safe midpoint mean across wide intervals.
      final wide = UniformDistribution(-1e308, 1e308);
      check(wide.mean).equals(0.0);
    });
  });

  group('UniformDistribution probabilities', () {
    test(
      'probability and logProbability handle interior, boundaries, and NaN',
      () {
        check(dist.probability(9.9)).equals(0.0);
        check(dist.probability(10.0)).equals(0.1);
        check(dist.probability(15.0)).equals(0.1);
        check(dist.probability(20.0)).equals(0.1);
        check(dist.probability(20.1)).equals(0.0);
        check(dist.probability(double.nan).isNaN).isTrue;

        check(dist.logProbability(9.9)).equals(double.negativeInfinity);
        check(dist.logProbability(15.0)).isCloseTo(-math.log(10.0), 1e-12);
        check(dist.logProbability(double.nan).isNaN).isTrue;
      },
    );

    test('cumulativeProbability and survival are complementary', () {
      check(dist.cumulativeProbability(5.0)).equals(0.0);
      check(dist.cumulativeProbability(15.0)).equals(0.5);
      check(dist.cumulativeProbability(25.0)).equals(1.0);
      check(dist.survival(5.0)).equals(1.0);
      check(dist.survival(15.0)).equals(0.5);
      check(dist.survival(25.0)).equals(0.0);
      check(dist.cumulativeProbability(double.nan).isNaN).isTrue;
      check(dist.survival(double.nan).isNaN).isTrue;
    });

    test('inverseCumulativeProbability and inverseSurvival round-trips', () {
      check(dist.inverseCumulativeProbability(0.0)).equals(10.0);
      check(dist.inverseCumulativeProbability(0.25)).equals(12.5);
      check(dist.inverseCumulativeProbability(1.0)).equals(20.0);
      check(dist.inverseSurvival(1.0)).equals(10.0);
      check(dist.inverseSurvival(0.25)).equals(17.5);
      check(dist.inverseSurvival(0.0)).equals(20.0);

      check(() => dist.inverseCumulativeProbability(-0.1))
          .throws<InvalidProbability>();
      check(() => dist.inverseSurvival(1.1)).throws<InvalidProbability>();
    });
  });

  group('UniformDistribution sampling, fitting, and validation', () {
    test('samples stay within [min, max]', () {
      final single = dist.sample();
      check(single).isGreaterOrEqual(10.0);
      check(single).isLessOrEqual(20.0);

      final samples = dist.samples(random: math.Random(42)).take(500).toList();
      check(samples.every((x) => x >= 10.0 && x < 20.0)).isTrue;
    });

    test('fit estimates bounds and handles single or invalid samples', () {
      final fitted = UniformDistribution.fit(const [10.5, 12.0, 15.0, 19.5]);
      check(fitted.min).equals(10.5);
      check(fitted.max).equals(19.5);

      final singleton = UniformDistribution.fit(const [5.0]);
      check(singleton.min).equals(5.0);
      check(singleton.max).equals(6.0);

      check(() => UniformDistribution.fit(const [])).throws<ArgumentError>();
      check(() => UniformDistribution.fit(const [1.0, double.nan]))
          .throws<ArgumentError>();
      check(() => UniformDistribution.fit(const [1.0, double.infinity]))
          .throws<ArgumentError>();
    });

    test('constructor validation', () {
      check(() => UniformDistribution(20.0, 10.0)).throws<ArgumentError>();
      check(() => UniformDistribution(10.0, 10.0)).throws<ArgumentError>();
      check(() => UniformDistribution(double.negativeInfinity, 1.0))
          .throws<ArgumentError>();
      check(() => UniformDistribution(0.0, double.infinity))
          .throws<ArgumentError>();
    });

    test('equality, hashCode, and string representation', () {
      check(standard == UniformDistribution(0.0, 1.0)).isTrue;
      check(standard.hashCode).equals(UniformDistribution(0.0, 1.0).hashCode);
      check(standard == dist).isFalse;
      check(dist.toString()).contains('UniformDistribution');
    });
  });
}
