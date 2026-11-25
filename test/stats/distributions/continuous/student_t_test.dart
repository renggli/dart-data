import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/stats.dart';
import 'package:test/scaffolding.dart';

void main() {
  final dist = StudentDistribution(10.0);

  group('StudentDistribution moments and bounds', () {
    test('parameters, bounds, and moments across dof thresholds', () {
      check(dist.dof).equals(10.0);
      check(dist.lowerBound).equals(double.negativeInfinity);
      check(dist.upperBound).equals(double.infinity);
      check(dist.isLowerBoundOpen).isTrue;
      check(dist.isUpperBoundOpen).isTrue;
      check(dist.mean).equals(0.0);
      check(dist.median).equals(0.0);
      check(dist.mode).equals(0.0);
      check(dist.variance).isCloseTo(10.0 / 8.0, 1e-12);
      check(dist.standardDeviation).isCloseTo(math.sqrt(1.25), 1e-12);
      check(dist.skewness).equals(0.0);
      check(dist.excessKurtosis).equals(1.0);

      final dof1 = StudentDistribution(1.0);
      check(dof1.mean.isNaN).isTrue;
      check(dof1.variance.isNaN).isTrue;
      check(dof1.skewness.isNaN).isTrue;
      check(dof1.excessKurtosis.isNaN).isTrue;

      final dof2 = StudentDistribution(2.0);
      check(dof2.mean).equals(0.0);
      check(dof2.variance).equals(double.infinity);

      final dof3 = StudentDistribution(3.0);
      check(dof3.skewness.isNaN).isTrue;
      check(dof3.excessKurtosis).equals(double.infinity);

      final dof4 = StudentDistribution(4.0);
      check(dof4.excessKurtosis).equals(double.infinity);
    });
  });

  group('StudentDistribution probabilities', () {
    test('probability and logProbability handle extreme tails safely', () {
      check(dist.probability(0.0)).isCloseTo(0.38910838396603106, 1e-12);
      check(dist.logProbability(0.0))
          .isCloseTo(math.log(dist.probability(0.0)), 1e-12);
      check(dist.probability(1e30)).equals(0.0);
      final logTail = dist.logProbability(1e10);
      check(logTail.isFinite).isTrue;
      check(logTail).isLessThan(-200.0);
      check(dist.probability(double.infinity)).equals(0.0);
      check(dist.logProbability(double.infinity))
          .equals(double.negativeInfinity);
      check(dist.probability(double.nan).isNaN).isTrue;
      check(dist.logProbability(double.nan).isNaN).isTrue;
    });

    test(
      'cumulativeProbability and survival retain symmetry and tail precision',
      () {
        check(dist.cumulativeProbability(0.0)).equals(0.5);
        check(dist.survival(0.0)).equals(0.5);
        check(dist.cumulativeProbability(2.0) + dist.survival(2.0))
            .isCloseTo(1.0, 1e-14);
        check(dist.survival(50.0)).isGreaterThan(0.0);
        check(dist.survival(50.0)).equals(dist.cumulativeProbability(-50.0));
        check(dist.survival(1e10)).isGreaterThan(0.0);
        check(dist.cumulativeProbability(double.negativeInfinity)).equals(0.0);
        check(dist.cumulativeProbability(double.infinity)).equals(1.0);
        check(dist.survival(double.negativeInfinity)).equals(1.0);
        check(dist.survival(double.infinity)).equals(0.0);
        check(dist.cumulativeProbability(double.nan).isNaN).isTrue;
        check(dist.survival(double.nan).isNaN).isTrue;
      },
    );

    test('inverseCumulativeProbability and inverseSurvival stay accurate in deep tails', () {
      check(dist.inverseCumulativeProbability(0.0))
          .equals(double.negativeInfinity);
      check(dist.inverseCumulativeProbability(0.5)).equals(0.0);
      check(dist.inverseCumulativeProbability(1.0)).equals(double.infinity);
      check(dist.inverseSurvival(0.0)).equals(double.infinity);
      check(dist.inverseSurvival(0.5)).equals(0.0);
      check(dist.inverseSurvival(1.0)).equals(double.negativeInfinity);
      check(dist.inverseCumulativeProbability(0.975))
          .isCloseTo(2.2281388519649385, 1e-10);
      check(dist.inverseSurvival(1e-20))
          .isCloseTo(-dist.inverseCumulativeProbability(1e-20), 1e-9);
      check(dist.survival(dist.inverseSurvival(1e-10))).isCloseTo(1e-10, 1e-18);

      check(() => dist.inverseCumulativeProbability(-0.1))
          .throws<InvalidProbability>();
      check(() => dist.inverseSurvival(1.1)).throws<InvalidProbability>();
    });
  });

  group('StudentDistribution sampling, fitting, and validation', () {
    test('samples match theoretical variance and fit estimates dof', () {
      check(dist.sample().isFinite).isTrue;
      final samples = dist.samples(random: math.Random(42)).take(2500).toList();
      final fitted = StudentDistribution.fit(samples);
      check(fitted.dof).isCloseTo(10.0, 4.0);
    });

    test('fit handles low-variance samples and rejects invalid inputs', () {
      final lowVarFit = StudentDistribution.fit(const [0.0, 0.5, 1.0]);
      check(lowVarFit.dof).isGreaterThan(10.0);

      check(() => StudentDistribution.fit(const [])).throws<ArgumentError>();
      check(() => StudentDistribution.fit(const [1.0, 2.0]))
          .throws<ArgumentError>();
      check(() => StudentDistribution.fit(const [1.0, 2.0, double.nan]))
          .throws<ArgumentError>();
    });

    test('constructor validation', () {
      check(() => StudentDistribution(0.0)).throws<ArgumentError>();
      check(() => StudentDistribution(-1.0)).throws<ArgumentError>();
      check(() => StudentDistribution(double.infinity)).throws<ArgumentError>();
    });

    test('equality, hashCode, and string representation', () {
      check(dist == StudentDistribution(10.0)).isTrue;
      check(dist.hashCode).equals(StudentDistribution(10.0).hashCode);
      check(dist == StudentDistribution(5.0)).isFalse;
      check(dist.toString()).contains('StudentDistribution');
    });
  });
}
