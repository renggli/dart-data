import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:more/number.dart' show Complex;
import 'package:test/test.dart';

void main() {
  group('RationalNumber, IntegerNumber, and FractionNumber', () {
    test('canonical construction, reduction, and queries', () {
      final zero = RationalNumber(0);
      check(zero).isA<IntegerNumber>();
      check(zero.isZero).isTrue();
      check(zero.isOne).isFalse();
      check(zero.isNegativeOne).isFalse();
      check(zero.isInteger).isTrue();
      check(zero).equals(IntegerNumber.zero);
      check(zero.sign).equals(0);
      check(zero.abs()).equals(IntegerNumber.zero);

      final reduced = RationalNumber(6, 3);
      check(reduced).isA<IntegerNumber>();
      check(reduced).equals(IntegerNumber.two);
      check(reduced.asInt).equals(2);
      check(reduced.toInt()).equals(2);
      check(reduced.reciprocal()).equals(FractionNumber.half);

      final negDenom = RationalNumber(2, -4);
      check(negDenom).isA<FractionNumber>();
      check(negDenom).equals(FractionNumber.negativeHalf);
      check(negDenom.numerator).equals(Integer.negativeOne);
      check(negDenom.denominator).equals(Integer.two);
      check(negDenom.isNegative).isTrue();
      check(negDenom.isInteger).isFalse();
      check(negDenom.asInt).isNull();
      check(negDenom.abs()).equals(FractionNumber.half);
      check(negDenom.neg()).equals(FractionNumber.half);
      check(RationalNumber(7, 2).toInt()).equals(3);
      check(FractionNumber.third.toDouble()).isCloseTo(1.0 / 3.0, 1e-15);
      check(FractionNumber.quarter.toDouble()).equals(0.25);
      check(FractionNumber.half.hashCode).equals(RationalNumber(1, 2).hashCode);

      check(zero.freeVariables).isEmpty();
      check(zero.dependsOn('x')).isFalse();
      check(zero.substitute('x', IntegerNumber.one)).equals(zero);
      check(zero.mapChildren((e) => IntegerNumber.one)).equals(zero);
      check(zero.anyNode((e) => e == zero)).isTrue();
    });

    test('BigInt transparent promotion and demotion in IntegerNumber', () {
      final big = BigInt.two.pow(100);
      final expr = IntegerNumber(Integer.big(big));
      check(expr.value.isBig).isTrue();
      check(expr.asInt).isNull();
      check(expr.value.toBigInt()).equals(big);

      final quotient = expr / expr;
      check(quotient).equals(IntegerNumber.one);
      check((quotient as IntegerNumber).value.isBig).isFalse();
    });
  });

  group('RealNumber and ComplexNumber', () {
    test('RealNumber properties, normalization, and non-finite mapping', () {
      const negZero = RealNumber(-0.0);
      check(negZero.isZero).isTrue();
      check(negZero.isOne).isFalse();
      check(negZero.isNegativeOne).isFalse();
      check(negZero.isNegative).isFalse();
      check(negZero.sign).equals(0);

      check(RealNumber.one.isOne).isTrue();
      check(RealNumber.one.sign).equals(1);
      check(RealNumber.negativeOne.isNegativeOne).isTrue();
      check(RealNumber.negativeOne.isNegative).isTrue();
      check(RealNumber.negativeOne.sign).equals(-1);
      check(RealNumber.negativeOne.abs()).equals(RealNumber.one);
      check(RealNumber.one.conjugate).equals(RealNumber.one);
      check(RealNumber.one.toComplex()).equals(Complex.one);
      check(RealNumber.one.evaluate()).equals(1.0);
      check(RealNumber.one.hashCode).equals(const RealNumber(1.0).hashCode);

      check(RealNumber.fromDouble(-0.0)).equals(RealNumber.zero);
      check(RealNumber.fromDouble(double.infinity)).equals(Constant.infinity);
      check(RealNumber.fromDouble(double.negativeInfinity))
          .equals(-Constant.infinity);
      check(RealNumber.fromDouble(double.nan)).equals(Constant.undefined);
    });

    test('RealNumeric compareTo across rational and real types', () {
      check(RationalNumber(1, 3).compareTo(RationalNumber(1, 2))).isLessThan(0);
      check(const RealNumber(1.5).compareTo(const RealNumber(2.5)))
          .isLessThan(0);
      check(IntegerNumber.one.compareTo(const RealNumber(2.0))).isLessThan(0);
      check(FractionNumber.half.compareTo(const RealNumber(0.5))).equals(-1);
      check(const RealNumber(0.5).compareTo(FractionNumber.half)).equals(1);
    });

    test('ComplexNumber properties, demotion, and real-domain errors', () {
      final demoted = ComplexNumber.of(IntegerNumber.two, IntegerNumber.zero);
      check(demoted).isA<IntegerNumber>();
      check(demoted).equals(IntegerNumber.two);

      final gaussian = ComplexNumber.of(
        IntegerNumber.of(3),
        RationalNumber(-1, 2),
      );
      check(gaussian).isA<ComplexNumber>();
      final c = gaussian as ComplexNumber;
      check(c.isReal).isFalse();
      check(c.isZero).isFalse();
      check(c.isOne).isFalse();
      check(c.isNegativeOne).isFalse();
      check(c.isPureImaginary).isFalse();
      check(ComplexNumber.i.isPureImaginary).isTrue();
      check(c.value).equals(const Complex(3.0, -0.5));
      check(c.real).equals(IntegerNumber.of(3));
      check(c.imaginary).equals(FractionNumber.negativeHalf);
      check(c.conjugate.imaginary).equals(FractionNumber.half);
      check(c.neg())
          .equals(ComplexNumber(IntegerNumber.of(-3), FractionNumber.half));
      check(c.hashCode).equals(
        ComplexNumber(
          IntegerNumber.of(3),
          FractionNumber.negativeHalf,
        ).hashCode,
      );
      check(c.toDouble).throws<UnsupportedError>();
      check(c.evaluate).throws<UnsupportedError>();
    });
  });

  group('Number arithmetic and exponentiation', () {
    test('exact and contagious Number arithmetic and division by zero', () {
      final a = RationalNumber(1, 3);
      final b = RationalNumber(1, 6);
      check(a.add(b)).equals(FractionNumber.half);
      check(a.sub(b)).equals(RationalNumber(1, 6));
      check(a.mul(IntegerNumber.of(3))).equals(IntegerNumber.one);
      check(a.div(b)).equals(IntegerNumber.two);
      check(a.addRational(b)).equals(FractionNumber.half);
      check(a.subRational(b)).equals(RationalNumber(1, 6));
      check(a.mulRational(b)).equals(RationalNumber(1, 18));
      check(a.divRational(b)).equals(IntegerNumber.two);

      check(IntegerNumber.zero.mul(const RealNumber(2.5)))
          .equals(IntegerNumber.zero);
      check(const RealNumber(2.5).mul(IntegerNumber.zero))
          .equals(IntegerNumber.zero);
      check(IntegerNumber.zero.div(const RealNumber(2.5)))
          .equals(IntegerNumber.zero);
      check(const RealNumber(6.0).div(const RealNumber(2.0)))
          .equals(const RealNumber(3.0));

      final c = a.add(const RealNumber(0.5));
      check(c).isA<RealNumber>();
      check((c as RealNumber).value).isCloseTo(5.0 / 6.0, 1e-15);

      final z1 = ComplexNumber(IntegerNumber.of(1), IntegerNumber.of(2));
      final z2 = ComplexNumber(IntegerNumber.of(2), IntegerNumber.of(-4));
      check(z1.add(z2))
          .equals(ComplexNumber(IntegerNumber.of(3), IntegerNumber.of(-2)));
      check(
        z1.sub(z2),
      ).equals(ComplexNumber(IntegerNumber.negativeOne, IntegerNumber.of(6)));
      final prod = z1.mul(z2);
      check(prod).isA<IntegerNumber>();
      check(prod).equals(IntegerNumber.of(10));
      check(z1.div(z2))
          .equals(ComplexNumber(RationalNumber(-3, 10), RationalNumber(2, 5)));

      check(() => a.div(IntegerNumber.zero)).throws<UnsupportedError>();
      const tinyComplex = ComplexNumber(RealNumber.zero, RealNumber(1e-200));
      check(() => IntegerNumber.one.div(tinyComplex))
          .throws<UnsupportedError>();
    });

    test(
      'powNumber across rational, fractional root, complex, and real cases',
      () {
        check(IntegerNumber.zero.powNumber(IntegerNumber.zero))
            .equals(IntegerNumber.one);
        check(IntegerNumber.zero.powNumber(IntegerNumber.two))
            .equals(IntegerNumber.zero);
        check(() => IntegerNumber.zero.powNumber(IntegerNumber.negativeOne))
            .throws<UnsupportedError>();
        check(IntegerNumber.one.powNumber(IntegerNumber.of(5000)))
            .equals(IntegerNumber.one);
        check(IntegerNumber.negativeOne.powNumber(IntegerNumber.two))
            .equals(IntegerNumber.one);
        check(IntegerNumber.negativeOne.powNumber(IntegerNumber.of(3)))
            .equals(IntegerNumber.negativeOne);
        check(RationalNumber(2, 3).powNumber(IntegerNumber.of(3)))
            .equals(RationalNumber(8, 27));
        check(IntegerNumber.two.powNumber(IntegerNumber.of(2000))).isNull();

        check(IntegerNumber.zero.powNumber(FractionNumber.half))
            .equals(IntegerNumber.zero);
        check(() => IntegerNumber.zero.powNumber(FractionNumber.negativeHalf))
            .throws<UnsupportedError>();
        check(IntegerNumber.one.powNumber(FractionNumber.third))
            .equals(IntegerNumber.one);
        check(IntegerNumber.of(-4).powNumber(FractionNumber.half)).isNull();
        check(RationalNumber(8, 27).powNumber(RationalNumber(2, 3)))
            .equals(RationalNumber(4, 9));
        check(IntegerNumber.two.powNumber(FractionNumber.half)).isNull();
        check(IntegerNumber.of(4).powNumber(RationalNumber(1, 100))).isNull();

        check(ComplexNumber.i.powNumber(IntegerNumber.zero))
            .equals(IntegerNumber.one);
        check(ComplexNumber.i.powNumber(IntegerNumber.one))
            .equals(ComplexNumber.i);
        check(ComplexNumber.i.powNumber(IntegerNumber.two))
            .equals(IntegerNumber.negativeOne);
        check(ComplexNumber.i.powNumber(IntegerNumber.of(3)))
            .equals(ComplexNumber.negativeI);
        check(ComplexNumber.i.powNumber(IntegerNumber.of(4)))
            .equals(IntegerNumber.one);
        check(ComplexNumber.negativeI.powNumber(IntegerNumber.two))
            .equals(IntegerNumber.negativeOne);
        check(ComplexNumber.negativeI.powNumber(IntegerNumber.of(3)))
            .equals(ComplexNumber.i);

        const twoI = ComplexNumber(IntegerNumber.zero, IntegerNumber.two);
        check(twoI.powNumber(IntegerNumber.of(3)))
            .equals(ComplexNumber(IntegerNumber.zero, IntegerNumber.of(-8)));
        check(twoI.powNumber(IntegerNumber.of(2000))).isNull();

        const onePlusI = ComplexNumber(IntegerNumber.one, IntegerNumber.one);
        check(onePlusI.powNumber(const RealNumber(2.0))).equals(twoI);
        check(onePlusI.powNumber(IntegerNumber.of(-2))).equals(
          const ComplexNumber(IntegerNumber.zero, FractionNumber.negativeHalf),
        );
        check(onePlusI.powNumber(IntegerNumber.of(100))).isNull();
        check(onePlusI.powNumber(const RealNumber(1.5))).isNull();

        check(RealNumber.zero.powNumber(RealNumber.zero))
            .equals(IntegerNumber.one);
        check(RealNumber.zero.powNumber(const RealNumber(2.5)))
            .equals(RealNumber.zero);
        check(IntegerNumber.zero.powNumber(const RealNumber(2.5)))
            .equals(IntegerNumber.zero);
        check(() => RealNumber.zero.powNumber(const RealNumber(-1.5)))
            .throws<UnsupportedError>();
        check(RealNumber.one.powNumber(const RealNumber(2.5)))
            .equals(IntegerNumber.one);
        check(const RealNumber(-2.0).powNumber(const RealNumber(1.5))).isNull();
        check(const RealNumber(4.0).powNumber(const RealNumber(0.5)))
            .equals(const RealNumber(2.0));
        check(const RealNumber(1e200).powNumber(const RealNumber(10.0)))
            .isNull();
        check(IntegerNumber.two.powNumber(ComplexNumber.i)).isNull();
      },
    );
  });
}
