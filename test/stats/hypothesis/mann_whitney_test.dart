import 'package:checks/checks.dart';
import 'package:data/stats.dart';
import 'package:test/test.dart';

void main() {
  group('mann-whitney', () {
    test('Mann-Whitney U test', () {
      final x = [1.0, 2.0, 3.0, 4.0, 5.0];
      final y = [6.0, 7.0, 8.0, 9.0, 10.0];

      final res = mannWhitneyUTest(x, y);
      check(res.statistic).isCloseTo(0.0, 1e-10);
      check(res.isSignificant).isTrue();
      check(res.pValue).isLessThan(0.05);

      final resLess = mannWhitneyUTest(
        x,
        y,
        alternative: AlternativeHypothesis.less,
      );
      check(resLess.pValue).isLessThan(0.05);

      final resGreater = mannWhitneyUTest(
        x,
        y,
        alternative: AlternativeHypothesis.greater,
      );
      check(resGreater.pValue).isGreaterThan(0.9);

      // Errors
      check(() => mannWhitneyUTest(<double>[], y)).throws<ArgumentError>();
      check(() => mannWhitneyUTest(x, <double>[])).throws<ArgumentError>();
    });

    test('Mann-Whitney U test with ties and continuity correction', () {
      final x = [1.0, 2.0, 2.0, 3.0];
      final y = [1.0, 2.0, 3.0, 4.0];

      // With continuity correction and tie correction
      final res = mannWhitneyUTest(x, y);
      check(res.statistic).isCloseTo(6.0, 1e-10);
      check(res.pValue).isCloseTo(0.6531730510476854, 1e-6);

      // Without continuity correction (still with tie correction)
      final resNoCc = mannWhitneyUTest(x, y, continuityCorrection: false);
      check(resNoCc.statistic).isCloseTo(6.0, 1e-10);
      // z = 2.0 / sqrt(78/7) = 0.5991446... -> p = 2 * (1 - Phi(z)) = 0.5490764...
      check(resNoCc.pValue).isCloseTo(0.5490764027123644, 1e-6);

      // Less and greater alternatives with ties and continuity
      final resLess = mannWhitneyUTest(
        x,
        y,
        alternative: AlternativeHypothesis.less,
      );
      // z = (6 - 8 + 0.5) / sigma = -1.5 / sigma -> Phi(-z) = 0.3265865...
      check(resLess.pValue).isCloseTo(0.326586525, 1e-6);

      final resGreater = mannWhitneyUTest(
        x,
        y,
        alternative: AlternativeHypothesis.greater,
      );
      // z = (6 - 8 - 0.5) / sigma = -2.5 / sigma -> 1 - Phi(z) = 0.77305056...
      check(resGreater.pValue).isCloseTo(0.7730505610647775, 1e-6);
    });

    test('all identical values with zero variance', () {
      final x = [4.0, 4.0, 4.0];
      final y = [4.0, 4.0, 4.0];

      final res = mannWhitneyUTest(x, y);
      check(res.statistic).isCloseTo(4.5, 1e-10);
      check(res.pValue).equals(1.0);
    });
  });
}
