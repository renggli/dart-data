import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/test.dart';

void main() {
  group('Symbolic Calculus: Polynomials & Powers', () {
    test('constants: zero, non-zero, and independent variables', () {
      const y = Variable('y');

      // Constant zero integrates to zero
      final zero = const RationalNumber(0).integrate('x');
      check(zero).equals(const RationalNumber(0));

      // Constant scalar
      final c5 = const RationalNumber(5).integrate('x');
      check(c5.evaluate({'x': 2.0})).equals(10.0);
      check(c5.evaluate({'x': 0.0})).equals(0.0);

      // Independent variable y integrates to y * x
      final intY = y.integrate('x');
      check(intY.freeVariables).unorderedEquals({'x', 'y'});
      check(intY.evaluate({'x': 3.0, 'y': 4.0})).equals(12.0);

      // Verify integrate extension invocation matches
      check(const RationalNumber(5).integrate('x')).equals(c5);
    });

    test('linear variable: x -> x^2 / 2', () {
      const x = Variable('x');
      final anti = x.integrate('x');

      check(anti.evaluate({'x': 4.0})).equals(8.0);
      check(anti.evaluate({'x': 0.0})).equals(0.0);
      check(anti.diff('x').compile1D('x')(3.0)).isCloseTo(3.0, 1e-9);
    });

    test('powers: x^2 and negative powers x^-2', () {
      const x = Variable('x');

      // x^2 -> x^3 / 3
      final x2 = x.pow(2);
      final anti2 = x2.integrate('x');
      check(anti2.evaluate({'x': 3.0})).equals(9.0);
      check(anti2.diff('x').compile1D('x')(2.5)).isCloseTo(6.25, 1e-9);

      // x^-2 -> -x^-1
      final xNeg2 = x.pow(-2);
      final antiNeg2 = xNeg2.integrate('x');
      check(antiNeg2.evaluate({'x': 2.0})).isCloseTo(-0.5, 1e-9);
      check(antiNeg2.diff('x').compile1D('x')(2.0)).isCloseTo(0.25, 1e-9);
    });

    test('symbolic power: x^n', () {
      const x = Variable('x');
      const n = Variable('n');
      final xN = x.pow(n);
      final anti = xN.integrate('x');

      check(anti.freeVariables).unorderedEquals({'x', 'n'});
      // For n = 3, integral of x^3 is x^4 / 4 -> at x = 2: 16 / 4 = 4.0
      check(anti.evaluate({'x': 2.0, 'n': 3.0})).equals(4.0);
    });

    test('polynomial linear combination: 3x^2 + 2x + 1', () {
      const x = Variable('x');
      final poly = (x.pow(2) * 3) + (x * 2) + 1;
      final anti = poly.integrate('x');

      // Integral is x^3 + x^2 + x
      check(anti.evaluate({'x': 0.0})).equals(0.0);
      check(anti.evaluate({'x': 1.0})).equals(3.0);
      check(anti.evaluate({'x': 2.0})).equals(14.0);
      check(anti.diff('x').compile1D('x')(3.0))
          .isCloseTo(3.0 * 9.0 + 2.0 * 3.0 + 1.0, 1e-9);
    });
  });

  group('Symbolic Calculus: Logarithms & Reciprocal Powers', () {
    test('reciprocals: x^-1 and 1 / x', () {
      const x = Variable('x');

      // x^-1 -> ln(x)
      final xInv = x.pow(-1);
      final antiInv = xInv.integrate('x');
      check(antiInv).equals(const Ln(x));
      check(antiInv.evaluate({'x': math.e})).isCloseTo(1.0, 1e-9);

      // 1 / x -> ln(x)
      final divX = const RationalNumber(1) / x;
      final antiDiv = divX.integrate('x');
      check(antiDiv).equals(const Ln(x));
      check(antiDiv.evaluate({'x': math.e})).isCloseTo(1.0, 1e-9);
    });

    test('linear rational denominator: 1 / (2x + 3)', () {
      const x = Variable('x');
      final expr = const RationalNumber(1) / ((x * 2) + 3);
      final anti = expr.integrate('x');

      // (ln(2x + 3)) / 2
      final expectedAt0 = math.log(3.0) / 2.0;
      check(anti.evaluate({'x': 0.0})).isCloseTo(expectedAt0, 1e-9);
      check(anti.diff('x').compile1D('x')(1.0)).isCloseTo(1.0 / 5.0, 1e-9);
    });

    test('reciprocal powers in denominator: 1 / x^2 and c / (ax + b)^n', () {
      const x = Variable('x');

      // 1 / x^2 -> -1 / x
      final expr1 = const RationalNumber(1) / x.pow(2);
      final anti1 = expr1.integrate('x');
      check(anti1.evaluate({'x': 2.0})).isCloseTo(-0.5, 1e-9);
      check(anti1.diff('x').compile1D('x')(2.0)).isCloseTo(0.25, 1e-9);

      // 5 / (2x + 3)^2 -> -5 / (2 * (2x + 3))
      final expr2 = const RationalNumber(5) / ((x * 2) + 3).pow(2);
      final anti2 = expr2.integrate('x');
      check(anti2.evaluate({'x': 1.0})).isCloseTo(-0.5, 1e-9);
      check(anti2.diff('x').compile1D('x')(1.0)).isCloseTo(5.0 / 25.0, 1e-9);
    });

    test('logarithm: ln(x)', () {
      const x = Variable('x');
      const expr = Ln(x);
      final anti = expr.integrate('x');

      // x * ln(x) - x
      check(anti.evaluate({'x': 1.0})).isCloseTo(-1.0, 1e-9);
      check(anti.evaluate({'x': math.e})).isCloseTo(0.0, 1e-9);
      check(anti.diff('x').compile1D('x')(2.0)).isCloseTo(math.log(2.0), 1e-9);
    });

    test('linear logarithm: ln(3x + 1)', () {
      const x = Variable('x');
      final expr = Ln((x * 3) + 1);
      final anti = expr.integrate('x');

      // ((3x + 1)*ln(3x + 1) - (3x + 1)) / 3
      check(anti.evaluate({'x': 0.0})).isCloseTo(-1.0 / 3.0, 1e-9);
      check(anti.diff('x').compile1D('x')(1.0)).isCloseTo(math.log(4.0), 1e-9);
    });
  });

  group('Symbolic Calculus: Exponentials', () {
    test('natural exponential: exp(x)', () {
      const x = Variable('x');
      const expr = Exp(x);
      final anti = expr.integrate('x');

      check(anti).equals(expr);
      check(anti.evaluate({'x': 2.0})).isCloseTo(math.exp(2.0), 1e-9);
    });

    test('scaled exponent: exp(2x)', () {
      const x = Variable('x');
      final expr = Exp(x * 2);
      final anti = expr.integrate('x');

      check(anti.evaluate({'x': 0.0})).isCloseTo(0.5, 1e-9);
      check(anti.diff('x').compile1D('x')(1.0))
          .isCloseTo(math.exp(2.0) * 2.0 / 2.0, 1e-9);
    });

    test('arbitrary constant base: 2^x', () {
      const x = Variable('x');
      final expr = const RationalNumber(2).pow(x);
      final anti = expr.integrate('x');

      // 2^x / ln(2)
      final expectedAt3 = math.pow(2.0, 3.0) / math.log(2.0);
      check(anti.evaluate({'x': 3.0})).isCloseTo(expectedAt3, 1e-9);
      check(anti.diff('x').compile1D('x')(2.0)).isCloseTo(4.0, 1e-9);
    });

    test('linear exponential: exp(3x + 4)', () {
      const x = Variable('x');
      final expr = Exp((x * 3) + 4);
      final anti = expr.integrate('x');

      // exp(3x + 4) / 3
      check(anti.evaluate({'x': -1.0})).isCloseTo(math.exp(1.0) / 3.0, 1e-9);
      check(anti.diff('x').compile1D('x')(0.0)).isCloseTo(math.exp(4.0), 1e-9);
    });

    test('symbolic base exponential: b^x', () {
      const x = Variable('x');
      const b = Variable('b');
      final expr = b.pow(x);
      final anti = expr.integrate('x');

      // b^x / ln(b)
      check(anti.freeVariables).unorderedEquals({'x', 'b'});
      check(anti.evaluate({'x': 3.0, 'b': 2.0}))
          .isCloseTo(8.0 / math.log(2.0), 1e-9);
    });
  });

  group('Symbolic Calculus: Trigonometrics', () {
    test('sine: sin(x) and sin(-x)', () {
      const x = Variable('x');
      const expr = Sin(x);
      final anti = expr.integrate('x');

      check(anti).equals(const Neg(Cos(x)));
      check(anti.evaluate({'x': 0.0})).isCloseTo(-1.0, 1e-9);
      check(anti.evaluate({'x': math.pi})).isCloseTo(1.0, 1e-9);

      // sin(-x) -> cos(-x)
      const exprNeg = Sin(Neg(x));
      final antiNeg = exprNeg.integrate('x');
      check(antiNeg.evaluate({'x': 0.0})).isCloseTo(1.0, 1e-9);
      check(antiNeg.diff('x').compile1D('x')(1.0))
          .isCloseTo(math.sin(-1.0), 1e-9);
    });

    test('cosine: cos(x) and cos(-x)', () {
      const x = Variable('x');
      const expr = Cos(x);
      final anti = expr.integrate('x');

      check(anti).equals(const Sin(x));
      check(anti.evaluate({'x': 0.0})).isCloseTo(0.0, 1e-9);
      check(anti.evaluate({'x': math.pi / 2.0})).isCloseTo(1.0, 1e-9);

      // cos(-x) -> -sin(-x)
      const exprNeg = Cos(Neg(x));
      final antiNeg = exprNeg.integrate('x');
      check(antiNeg.diff('x').compile1D('x')(1.0))
          .isCloseTo(math.cos(-1.0), 1e-9);
    });

    test('scaled sine: sin(3x)', () {
      const x = Variable('x');
      final expr = Sin(x * 3);
      final anti = expr.integrate('x');

      // -cos(3x) / 3
      check(anti.evaluate({'x': 0.0})).isCloseTo(-1.0 / 3.0, 1e-9);
      check(anti.diff('x').compile1D('x')(1.0)).isCloseTo(math.sin(3.0), 1e-9);
    });

    test('linear cosine: cos(2x - 1)', () {
      const x = Variable('x');
      final expr = Cos((x * 2) - 1);
      final anti = expr.integrate('x');

      // sin(2x - 1) / 2
      check(anti.evaluate({'x': 0.5})).isCloseTo(0.0, 1e-9);
      check(anti.diff('x').compile1D('x')(1.0)).isCloseTo(math.cos(1.0), 1e-9);
    });
  });

  group('Symbolic Calculus: Products, Substitutions, and Parts', () {
    test('integration by parts: x * exp(x)', () {
      const x = Variable('x');
      final expr = x * const Exp(x);
      final anti = expr.integrate('x');

      // (x - 1) * exp(x)
      check(anti.evaluate({'x': 1.0})).isCloseTo(0.0, 1e-9);
      check(anti.evaluate({'x': 2.0})).isCloseTo(math.exp(2.0), 1e-9);
      check(anti.diff('x').compile1D('x')(2.0))
          .isCloseTo(2.0 * math.exp(2.0), 1e-9);
    });

    test('integration by parts: x * sin(x)', () {
      const x = Variable('x');
      final expr = x * const Sin(x);
      final anti = expr.integrate('x');

      // -x * cos(x) + sin(x)
      check(anti.evaluate({'x': math.pi})).isCloseTo(math.pi, 1e-9);
      check(anti.evaluate({'x': math.pi / 2.0})).isCloseTo(1.0, 1e-9);
      check(anti.diff('x').compile1D('x')(1.5))
          .isCloseTo(1.5 * math.sin(1.5), 1e-9);
    });

    test('integration by parts: x * cos(x)', () {
      const x = Variable('x');
      final expr = x * const Cos(x);
      final anti = expr.integrate('x');

      // x * sin(x) + cos(x)
      check(anti.evaluate({'x': 0.0})).isCloseTo(1.0, 1e-9);
      check(anti.evaluate({'x': math.pi / 2.0})).isCloseTo(math.pi / 2.0, 1e-9);
      check(anti.diff('x').compile1D('x')(1.5))
          .isCloseTo(1.5 * math.cos(1.5), 1e-9);
    });

    test('integration by parts: x * ln(x)', () {
      const x = Variable('x');
      final expr = x * const Ln(x);
      final anti = expr.integrate('x');

      // (x^2 / 2) * ln(x) - (x^2 / 4)
      check(anti.evaluate({'x': 1.0})).isCloseTo(-0.25, 1e-9);
      check(anti.evaluate({'x': 2.0}))
          .isCloseTo(2.0 * math.log(2.0) - 1.0, 1e-9);
      check(anti.diff('x').compile1D('x')(3.0))
          .isCloseTo(3.0 * math.log(3.0), 1e-9);

      // (2x) * ln(x) -> x^2 * ln(x) - x^2 / 2
      final expr2 = (x * 2) * const Ln(x);
      final anti2 = expr2.integrate('x');
      check(anti2.diff('x').compile1D('x')(2.5))
          .isCloseTo(5.0 * math.log(2.5), 1e-9);

      // (x + 1) * ln(x)
      final expr3 = (x + 1) * const Ln(x);
      final anti3 = expr3.integrate('x');
      check(anti3.diff('x').compile1D('x')(2.0))
          .isCloseTo(3.0 * math.log(2.0), 1e-9);
    });

    test(
      'chain-rule substitution with compound u(x): (2x + 1) * cos(x^2 + x)',
      () {
        const x = Variable('x');
        final expr = ((x * 2) + 1) * Cos(x.pow(2) + x);
        final anti = expr.integrate('x');

        // sin(x^2 + x)
        check(anti.evaluate({'x': 0.0})).isCloseTo(0.0, 1e-9);
        check(anti.diff('x').compile1D('x')(1.0))
            .isCloseTo(3.0 * math.cos(2.0), 1e-9);
      },
    );

    test('chain-rule substitution: 2x * cos(x^2)', () {
      const x = Variable('x');
      final expr = (x * 2) * Cos(x.pow(2));
      final anti = expr.integrate('x');

      // sin(x^2)
      check(anti.evaluate({'x': 0.0})).isCloseTo(0.0, 1e-9);
      check(anti.evaluate({'x': math.sqrt(math.pi / 2.0)}))
          .isCloseTo(1.0, 1e-9);
      check(anti.diff('x').compile1D('x')(1.2))
          .isCloseTo(2.4 * math.cos(1.44), 1e-9);
    });

    test('chain-rule substitution: x * exp(x^2) and (x / 2) * exp(x^2)', () {
      const x = Variable('x');
      final expr = x * Exp(x.pow(2));
      final anti = expr.integrate('x');

      // (1 / 2) * exp(x^2)
      check(anti.evaluate({'x': 0.0})).isCloseTo(0.5, 1e-9);
      check(anti.evaluate({'x': 1.0})).isCloseTo(0.5 * math.e, 1e-9);
      check(anti.diff('x').compile1D('x')(1.5))
          .isCloseTo(1.5 * math.exp(2.25), 1e-9);

      // (x / 2) * exp(x^2) -> 0.25 * exp(x^2)
      final exprDiv = (x / 2) * Exp(x.pow(2));
      final antiDiv = exprDiv.integrate('x');
      check(antiDiv.diff('x').compile1D('x')(1.5))
          .isCloseTo(0.75 * math.exp(2.25), 1e-9);
    });

    test('chain-rule substitution on rational powers: 2x / (x^2 + 1)^2', () {
      const x = Variable('x');
      final expr = (x * 2) / (x.pow(2) + 1).pow(2);
      final anti = expr.integrate('x');

      // - (x^2 + 1)^-1
      check(anti.evaluate({'x': 1.0})).isCloseTo(-0.5, 1e-9);
      check(anti.diff('x').compile1D('x')(2.0)).isCloseTo(4.0 / 25.0, 1e-9);
    });

    test('integration by parts: x * 2^x', () {
      const x = Variable('x');
      final expr = x * const RationalNumber(2).pow(x);
      final anti = expr.integrate('x');

      check(anti.diff('x').compile1D('x')(2.0)).isCloseTo(2.0 * 4.0, 1e-9);
    });

    test('identity multiplication and distributive expansion', () {
      const x = Variable('x');

      // Identity multiplication: x * x -> x^3 / 3
      final sq = (x * x).integrate('x');
      check(sq.evaluate({'x': 3.0})).equals(9.0);

      // Distributive expansion: (x + 1) * (x + 2)
      final prod = ((x + 1) * (x + 2)).integrate('x');
      // Integral of x^2 + 3x + 2 is x^3/3 + 1.5*x^2 + 2x
      check(prod.diff('x').compile1D('x')(2.0))
          .isCloseTo((2.0 + 1.0) * (2.0 + 2.0), 1e-9);
    });
  });

  group('Definite Integration: Analytical Evaluation', () {
    test(
      'definite integral of polynomial: int_0^2 (3x^2 + 2x + 1) dx = 14',
      () {
        const x = Variable('x');
        final poly = (x.pow(2) * 3) + (x * 2) + 1;
        final result = poly.integrate('x', from: 0, to: 2);

        check(result).equals(const RationalNumber(14));
      },
    );

    test('definite integral of sine: int_0^pi sin(x) dx = 2', () {
      const x = Variable('x');
      const expr = Sin(x);
      final result = expr.integrate('x', from: 0, to: math.pi);

      check(result).isA<Number>();
      check(result.evaluate(const {})).isCloseTo(2.0, 1e-9);
    });

    test('definite integral of 1 / x: int_1^e (1 / x) dx = 1', () {
      const x = Variable('x');
      final expr = const RationalNumber(1) / x;
      final result = expr.integrate('x', from: 1, to: math.e);

      check(result).isA<Number>();
      check(result.evaluate(const {})).isCloseTo(1.0, 1e-9);
    });

    test('definite integral with equal bounds returns zero', () {
      const x = Variable('x');
      final expr = (x.pow(3) * 5) + const Exp(x);
      final result = expr.integrate('x', from: 4.5, to: 4.5);

      check(result).equals(const RationalNumber(0));
    });

    test('definite integral with reversed bounds: int_2^0 (2x) dx = -4', () {
      const x = Variable('x');
      final expr = x * 2;
      final result = expr.integrate('x', from: 2, to: 0);

      check(result).equals(const RationalNumber(-4));
    });
  });

  group('Definite Integration: Multivariable Expressions', () {
    test('multivariable definite integral: int_0^1 (x + y) dx = y + 0.5', () {
      const x = Variable('x');
      const y = Variable('y');
      final expr = x + y;
      final result = expr.integrate('x', from: 0, to: 1);

      // Result should still depend on free variable y
      check(result.freeVariables).unorderedEquals({'y'});
      check(result.evaluate({'y': 3.0})).equals(3.5);
      check(result.evaluate({'y': 0.0})).equals(0.5);
      check(result.evaluate({'y': -0.5})).equals(0.0);
    });
  });

  group('Definite Integration: Numerical Quadrature Fallback', () {
    test(
      'Gaussian integral fallback: int_0^1 exp(-x^2) dx approx 0.7468241328',
      () {
        const x = Variable('x');
        final expr = Exp(-x.pow(2));
        final result = expr.integrate('x', from: 0, to: 1);

        check(result).isA<Number>();
        check(result.evaluate(const {})).isCloseTo(0.7468241328, 1e-6);
      },
    );

    test('Fresnel integral fallback: int_0^1 sin(x^2) dx', () {
      const x = Variable('x');
      final expr = Sin(x.pow(2));
      final result = expr.integrate('x', from: 0, to: 1);

      check(result).isA<Number>();
      check(result.evaluate(const {})).isCloseTo(0.3102683, 1e-5);
    });
  });

  group('Integration Error Handling & Edge Cases', () {
    test('asymmetric bounds throw ArgumentError', () {
      const x = Variable('x');

      check(() => x.integrate('x', from: 0)).throws<ArgumentError>();
      check(() => x.integrate('x', to: 1)).throws<ArgumentError>();
    });

    test('indefinite integration of non-elementary expressions throws UnsupportedError', () {
      const x = Variable('x');
      final nonElem1 = Exp(-x.pow(2));
      final nonElem2 = Sin(x.pow(2));

      check(() => nonElem1.integrate('x')).throws<UnsupportedError>();
      check(() => nonElem2.integrate('x')).throws<UnsupportedError>();
    });
  });

  group('LinearFormExtension', () {
    const x = Variable('x');
    const y = Variable('y');

    test('matchLinear decomposes affine expressions', () {
      // 3x + 5 -> a = 3, b = 5
      final expr = (const RationalNumber(3) * x) + const RationalNumber(5);
      final lin = expr.matchLinear('x');
      check(lin).isNotNull();
      check(lin!.a).equals(const RationalNumber(3));
      check(lin.b).equals(const RationalNumber(5));

      // -x -> a = -1, b = 0
      final negX = -x;
      final linNeg = negX.matchLinear('x');
      check(linNeg).isNotNull();
      check(linNeg!.a).equals(const RationalNumber(-1));
      check(linNeg.b).equals(const RationalNumber(0));

      // x / 2 -> a = 0.5, b = 0
      final halfX = x / const RationalNumber(2);
      final linDiv = halfX.matchLinear('x');
      check(linDiv).isNotNull();
      check(linDiv!.a.evaluate(const {})).equals(0.5);

      // independent or nonlinear returns null
      check(y.matchLinear('x')).isNull();
      check(x.pow(2).matchLinear('x')).isNull();
    });

    test('matchScalarMultiple checks scalar proportionality', () {
      final u = x.pow(2);
      final twoU = const RationalNumber(2) * x.pow(2);
      final k = twoU.matchScalarMultiple(u, 'x');
      check(k).isNotNull();
      check(k!.evaluate(const {})).equals(2.0);

      // Non-multiple returns null
      check(x.matchScalarMultiple(x.pow(2), 'x')).isNull();
    });

    test('scale scales expression with identity and constant folding', () {
      final expr = x + const RationalNumber(2);
      check(expr.scale(const RationalNumber(1))).equals(expr);
      check(expr.scale(const RationalNumber(0)))
          .equals(const RationalNumber(0));
      check(const RationalNumber(3).scale(const RationalNumber(2)))
          .equals(const RationalNumber(6));
    });
  });
}
