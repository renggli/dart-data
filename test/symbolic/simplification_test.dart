import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('Trigonometric identity simplification', () {
    const x = Variable('x');

    test('constant evaluations at 0 and pi multiples', () {
      check(const Sin(RationalNumber.zero).simplify())
          .equals(RationalNumber.zero);
      check(const Sin(ConstantNumber.pi).simplify())
          .equals(RationalNumber.zero);
      check(const Sin(Mul(RationalNumber(1, 2), ConstantNumber.pi)).simplify())
          .equals(RationalNumber.one);
      check(const Sin(Mul(RationalNumber(-1, 2), ConstantNumber.pi)).simplify())
          .equals(RationalNumber.negativeOne);

      check(const Cos(RationalNumber.zero).simplify())
          .equals(RationalNumber.one);
      check(const Cos(ConstantNumber.pi).simplify())
          .equals(RationalNumber.negativeOne);
      check(const Cos(Mul(RationalNumber(1, 2), ConstantNumber.pi)).simplify())
          .equals(RationalNumber.zero);

      check(const Tan(RationalNumber.zero).simplify())
          .equals(RationalNumber.zero);
      check(const Tan(ConstantNumber.pi).simplify())
          .equals(RationalNumber.zero);
      check(const Tan(Mul(RationalNumber(1, 4), ConstantNumber.pi)).simplify())
          .equals(RationalNumber.one);
      check(const Tan(Mul(RationalNumber(-1, 4), ConstantNumber.pi)).simplify())
          .equals(RationalNumber.negativeOne);

      check(const Asin(RationalNumber.zero).simplify())
          .equals(RationalNumber.zero);
      check(const Asin(RationalNumber.one).simplify())
          .equals(const Mul(RationalNumber(1, 2), ConstantNumber.pi));
      check(const Asin(RationalNumber.negativeOne).simplify())
          .equals(const Mul(RationalNumber(-1, 2), ConstantNumber.pi));

      check(const Acos(RationalNumber.one).simplify())
          .equals(RationalNumber.zero);
      check(const Acos(RationalNumber.zero).simplify())
          .equals(const Mul(RationalNumber(1, 2), ConstantNumber.pi));
      check(const Acos(RationalNumber.negativeOne).simplify())
          .equals(ConstantNumber.pi);

      check(const Atan(RationalNumber.zero).simplify())
          .equals(RationalNumber.zero);
      check(const Atan(RationalNumber.one).simplify())
          .equals(const Mul(RationalNumber(1, 4), ConstantNumber.pi));
      check(const Atan(RationalNumber.negativeOne).simplify())
          .equals(const Mul(RationalNumber(-1, 4), ConstantNumber.pi));
    });

    test('parity symmetry argument normalization', () {
      check(const Sin(Neg(x)).simplify()).equals(const Neg(Sin(x)));
      check(const Cos(Neg(x)).simplify()).equals(const Cos(x));
      check(const Tan(Neg(x)).simplify()).equals(const Neg(Tan(x)));
      check(const Asin(Neg(x)).simplify()).equals(const Neg(Asin(x)));
      check(const Atan(Neg(x)).simplify()).equals(const Neg(Atan(x)));

      // Scaled negative argument
      check(const Sin(Mul(RationalNumber(-3), x)).simplify())
          .equals(const Neg(Sin(Mul(RationalNumber(3), x))));
      check(const Cos(Mul(RationalNumber(-3), x)).simplify())
          .equals(const Cos(Mul(RationalNumber(3), x)));
    });

    test('Pythagorean identities in term accumulator', () {
      const sin2 = Pow(Sin(x), RationalNumber(2));
      const cos2 = Pow(Cos(x), RationalNumber(2));

      // sin^2(x) + cos^2(x) = 1
      check(const Add(sin2, cos2).simplify()).equals(RationalNumber.one);
      check(const Add(cos2, sin2).simplify()).equals(RationalNumber.one);

      // 3 * sin^2(x) + 3 * cos^2(x) = 3
      const threeSin2 = Mul(RationalNumber(3), sin2);
      const threeCos2 = Mul(RationalNumber(3), cos2);
      check(const Add(threeSin2, threeCos2).simplify())
          .equals(const RationalNumber(3));

      // 5 * sin^2(x) + 3 * cos^2(x) = 2 * sin^2(x) + 3
      const fiveSin2 = Mul(RationalNumber(5), sin2);
      check(const Add(fiveSin2, threeCos2).simplify())
          .equals(const Add(Mul(RationalNumber(2), sin2), RationalNumber(3)));

      // 1 - sin^2(x) = cos^2(x)
      check(const Sub(RationalNumber.one, sin2).simplify()).equals(cos2);

      // 1 - cos^2(x) = sin^2(x)
      check(const Sub(RationalNumber.one, cos2).simplify()).equals(sin2);
    });

    test('inverse function involutions', () {
      check(const Sin(Asin(x)).simplify()).equals(x);
      check(const Cos(Acos(x)).simplify()).equals(x);
      check(const Tan(Atan(x)).simplify()).equals(x);

      check(const Asin(Sin(x)).simplify()).equals(x);
      check(const Acos(Cos(x)).simplify()).equals(x);
      check(const Atan(Tan(x)).simplify()).equals(x);
    });
  });

  group('Hyperbolic identity simplification', () {
    const x = Variable('x');

    test('constant evaluations at 0', () {
      check(const Sinh(RationalNumber.zero).simplify())
          .equals(RationalNumber.zero);
      check(const Cosh(RationalNumber.zero).simplify())
          .equals(RationalNumber.one);
      check(const Tanh(RationalNumber.zero).simplify())
          .equals(RationalNumber.zero);
    });

    test('parity symmetry', () {
      check(const Sinh(Neg(x)).simplify()).equals(const Neg(Sinh(x)));
      check(const Cosh(Neg(x)).simplify()).equals(const Cosh(x));
      check(const Tanh(Neg(x)).simplify()).equals(const Neg(Tanh(x)));
    });

    test('hyperbolic Pythagorean identities in term accumulator', () {
      const cosh2 = Pow(Cosh(x), RationalNumber(2));
      const sinh2 = Pow(Sinh(x), RationalNumber(2));

      // cosh^2(x) - sinh^2(x) = 1
      check(const Sub(cosh2, sinh2).simplify()).equals(RationalNumber.one);

      // 1 + sinh^2(x) = cosh^2(x)
      check(const Add(RationalNumber.one, sinh2).simplify()).equals(cosh2);

      // cosh^2(x) - 1 = sinh^2(x)
      check(const Sub(cosh2, RationalNumber.one).simplify()).equals(sinh2);
    });
  });

  group('Exponential and logarithmic simplification', () {
    const x = Variable('x');
    const y = Variable('y');

    test('basic identities and constant evaluations', () {
      check(const Exp(Ln(x)).simplify()).equals(x);
      check(const Ln(Exp(x)).simplify()).equals(x);
      check(const Ln(RationalNumber.one).simplify())
          .equals(RationalNumber.zero);
      check(const Ln(ConstantNumber.e).simplify()).equals(RationalNumber.one);
    });

    test('power relations in exponent and logarithm', () {
      // e^(3 * ln(x)) = x^3
      check(const Exp(Mul(RationalNumber(3), Ln(x))).simplify())
          .equals(const Pow(x, RationalNumber(3)));

      // e^(-ln(x)) = x^(-1)
      check(const Exp(Neg(Ln(x))).simplify())
          .equals(const Pow(x, RationalNumber.negativeOne));

      // ln(x^4) = 4 * ln(x)
      check(const Ln(Pow(x, RationalNumber(4))).simplify())
          .equals(const Mul(RationalNumber(4), Ln(x)));

      // ln(sqrt(x)) = 1/2 * ln(x)
      check(const Ln(Sqrt(x)).simplify())
          .equals(const Mul(RationalNumber(1, 2), Ln(x)));
    });

    test('logarithm product and quotient aggregation', () {
      // ln(x) + ln(y) = ln(x * y)
      check(const Add(Ln(x), Ln(y)).simplify()).equals(const Ln(Mul(x, y)));

      // ln(x) - ln(y) = ln(x / y)
      check(const Sub(Ln(x), Ln(y)).simplify()).equals(const Ln(Div(x, y)));
    });

    test('exponential multiplication, division, and power laws', () {
      // e^x * e^y = e^(x + y)
      check(const Mul(Exp(x), Exp(y)).simplify()).equals(const Exp(Add(x, y)));

      // e^x / e^y = e^(x - y)
      check(const Div(Exp(x), Exp(y)).simplify()).equals(const Exp(Sub(x, y)));

      // (e^x)^y = e^(x * y)
      check(const Pow(Exp(x), y).simplify()).equals(const Exp(Mul(x, y)));
    });

    test('arbitrary base logarithm simplifications', () {
      // log(b, 1) = 0
      check(const Log(x, RationalNumber.one).simplify())
          .equals(RationalNumber.zero);

      // log(b, b) = 1
      check(const Log(x, x).simplify()).equals(RationalNumber.one);

      // log(b, b^k) = k
      check(const Log(x, Pow(x, RationalNumber(3))).simplify())
          .equals(const RationalNumber(3));

      // log(e, x) = ln(x)
      check(const Log(ConstantNumber.e, x).simplify()).equals(const Ln(x));
    });
  });

  group('Absolute value and radical simplification', () {
    const x = Variable('x');
    const y = Variable('y');

    test('absolute value reductions', () {
      // |-x| = |x|
      check(const Abs(Neg(x)).simplify()).equals(const Abs(x));

      // ||x|| = |x|
      check(const Abs(Abs(x)).simplify()).equals(const Abs(x));

      // |e^x| = e^x
      check(const Abs(Exp(x)).simplify()).equals(const Exp(x));

      // |x|^2 = x^2
      check(const Pow(Abs(x), RationalNumber(2)).simplify())
          .equals(const Pow(x, RationalNumber(2)));
    });

    test('radical reductions', () {
      check(const Sqrt(RationalNumber.zero).simplify())
          .equals(RationalNumber.zero);
      check(const Sqrt(RationalNumber.one).simplify())
          .equals(RationalNumber.one);
      check(const Sqrt(RationalNumber(4, 9)).simplify())
          .equals(const RationalNumber(2, 3));

      // sqrt(x)^2 = x
      check(const Pow(Sqrt(x), RationalNumber(2)).simplify()).equals(x);

      // sqrt(x^2) = |x|
      check(const Sqrt(Pow(x, RationalNumber(2))).simplify())
          .equals(const Abs(x));

      // sqrt(x) * sqrt(y) = sqrt(x * y)
      check(const Mul(Sqrt(x), Sqrt(y)).simplify())
          .equals(const Sqrt(Mul(x, y)));

      // sqrt(x) / sqrt(y) = sqrt(x / y)
      check(const Div(Sqrt(x), Sqrt(y)).simplify())
          .equals(const Sqrt(Div(x, y)));
    });
  });

  group('Simplification idempotence and stability', () {
    final expressions = [
      Expr.parse('tan(x) + cosh(x) - sinh(x)'),
      Expr.parse('sin(x)^2 + cos(x)^2 + abs(-x)'),
      Expr.parse('ln(x) + ln(y) - ln(z)'),
      Expr.parse('exp(x) * exp(y) / exp(z)'),
      Expr.parse('sqrt(x) * sqrt(y)'),
      Expr.parse('log(2, 8)'),
    ];

    test('expr.simplify().simplify() == expr.simplify()', () {
      for (final expr in expressions) {
        final s1 = expr.simplify();
        final s2 = s1.simplify();
        check(s2).equals(s1);
      }
    });
  });
}
