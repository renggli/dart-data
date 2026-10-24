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
        check(identifySpecialRadical(const RealNumber(0.5))).isNull();
        check(identifySpecialRadical(RealNumber(math.sqrt(3)))).isNull();
      },
    );

    test(
      'recognizes alternative exact AST representations of special radicals',
      () {
        // FractionNumber representations of +/- 1/2
        check(isHalf(FractionNumber.half)).isTrue();
        check(isHalf(FractionNumber.negativeHalf)).isFalse();
        check(isHalf(const Variable('x'))).isFalse();

        check(isNegativeHalf(FractionNumber.negativeHalf)).isTrue();
        check(isNegativeHalf(FractionNumber.half)).isFalse();
        check(isNegativeHalf(const Variable('x'))).isFalse();

        // Real numbers must never be recognized as exact constants
        check(isHalf(const RealNumber(0.5))).isFalse();
        check(isHalf(const RealNumber(-0.5))).isFalse();
        check(isNegativeHalf(const RealNumber(-0.5))).isFalse();
        check(isNegativeHalf(const RealNumber(0.5))).isFalse();

        // Pow(1/2, 1/2) and 2^(-1/2) representations of sqrt(2)/2
        final powHalf = Pow(FractionNumber.half, FractionNumber.half);
        check(isSqrt2Over2(powHalf)).isTrue();
        check(
          isSqrt2Over2(
            Pow(
              IntegerNumber.two,
              const FractionNumber(Integer.negativeOne, Integer.two),
            ),
          ),
        ).isTrue();
        check(isSqrt2Over2(const RealNumber(math.sqrt1_2))).isFalse();
        check(isNegativeSqrt2Over2(const RealNumber(-math.sqrt1_2))).isFalse();

        // Direct Pow(3, 1/2) for isSqrt3
        final sqrt3Pow = Pow(IntegerNumber.of(3), FractionNumber.half);
        check(isSqrt(sqrt3Pow, 3)).isTrue();
        check(isSqrt(const Variable('x'), 3)).isFalse();
        check(isSqrt3(sqrt3Pow)).isTrue();
        check(isSqrt3(RealNumber(math.sqrt(3)))).isFalse();
        check(isNegativeSqrt3(RealNumber(-math.sqrt(3)))).isFalse();

        // 3^(-1/2) representation of sqrt(3)/3
        check(
          isSqrt3Over3(
            Pow(
              IntegerNumber.of(3),
              const FractionNumber(Integer.negativeOne, Integer.two),
            ),
          ),
        ).isTrue();
        check(isSqrt3Over3(const RealNumber(0.5773502691896257))).isFalse();
        check(isSqrt3Over2(const RealNumber(0.8660254037844386))).isFalse();

        // Non-real and free-variable expressions return false
        check(isSqrt3Over2(const Variable('x'))).isFalse();
        check(isSqrt3Over2(ComplexNumber.i)).isFalse();
        check(isSqrt3Over3(Ln(IntegerNumber.zero))).isFalse();
      },
    );
  });

  group('Exact trigonometric and inverse trigonometric evaluations', () {
    test('evaluates sin, cos, and tan at special multiples of pi', () {
      check(Expr.parse('sin(pi / 6)').simplify().toString()).equals('1/2');
      check(Expr.parse('sin(pi / 4)').simplify().toString())
          .equals('1/2 * sqrt(2)');
      check(Expr.parse('sin(pi / 3)').simplify().toString())
          .equals('1/2 * sqrt(3)');
      check(Expr.parse('sin(pi / 2)').simplify()).equals(IntegerNumber.one);
      check(Expr.parse('sin(3 * pi / 2)').simplify())
          .equals(IntegerNumber.negativeOne);
      check(Expr.parse('sin(pi)').simplify()).equals(IntegerNumber.zero);

      check(Expr.parse('cos(pi / 6)').simplify().toString())
          .equals('1/2 * sqrt(3)');
      check(Expr.parse('cos(pi / 4)').simplify().toString())
          .equals('1/2 * sqrt(2)');
      check(Expr.parse('cos(pi / 3)').simplify().toString()).equals('1/2');
      check(Expr.parse('cos(pi)').simplify()).equals(IntegerNumber.negativeOne);
      check(Expr.parse('cos(2 * pi)').simplify()).equals(IntegerNumber.one);
      check(Expr.parse('cos(pi / 2)').simplify()).equals(IntegerNumber.zero);

      check(Expr.parse('tan(pi / 6)').simplify().toString())
          .equals('1/3 * sqrt(3)');
      check(Expr.parse('tan(pi / 4)').simplify()).equals(IntegerNumber.one);
      check(Expr.parse('tan(pi / 3)').simplify().toString()).equals('sqrt(3)');
      check(Expr.parse('tan(3 * pi / 4)').simplify())
          .equals(IntegerNumber.negativeOne);
      check(Expr.parse('tan(pi / 2)').simplify()).equals(Constant.undefined);
    });

    test('evaluates Euler identity e^(i * k * pi)', () {
      check(Expr.parse('exp(i * pi)').simplify())
          .equals(IntegerNumber.negativeOne);
      check(Expr.parse('exp(2 * i * pi)').simplify()).equals(IntegerNumber.one);
      check(Expr.parse('exp(i * pi / 2)').simplify()).equals(ComplexNumber.i);
      check(Expr.parse('exp(-i * pi / 2)').simplify())
          .equals(ComplexNumber.negativeI);
      check(Expr.parse('exp(i * pi / 3)').simplify().toString())
          .equals('1/2 + 1/2 * i * sqrt(3)');
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

    test(
      'real numbers simplify down to numeric results without symbolic guessing',
      () {
        // Real numbers must evaluate to RealNumber numeric results, not exact pi multiples
        final asinHalf = Expr.parse('asin(0.5)').simplify();
        check(asinHalf).isA<RealNumber>();
        check((asinHalf as RealNumber).value).isCloseTo(math.asin(0.5), 1e-12);

        final acosHalf = Expr.parse('acos(0.5)').simplify();
        check(acosHalf).isA<RealNumber>();
        check((acosHalf as RealNumber).value).isCloseTo(math.acos(0.5), 1e-12);

        final atanOne = Expr.parse('atan(1.0)').simplify();
        check(atanOne).isA<RealNumber>();
        check((atanOne as RealNumber).value).isCloseTo(math.atan(1.0), 1e-12);

        final sinHalf = Expr.parse('sin(0.5)').simplify();
        check(sinHalf).isA<RealNumber>();
        check((sinHalf as RealNumber).value).isCloseTo(math.sin(0.5), 1e-12);

        final cosHalf = Expr.parse('cos(0.5)').simplify();
        check(cosHalf).isA<RealNumber>();
        check((cosHalf as RealNumber).value).isCloseTo(math.cos(0.5), 1e-12);

        final tanHalf = Expr.parse('tan(0.5)').simplify();
        check(tanHalf).isA<RealNumber>();
        check((tanHalf as RealNumber).value).isCloseTo(math.tan(0.5), 1e-12);

        final expOne = Expr.parse('exp(1.0)').simplify();
        check(expOne).isA<RealNumber>();
        check((expOne as RealNumber).value).isCloseTo(math.e, 1e-12);

        final lnTwo = Expr.parse('ln(2.0)').simplify();
        check(lnTwo).isA<RealNumber>();
        check((lnTwo as RealNumber).value).isCloseTo(math.log(2.0), 1e-12);

        // Real zero preserves floating domain
        final sinZero = Sin(const RealNumber(0.0)).simplify();
        check(sinZero).equals(const RealNumber(0.0));

        final cosZero = Cos(const RealNumber(0.0)).simplify();
        check(cosZero).equals(const RealNumber(1.0));
      },
    );
  });
}
