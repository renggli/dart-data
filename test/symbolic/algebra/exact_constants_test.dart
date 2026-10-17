import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/src/symbolic/algebra/exact_constants.dart';
import 'package:data/symbolic.dart';
import 'package:test/test.dart';

void main() {
  group('SpecialRadical construction and recognition', () {
    test(
      'constructs and recognizes all positive and negative special radicals',
      () {
        for (final radical in SpecialRadical.values) {
          check(radical.numericValue).isGreaterThan(0.0);
          final pos = specialRadicalExpr(radical);
          final neg = specialRadicalExpr(radical, negative: true);

          check(isSpecialAngleConstant(pos, radical)).isTrue();
          check(isSpecialAngleConstant(pos, radical, negative: true)).isFalse();
          check(isSpecialAngleConstant(neg, radical, negative: true)).isTrue();
          check(isSpecialAngleConstant(neg, radical)).isFalse();

          final idPos = identifySpecialRadical(pos);
          check(idPos).equals((radical: radical, isNegative: false));

          final idNeg = identifySpecialRadical(neg);
          check(idNeg).equals((radical: radical, isNegative: true));
        }

        check(identifySpecialRadical(IntegerNumber.two)).isNull();
        check(identifySpecialRadical(const Variable('x'))).isNull();
      },
    );

    test('recognizes alternative AST representations of special radicals', () {
      // RealNumber representations of +/- 1/2
      check(isHalf(const RealNumber(0.5))).isTrue();
      check(isHalf(const RealNumber(-0.5))).isFalse();
      check(isHalf(const Variable('x'))).isFalse();

      check(isNegativeHalf(const RealNumber(-0.5))).isTrue();
      check(isNegativeHalf(const RealNumber(0.5))).isFalse();
      check(isNegativeHalf(const Variable('x'))).isFalse();

      // Pow(1/2, 1/2) representation of sqrt(2)/2
      final powHalf = Pow(FractionNumber.half, FractionNumber.half);
      check(isSqrt2Over2(powHalf)).isTrue();

      // Direct Pow(3, 1/2) vs RealNumber(sqrt(3)) for isSqrt3
      final sqrt3Pow = Pow(IntegerNumber.of(3), FractionNumber.half);
      check(isSqrt(sqrt3Pow, 3)).isTrue();
      check(isSqrt(const Variable('x'), 3)).isFalse();
      check(isSqrt3(sqrt3Pow)).isTrue();
      check(isSqrt3(RealNumber(math.sqrt(3)))).isTrue();
      check(isNegativeSqrt3(RealNumber(-math.sqrt(3)))).isTrue();

      // Non-real and free-variable expressions return false in _evalClose
      check(isSqrt3Over2(const Variable('x'))).isFalse();
      check(isSqrt3Over2(ComplexNumber.i)).isFalse();
      check(isSqrt3Over3(Ln(IntegerNumber.zero))).isFalse();
    });
  });

  group('Exact trigonometric and inverse trigonometric evaluations', () {
    test('evaluates sin, cos, and tan at special multiples of pi', () {
      check(Expr.parse('sin(pi / 2)').simplify()).equals(IntegerNumber.one);
      check(Expr.parse('sin(3 * pi / 2)').simplify())
          .equals(IntegerNumber.negativeOne);
      check(Expr.parse('sin(pi)').simplify()).equals(IntegerNumber.zero);
      check(Expr.parse('cos(pi)').simplify()).equals(IntegerNumber.negativeOne);
      check(Expr.parse('cos(2 * pi)').simplify()).equals(IntegerNumber.one);
      check(Expr.parse('cos(pi / 2)').simplify()).equals(IntegerNumber.zero);
      check(Expr.parse('tan(pi / 4)').simplify()).equals(IntegerNumber.one);
      check(Expr.parse('tan(3 * pi / 4)').simplify())
          .equals(IntegerNumber.negativeOne);
    });

    test('evaluates asin, acos, and atan at all exact special radicals', () {
      check(Expr.parse('asin(1 / 2)').simplify().toString()).equals('1/6 * pi');
      check(Expr.parse('asin(sqrt(2) / 2)').simplify().toString())
          .equals('1/4 * pi');
      check(Expr.parse('asin(sqrt(3) / 2)').simplify().toString())
          .equals('1/3 * pi');

      check(Expr.parse('acos(1 / 2)').simplify().toString()).equals('1/3 * pi');
      check(Expr.parse('acos(sqrt(2) / 2)').simplify().toString())
          .equals('1/4 * pi');
      check(Expr.parse('acos(sqrt(3) / 2)').simplify().toString())
          .equals('1/6 * pi');
      check(Expr.parse('acos(-1 / 2)').simplify().toString())
          .equals('2/3 * pi');
      check(Expr.parse('acos(-sqrt(2) / 2)').simplify().toString())
          .equals('3/4 * pi');
      check(Expr.parse('acos(-sqrt(3) / 2)').simplify().toString())
          .equals('5/6 * pi');

      check(Expr.parse('atan(sqrt(3) / 3)').simplify().toString())
          .equals('1/6 * pi');
      check(Expr.parse('atan(sqrt(3))').simplify().toString())
          .equals('1/3 * pi');
      check(Expr.parse('atan(-sqrt(3) / 3)').simplify().toString())
          .equals('-1/6 * pi');
      check(Expr.parse('atan(-sqrt(3))').simplify().toString())
          .equals('-1/3 * pi');
    });
  });
}
