import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/test.dart';

void main() {
  group('Error functions (Erf and Erfc)', () {
    test('identities, evaluation, substitution, and mapChildren', () {
      const x = Variable('x');
      const y = Variable('y');
      check(Erf(IntegerNumber.zero).simplify()).equals(IntegerNumber.zero);
      check(Erfc(IntegerNumber.zero).simplify()).equals(IntegerNumber.one);
      check(Erf(Constant.infinity).simplify()).equals(IntegerNumber.one);
      check(Erfc(Constant.infinity).simplify()).equals(IntegerNumber.zero);
      check(Erf(-x).simplify()).equals(-Erf(x));

      const v = 0.7;
      check(Erf(x).evaluate({'x': v}) + Erfc(x).evaluate({'x': v}))
          .isCloseTo(1.0, 1e-14);

      check(Erf(x).substitute('x', y)).equals(Erf(y));
      check(Erf(x).mapChildren((_) => y)).equals(Erf(y));
      check(Erfc(x).substitute('x', y)).equals(Erfc(y));
      check(Erfc(x).mapChildren((_) => y)).equals(Erfc(y));
    });
  });

  group('Euler Gamma and Beta functions', () {
    test('exact factorials, half-integers, evaluation, substitution, and mapChildren', () {
      const x = Variable('x');
      const y = Variable('y');
      check(Gamma(IntegerNumber.one).simplify()).equals(IntegerNumber.one);
      check(Gamma(IntegerNumber.of(5)).simplify()).equals(IntegerNumber.of(24));
      check(Gamma(FractionNumber.half).simplify())
          .equals(Pow(Constant.pi, FractionNumber.half, isSimplified: true));
      check(Gamma(x).evaluate({'x': 4.0})).isCloseTo(6.0, 1e-12);
      check(Gamma(x).substitute('x', y)).equals(Gamma(y));
      check(Gamma(x).mapChildren((_) => y)).equals(Gamma(y));

      check(Beta(IntegerNumber.of(2), IntegerNumber.of(3)).simplify())
          .equals(RationalNumber(1, 12));
      check(Beta(x, y).evaluate({'x': 2.0, 'y': 3.0}))
          .isCloseTo(1.0 / 12.0, 1e-12);
      check(Beta(x, y).substitute('x', IntegerNumber.two))
          .equals(Beta(IntegerNumber.two, y));
      check(Beta(x, y).mapChildren((e) => e == x ? IntegerNumber.two : e))
          .equals(Beta(IntegerNumber.two, y));
    });
  });

  group('Inverse hyperbolic functions (Asinh, Acosh, Atanh)', () {
    test('simplification and evaluation', () {
      const x = Variable('x');
      check(Asinh(IntegerNumber.zero).simplify()).equals(IntegerNumber.zero);
      check(Acosh(IntegerNumber.one).simplify()).equals(IntegerNumber.zero);
      check(Atanh(IntegerNumber.zero).simplify()).equals(IntegerNumber.zero);
      check(Asinh(-x).simplify()).equals(-Asinh(x));
      check(Atanh(-x).simplify()).equals(-Atanh(x));

      final sinhVal = Sinh(const RealNumber(1.2)).evaluate();
      final coshVal = Cosh(const RealNumber(1.2)).evaluate();
      final tanhVal = Tanh(const RealNumber(0.6)).evaluate();
      check(Asinh(x).evaluate({'x': sinhVal})).isCloseTo(1.2, 1e-12);
      check(Acosh(x).evaluate({'x': coshVal})).isCloseTo(1.2, 1e-12);
      check(Atanh(x).evaluate({'x': tanhVal})).isCloseTo(0.6, 1e-12);
    });
  });
}
