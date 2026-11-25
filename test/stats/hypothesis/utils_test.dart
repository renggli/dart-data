import 'package:checks/checks.dart';
import 'package:data/src/stats/hypothesis/utils.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('validateAlpha', () {
    test('accepts strictly interior alpha values', () {
      validateAlpha(0.01);
      validateAlpha(0.05);
      validateAlpha(0.5);
      validateAlpha(0.99);
    });

    test('rejects boundary, out-of-range, and non-finite alpha', () {
      check(() => validateAlpha(0.0)).throws<ArgumentError>();
      check(() => validateAlpha(1.0)).throws<ArgumentError>();
      check(() => validateAlpha(-0.05)).throws<ArgumentError>();
      check(() => validateAlpha(1.05)).throws<ArgumentError>();
      check(() => validateAlpha(double.nan)).throws<ArgumentError>();
      check(() => validateAlpha(double.infinity)).throws<ArgumentError>();
    });
  });

  group('rankDataWithTies', () {
    test('ranks untied data without flagging ties', () {
      final res = rankDataWithTies([30.0, 10.0, 20.0]);
      check(res.ranks).deepEquals([3.0, 1.0, 2.0]);
      check(res.hasTies).isFalse;
      check(res.tieCorrectionSum).equals(0.0);
    });

    test('computes fractional ranks and tie correction sum for tied data', () {
      final res = rankDataWithTies([10.0, 20.0, 20.0, 30.0, 30.0, 30.0]);
      check(res.ranks).deepEquals([1.0, 2.5, 2.5, 5.0, 5.0, 5.0]);
      check(res.hasTies).isTrue;
      // Tie sums: (2^3 - 2) + (3^3 - 3) = 6 + 24 = 30
      check(res.tieCorrectionSum).equals(30.0);
    });
  });
}
