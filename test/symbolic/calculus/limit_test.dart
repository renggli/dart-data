import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/test.dart';

void main() {
  group('Symbolic limits', () {
    test('evaluates classic indeterminate limits at finite points', () {
      check(Expr.parse('sin(x) / x').limit('x', IntegerNumber.zero))
          .equals(IntegerNumber.one);
      check(Expr.parse('(1 - cos(x)) / x^2').limit('x', IntegerNumber.zero))
          .equals(FractionNumber.half);
      check(Expr.parse('(exp(x) - 1 - x) / x^2').limit('x', IntegerNumber.zero))
          .equals(FractionNumber.half);
      check(Expr.parse('(x^2 - 4) / (x - 2)').limit('x', IntegerNumber.two))
          .equals(IntegerNumber.of(4));
    });

    test('evaluates limits at infinity and one-sided limits', () {
      check(Expr.parse('(1 + 1 / x)^x').limit('x', Constant.infinity))
          .equals(Constant.e);
      check(Expr.parse('(3*x^2 + 1) / (x^2 - 5)').limit('x', Constant.infinity))
          .equals(IntegerNumber.of(3));
      check(
        Expr.parse(
          '1 / x',
        ).limit('x', IntegerNumber.zero, direction: LimitDirection.fromAbove),
      ).equals(Constant.infinity);
      check(
        Expr.parse(
          '1 / x',
        ).limit('x', IntegerNumber.zero, direction: LimitDirection.fromBelow),
      ).equals(-Constant.infinity);
    });
  });
}
