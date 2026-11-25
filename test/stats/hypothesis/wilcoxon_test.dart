import 'package:checks/checks.dart';
import 'package:data/stats.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('wilcoxonSignedRankTest exact and asymptotic paths', () {
    test('evaluates exact signed-rank permutation p-values for small untied samples', () {
      // n = 10 all positive differences: W+ = 55, W- = 0 => exact P(twoSided) = 2 / 2^10 = 1/512.
      const x = [3.0, 4.0, 2.5, 5.0, 6.2, 4.1, 5.5, 3.8, 4.9, 6.0];
      final res = wilcoxonSignedRankTest(x);
      check(res.statistic).equals(0.0);
      check(res.pValue).isCloseTo(1.0 / 512.0, 1e-12);
      check(res.isSignificant).isTrue;

      const before = [120.0, 125.0, 130.0, 118.0, 140.0, 135.0, 122.0, 128.0];
      const after = [110.0, 115.0, 122.0, 112.0, 128.0, 125.0, 118.0, 120.0];
      final pairedAsymp = wilcoxonSignedRankTest(
        before,
        y: after,
        exact: false,
      );
      final pairedNoCc = wilcoxonSignedRankTest(
        before,
        y: after,
        continuityCorrection: false,
        exact: false,
      );
      check(pairedNoCc.pValue).isLessThan(pairedAsymp.pValue);

      final greater = wilcoxonSignedRankTest(
        before,
        y: after,
        alternative: AlternativeHypothesis.greater,
        exact: false,
      );
      final greaterNoCc = wilcoxonSignedRankTest(
        before,
        y: after,
        alternative: AlternativeHypothesis.greater,
        continuityCorrection: false,
        exact: false,
      );
      check(greaterNoCc.pValue).isLessThan(greater.pValue);

      final less = wilcoxonSignedRankTest(
        before,
        y: after,
        alternative: AlternativeHypothesis.less,
        exact: false,
      );
      final lessNoCc = wilcoxonSignedRankTest(
        before,
        y: after,
        alternative: AlternativeHypothesis.less,
        continuityCorrection: false,
        exact: false,
      );
      check(less.pValue).isGreaterThan(0.95);
      check(lessNoCc.pValue).isLessThan(less.pValue);

      // Mixed positive/negative exact untied permutation checks across alternatives:
      // |diffs| = [1.5(-), 2.1(-), 3.0(+), 4.2(+), 5.8(+), 6.0(+)] => W+ = 18, W- = 3.
      const mixed = [3.0, -1.5, 4.2, -2.1, 5.8, 6.0];
      final mixedTwo = wilcoxonSignedRankTest(mixed, exact: true);
      final mixedGreater = wilcoxonSignedRankTest(
        mixed,
        alternative: AlternativeHypothesis.greater,
        exact: true,
      );
      final mixedLess = wilcoxonSignedRankTest(
        mixed,
        alternative: AlternativeHypothesis.less,
        exact: true,
      );
      check(mixedTwo.statistic).equals(3.0);
      check(mixedGreater.statistic).equals(18.0);
      check(mixedLess.statistic).equals(18.0);
      check(mixedTwo.pValue).isCloseTo(10.0 / 64.0, 1e-12);
      check(mixedGreater.pValue).isCloseTo(5.0 / 64.0, 1e-12);
      check(mixedLess.pValue).isCloseTo(61.0 / 64.0, 1e-12);
    });

    test('handles ties, all-zero differences, NaN, and validation', () {
      final resTied = wilcoxonSignedRankTest(
        const [1.0, 2.0, 3.0, 4.0, 5.0, 6.0],
        y: const [1.0, 2.0, 3.0, 3.5, 4.5, 5.5],
      );
      check(resTied.statistic).equals(0.0);
      check(resTied.pValue).isLessThan(0.2);

      final resZero = wilcoxonSignedRankTest(
        const [1.0, 2.0],
        y: const [1.0, 2.0],
        alternative: AlternativeHypothesis.greater,
      );
      check(resZero.statistic).equals(0.0);
      check(resZero.pValue).equals(1.0);
      check(resZero.alternative).equals(AlternativeHypothesis.greater);

      final nanOne = wilcoxonSignedRankTest(const [1.0, double.nan, 3.0]);
      check(nanOne.statistic.isNaN).isTrue;
      check(nanOne.pValue.isNaN).isTrue;

      final nanPaired = wilcoxonSignedRankTest(
        const [1.0, 2.0],
        y: const [double.nan, 5.0],
      );
      check(nanPaired.statistic.isNaN).isTrue;

      check(() => wilcoxonSignedRankTest(const <double>[]))
          .throws<ArgumentError>();
      check(() => wilcoxonSignedRankTest(const [1.0], y: const [1.0, 2.0]))
          .throws<ArgumentError>();
      check(() => wilcoxonSignedRankTest(const [1.0, 2.0], y: const [1.0]))
          .throws<ArgumentError>();
      check(() => wilcoxonSignedRankTest(const [1.0, -1.0], exact: true))
          .throws<ArgumentError>();
      check(
        () => wilcoxonSignedRankTest([
          for (var i = 1; i <= 51; i++) i.toDouble(),
        ], exact: true),
      ).throws<ArgumentError>();
      check(() => wilcoxonSignedRankTest(const [1.0, 2.0], alpha: 0.0))
          .throws<ArgumentError>();
    });
  });
}
