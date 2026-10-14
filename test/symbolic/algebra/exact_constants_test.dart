import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/src/symbolic/algebra/exact_constants.dart';
import 'package:data/symbolic.dart';
import 'package:test/test.dart';

void main() {
  group('SpecialRadical', () {
    test('enum values and numeric values', () {
      check(SpecialRadical.half.numericValue).equals(0.5);
      check((SpecialRadical.sqrt2Over2.numericValue - math.sqrt(2) / 2).abs())
          .isLessThan(1e-12);
      check((SpecialRadical.sqrt3Over2.numericValue - math.sqrt(3) / 2).abs())
          .isLessThan(1e-12);
      check((SpecialRadical.sqrt3Over3.numericValue - math.sqrt(3) / 3).abs())
          .isLessThan(1e-12);
      check((SpecialRadical.sqrt3.numericValue - math.sqrt(3)).abs())
          .isLessThan(1e-12);
    });

    test('isHalf and isNegativeHalf', () {
      check(isHalf(const RationalNumber(1, 2))).isTrue();
      check(isHalf(const RealNumber(0.5))).isTrue();
      check(isHalf(const RationalNumber(1, 3))).isFalse();
      check(isNegativeHalf(const RationalNumber(-1, 2))).isTrue();
      check(isNegativeHalf(const RealNumber(-0.5))).isTrue();
      check(isNegativeHalf(const RationalNumber(1, 2))).isFalse();
    });

    test('isSqrt and isSqrt2Over2', () {
      check(isSqrt(const Pow(RationalNumber(2), RationalNumber(1, 2)), 2))
          .isTrue();
      check(isSqrt(const Pow(RationalNumber(3), RationalNumber(1, 2)), 2))
          .isFalse();

      const sqrt2Over2Mul = Mul(
        RationalNumber(1, 2),
        Pow(RationalNumber(2), RationalNumber(1, 2)),
      );
      check(isSqrt2Over2(sqrt2Over2Mul)).isTrue();

      const sqrt2Over2Div = Div(
        Pow(RationalNumber(2), RationalNumber(1, 2)),
        RationalNumber(2),
      );
      check(isSqrt2Over2(sqrt2Over2Div)).isTrue();
      check(isSqrt2Over2(RealNumber(math.sqrt(2) / 2))).isTrue();

      check(isNegativeSqrt2Over2(const Neg(sqrt2Over2Div))).isTrue();
      check(isNegativeSqrt2Over2(RealNumber(-math.sqrt(2) / 2))).isTrue();
    });

    test('isSqrt3Over2 and isSqrt3Over3 and isSqrt3', () {
      const sqrt3Over2Div = Div(
        Pow(RationalNumber(3), RationalNumber(1, 2)),
        RationalNumber(2),
      );
      check(isSqrt3Over2(sqrt3Over2Div)).isTrue();
      check(isNegativeSqrt3Over2(const Neg(sqrt3Over2Div))).isTrue();

      const sqrt3Over3Div = Div(
        Pow(RationalNumber(3), RationalNumber(1, 2)),
        RationalNumber(3),
      );
      check(isSqrt3Over3(sqrt3Over3Div)).isTrue();
      check(isNegativeSqrt3Over3(const Neg(sqrt3Over3Div))).isTrue();

      const sqrt3Node = Pow(RationalNumber(3), RationalNumber(1, 2));
      check(isSqrt3(sqrt3Node)).isTrue();
      check(isNegativeSqrt3(const Neg(sqrt3Node))).isTrue();
    });
  });

  group('Radical identification', () {
    test('isSpecialAngleConstant matches accurately', () {
      for (final rad in SpecialRadical.values) {
        final posExpr = specialRadicalExpr(rad, negative: false);
        check(isSpecialAngleConstant(posExpr, rad, negative: false)).isTrue();
        check(isSpecialAngleConstant(posExpr, rad, negative: true)).isFalse();

        final negExpr = specialRadicalExpr(rad, negative: true);
        check(isSpecialAngleConstant(negExpr, rad, negative: true)).isTrue();
        check(isSpecialAngleConstant(negExpr, rad, negative: false)).isFalse();
      }
    });

    test(
      'identifySpecialRadical identifies positive and negative radicals',
      () {
        for (final rad in SpecialRadical.values) {
          final posExpr = specialRadicalExpr(rad, negative: false);
          final identifiedPos = identifySpecialRadical(posExpr);
          check(identifiedPos).isNotNull();
          check(identifiedPos!.radical).equals(rad);
          check(identifiedPos.isNegative).isFalse();

          final negExpr = specialRadicalExpr(rad, negative: true);
          final identifiedNeg = identifySpecialRadical(negExpr);
          check(identifiedNeg).isNotNull();
          check(identifiedNeg!.radical).equals(rad);
          check(identifiedNeg.isNegative).isTrue();
        }

        check(identifySpecialRadical(const RationalNumber(42))).isNull();
      },
    );

    test('alternative AST representations and fallback evaluation', () {
      // 1 / sqrt(2) == sqrt(2) / 2
      const invSqrt2 = Div(
        RationalNumber.one,
        Pow(RationalNumber(2), RationalNumber(1, 2)),
      );
      check(isSqrt2Over2(invSqrt2)).isTrue();
      check(isNegativeSqrt2Over2(const Neg(invSqrt2))).isTrue();
      check(identifySpecialRadical(invSqrt2)?.radical)
          .equals(SpecialRadical.sqrt2Over2);
      check(identifySpecialRadical(const Neg(invSqrt2))!.isNegative).isTrue();

      // 1 / sqrt(3) == sqrt(3) / 3
      const invSqrt3 = Div(
        RationalNumber.one,
        Pow(RationalNumber(3), RationalNumber(1, 2)),
      );
      check(isSqrt3Over3(invSqrt3)).isTrue();
      check(isNegativeSqrt3Over3(const Neg(invSqrt3))).isTrue();
      check(identifySpecialRadical(invSqrt3)?.radical)
          .equals(SpecialRadical.sqrt3Over3);
      check(identifySpecialRadical(const Neg(invSqrt3))!.isNegative).isTrue();

      // Reversed multiplications: sqrt(2) * 1/2, sqrt(3) * 1/2, sqrt(3) * 1/3
      const mulSqrt2 = Mul(
        Pow(RationalNumber(2), RationalNumber(1, 2)),
        RationalNumber(1, 2),
      );
      check(isSqrt2Over2(mulSqrt2)).isTrue();

      const mulNegSqrt2 = Mul(
        Pow(RationalNumber(2), RationalNumber(1, 2)),
        RationalNumber(-1, 2),
      );
      check(isNegativeSqrt2Over2(mulNegSqrt2)).isTrue();

      const mulSqrt3Over2 = Mul(
        Pow(RationalNumber(3), RationalNumber(1, 2)),
        RationalNumber(1, 2),
      );
      check(isSqrt3Over2(mulSqrt3Over2)).isTrue();

      const mulNegSqrt3Over2 = Mul(
        Pow(RationalNumber(3), RationalNumber(1, 2)),
        RationalNumber(-1, 2),
      );
      check(isNegativeSqrt3Over2(mulNegSqrt3Over2)).isTrue();

      const mulSqrt3Over3 = Mul(
        Pow(RationalNumber(3), RationalNumber(1, 2)),
        RationalNumber(1, 3),
      );
      check(isSqrt3Over3(mulSqrt3Over3)).isTrue();

      const mulNegSqrt3Over3 = Mul(
        Pow(RationalNumber(3), RationalNumber(1, 2)),
        RationalNumber(-1, 3),
      );
      check(isNegativeSqrt3Over3(mulNegSqrt3Over3)).isTrue();

      // Direct fractional roots: (1/2)^(1/2) and (1/3)^(1/2)
      const fracPow2 = Pow(RationalNumber(1, 2), RationalNumber(1, 2));
      check(isSqrt2Over2(fracPow2)).isTrue();

      const fracPow3 = Pow(RationalNumber(1, 3), RationalNumber(1, 2));
      check(isSqrt3Over3(fracPow3)).isTrue();

      // Negative sqrt(3): -1 * sqrt(3)
      const mulNegSqrt3 = Mul(
        RationalNumber.negativeOne,
        Pow(RationalNumber(3), RationalNumber(1, 2)),
      );
      check(isNegativeSqrt3(mulNegSqrt3)).isTrue();

      // Non-matches
      check(identifySpecialRadical(const RationalNumber(1, 4))).isNull();
      check(identifySpecialRadical(const ConstantNumber('pi'))).isNull();
      check(identifySpecialRadical(const Variable('x'))).isNull();
    });
  });

  group('Exact angle simplification', () {
    test('Asin, Acos, and Atan simplify special radicals', () {
      // Asin special radicals
      check(Asin(specialRadicalExpr(SpecialRadical.half)).simplify())
          .equals(const Mul(RationalNumber(1, 6), ConstantNumber.pi));
      check(
        Asin(specialRadicalExpr(SpecialRadical.half, negative: true))
            .simplify(),
      ).equals(const Neg(Mul(RationalNumber(1, 6), ConstantNumber.pi)));
      check(Asin(specialRadicalExpr(SpecialRadical.sqrt2Over2)).simplify())
          .equals(const Mul(RationalNumber(1, 4), ConstantNumber.pi));
      check(
        Asin(specialRadicalExpr(SpecialRadical.sqrt2Over2, negative: true))
            .simplify(),
      ).equals(const Neg(Mul(RationalNumber(1, 4), ConstantNumber.pi)));
      check(Asin(specialRadicalExpr(SpecialRadical.sqrt3Over2)).simplify())
          .equals(const Mul(RationalNumber(1, 3), ConstantNumber.pi));
      check(
        Asin(specialRadicalExpr(SpecialRadical.sqrt3Over2, negative: true))
            .simplify(),
      ).equals(const Neg(Mul(RationalNumber(1, 3), ConstantNumber.pi)));

      // Acos special radicals
      check(Acos(specialRadicalExpr(SpecialRadical.half)).simplify())
          .equals(const Mul(RationalNumber(1, 3), ConstantNumber.pi));
      check(
        Acos(specialRadicalExpr(SpecialRadical.half, negative: true))
            .simplify(),
      ).equals(const Mul(RationalNumber(2, 3), ConstantNumber.pi));
      check(Acos(specialRadicalExpr(SpecialRadical.sqrt2Over2)).simplify())
          .equals(const Mul(RationalNumber(1, 4), ConstantNumber.pi));
      check(
        Acos(specialRadicalExpr(SpecialRadical.sqrt2Over2, negative: true))
            .simplify(),
      ).equals(const Mul(RationalNumber(3, 4), ConstantNumber.pi));
      check(Acos(specialRadicalExpr(SpecialRadical.sqrt3Over2)).simplify())
          .equals(const Mul(RationalNumber(1, 6), ConstantNumber.pi));
      check(
        Acos(specialRadicalExpr(SpecialRadical.sqrt3Over2, negative: true))
            .simplify(),
      ).equals(const Mul(RationalNumber(5, 6), ConstantNumber.pi));

      // Atan special radicals
      check(Atan(specialRadicalExpr(SpecialRadical.sqrt3Over3)).simplify())
          .equals(const Mul(RationalNumber(1, 6), ConstantNumber.pi));
      check(
        Atan(specialRadicalExpr(SpecialRadical.sqrt3Over3, negative: true))
            .simplify(),
      ).equals(const Neg(Mul(RationalNumber(1, 6), ConstantNumber.pi)));
      check(Atan(specialRadicalExpr(SpecialRadical.sqrt3)).simplify())
          .equals(const Mul(RationalNumber(1, 3), ConstantNumber.pi));
      check(
        Atan(specialRadicalExpr(SpecialRadical.sqrt3, negative: true))
            .simplify(),
      ).equals(const Neg(Mul(RationalNumber(1, 3), ConstantNumber.pi)));
    });
  });
}
