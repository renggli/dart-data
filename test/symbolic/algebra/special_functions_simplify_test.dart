import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/scaffolding.dart';

void main() {
  const x = Variable('x');

  group('LambertW simplification', () {
    test('special values W(0) = 0 and W(e) = 1', () {
      check(const LambertW(RationalNumber.zero).simplify())
          .equals(RationalNumber.zero);
      check(const LambertW(ConstantNumber.e).simplify())
          .equals(RationalNumber.one);
    });

    test('branch point value W_0(-1/e) = -1', () {
      const invE = Div(RationalNumber.negativeOne, ConstantNumber.e);
      check(const LambertW(invE).simplify()).equals(RationalNumber.negativeOne);
    });
  });

  group('Erf & Erfc simplification', () {
    test('Erf(0) = 0 and Erfc(0) = 1', () {
      check(const Erf(RationalNumber.zero).simplify())
          .equals(RationalNumber.zero);
      check(const Erfc(RationalNumber.zero).simplify())
          .equals(RationalNumber.one);
    });

    test('Erf parity: Erf(-x) = -Erf(x)', () {
      final erfNeg = const Erf(Neg(x)).simplify();
      check(erfNeg).equals(const Neg(Erf(x)));
    });
  });

  group('Gamma & Beta simplification', () {
    test('Gamma integer values', () {
      check(const Gamma(RationalNumber.one).simplify())
          .equals(RationalNumber.one);
      check(const Gamma(RationalNumber(2)).simplify())
          .equals(RationalNumber.one);
      check(const Gamma(RationalNumber(3)).simplify())
          .equals(const RationalNumber(2));
      check(const Gamma(RationalNumber(4)).simplify())
          .equals(const RationalNumber(6));
      check(const Gamma(RationalNumber(5)).simplify())
          .equals(const RationalNumber(24));
    });

    test('Gamma(1/2) = sqrt(pi)', () {
      final gHalf = const Gamma(RationalNumber(1, 2)).simplify();
      check(gHalf).equals(const Pow(ConstantNumber.pi, RationalNumber(1, 2)));
    });

    test('Beta symmetry Beta(b, a) = Beta(a, b)', () {
      const a = Variable('a');
      const b = Variable('b');
      final b1 = const Beta(a, b).simplify();
      final b2 = const Beta(b, a).simplify();
      check(b1).equals(b2);
    });

    test('Beta integer evaluation', () {
      check(const Beta(RationalNumber(2), RationalNumber(3)).simplify())
          .equals(const RationalNumber(1, 12));
    });
  });

  group('Inverse hyperbolic simplification', () {
    test('Asinh(0) = 0 and parity Asinh(-x) = -Asinh(x)', () {
      check(const Asinh(RationalNumber.zero).simplify())
          .equals(RationalNumber.zero);
      check(const Asinh(Neg(x)).simplify()).equals(const Neg(Asinh(x)));
    });

    test('Acosh(1) = 0', () {
      check(const Acosh(RationalNumber.one).simplify())
          .equals(RationalNumber.zero);
    });

    test('Atanh(0) = 0 and parity Atanh(-x) = -Atanh(x)', () {
      check(const Atanh(RationalNumber.zero).simplify())
          .equals(RationalNumber.zero);
      check(const Atanh(Neg(x)).simplify()).equals(const Neg(Atanh(x)));
    });
  });

  group('Piecewise simplification', () {
    test('collapses when first branch is true', () {
      const pw = Piecewise([
        (Equal(RationalNumber.one, RationalNumber.one), RationalNumber(42)),
        (Equal(RationalNumber.zero, RationalNumber.one), RationalNumber(10)),
      ]);
      check(pw.simplify()).equals(const RationalNumber(42));
    });

    test('eliminates branches with false conditions', () {
      const pw = Piecewise([
        (Equal(RationalNumber.zero, RationalNumber.one), RationalNumber(10)),
        (LessThan(x, RationalNumber.zero), RationalNumber(99)),
      ], otherwise: RationalNumber.zero);

      final simplified = pw.simplify();
      check(simplified).isA<Piecewise>();
      final pwSimple = simplified as Piecewise;
      check(pwSimple.branches.length).equals(1);
      check(pwSimple.branches.first.$2).equals(const RationalNumber(99));
    });
  });
}
