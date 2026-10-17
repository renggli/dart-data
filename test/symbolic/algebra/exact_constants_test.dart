import 'package:checks/checks.dart';
import 'package:data/src/symbolic/algebra/exact_constants.dart';
import 'package:data/symbolic.dart';
import 'package:test/test.dart';

void main() {
  group('Exact special angle trigonometric evaluation', () {
    test('SpecialRadical canonical construction and recognition', () {
      for (final radical in SpecialRadical.values) {
        final pos = specialRadicalExpr(radical);
        final neg = specialRadicalExpr(radical, negative: true);
        check(isSpecialAngleConstant(pos, radical)).isTrue();
        check(isSpecialAngleConstant(neg, radical, negative: true)).isTrue();
      }
      check(Expr.parse('sin(pi / 2)').simplify()).equals(IntegerNumber.one);
      check(Expr.parse('sin(pi)').simplify()).equals(IntegerNumber.zero);
      check(Expr.parse('cos(pi)').simplify()).equals(IntegerNumber.negativeOne);
      check(Expr.parse('tan(pi / 4)').simplify()).equals(IntegerNumber.one);
    });

    test(
      'evaluates inverse trigonometric functions at exact algebraic values',
      () {
        check(Expr.parse('asin(1 / 2)').simplify().toString())
            .equals('1/6 * pi');
        check(Expr.parse('acos(1 / 2)').simplify().toString())
            .equals('1/3 * pi');
        check(Expr.parse('atan(1)').simplify().toString()).equals('1/4 * pi');
        check(Expr.parse('asin(sqrt(2) / 2)').simplify().toString())
            .equals('1/4 * pi');
        check(Expr.parse('acos(0)').simplify().toString()).equals('1/2 * pi');
      },
    );
  });
}
