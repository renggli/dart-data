import 'dart:math';

import 'package:checks/checks.dart';
import 'package:data/special.dart';
import 'package:data/stats.dart';
import 'package:test/test.dart';

class _SimpleDistribution extends Distribution<double> {
  const new();

  @override
  double get lowerBound => 0.0;

  @override
  bool get isLowerBoundOpen => false;

  @override
  double get upperBound => 10.0;

  @override
  bool get isUpperBoundOpen => false;

  @override
  double get mean => 5.0;

  @override
  double get median => 5.0;

  @override
  double get mode => 5.0;

  @override
  double get variance => 4.0;

  @override
  double get skewness => 0.0;

  @override
  double get excessKurtosis => 0.0;

  @override
  double probability(double x) => (x >= 0.0 && x <= 10.0) ? 0.1 : 0.0;

  @override
  double cumulativeProbability(double x) {
    if (x <= 0.0) return 0.0;
    if (x >= 10.0) return 1.0;
    return x / 10.0;
  }

  @override
  double inverseCumulativeProbability(num probability) =>
      probability.toDouble() * 10.0;

  @override
  double sample({Random? random}) => (random?.nextDouble() ?? 0.5) * 10.0;
}

void main() {
  group('Distribution base class', () {
    const dist = _SimpleDistribution();

    test('derived moments and bounds', () {
      check(dist.standardDeviation).equals(2.0);
      check(dist.excessKurtosis).equals(0.0);
      check(dist.lowerBound).equals(0.0);
      check(dist.upperBound).equals(10.0);
      check(dist.isLowerBoundOpen).isFalse();
      check(dist.isUpperBoundOpen).isFalse();
    });

    test('probabilities and CDF', () {
      check(dist.probability(5.0)).equals(0.1);
      check(dist.cumulativeProbability(5.0)).equals(0.5);
      check(dist.inverseCumulativeProbability(0.5)).equals(5.0);
      check(dist.survival(5.0)).equals(0.5);
      check(dist.inverseSurvival(0.25)).equals(7.5);
    });

    test('sampling', () {
      final s = dist.sample();
      check(s).isGreaterOrEqual(0.0);
      check(s).isLessOrEqual(10.0);

      final list = dist.samples().take(5).toList();
      check(list.length).equals(5);

      final gammaDist = GammaDistribution(2.0, 1.0);
      check(gammaDist.survival(-1.0)).equals(1.0);
      check(gammaDist.survival(1.0)).isGreaterThan(0.0);

      final invGamma = InverseGammaDistribution(5.0, 1.0);
      check(invGamma.excessKurtosis).isCloseTo(42.0, 1e-12);

      check(combination(5, 4)).equals(5.0);
      check(combination(5.5, 2.5)).isGreaterThan(10.0);
      check(permutation(5.5, 2.5)).isGreaterThan(20.0);
    });
  });
}
