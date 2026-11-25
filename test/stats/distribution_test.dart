import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/stats.dart';
import 'package:test/scaffolding.dart';

class _MinimalDistribution extends Distribution<double> {
  const new();

  @override
  double get lowerBound => 0.0;

  @override
  bool get isLowerBoundOpen => false;

  @override
  double get upperBound => 1.0;

  @override
  bool get isUpperBoundOpen => false;

  @override
  double get mean => 0.5;

  @override
  double get median => 0.5;

  @override
  double get mode => double.nan;

  @override
  double get variance => 1.0 / 12.0;

  @override
  double get skewness => 0.0;

  @override
  double get excessKurtosis => -1.2;

  @override
  double probability(double x) => (x >= 0.0 && x <= 1.0) ? 1.0 : 0.0;

  @override
  double cumulativeProbability(double x) => x.clamp(0.0, 1.0);

  @override
  double inverseCumulativeProbability(num probability) {
    InvalidProbability.check(probability);
    return probability.toDouble();
  }

  @override
  double sample({math.Random? random}) =>
      (random ?? math.Random()).nextDouble();
}

void main() {
  const distribution = _MinimalDistribution();

  group('Distribution base contract', () {
    test('computes standardDeviation from variance', () {
      check(distribution.standardDeviation)
          .isCloseTo(math.sqrt(1.0 / 12.0), 1e-12);
    });

    test('computes default logProbability via probability', () {
      check(distribution.logProbability(0.5)).equals(0.0);
      check(distribution.logProbability(-1.0)).equals(double.negativeInfinity);
    });

    test('computes default survival and inverseSurvival', () {
      check(distribution.survival(0.25)).isCloseTo(0.75, 1e-12);
      check(distribution.inverseSurvival(0.25)).isCloseTo(0.75, 1e-12);
      check(() => distribution.inverseSurvival(-0.1))
          .throws<InvalidProbability>();
      check(() => distribution.inverseSurvival(1.1))
          .throws<InvalidProbability>();
    });

    test('generates lazy infinite samples stream', () {
      final draws = distribution
          .samples(random: math.Random(7))
          .take(5)
          .toList();
      check(draws.length).equals(5);
      check(draws.every((value) => value >= 0.0 && value < 1.0)).isTrue;
    });
  });
}
