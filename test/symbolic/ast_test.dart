import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:more/number.dart' show Complex;
import 'package:test/test.dart';

void main() {
  group('Number tower', () {
    test('IntegerNumber and RationalNumber canonical construction', () {
      final zero = RationalNumber(0);
      check(zero).isA<IntegerNumber>();
      check(zero.isZero).isTrue();
      check(zero.isOne).isFalse();
      check(zero.isInteger).isTrue();
      check(zero).equals(IntegerNumber.zero);

      final reduced = RationalNumber(6, 3);
      check(reduced).isA<IntegerNumber>();
      check(reduced).equals(IntegerNumber.two);

      final negDenom = RationalNumber(2, -4);
      check(negDenom).isA<FractionNumber>();
      check(negDenom).equals(FractionNumber.negativeHalf);
      check(negDenom.numerator).equals(Integer.negativeOne);
      check(negDenom.denominator).equals(Integer.two);
      check(negDenom.isNegative).isTrue();
    });

    test('BigInt transparent promotion and demotion in IntegerNumber', () {
      final big = BigInt.two.pow(100);
      final expr = IntegerNumber(Integer.big(big));
      check(expr.value.isBig).isTrue();
      check(expr.value.toBigInt()).equals(big);

      final quotient = expr / expr;
      check(quotient).equals(IntegerNumber.one);
      check((quotient as IntegerNumber).value.isBig).isFalse();
    });

    test('RealNumber normalizes -0.0 and maps non-finite values', () {
      const negZero = RealNumber(-0.0);
      check(negZero.isZero).isTrue();
      check(RealNumber.fromDouble(-0.0)).equals(RealNumber.zero);
      check(RealNumber.fromDouble(double.infinity)).equals(Constant.infinity);
      check(RealNumber.fromDouble(double.negativeInfinity))
          .equals(-Constant.infinity);
      check(RealNumber.fromDouble(double.nan)).equals(Constant.undefined);
    });

    test('ComplexNumber auto-demotes when imaginary part is zero', () {
      final demoted = ComplexNumber.of(IntegerNumber.two, IntegerNumber.zero);
      check(demoted).isA<IntegerNumber>();
      check(demoted).equals(IntegerNumber.two);

      final gaussian = ComplexNumber.of(
        IntegerNumber.of(3),
        RationalNumber(-1, 2),
      );
      check(gaussian).isA<ComplexNumber>();
      check(gaussian.isReal).isFalse();
      check((gaussian as ComplexNumber).real).equals(IntegerNumber.of(3));
      check(gaussian.imaginary).equals(FractionNumber.negativeHalf);
      check(gaussian.conjugate.imaginary).equals(FractionNumber.half);
    });

    test('exact and contagious Number arithmetic', () {
      final a = RationalNumber(1, 3);
      final b = RationalNumber(1, 6);
      check(a.add(b)).equals(FractionNumber.half);
      check(a.sub(b)).equals(RationalNumber(1, 6));
      check(a.mul(IntegerNumber.of(3))).equals(IntegerNumber.one);
      check(a.div(b)).equals(IntegerNumber.two);

      // Float contagion
      final c = a.add(const RealNumber(0.5));
      check(c).isA<RealNumber>();
      check((c as RealNumber).value).isCloseTo(5.0 / 6.0, 1e-15);

      // Complex arithmetic
      final z1 = ComplexNumber(IntegerNumber.of(1), IntegerNumber.of(2));
      final z2 = ComplexNumber(IntegerNumber.of(2), IntegerNumber.of(-4));
      // (1 + 2i) * (2 - 4i) = 2 - 4i + 4i - 8i^2 = 10 (purely real!)
      final prod = z1.mul(z2);
      check(prod).isA<IntegerNumber>();
      check(prod).equals(IntegerNumber.of(10));
    });
  });

  group('Constant and Variable', () {
    test('built-in constants are opaque symbolic nodes', () {
      check(Constant.pi.name).equals('pi');
      check(Constant.pi.evaluate()).isCloseTo(math.pi, 1e-15);
      check(Constant.e.evaluate()).isCloseTo(math.e, 1e-15);
      check(Constant.infinity.evaluate()).equals(double.infinity);
      check(Constant.undefined.evaluate().isNaN).isTrue();
      check(Constant.i).equals(ComplexNumber.i);
    });

    test('Variable freeVariables, dependsOn, and substitute', () {
      const x = Variable('x');
      const y = Variable('y');
      final expr = x * y + Sin(x);
      check(expr.freeVariables).unorderedEquals(['x', 'y']);
      check(expr.dependsOn('x')).isTrue();
      check(expr.dependsOn('z')).isFalse();

      final sub = expr.substitute('x', IntegerNumber.zero);
      check(sub.freeVariables).unorderedEquals(['y']);
      check(sub.evaluate({'y': 5.0})).equals(0.0);
    });
  });

  group('Unified n-ary Add, Mul, and Pow', () {
    test('Add and Mul flatten unsimplified operands and preserve order', () {
      const x = Variable('x');
      const y = Variable('y');
      const z = Variable('z');

      final sum = x + y - z + 1;
      check(sum).isA<Add>();
      final terms = (sum as Add).terms;
      check(terms.length).equals(4);
      check(terms[0]).equals(x);
      check(terms[1]).equals(y);
      check(terms[2]).equals(Mul([IntegerNumber.negativeOne, z]));
      check(terms[3]).equals(IntegerNumber.one);

      final prod = x * y / z;
      check(prod).isA<Mul>();
      final factors = (prod as Mul).factors;
      check(factors.length).equals(3);
      check(factors[0]).equals(x);
      check(factors[1]).equals(y);
      check(factors[2]).equals(Pow(z, IntegerNumber.negativeOne));
    });

    test('division of exact RationalNumbers reduces immediately', () {
      final r = IntegerNumber.of(2) / IntegerNumber.of(4);
      check(r).isA<FractionNumber>();
      check(r).equals(FractionNumber.half);
    });

    test('evaluate and evaluateComplex on composite ASTs', () {
      const x = Variable('x');
      final f = Pow(Constant.e, ComplexNumber.i * x);
      final val = f.evaluateComplex({'x': const Complex(math.pi / 2)});
      check(val.a).isCloseTo(0.0, 1e-12);
      check(val.b).isCloseTo(1.0, 1e-12);
    });
  });
}
