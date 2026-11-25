import 'package:checks/checks.dart';
import 'package:data/stats.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('mannWhitneyUTest exact and asymptotic paths', () {
    test('computes exact permutation p-values for small untied samples', () {
      const x = [1.0, 2.0, 3.0, 4.0, 5.0];
      const y = [6.0, 7.0, 8.0, 9.0, 10.0];

      // C(10, 5) = 252 => exact U = 0 has P(twoSided) = 2/252, P(less) = 1/252, P(greater) = 1.0.
      final twoSided = mannWhitneyUTest(x, y);
      check(twoSided.statistic).equals(0.0);
      check(twoSided.pValue).isCloseTo(2.0 / 252.0, 1e-12);
      check(twoSided.isSignificant).isTrue;

      final less = mannWhitneyUTest(
        x,
        y,
        alternative: AlternativeHypothesis.less,
      );
      check(less.pValue).isCloseTo(1.0 / 252.0, 1e-12);

      final greater = mannWhitneyUTest(
        x,
        y,
        alternative: AlternativeHypothesis.greater,
      );
      check(greater.pValue).equals(1.0);
    });

    test(
      'supports normal approximation with tie and continuity corrections',
      () {
        const x = [1.0, 2.0, 2.0, 3.0];
        const y = [1.0, 2.0, 3.0, 4.0];

        final res = mannWhitneyUTest(x, y);
        check(res.statistic).isCloseTo(6.0, 1e-10);
        check(res.pValue).isCloseTo(0.6531730510476854, 1e-6);

        final resNoCc = mannWhitneyUTest(x, y, continuityCorrection: false);
        check(resNoCc.pValue).isCloseTo(0.5490764027123644, 1e-6);

        final resLess = mannWhitneyUTest(
          x,
          y,
          alternative: AlternativeHypothesis.less,
        );
        check(resLess.pValue).isCloseTo(0.326586525, 1e-6);

        final resGreater = mannWhitneyUTest(
          x,
          y,
          alternative: AlternativeHypothesis.greater,
        );
        check(resGreater.pValue).isCloseTo(0.7730505610647775, 1e-6);

        // Explicit exact: false forces normal approximation on untied data.
        final forcedAsymp = mannWhitneyUTest(
          const [1.0, 2.0, 3.0, 4.0],
          const [5.0, 6.0, 7.0, 8.0],
          exact: false,
        );
        check(forcedAsymp.pValue).isCloseTo(0.030382821976577483, 1e-9);
      },
    );

    test('handles identical values, NaN, and invalid arguments', () {
      final equal = mannWhitneyUTest(
        const [4.0, 4.0, 4.0],
        const [4.0, 4.0, 4.0],
      );
      check(equal.statistic).isCloseTo(4.5, 1e-10);
      check(equal.pValue).equals(1.0);

      final nanRes = mannWhitneyUTest(
        const [1.0, double.nan],
        const [4.0, 5.0],
        alternative: AlternativeHypothesis.less,
      );
      check(nanRes.statistic.isNaN).isTrue;
      check(nanRes.pValue.isNaN).isTrue;
      check(nanRes.alternative).equals(AlternativeHypothesis.less);

      check(() => mannWhitneyUTest(const <double>[], const [1.0]))
          .throws<ArgumentError>();
      check(() => mannWhitneyUTest(const [1.0], const <double>[]))
          .throws<ArgumentError>();
      check(
        () => mannWhitneyUTest(const [1.0, 2.0], const [2.0, 3.0], exact: true),
      ).throws<ArgumentError>();
      check(
        () => mannWhitneyUTest(
          [for (var i = 0; i < 30; i++) i.toDouble()],
          [for (var i = 30; i < 60; i++) i.toDouble()],
          exact: true,
        ),
      ).throws<ArgumentError>();
      check(() => mannWhitneyUTest(const [1.0], const [2.0], alpha: 0.0))
          .throws<ArgumentError>();
    });
  });
}
