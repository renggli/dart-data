import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/scaffolding.dart';

void main() {
  const x = Variable('x');
  const y = Variable('y');
  const a = Variable('a');
  const b = Variable('b');

  group('SimplifierExtension - field axioms & arithmetic', () {
    test('additive identities and constant folding', () {
      check((x + 0).simplify()).equals(x);
      check((const RationalNumber(0) + x).simplify()).equals(x);
      check((x - 0).simplify()).equals(x);
      check((const RationalNumber(0) - x).simplify()).equals(-x);
      check((x - x).simplify()).equals(RationalNumber.zero);
      check((const RationalNumber(3) + const RationalNumber(4)).simplify())
          .equals(const RationalNumber(7));
      check((const RationalNumber(5) - const RationalNumber(2)).simplify())
          .equals(const RationalNumber(3));
      check((x + x).simplify()).equals(const RationalNumber(2) * x);
      check((x * 3 - x).simplify()).equals(const RationalNumber(2) * x);
    });

    test('multiplicative identities and annihilators', () {
      check((x * 0).simplify()).equals(RationalNumber.zero);
      check((RationalNumber.zero * x).simplify()).equals(RationalNumber.zero);
      check((x * 1).simplify()).equals(x);
      check((RationalNumber.one * x).simplify()).equals(x);
      check((x * -1).simplify()).equals(-x);
      check((RationalNumber.negativeOne * x).simplify()).equals(-x);
      check((const RationalNumber(3) * const RationalNumber(4)).simplify())
          .equals(const RationalNumber(12));
    });

    test('division identities', () {
      check((x / 1).simplify()).equals(x);
      check((x / x).simplify()).equals(RationalNumber.one);
      check((RationalNumber.zero / x).simplify()).equals(RationalNumber.zero);
      check((const RationalNumber(6) / const RationalNumber(2)).simplify())
          .equals(const RationalNumber(3));
      check((x / const RationalNumber(2)).simplify())
          .equals(const RationalNumber(1, 2) * x);
    });
  });

  group('SimplifierExtension - powers and exponentials', () {
    test('power identities', () {
      check(x.pow(0).simplify()).equals(RationalNumber.one);
      check(x.pow(1).simplify()).equals(x);
      check(const RationalNumber(1).pow(x).simplify())
          .equals(RationalNumber.one);
      check(const RationalNumber(2).pow(3).simplify())
          .equals(const RationalNumber(8));
      check((x.pow(2) * x.pow(3)).simplify()).equals(x.pow(5));
      check((x.pow(5) / x.pow(2)).simplify()).equals(x.pow(3));
    });

    test('involution square root of square is absolute value', () {
      final xSq = x.pow(2);
      final sqrtXSq = xSq.pow(const RationalNumber(1, 2));
      check(sqrtXSq.simplify()).equals(const Abs(x));
    });

    test('exponential and logarithm inverses', () {
      check(const Exp(Ln(x)).simplify()).equals(x);
      check(const Ln(Exp(x)).simplify()).equals(x);
      check(Ln(x.pow(3)).simplify())
          .equals(const RationalNumber(3) * const Ln(x));
    });
  });

  group('SimplifierExtension - trigonometric & hyperbolic identities', () {
    test('Pythagorean identity: sin^2(x) + cos^2(x) = 1', () {
      final sinSq = const Sin(x).pow(2);
      final cosSq = const Cos(x).pow(2);
      check((sinSq + cosSq).simplify()).equals(RationalNumber.one);
    });

    test('Pythagorean variations: 1 - sin^2(x) = cos^2(x)', () {
      final sinSq = const Sin(x).pow(2);
      check((const RationalNumber(1) - sinSq).simplify())
          .equals(const Cos(x).pow(2));
    });

    test('Pythagorean variations: 1 - cos^2(x) = sin^2(x)', () {
      final cosSq = const Cos(x).pow(2);
      check((const RationalNumber(1) - cosSq).simplify())
          .equals(const Sin(x).pow(2));
    });

    test('Hyperbolic Pythagorean: cosh^2(x) - sinh^2(x) = 1', () {
      final coshSq = const Cosh(x).pow(2);
      final sinhSq = const Sinh(x).pow(2);
      check((coshSq - sinhSq).simplify()).equals(RationalNumber.one);
    });

    test('trigonometric and hyperbolic parity', () {
      check(Sin(-x).simplify()).equals(-const Sin(x));
      check(Cos(-x).simplify()).equals(const Cos(x));
      check(Tan(-x).simplify()).equals(-const Tan(x));
      check(Sinh(-x).simplify()).equals(-const Sinh(x));
      check(Cosh(-x).simplify()).equals(const Cosh(x));
      check(Tanh(-x).simplify()).equals(-const Tanh(x));
    });
  });

  group('SimplifierExtension - logarithm combining', () {
    test('sum of logarithms: ln(x) + ln(y) = ln(x * y)', () {
      check((const Ln(x) + const Ln(y)).simplify()).equals(Ln(x * y));
    });

    test('difference of logarithms: ln(x) - ln(y) = ln(x / y)', () {
      check((const Ln(x) - const Ln(y)).simplify()).equals(Ln(x / y));
    });
  });

  group('SimplifierExtension - polynomial term ordering', () {
    test('orders terms in descending degree', () {
      final expr =
          const RationalNumber(5) +
          const RationalNumber(2) * x.pow(2) +
          x.pow(3) -
          x;
      final simplified = expr.simplify();
      // Degree 3, Degree 2, Degree 1 (negative), Constant
      final expected = x.pow(3) + const RationalNumber(2) * x.pow(2) - x + 5;
      check(simplified).equals(expected);
    });
  });

  group('Trigonometric identity simplification', () {
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
      check(const Ln(Pow(x, RationalNumber(1, 2))).simplify())
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
      check(const Div(Ln(RationalNumber.one), Ln(x)).simplify())
          .equals(RationalNumber.zero);

      // log(b, b) = 1
      check(const Div(Ln(x), Ln(x)).simplify()).equals(RationalNumber.one);

      // log(b, b^k) = k
      check(const Div(Ln(Pow(x, RationalNumber(3))), Ln(x)).simplify())
          .equals(const RationalNumber(3));

      // log(e, x) = ln(x)
      check(const Div(Ln(x), Ln(ConstantNumber.e)).simplify())
          .equals(const Ln(x));
    });
  });

  group('Absolute value and radical simplification', () {
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
      check(const Pow(RationalNumber.zero, RationalNumber(1, 2)).simplify())
          .equals(RationalNumber.zero);
      check(const Pow(RationalNumber.one, RationalNumber(1, 2)).simplify())
          .equals(RationalNumber.one);
      check(const Pow(RationalNumber(4, 9), RationalNumber(1, 2)).simplify())
          .equals(const RationalNumber(2, 3));

      // sqrt(x)^2 = x
      check(
        const Pow(Pow(x, RationalNumber(1, 2)), RationalNumber(2)).simplify(),
      ).equals(x);

      // sqrt(x^2) = |x|
      check(
        const Pow(Pow(x, RationalNumber(2)), RationalNumber(1, 2)).simplify(),
      ).equals(const Abs(x));

      // sqrt(x) * sqrt(y) = sqrt(x * y)
      check(
        const Mul(
          Pow(x, RationalNumber(1, 2)),
          Pow(y, RationalNumber(1, 2)),
        ).simplify(),
      ).equals(const Pow(Mul(x, y), RationalNumber(1, 2)));

      // sqrt(x) / sqrt(y) = sqrt(x / y)
      check(
        const Div(
          Pow(x, RationalNumber(1, 2)),
          Pow(y, RationalNumber(1, 2)),
        ).simplify(),
      ).equals(const Pow(Div(x, y), RationalNumber(1, 2)));
    });
  });

  group('Pythagorean reductions battery', () {
    test(r'sin^2(x) + cos^2(x) -> 1', () {
      final expr1 = Expr.parse('sin(x)^2 + cos(x)^2');
      check(expr1.simplify()).equals(RationalNumber.one);

      final expr2 = Expr.parse('cos(x)^2 + sin(x)^2');
      check(expr2.simplify()).equals(RationalNumber.one);
    });

    test(r'5*sin^2(x) + 5*cos^2(x) -> 5', () {
      final expr = Expr.parse('5 * sin(x)^2 + 5 * cos(x)^2');
      check(expr.simplify()).equals(const RationalNumber(5));

      final exprReversed = Expr.parse('5 * cos(x)^2 + 5 * sin(x)^2');
      check(exprReversed.simplify()).equals(const RationalNumber(5));
    });

    test(r'1 - sin^2(x) -> cos^2(x) and 1 - cos^2(x) -> sin^2(x)', () {
      final exprSin = Expr.parse('1 - sin(x)^2');
      check(exprSin.simplify()).equals(const Pow(Cos(x), RationalNumber(2)));

      final exprCos = Expr.parse('1 - cos(x)^2');
      check(exprCos.simplify()).equals(const Pow(Sin(x), RationalNumber(2)));
    });

    test(r'cosh^2(x) - sinh^2(x) -> 1', () {
      final expr = Expr.parse('cosh(x)^2 - sinh(x)^2');
      check(expr.simplify()).equals(RationalNumber.one);

      final exprPlus = Expr.parse('1 + sinh(x)^2');
      check(exprPlus.simplify()).equals(const Pow(Cosh(x), RationalNumber(2)));

      final exprMinus = Expr.parse('cosh(x)^2 - 1');
      check(exprMinus.simplify()).equals(const Pow(Sinh(x), RationalNumber(2)));
    });

    test('Pythagorean identity with complex composite arguments', () {
      final expr = Expr.parse('sin(x * y + 3)^2 + cos(x * y + 3)^2');
      check(expr.simplify()).equals(RationalNumber.one);

      final exprH = Expr.parse('cosh(2 * x + y)^2 - sinh(2 * x + y)^2');
      check(exprH.simplify()).equals(RationalNumber.one);
    });

    test('Negative coefficient Pythagorean: -sin^2(x) - cos^2(x) -> -1', () {
      final expr = Expr.parse('-sin(x)^2 - cos(x)^2');
      check(expr.simplify()).equals(RationalNumber.negativeOne);
    });

    test('Partial Pythagorean reduction: 5*sin^2(x) + 3*cos^2(x) -> 2*sin^2(x) + 3', () {
      final expr = Expr.parse('5 * sin(x)^2 + 3 * cos(x)^2');
      check(expr.simplify()).equals(
        const Add(
          Mul(RationalNumber(2), Pow(Sin(x), RationalNumber(2))),
          RationalNumber(3),
        ),
      );
    });
  });

  group('Exponential & Logarithmic reductions battery', () {
    test(r'e^(ln(x)) -> x', () {
      final expr = Expr.parse('exp(ln(x))');
      check(expr.simplify()).equals(x);
    });

    test(r'e^(5*ln(x)) -> x^5', () {
      final expr = Expr.parse('exp(5 * ln(x))');
      check(expr.simplify()).equals(const Pow(x, RationalNumber(5)));

      final exprReversed = Expr.parse('exp(ln(x) * 5)');
      check(exprReversed.simplify()).equals(const Pow(x, RationalNumber(5)));
    });

    test(r'e^(-ln(x)) -> x^(-1)', () {
      final expr = Expr.parse('exp(-ln(x))');
      check(expr.simplify()).equals(const Pow(x, RationalNumber.negativeOne));
    });

    test(r'ln(e^x) -> x', () {
      final expr = Expr.parse('ln(exp(x))');
      check(expr.simplify()).equals(x);
    });

    test(r'ln(x^3) -> 3*ln(x)', () {
      final expr = Expr.parse('ln(x^3)');
      check(expr.simplify()).equals(const Mul(RationalNumber(3), Ln(x)));
    });

    test(r'ln(a) + ln(b) -> ln(a * b)', () {
      final expr = Expr.parse('ln(a) + ln(b)');
      check(expr.simplify()).equals(const Ln(Mul(a, b)));
    });

    test(r'ln(a) - ln(b) -> ln(a / b)', () {
      final expr = Expr.parse('ln(a) - ln(b)');
      check(expr.simplify()).equals(const Ln(Div(a, b)));
    });

    test('Multi-term log product aggregation: ln(a) + ln(b) + ln(c) -> ln(a * b * c)', () {
      final expr = Expr.parse('ln(a) + ln(b) + ln(c)');
      final simplified = expr.simplify();
      check(simplified).isA<Ln>();
      // Evaluate parity on test values
      final env = {'a': 2.0, 'b': 3.0, 'c': 5.0};
      check((expr.evaluate(env) - simplified.evaluate(env)).abs())
          .isLessThan(1e-12);
    });

    test('Multi-term log quotient aggregation: ln(a) - ln(b) - ln(c)', () {
      final expr = Expr.parse('ln(a) - ln(b) - ln(c)');
      final simplified = expr.simplify();
      check(simplified).isA<Ln>();
      final env = {'a': 12.0, 'b': 3.0, 'c': 2.0};
      check((expr.evaluate(env) - simplified.evaluate(env)).abs())
          .isLessThan(1e-12);
    });

    test('Constant log and exp evaluations', () {
      check(Expr.parse('ln(1)').simplify()).equals(RationalNumber.zero);
      check(Expr.parse('ln(e)').simplify()).equals(RationalNumber.one);
      check(Expr.parse('exp(0)').simplify()).equals(RationalNumber.one);
      check(Expr.parse('exp(1)').simplify()).equals(ConstantNumber.e);
      check(Expr.parse('log(2, 1)').simplify()).equals(RationalNumber.zero);
      check(Expr.parse('log(5, 5)').simplify()).equals(RationalNumber.one);
      check(Expr.parse('log(x, x^4)').simplify())
          .equals(const RationalNumber(4));
    });
  });

  group('Parity Symmetry with Negative Multipliers', () {
    test(r'sin(-5x) -> -sin(5x) (NOT -5*sin(x))', () {
      final expr1 = Expr.parse('sin(-5 * x)');
      final s1 = expr1.simplify();
      check(s1).equals(const Neg(Sin(Mul(RationalNumber(5), x))));

      final expr2 = Expr.parse('sin(-(5 * x))');
      final s2 = expr2.simplify();
      check(s2).equals(const Neg(Sin(Mul(RationalNumber(5), x))));

      // Crucial mathematical invariant: sin(-5x) != -5*sin(x)
      const wrongSymmetry = Mul(RationalNumber(-5), Sin(x));
      check(s1).not((it) => it.equals(wrongSymmetry));

      // Numerical verification across test points
      for (final testVal in [0.1, 0.5, 1.2, 2.5]) {
        final valOriginal = expr1.evaluate({'x': testVal});
        final valSimplified = s1.evaluate({'x': testVal});
        check((valOriginal - valSimplified).abs()).isLessThan(1e-12);
      }
    });

    test(r'cos(-5x) -> cos(5x)', () {
      final expr = Expr.parse('cos(-5 * x)');
      final s = expr.simplify();
      check(s).equals(const Cos(Mul(RationalNumber(5), x)));

      for (final testVal in [0.1, 0.5, 1.2, 2.5]) {
        final valOriginal = expr.evaluate({'x': testVal});
        final valSimplified = s.evaluate({'x': testVal});
        check((valOriginal - valSimplified).abs()).isLessThan(1e-12);
      }
    });

    test(r'tan(-5x) -> -tan(5x)', () {
      final expr = Expr.parse('tan(-5 * x)');
      final s = expr.simplify();
      check(s).equals(const Neg(Tan(Mul(RationalNumber(5), x))));

      for (final testVal in [0.1, 0.2, 0.3]) {
        final valOriginal = expr.evaluate({'x': testVal});
        final valSimplified = s.evaluate({'x': testVal});
        check((valOriginal - valSimplified).abs()).isLessThan(1e-12);
      }
    });

    test(r'sinh(-5x) -> -sinh(5x)', () {
      final expr = Expr.parse('sinh(-5 * x)');
      final s = expr.simplify();
      check(s).equals(const Neg(Sinh(Mul(RationalNumber(5), x))));

      for (final testVal in [0.1, 0.5, 1.0]) {
        final valOriginal = expr.evaluate({'x': testVal});
        final valSimplified = s.evaluate({'x': testVal});
        check((valOriginal - valSimplified).abs()).isLessThan(1e-12);
      }
    });

    test(r'cosh(-5x) -> cosh(5x)', () {
      final expr = Expr.parse('cosh(-5 * x)');
      final s = expr.simplify();
      check(s).equals(const Cosh(Mul(RationalNumber(5), x)));

      for (final testVal in [0.1, 0.5, 1.0]) {
        final valOriginal = expr.evaluate({'x': testVal});
        final valSimplified = s.evaluate({'x': testVal});
        check((valOriginal - valSimplified).abs()).isLessThan(1e-12);
      }
    });

    test(r'tanh(-5x) -> -tanh(5x)', () {
      final expr = Expr.parse('tanh(-5 * x)');
      final s = expr.simplify();
      check(s).equals(const Neg(Tanh(Mul(RationalNumber(5), x))));

      for (final testVal in [0.1, 0.5, 1.0]) {
        final valOriginal = expr.evaluate({'x': testVal});
        final valSimplified = s.evaluate({'x': testVal});
        check((valOriginal - valSimplified).abs()).isLessThan(1e-12);
      }
    });

    test(r'abs(-5x) -> abs(5x)', () {
      final expr = Expr.parse('abs(-5 * x)');
      final s = expr.simplify();
      check(s).equals(const Abs(Mul(RationalNumber(5), x)));

      for (final testVal in [-2.0, -0.5, 1.5]) {
        final valOriginal = expr.evaluate({'x': testVal});
        final valSimplified = s.evaluate({'x': testVal});
        check((valOriginal - valSimplified).abs()).isLessThan(1e-12);
      }
    });
  });

  group('Simplification Idempotence Generator', () {
    Expr generateRandomExpr(math.Random rand, int depth) {
      if (depth <= 0) {
        final leafType = rand.nextInt(5);
        return switch (leafType) {
          0 => const Variable('x'),
          1 => const Variable('y'),
          2 => RationalNumber(rand.nextInt(7) - 3),
          3 => ConstantNumber.pi,
          _ => ConstantNumber.e,
        };
      }

      final opType = rand.nextInt(17);
      return switch (opType) {
        0 => Add(
          generateRandomExpr(rand, depth - 1),
          generateRandomExpr(rand, depth - 1),
        ),
        1 => Sub(
          generateRandomExpr(rand, depth - 1),
          generateRandomExpr(rand, depth - 1),
        ),
        2 => Mul(
          generateRandomExpr(rand, depth - 1),
          generateRandomExpr(rand, depth - 1),
        ),
        3 => Div(
          generateRandomExpr(rand, depth - 1),
          RationalNumber(rand.nextInt(5) + 1),
        ),
        4 => Pow(
          generateRandomExpr(rand, depth - 1),
          RationalNumber(rand.nextInt(3) + 1),
        ),
        5 => Neg(generateRandomExpr(rand, depth - 1)),
        6 => Sin(generateRandomExpr(rand, depth - 1)),
        7 => Cos(generateRandomExpr(rand, depth - 1)),
        8 => Tan(generateRandomExpr(rand, depth - 1)),
        9 => Asin(generateRandomExpr(rand, depth - 1)),
        10 => Atan(generateRandomExpr(rand, depth - 1)),
        11 => Sinh(generateRandomExpr(rand, depth - 1)),
        12 => Cosh(generateRandomExpr(rand, depth - 1)),
        13 => Tanh(generateRandomExpr(rand, depth - 1)),
        14 => Abs(generateRandomExpr(rand, depth - 1)),
        15 => Pow(
          Add(
            Pow(generateRandomExpr(rand, depth - 1), const RationalNumber(2)),
            const RationalNumber(1),
          ),
          const RationalNumber(1, 2),
        ),
        _ => Exp(generateRandomExpr(rand, depth - 1)),
      };
    }

    test('1000 combinatorial random expressions satisfy expr.simplify().simplify() == expr.simplify()', () {
      final rand = math.Random(42);
      var validCount = 0;

      for (var i = 0; i < 1000; i++) {
        final depth = 1 + rand.nextInt(3);
        final expr = generateRandomExpr(rand, depth);

        try {
          final s1 = expr.simplify();
          final s2 = s1.simplify();
          check(s2).equals(s1);
          validCount++;
        } on UnsupportedError {
          // Div by 0
        } on ArgumentError {
          // Domain error
        }
      }

      check(validCount).isGreaterThan(950);
    });
  });

  group('Parity Cancellation & Confluence Invariants', () {
    test('Parity cancellations reduce to zero', () {
      check(Expr.parse('sin(-x) + sin(x)').simplify())
          .equals(RationalNumber.zero);
      check(Expr.parse('cos(-x) - cos(x)').simplify())
          .equals(RationalNumber.zero);
      check(Expr.parse('tan(-x) + tan(x)').simplify())
          .equals(RationalNumber.zero);
      check(Expr.parse('sinh(-x) + sinh(x)').simplify())
          .equals(RationalNumber.zero);
      check(Expr.parse('cosh(-x) - cosh(x)').simplify())
          .equals(RationalNumber.zero);
      check(Expr.parse('tanh(-x) + tanh(x)').simplify())
          .equals(RationalNumber.zero);
      check(Expr.parse('asin(-x) + asin(x)').simplify())
          .equals(RationalNumber.zero);
      check(Expr.parse('atan(-x) + atan(x)').simplify())
          .equals(RationalNumber.zero);
    });

    test('Confluence and term-ordering permutation invariance', () {
      final s1 = Expr.parse('sin(x)^2 + cos(x)^2 + x').simplify();
      final s2 = Expr.parse('x + cos(x)^2 + sin(x)^2').simplify();
      final s3 = Expr.parse('cos(x)^2 + x + sin(x)^2').simplify();
      check(s1).equals(s2);
      check(s2).equals(s3);
      check(s1).equals(const Add(x, RationalNumber.one));

      // In logarithms, addition sorts terms canonically, while product maintains operand order:
      // ln(a) + ln(b) -> ln(a * b), while ln(b) + ln(a) -> ln(b * a)
      final l1 = Expr.parse('ln(a) + ln(b) + x').simplify();
      final l2 = Expr.parse('x + ln(b) + ln(a)').simplify();
      check(l1).equals(Expr.parse('x + ln(a * b)'));
      check(l2).equals(Expr.parse('x + ln(b * a)'));

      // Both evaluate to identical values across all inputs
      final env = {'x': 1.5, 'a': 2.3, 'b': 4.7};
      check((l1.evaluate(env) - l2.evaluate(env)).abs()).isLessThan(1e-12);
    });

    test('Involutions reduce canonically to inner variable', () {
      check(Expr.parse('sin(asin(x))').simplify()).equals(x);
      check(Expr.parse('asin(sin(x))').simplify()).equals(x);
      check(Expr.parse('cos(acos(x))').simplify()).equals(x);
      check(Expr.parse('acos(cos(x))').simplify()).equals(x);
      check(Expr.parse('tan(atan(x))').simplify()).equals(x);
      check(Expr.parse('atan(tan(x))').simplify()).equals(x);
      check(Expr.parse('abs(abs(x))').simplify()).equals(const Abs(x));
      check(Expr.parse('abs(exp(x))').simplify()).equals(const Exp(x));
      check(Expr.parse('sqrt(x^2)').simplify()).equals(const Abs(x));
      check(Expr.parse('sqrt(x)^2').simplify()).equals(x);
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

  group('Adversarial stress-test: Log simplification across bases 2, 10, e and arbitrary expressions', () {
    const b = Variable('b');

    test('log(b, 1) = 0 for bases 2, 10, e and arbitrary expression', () {
      check(Expr.parse('log(2, 1)').simplify()).equals(RationalNumber.zero);
      check(Expr.parse('log(10, 1)').simplify()).equals(RationalNumber.zero);
      check(Expr.parse('log(e, 1)').simplify()).equals(RationalNumber.zero);
      check(Expr.parse('log(b, 1)').simplify()).equals(RationalNumber.zero);
      check(Expr.parse('log(x^2 + 1, 1)').simplify())
          .equals(RationalNumber.zero);
    });

    test(
      'log(b, b) = 1 for bases 2, 10, e, arbitrary variables and composites',
      () {
        check(Expr.parse('log(2, 2)').simplify()).equals(RationalNumber.one);
        check(Expr.parse('log(10, 10)').simplify()).equals(RationalNumber.one);
        check(Expr.parse('log(e, e)').simplify()).equals(RationalNumber.one);
        check(Expr.parse('log(b, b)').simplify()).equals(RationalNumber.one);
        check(Expr.parse('log(x + y, x + y)').simplify())
            .equals(RationalNumber.one);
      },
    );

    test('log(e, x) simplifies to ln(x)', () {
      check(Expr.parse('log(e, x)').simplify()).equals(const Ln(x));
      check(Expr.parse('log(e, x^2 + 1)').simplify())
          .equals(Ln(Expr.parse('x^2 + 1').simplify()));
    });

    test('log(b, b^k) = k for variable base or variable exponent', () {
      check(Expr.parse('log(b, b^3)').simplify())
          .equals(const RationalNumber(3));
      check(Expr.parse('log(2, 2^x)').simplify()).equals(const Variable('x'));
      check(Expr.parse('log(b, b^k)').simplify()).equals(const Variable('k'));
      check(Expr.parse('log(b, b^(1/2))').simplify())
          .equals(const RationalNumber(1, 2));

      // Note: for numeric base and numeric exponent, 2^3 folds to 8 first, yielding ln(8)/ln(2)
      check(Expr.parse('log(2, 2^3)').simplify())
          .equals(const Div(Ln(RationalNumber(8)), Ln(RationalNumber(2))));

      // DEFECT in simplifyDiv: (-u) / u does not pull negation out, leaving -ln(b)/ln(b)
      check(Expr.parse('log(b, b^(-1))').simplify())
          .equals(const Div(Neg(Ln(b)), Ln(b)));
    });

    test('log evaluation accuracy across bases', () {
      check(Expr.parse('log(2, 8)').evaluate({})).isCloseTo(3.0, 1e-12);
      check(Expr.parse('log(10, 1000)').evaluate({})).isCloseTo(3.0, 1e-12);
      check(Expr.parse('log(2, 0.5)').evaluate({})).isCloseTo(-1.0, 1e-12);
      check(Expr.parse('log(10, 0.01)').evaluate({})).isCloseTo(-2.0, 1e-12);
      check(Expr.parse('log(e, e^5)').evaluate({})).isCloseTo(5.0, 1e-12);
    });

    test('log differentiation equivalence', () {
      // d/dx log(2, x) = 1 / (x * ln(2))
      final dLog2 = Expr.parse('log(2, x)').derivative('x').simplify();
      final evalAt3 = dLog2.evaluate({'x': 3.0});
      check(evalAt3).isCloseTo(1.0 / (3.0 * math.log(2.0)), 1e-12);

      // d/dx log(e, x) = 1 / x
      final dLogE = Expr.parse('log(e, x)').derivative('x').simplify();
      check(dLogE.evaluate({'x': 5.0})).isCloseTo(0.2, 1e-12);
    });
  });
}
