import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/stats.dart';
import 'package:test/scaffolding.dart';

class _MinimalContinuousDistribution extends ContinuousDistribution {
  const new();

  @override
  double get mean => 0.0;

  @override
  double get mode => 0.0;

  @override
  double get variance => 1.0;

  @override
  double get skewness => 0.0;

  @override
  double get excessKurtosis => 0.0;

  @override
  double probability(double x) => 1.0 / (math.pi * (1.0 + x * x));

  @override
  double cumulativeProbability(double x) => 0.5 + math.atan(x) / math.pi;

  @override
  double inverseCumulativeProbability(num probability) {
    InvalidProbability.check(probability);
    return math.tan(math.pi * (probability - 0.5));
  }

  @override
  double sample({math.Random? random}) =>
      inverseCumulativeProbability((random ?? math.Random()).nextDouble());
}

void main() {
  const distribution = _MinimalContinuousDistribution();

  group('ContinuousDistribution defaults', () {
    test('defaults bounds to open (-infinity, +infinity)', () {
      check(distribution.lowerBound).equals(double.negativeInfinity);
      check(distribution.isLowerBoundOpen).isTrue;
      check(distribution.upperBound).equals(double.infinity);
      check(distribution.isUpperBoundOpen).isTrue;
    });

    test('computes median via inverseCumulativeProbability(0.5)', () {
      check(distribution.median).isCloseTo(0.0, 1e-12);
    });
  });
}
