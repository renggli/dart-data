import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/test.dart';

void main() {
  group('Special functions and inverse hyperbolic AST', () {
    test('Erf and Erfc identities and evaluation', () {
      const x = Variable('x');
      check(Erf(IntegerNumber.zero).simplify()).equals(IntegerNumber.zero);
      check(Erfc(IntegerNumber.zero).simplify()).equals(IntegerNumber.one);
      check(Erf(Constant.infinity).simplify()).equals(IntegerNumber.one);
      check(Erfc(Constant.infinity).simplify()).equals(IntegerNumber.zero);
      check(Erf(-x).simplify()).equals(-Erf(x));

      const v = 0.7;
      check(Erf(x).evaluate({'x': v}) + Erfc(x).evaluate({'x': v}))
          .isCloseTo(1.0, 1e-14);
    });

    test('Gamma and Beta exact factorials and half-integers', () {
      check(Gamma(IntegerNumber.one).simplify()).equals(IntegerNumber.one);
      check(Gamma(IntegerNumber.of(5)).simplify()).equals(IntegerNumber.of(24));
      check(Gamma(FractionNumber.half).simplify())
          .equals(Pow(Constant.pi, FractionNumber.half, isSimplified: true));

      check(Beta(IntegerNumber.of(2), IntegerNumber.of(3)).simplify())
          .equals(RationalNumber(1, 12));
    });

    test('Asinh, Acosh, and Atanh simplification and evaluation', () {
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
