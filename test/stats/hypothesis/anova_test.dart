import 'package:checks/checks.dart';
import 'package:data/stats.dart';
import 'package:test/test.dart';

void main() {
  group('ANOVA', () {
    test('one-way ANOVA', () {
      // 3 groups with clearly separated means
      final g1 = [1.0, 2.0, 3.0, 2.5, 1.5];
      final g2 = [10.0, 11.0, 9.5, 10.5, 11.2];
      final g3 = [20.0, 19.5, 21.0, 20.5, 19.8];

      final res = oneWayAnova([g1, g2, g3]);
      check(res.isSignificant).isTrue();
      check(res.pValue).isLessThan(1e-6);
      check(res.statistic).isGreaterThan(100.0);

      // Errors
      check(() => oneWayAnova([g1])).throws<ArgumentError>();
      check(() => oneWayAnova([g1, <double>[]])).throws<ArgumentError>();
      check(
        () => oneWayAnova([
          [1.0],
          [2.0],
        ]),
      ).throws<ArgumentError>();
    });
  });
}
