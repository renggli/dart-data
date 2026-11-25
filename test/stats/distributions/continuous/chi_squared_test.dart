import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/stats.dart';
import 'package:test/scaffolding.dart';

void main() {
  final chi2 = ChiSquaredDistribution(2.0);
  final chi5 = ChiSquaredDistribution(5.0);

  group('ChiSquaredDistribution moments and bounds', () {
    test('parameters, support bounds, and moments', () {
      check(chi5.dof).equals(5.0);
      check(chi5.lowerBound).equals(0.0);
      check(chi5.upperBound).equals(double.infinity);
      check(chi5.isLowerBoundOpen).isFalse;
      check(chi5.isUpperBoundOpen).isTrue;
      check(chi2.isLowerBoundOpen).isFalse;
      check(chi5.mean).equals(5.0);
      check(chi5.mode).equals(3.0);
      check(ChiSquaredDistribution(1.0).mode).equals(0.0);
      check(chi5.variance).equals(10.0);
      check(chi5.standardDeviation).isCloseTo(math.sqrt(10.0), 1e-12);
      check(chi5.skewness).isCloseTo(math.sqrt(8.0 / 5.0), 1e-12);
      check(chi5.excessKurtosis).equals(2.4);
      check(chi2.median).isCloseTo(2.0 * math.ln2, 1e-12);
    });
  });

  group('ChiSquaredDistribution probabilities', () {
    test('probability and logProbability at boundary and interior', () {
      check(chi2.probability(0.0)).equals(0.5);
      check(chi2.logProbability(0.0)).isCloseTo(math.log(0.5), 1e-12);
      check(chi5.probability(-1.0)).equals(0.0);
      check(chi5.logProbability(-1.0)).equals(double.negativeInfinity);
      check(chi5.probability(0.0)).equals(0.0);
      check(chi5.logProbability(0.0)).equals(double.negativeInfinity);
      check(chi5.probability(3.0)).isCloseTo(0.15418032980381084, 1e-12);
      check(chi5.logProbability(3.0))
          .isCloseTo(math.log(chi5.probability(3.0)), 1e-12);
      check(chi5.probability(double.nan).isNaN).isTrue;
    });

    test('cumulativeProbability and survival retain upper-tail precision', () {
      check(chi2.cumulativeProbability(0.0)).equals(0.0);
      check(chi2.cumulativeProbability(2.0))
          .isCloseTo(1.0 - math.exp(-1.0), 1e-12);
      check(chi2.survival(2.0)).isCloseTo(math.exp(-1.0), 1e-12);
      check(chi5.survival(0.0)).equals(1.0);
      check(chi5.survival(-1.0)).equals(1.0);
      check(chi5.survival(double.infinity)).equals(0.0);
      check(chi5.cumulativeProbability(10.0) + chi5.survival(10.0))
          .isCloseTo(1.0, 1e-14);
      check(chi5.survival(100.0)).isGreaterThan(0.0);
      check(chi5.cumulativeProbability(double.nan).isNaN).isTrue;
      check(chi5.survival(double.nan).isNaN).isTrue;
    });

    test('inverseCumulativeProbability and inverseSurvival round-trips', () {
      check(chi5.inverseCumulativeProbability(0.0)).equals(0.0);
      check(chi5.inverseCumulativeProbability(1.0)).equals(double.infinity);
      check(chi5.inverseSurvival(1.0)).equals(0.0);
      check(chi5.inverseSurvival(0.0)).equals(double.infinity);

      for (final p in const [1e-6, 0.05, 0.5, 0.95]) {
        final x = chi5.inverseCumulativeProbability(p);
        check(chi5.cumulativeProbability(x)).isCloseTo(p, 1e-10);
        final xs = chi5.inverseSurvival(p);
        check(chi5.survival(xs)).isCloseTo(p, 1e-10);
      }

      check(() => chi5.inverseCumulativeProbability(-0.1))
          .throws<InvalidProbability>();
      check(() => chi5.inverseSurvival(1.1)).throws<InvalidProbability>();
    });
  });

  group('ChiSquaredDistribution sampling, fitting, and validation', () {
    test('samples match theoretical mean', () {
      final samples = chi5.samples(random: math.Random(42)).take(2000).toList();
      final sampleMean = samples.reduce((a, b) => a + b) / samples.length;
      check(sampleMean).isCloseTo(5.0, 0.3);
      check(samples.every((x) => x >= 0.0)).isTrue;
    });

    test('fit estimates degrees of freedom and validates inputs', () {
      final fitted = ChiSquaredDistribution.fit(const [2.0, 4.0, 6.0]);
      check(fitted.dof).isCloseTo(4.0, 1e-12);
      final zeroFit = ChiSquaredDistribution.fit(const [0.0, 0.0]);
      check(zeroFit.dof).equals(1.0);

      check(() => ChiSquaredDistribution.fit(const [])).throws<ArgumentError>();
      check(() => ChiSquaredDistribution.fit(const [-1.0, 2.0]))
          .throws<ArgumentError>();
    });

    test('constructor validation', () {
      check(() => ChiSquaredDistribution(0.0)).throws<ArgumentError>();
      check(() => ChiSquaredDistribution(-1.0)).throws<ArgumentError>();
      check(() => ChiSquaredDistribution(double.infinity))
          .throws<ArgumentError>();
    });

    test('equality, hashCode, and string representation', () {
      check(chi5 == ChiSquaredDistribution(5.0)).isTrue;
      check(chi5.hashCode).equals(ChiSquaredDistribution(5.0).hashCode);
      check(chi5 == chi2).isFalse;
      check(chi5.toString()).contains('ChiSquaredDistribution');
    });
  });
}
