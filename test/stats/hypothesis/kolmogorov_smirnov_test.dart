import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/stats.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('kolmogorovSmirnovTest', () {
    test('evaluates two-sided and one-sided alternatives against continuous distributions', () {
      const normal = NormalDistribution.standard();
      final normalSample = normal
          .samples(random: math.Random(42))
          .take(100)
          .toList();
      final resNormal = kolmogorovSmirnovTest(normalSample, normal);
      check(resNormal.isSignificant).isFalse;
      check(resNormal.pValue).isGreaterThan(0.05);
      check(resNormal.statistic).isLessThan(0.15);

      const uniform = UniformDistribution.standard();
      final uniformSample = uniform
          .samples(random: math.Random(42))
          .take(120)
          .toList();
      final resReject = kolmogorovSmirnovTest(uniformSample, normal);
      check(resReject.isSignificant).isTrue;
      check(resReject.pValue).isLessThan(1e-4);

      // Shifted sample below N(0,1) produces large D+ (empirical > theoretical).
      final shiftedDown = [for (final x in normalSample) x - 1.5];
      final resGreater = kolmogorovSmirnovTest(
        shiftedDown,
        normal,
        alternative: AlternativeHypothesis.greater,
      );
      check(resGreater.isSignificant).isTrue;
      final resLess = kolmogorovSmirnovTest(
        shiftedDown,
        normal,
        alternative: AlternativeHypothesis.less,
      );
      check(resLess.pValue).isGreaterThan(0.9);
    });

    test(
      'matches exact small-sample Marsaglia-Tsang-Wang and Smirnov p-values',
      () {
        const uniform = UniformDistribution.standard();

        final res1 = kolmogorovSmirnovTest(const [0.7], uniform);
        check(res1.statistic).isCloseTo(0.7, 1e-12);
        check(res1.pValue).isCloseTo(0.6, 1e-12);

        final res1Greater = kolmogorovSmirnovTest(
          const [0.3],
          uniform,
          alternative: AlternativeHypothesis.greater,
        );
        // D+ = 1 - 0.3 = 0.7 -> exact P(D+ >= 0.7) = 0.3
        check(res1Greater.statistic).isCloseTo(0.7, 1e-12);
        check(res1Greater.pValue).isCloseTo(0.3, 1e-12);

        final res2 = kolmogorovSmirnovTest(const [0.4, 0.4], uniform);
        check(res2.statistic).isCloseTo(0.6, 1e-12);
        check(res2.pValue).isCloseTo(0.32, 1e-12);

        final res5 = kolmogorovSmirnovTest(const [
          0.1,
          0.2,
          0.3,
          0.4,
          0.5,
        ], uniform);
        check(res5.statistic).isCloseTo(0.5, 1e-12);
        check(res5.pValue).isCloseTo(0.112, 1e-12);
      },
    );

    test(
      'uses asymptotic approximations above n = 100 and validates inputs',
      () {
        const normal = NormalDistribution.standard();
        final large = normal.samples(random: math.Random(1)).take(150).toList();
        final largeTwoSided = kolmogorovSmirnovTest(large, normal);
        check(largeTwoSided.pValue).isGreaterThan(0.05);
        final largeOneSided = kolmogorovSmirnovTest(
          large,
          normal,
          alternative: AlternativeHypothesis.greater,
        );
        check(largeOneSided.pValue).isGreaterThan(0.05);

        check(() => kolmogorovSmirnovTest(const <double>[], normal))
            .throws<ArgumentError>();
        check(
          () => kolmogorovSmirnovTest(const [
            1.0,
            2.0,
          ], DegenerateDistribution(1.0)),
        ).throws<ArgumentError>();
        check(() => kolmogorovSmirnovTest(const [1.0], normal, alpha: 0.0))
            .throws<ArgumentError>();

        final nanRes = kolmogorovSmirnovTest(const [
          1.0,
          double.nan,
          2.0,
        ], normal);
        check(nanRes.statistic.isNaN).isTrue;
        check(nanRes.pValue.isNaN).isTrue;
        final nanCdfRes = kolmogorovSmirnovTest(const [
          1.0,
          2.0,
        ], const _NanCdfDistribution());
        check(nanCdfRes.statistic.isNaN).isTrue;
        check(nanCdfRes.pValue.isNaN).isTrue;
      },
    );
  });

  group('kolmogorovSmirnovTwoSample', () {
    test('compares two empirical samples via asymptotic and exact DP paths', () {
      const normal = NormalDistribution.standard();
      final sample1 = normal.samples(random: math.Random(1)).take(120).toList();
      final sample2 = normal.samples(random: math.Random(2)).take(120).toList();

      final resSame = kolmogorovSmirnovTwoSample(sample1, sample2);
      check(resSame.isSignificant).isFalse;
      check(resSame.pValue).isGreaterThan(0.05);

      final shifted = [for (final x in sample1) x + 3.0];
      final resDiff = kolmogorovSmirnovTwoSample(sample1, shifted);
      check(resDiff.isSignificant).isTrue;
      check(resDiff.pValue).isLessThan(1e-4);

      // Exact untied small two-sample DP checks:
      // [1, 2] vs [3, 4] has D = 1.0 => exact P(twoSided) = 2 / C(4, 2) = 1/3, P(greater) = 1/6.
      final exactTwo = kolmogorovSmirnovTwoSample(
        const [1.0, 2.0],
        const [3.0, 4.0],
      );
      check(exactTwo.statistic).equals(1.0);
      check(exactTwo.pValue).isCloseTo(1.0 / 3.0, 1e-12);

      final exactGreater = kolmogorovSmirnovTwoSample(
        const [1.0, 2.0],
        const [3.0, 4.0],
        alternative: AlternativeHypothesis.greater,
      );
      check(exactGreater.pValue).isCloseTo(1.0 / 6.0, 1e-12);

      final exactLess = kolmogorovSmirnovTwoSample(
        const [1.0, 2.0],
        const [3.0, 4.0],
        alternative: AlternativeHypothesis.less,
      );
      check(exactLess.statistic).equals(0.0);
      check(exactLess.pValue).equals(1.0);

      // Non-trivial intermediate 0 < D < 1 exact lattice DP across alternatives
      // plus trailing sample1 elements after sample2 ends.
      final midTwo = kolmogorovSmirnovTwoSample(
        const [1.0, 2.0, 5.0, 7.0],
        const [3.0, 4.0, 6.0, 8.0],
      );
      check(midTwo.statistic).isCloseTo(0.5, 1e-12);
      check(midTwo.pValue).isGreaterThan(0.1);
      check(midTwo.pValue).isLessThan(1.0);

      final midGreater = kolmogorovSmirnovTwoSample(
        const [1.0, 2.0, 5.0, 7.0],
        const [3.0, 4.0, 6.0, 8.0],
        alternative: AlternativeHypothesis.greater,
      );
      check(midGreater.statistic).isCloseTo(0.5, 1e-12);
      check(midGreater.pValue).isLessThan(midTwo.pValue);

      final midLess = kolmogorovSmirnovTwoSample(
        const [3.0, 4.0, 6.0, 9.0],
        const [1.0, 2.0, 5.0, 7.0],
        alternative: AlternativeHypothesis.less,
      );
      check(midLess.statistic).isCloseTo(0.5, 1e-12);
      check(midLess.pValue).isCloseTo(midGreater.pValue, 1e-12);
    });

    test('handles ties, NaN, empty samples, and invalid alpha', () {
      final tiedRes = kolmogorovSmirnovTwoSample(
        const [1.0, 2.0, 2.0, 3.0],
        const [2.0, 3.0, 4.0, 5.0],
        alternative: AlternativeHypothesis.less,
      );
      check(tiedRes.pValue).isGreaterThan(0.0);

      final nanRes = kolmogorovSmirnovTwoSample(
        const [1.0, 2.0],
        const [double.nan, 3.0],
      );
      check(nanRes.statistic.isNaN).isTrue;
      check(nanRes.pValue.isNaN).isTrue;

      check(() => kolmogorovSmirnovTwoSample(const <double>[], const [1.0]))
          .throws<ArgumentError>();
      check(() => kolmogorovSmirnovTwoSample(const [1.0], const <double>[]))
          .throws<ArgumentError>();
      check(
        () => kolmogorovSmirnovTwoSample(
          const [1.0, 2.0],
          const [3.0, 4.0],
          alpha: 1.0,
        ),
      ).throws<ArgumentError>();
    });
  });
}

final class _NanCdfDistribution extends ContinuousDistribution {
  const new();

  @override
  double get mean => double.nan;

  @override
  double get mode => double.nan;

  @override
  double get variance => double.nan;

  @override
  double get skewness => double.nan;

  @override
  double get excessKurtosis => double.nan;

  @override
  double probability(double x) => double.nan;

  @override
  double cumulativeProbability(double x) => double.nan;

  @override
  double inverseCumulativeProbability(num probability) => double.nan;

  @override
  double sample({math.Random? random}) => double.nan;
}
