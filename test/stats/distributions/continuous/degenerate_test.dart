import 'package:checks/checks.dart';
import 'package:data/stats.dart';
import 'package:test/scaffolding.dart';

void main() {
  const standard = DegenerateDistribution.standard();
  final dist = DegenerateDistribution(5.0);

  group('DegenerateDistribution moments and bounds', () {
    test('parameters, support bounds, and moments', () {
      check(dist.k).equals(5.0);
      check(standard.k).equals(0.0);
      check(dist.lowerBound).equals(5.0);
      check(dist.upperBound).equals(5.0);
      check(dist.isLowerBoundOpen).isFalse;
      check(dist.isUpperBoundOpen).isFalse;
      check(dist.mean).equals(5.0);
      check(dist.median).equals(5.0);
      check(dist.mode).equals(5.0);
      check(dist.variance).equals(0.0);
      check(dist.standardDeviation).equals(0.0);
      check(dist.skewness.isNaN).isTrue;
      check(dist.excessKurtosis.isNaN).isTrue;
    });
  });

  group('DegenerateDistribution probabilities', () {
    test('probability and logProbability', () {
      check(dist.probability(4.9)).equals(0.0);
      check(dist.probability(5.0)).equals(1.0);
      check(dist.probability(5.1)).equals(0.0);
      check(dist.probability(double.nan).isNaN).isTrue;

      check(dist.logProbability(4.9)).equals(double.negativeInfinity);
      check(dist.logProbability(5.0)).equals(0.0);
      check(dist.logProbability(double.nan).isNaN).isTrue;
    });

    test('cumulativeProbability and survival', () {
      check(dist.cumulativeProbability(4.9)).equals(0.0);
      check(dist.cumulativeProbability(5.0)).equals(1.0);
      check(dist.cumulativeProbability(5.1)).equals(1.0);
      check(dist.cumulativeProbability(double.nan).isNaN).isTrue;

      check(dist.survival(4.9)).equals(1.0);
      check(dist.survival(5.0)).equals(0.0);
      check(dist.survival(5.1)).equals(0.0);
      check(dist.survival(double.nan).isNaN).isTrue;
    });

    test('inverseCumulativeProbability and inverseSurvival', () {
      for (final p in const [0.0, 0.25, 0.5, 1.0]) {
        check(dist.inverseCumulativeProbability(p)).equals(5.0);
        check(dist.inverseSurvival(p)).equals(5.0);
      }
      check(() => dist.inverseCumulativeProbability(-0.1))
          .throws<InvalidProbability>();
      check(() => dist.inverseSurvival(1.1)).throws<InvalidProbability>();
    });
  });

  group('DegenerateDistribution sampling, fitting, and validation', () {
    test('sample always emits k', () {
      check(dist.sample()).equals(5.0);
      check(dist.samples().take(5).toList())
          .deepEquals([5.0, 5.0, 5.0, 5.0, 5.0]);
    });

    test(
      'fit succeeds on constant samples and rejects non-constant inputs',
      () {
        check(DegenerateDistribution.fit(const [5.0])).equals(dist);
        check(DegenerateDistribution.fit(const [5, 5.0, 5])).equals(dist);
        check(() => DegenerateDistribution.fit(const []))
            .throws<ArgumentError>();
        check(() => DegenerateDistribution.fit(const [1.0, 2.0]))
            .throws<ArgumentError>();
        check(() => DegenerateDistribution.fit(const [double.nan]))
            .throws<ArgumentError>();
        check(() => DegenerateDistribution.fit(const [double.infinity]))
            .throws<ArgumentError>();
      },
    );

    test('constructor validation', () {
      check(() => DegenerateDistribution(double.nan)).throws<ArgumentError>();
      check(() => DegenerateDistribution(double.infinity))
          .throws<ArgumentError>();
    });

    test('equality, hashCode, and string representation', () {
      check(standard == DegenerateDistribution(0.0)).isTrue;
      check(standard.hashCode).equals(DegenerateDistribution(0.0).hashCode);
      check(standard == dist).isFalse;
      check(dist.toString()).contains('DegenerateDistribution');
    });
  });
}
