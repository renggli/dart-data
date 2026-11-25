import 'package:checks/checks.dart';
import 'package:data/stats.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('tTestOneSample', () {
    test(
      'evaluates two-sided and one-sided hypotheses with confidence intervals',
      () {
        const sample = [10.2, 9.8, 10.1, 10.5, 9.9, 10.0, 10.3, 9.7];
        final resNullTrue = tTestOneSample(sample, mu0: 10.0);
        check(resNullTrue.isSignificant).isFalse;
        check(resNullTrue.pValue).isGreaterThan(0.5);
        final (:lower, :upper) = resNullTrue.confidenceInterval!;
        check(lower).isLessThan(10.0);
        check(upper).isGreaterThan(10.0);

        final resLess = tTestOneSample(
          sample,
          mu0: 15.0,
          alternative: AlternativeHypothesis.less,
        );
        check(resLess.isSignificant).isTrue;
        check(resLess.pValue).isLessThan(1e-5);
        check(resLess.confidenceInterval!.lower)
            .equals(double.negativeInfinity);
        check(resLess.confidenceInterval!.upper.isFinite).isTrue;

        final resGreater = tTestOneSample(
          sample,
          mu0: 5.0,
          alternative: AlternativeHypothesis.greater,
        );
        check(resGreater.isSignificant).isTrue;
        check(resGreater.pValue).isLessThan(1e-5);
        check(resGreater.confidenceInterval!.lower.isFinite).isTrue;
        check(resGreater.confidenceInterval!.upper).equals(double.infinity);

        // Tiny alpha confidence interval uses survival quantile without inf overflow.
        final tinyAlpha = tTestOneSample(sample, mu0: 10.0, alpha: 1e-17);
        check(tinyAlpha.confidenceInterval!.lower.isFinite).isTrue;
        check(tinyAlpha.confidenceInterval!.upper.isFinite).isTrue;
      },
    );

    test('handles zero variance, NaN, and parameter validation', () {
      const constSample = [5.0, 5.0, 5.0];
      check(tTestOneSample(constSample, mu0: 5.0).pValue).equals(1.0);
      check(tTestOneSample(constSample, mu0: 4.0).statistic)
          .equals(double.infinity);
      check(
        tTestOneSample(
          constSample,
          mu0: 6.0,
          alternative: AlternativeHypothesis.less,
        ).pValue,
      ).equals(0.0);
      check(
        tTestOneSample(
          constSample,
          mu0: 4.0,
          alternative: AlternativeHypothesis.greater,
        ).pValue,
      ).equals(0.0);

      final nanRes = tTestOneSample(const [1.0, double.nan, 3.0]);
      check(nanRes.statistic.isNaN).isTrue;
      check(nanRes.pValue.isNaN).isTrue;

      check(() => tTestOneSample(const [1.0])).throws<ArgumentError>();
      check(() => tTestOneSample(const [1.0, 2.0], mu0: double.infinity))
          .throws<ArgumentError>();
      check(() => tTestOneSample(const [1.0, 2.0], alpha: 0.0))
          .throws<ArgumentError>();
    });
  });

  group('tTestTwoSample', () {
    test(
      'evaluates Student and Welch two-sample tests including non-zero mu0',
      () {
        const groupA = [12.0, 14.0, 13.0, 15.0, 14.0];
        const groupB = [18.0, 19.0, 17.0, 20.0, 18.5];

        final student = tTestTwoSample(groupA, groupB, equalVariance: true);
        check(student.isSignificant).isTrue;
        check(student.pValue).isLessThan(0.001);

        final welch = tTestTwoSample(groupA, groupB);
        check(welch.isSignificant).isTrue;
        check(welch.pValue).isLessThan(0.001);

        // Difference is -4.9; testing H0: mu1 - mu2 = -4.9 yields t ~ 0, p ~ 1.
        final shiftedMu = tTestTwoSample(groupA, groupB, mu0: -4.9);
        check(shiftedMu.statistic).isCloseTo(0.0, 1e-12);
        check(shiftedMu.pValue).isGreaterThan(0.9);

        check(
          tTestTwoSample(
            groupA,
            groupB,
            alternative: AlternativeHypothesis.less,
          ).pValue,
        ).isLessThan(0.001);
        check(
          tTestTwoSample(
            groupA,
            groupB,
            alternative: AlternativeHypothesis.greater,
          ).pValue,
        ).isGreaterThan(0.9);
      },
    );

    test('handles huge variances without Welch-Satterthwaite overflow, zero variance, and NaN', () {
      // Variances near 1e200 must produce finite Welch degrees of freedom.
      final hugeWelch = tTestTwoSample(
        const [1e160, 2e160, 3e160],
        const [1e160, 3e160, 5e160],
      );
      check(hugeWelch.degreesOfFreedom!.isFinite).isTrue;
      check(hugeWelch.pValue.isFinite).isTrue;

      final constSame = tTestTwoSample(const [3.0, 3.0], const [3.0, 3.0]);
      check(constSame.statistic).equals(0.0);
      check(constSame.pValue).equals(1.0);
      check(constSame.degreesOfFreedom).equals(2.0);

      final constDiff = tTestTwoSample(const [3.0, 3.0], const [5.0, 5.0]);
      check(constDiff.statistic).equals(double.negativeInfinity);
      check(constDiff.pValue).equals(0.0);

      final nanRes = tTestTwoSample(const [1.0, double.nan], const [2.0, 3.0]);
      check(nanRes.statistic.isNaN).isTrue;

      check(() => tTestTwoSample(const [1.0], const [2.0, 3.0]))
          .throws<ArgumentError>();
      check(() => tTestTwoSample(const [1.0, 2.0], const [3.0]))
          .throws<ArgumentError>();
      check(
        () =>
            tTestTwoSample(const [1.0, 2.0], const [3.0, 4.0], mu0: double.nan),
      ).throws<ArgumentError>();
    });
  });

  group('tTestPaired', () {
    test('evaluates paired differences against default and custom mu0', () {
      const before = [120.0, 125.0, 130.0, 128.0, 122.0];
      const after = [115.0, 118.0, 121.0, 120.0, 116.0];

      final res = tTestPaired(before, after);
      check(res.isSignificant).isTrue;
      check(res.pValue).isLessThan(0.01);
      check(res.statistic).isGreaterThan(0.0);

      final shifted = tTestPaired(before, after, mu0: 7.0);
      check(shifted.statistic).isCloseTo(0.0, 1e-12);
      check(shifted.pValue).equals(1.0);

      check(
        tTestPaired(
          before,
          after,
          alternative: AlternativeHypothesis.greater,
        ).pValue,
      ).isLessThan(0.01);
      check(
        tTestPaired(
          before,
          after,
          alternative: AlternativeHypothesis.less,
        ).pValue,
      ).isGreaterThan(0.99);

      final nanRes = tTestPaired(const [1.0, double.nan], const [3.0, 4.0]);
      check(nanRes.statistic.isNaN).isTrue;

      check(() => tTestPaired(const [1.0], after)).throws<ArgumentError>();
      check(() => tTestPaired(const [1.0, 2.0, 3.0], const [1.0, 2.0]))
          .throws<ArgumentError>();
      check(() => tTestPaired(const [1.0, 2.0], const [1.0, 2.0, 3.0]))
          .throws<ArgumentError>();
      check(() => tTestPaired(before, after, mu0: double.nan))
          .throws<ArgumentError>();
      check(() => tTestPaired(before, after, alpha: 1.0))
          .throws<ArgumentError>();
    });
  });
}
