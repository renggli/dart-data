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
  });
}
