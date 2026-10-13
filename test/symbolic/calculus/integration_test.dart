import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/numeric.dart';
import 'package:data/symbolic.dart';
import 'package:test/scaffolding.dart';

void main() {
  const x = Variable('x');
  const y = Variable('y');

  group('Indefinite Integration: Polynomials & Powers', () {
    test('constants: zero, non-zero, and independent variables', () {
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
      final anti = x.integrate('x');
      check(anti.evaluate({'x': 4.0})).equals(8.0);
      check(anti.evaluate({'x': 0.0})).equals(0.0);
      check(anti.derivative('x').toFunction1D('x')(3.0)).isCloseTo(3.0, 1e-9);
    });

    test('powers: x^2 and negative powers x^-2', () {
      // x^2 -> x^3 / 3
      final x2 = x.pow(2);
      final anti2 = x2.integrate('x');
      check(anti2.evaluate({'x': 3.0})).equals(9.0);
      check(anti2.derivative('x').toFunction1D('x')(2.5)).isCloseTo(6.25, 1e-9);

      // x^-2 -> -x^-1
      final xNeg2 = x.pow(-2);
      final antiNeg2 = xNeg2.integrate('x');
      check(antiNeg2.evaluate({'x': 2.0})).isCloseTo(-0.5, 1e-9);
      check(antiNeg2.derivative('x').toFunction1D('x')(2.0))
          .isCloseTo(0.25, 1e-9);
    });

    test('symbolic power: x^n', () {
      const n = Variable('n');
      final xN = x.pow(n);
      final anti = xN.integrate('x');

      check(anti.freeVariables).unorderedEquals({'x', 'n'});
      check(anti.evaluate({'x': 2.0, 'n': 3.0})).equals(4.0);
    });

    test('polynomial linear combination: 3x^2 + 2x + 1', () {
      final poly = (x.pow(2) * 3) + (x * 2) + 1;
      final anti = poly.integrate('x');

      check(anti.evaluate({'x': 0.0})).equals(0.0);
      check(anti.evaluate({'x': 1.0})).equals(3.0);
      check(anti.evaluate({'x': 2.0})).equals(14.0);
      check(anti.derivative('x').toFunction1D('x')(3.0))
          .isCloseTo(3.0 * 9.0 + 2.0 * 3.0 + 1.0, 1e-9);
    });
  });

  group('Indefinite Integration: Logarithms & Reciprocal Powers', () {
    test('reciprocals: x^-1 and 1 / x', () {
      final xInv = x.pow(-1);
      final antiInv = xInv.integrate('x');
      check(antiInv).equals(const Ln(x));
      check(antiInv.evaluate({'x': math.e})).isCloseTo(1.0, 1e-9);

      final divX = const RationalNumber(1) / x;
      final antiDiv = divX.integrate('x');
      check(antiDiv).equals(const Ln(x));
      check(antiDiv.evaluate({'x': math.e})).isCloseTo(1.0, 1e-9);
    });

    test('linear rational denominator: 1 / (2x + 3)', () {
      final expr = const RationalNumber(1) / ((x * 2) + 3);
      final anti = expr.integrate('x');

      final expectedAt0 = math.log(3.0) / 2.0;
      check(anti.evaluate({'x': 0.0})).isCloseTo(expectedAt0, 1e-9);
      check(anti.derivative('x').toFunction1D('x')(1.0))
          .isCloseTo(1.0 / 5.0, 1e-9);
    });

    test('reciprocal powers in denominator: 1 / x^2 and c / (ax + b)^n', () {
      final expr1 = const RationalNumber(1) / x.pow(2);
      final anti1 = expr1.integrate('x');
      check(anti1.evaluate({'x': 2.0})).isCloseTo(-0.5, 1e-9);
      check(anti1.derivative('x').toFunction1D('x')(2.0)).isCloseTo(0.25, 1e-9);

      final expr2 = const RationalNumber(5) / ((x * 2) + 3).pow(2);
      final anti2 = expr2.integrate('x');
      check(anti2.evaluate({'x': 1.0})).isCloseTo(-0.5, 1e-9);
      check(anti2.derivative('x').toFunction1D('x')(1.0))
          .isCloseTo(5.0 / 25.0, 1e-9);
    });

    test('logarithm: ln(x) and ln(3x + 1)', () {
      const expr = Ln(x);
      final anti = expr.integrate('x');

      check(anti.evaluate({'x': 1.0})).isCloseTo(-1.0, 1e-9);
      check(anti.evaluate({'x': math.e})).isCloseTo(0.0, 1e-9);
      check(anti.derivative('x').toFunction1D('x')(2.0))
          .isCloseTo(math.log(2.0), 1e-9);

      final expr2 = Ln((x * 3) + 1);
      final anti2 = expr2.integrate('x');
      check(anti2.evaluate({'x': 0.0})).isCloseTo(-1.0 / 3.0, 1e-9);
      check(anti2.derivative('x').toFunction1D('x')(1.0))
          .isCloseTo(math.log(4.0), 1e-9);
    });
  });

  group('Indefinite Integration: Exponentials', () {
    test('natural and scaled exponential', () {
      const expr = Exp(x);
      final anti = expr.integrate('x');
      check(anti).equals(expr);
      check(anti.evaluate({'x': 2.0})).isCloseTo(math.exp(2.0), 1e-9);

      final expr2 = Exp(x * 2);
      final anti2 = expr2.integrate('x');
      check(anti2.evaluate({'x': 0.0})).isCloseTo(0.5, 1e-9);
      check(anti2.derivative('x').toFunction1D('x')(1.0))
          .isCloseTo(math.exp(2.0), 1e-9);
    });

    test('arbitrary constant and symbolic base: 2^x and b^x', () {
      final expr = const RationalNumber(2).pow(x);
      final anti = expr.integrate('x');

      final expectedAt3 = math.pow(2.0, 3.0) / math.log(2.0);
      check(anti.evaluate({'x': 3.0})).isCloseTo(expectedAt3, 1e-9);
      check(anti.derivative('x').toFunction1D('x')(2.0)).isCloseTo(4.0, 1e-9);

      const b = Variable('b');
      final exprB = b.pow(x);
      final antiB = exprB.integrate('x');
      check(antiB.freeVariables).unorderedEquals({'x', 'b'});
      check(antiB.evaluate({'x': 3.0, 'b': 2.0}))
          .isCloseTo(8.0 / math.log(2.0), 1e-9);
    });

    test('linear exponential: exp(3x + 4)', () {
      final expr = Exp((x * 3) + 4);
      final anti = expr.integrate('x');
      check(anti.evaluate({'x': -1.0})).isCloseTo(math.exp(1.0) / 3.0, 1e-9);
      check(anti.derivative('x').toFunction1D('x')(0.0))
          .isCloseTo(math.exp(4.0), 1e-9);
    });
  });

  group('Indefinite Integration: Trigonometrics and Hyperbolics', () {
    test('sine and cosine', () {
      const exprSin = Sin(x);
      final antiSin = exprSin.integrate('x');
      check(antiSin).equals(const Neg(Cos(x)));
      check(antiSin.evaluate({'x': 0.0})).isCloseTo(-1.0, 1e-9);
      check(antiSin.evaluate({'x': math.pi})).isCloseTo(1.0, 1e-9);

      const exprCos = Cos(x);
      final antiCos = exprCos.integrate('x');
      check(antiCos).equals(const Sin(x));
      check(antiCos.evaluate({'x': 0.0})).isCloseTo(0.0, 1e-9);
      check(antiCos.evaluate({'x': math.pi / 2.0})).isCloseTo(1.0, 1e-9);
    });

    test('tangent and inverse trigonometric', () {
      const exprTan = Tan(x);
      final antiTan = exprTan.integrate('x');
      check(antiTan.evaluate({'x': 0.0})).isCloseTo(0.0, 1e-9);
      check(antiTan.derivative('x').toFunction1D('x')(0.5))
          .isCloseTo(math.tan(0.5), 1e-9);

      const asinExpr = Asin(x);
      final antiAsin = asinExpr.integrate('x');
      check(antiAsin.derivative('x').toFunction1D('x')(0.5))
          .isCloseTo(math.asin(0.5), 1e-9);

      const acosExpr = Acos(x);
      final antiAcos = acosExpr.integrate('x');
      check(antiAcos.derivative('x').toFunction1D('x')(0.5))
          .isCloseTo(math.acos(0.5), 1e-9);

      const atanExpr = Atan(x);
      final antiAtan = atanExpr.integrate('x');
      check(antiAtan.derivative('x').toFunction1D('x')(0.8))
          .isCloseTo(math.atan(0.8), 1e-9);
    });

    test('hyperbolic functions: sinh, cosh, tanh', () {
      const sinhExpr = Sinh(x);
      final antiSinh = sinhExpr.integrate('x');
      check(antiSinh.derivative('x').toFunction1D('x')(1.0))
          .isCloseTo((math.exp(1.0) - math.exp(-1.0)) / 2.0, 1e-9);

      const coshExpr = Cosh(x);
      final antiCosh = coshExpr.integrate('x');
      check(antiCosh.derivative('x').toFunction1D('x')(1.0))
          .isCloseTo((math.exp(1.0) + math.exp(-1.0)) / 2.0, 1e-9);

      const tanhExpr = Tanh(x);
      final antiTanh = tanhExpr.integrate('x');
      check(antiTanh.derivative('x').toFunction1D('x')(0.8))
          .isCloseTo((math.exp(1.6) - 1.0) / (math.exp(1.6) + 1.0), 1e-9);
    });

    test('absolute value and square root', () {
      const absExpr = Abs(x);
      final antiAbs = absExpr.integrate('x');
      check(antiAbs.evaluate({'x': 2.0})).equals(2.0);
      check(antiAbs.evaluate({'x': -2.0})).equals(-2.0);

      const sqrtExpr = Pow(x, RationalNumber(1, 2));
      final antiSqrt = sqrtExpr.integrate('x');
      check(antiSqrt.evaluate({'x': 4.0})).isCloseTo(16.0 / 3.0, 1e-9);
      check(antiSqrt.derivative('x').toFunction1D('x')(9.0))
          .isCloseTo(3.0, 1e-9);
    });
  });

  group('Indefinite Integration: Products, Substitutions, and Parts', () {
    test('integration by parts: x * exp(x), x * sin(x), x * cos(x)', () {
      final antiExp = (x * const Exp(x)).integrate('x');
      check(antiExp.evaluate({'x': 1.0})).isCloseTo(0.0, 1e-9);
      check(antiExp.derivative('x').toFunction1D('x')(2.0))
          .isCloseTo(2.0 * math.exp(2.0), 1e-9);

      final antiSin = (x * const Sin(x)).integrate('x');
      check(antiSin.evaluate({'x': math.pi})).isCloseTo(math.pi, 1e-9);
      check(antiSin.derivative('x').toFunction1D('x')(1.5))
          .isCloseTo(1.5 * math.sin(1.5), 1e-9);

      final antiCos = (x * const Cos(x)).integrate('x');
      check(antiCos.evaluate({'x': 0.0})).isCloseTo(1.0, 1e-9);
      check(antiCos.derivative('x').toFunction1D('x')(1.5))
          .isCloseTo(1.5 * math.cos(1.5), 1e-9);
    });

    test('integration by parts: x * ln(x), x * sinh(x), x * cosh(x)', () {
      final antiLn = (x * const Ln(x)).integrate('x');
      check(antiLn.evaluate({'x': 1.0})).isCloseTo(-0.25, 1e-9);
      check(antiLn.derivative('x').toFunction1D('x')(3.0))
          .isCloseTo(3.0 * math.log(3.0), 1e-9);

      final antiSinh = (x * const Sinh(x)).integrate('x');
      check(antiSinh.derivative('x').toFunction1D('x')(1.5))
          .isCloseTo(1.5 * ((math.exp(1.5) - math.exp(-1.5)) / 2.0), 1e-9);

      final antiCosh = (x * const Cosh(x)).integrate('x');
      check(antiCosh.derivative('x').toFunction1D('x')(1.5))
          .isCloseTo(1.5 * ((math.exp(1.5) + math.exp(-1.5)) / 2.0), 1e-9);
    });

    test('chain-rule substitution with compound u(x)', () {
      // (2x + 1) * cos(x^2 + x)
      final anti1 = (((x * 2) + 1) * Cos(x.pow(2) + x)).integrate('x');
      check(anti1.evaluate({'x': 0.0})).isCloseTo(0.0, 1e-9);
      check(anti1.derivative('x').toFunction1D('x')(1.0))
          .isCloseTo(3.0 * math.cos(2.0), 1e-9);

      // 2x * cos(x^2)
      final anti2 = ((x * 2) * Cos(x.pow(2))).integrate('x');
      check(anti2.evaluate({'x': 0.0})).isCloseTo(0.0, 1e-9);
      check(anti2.derivative('x').toFunction1D('x')(1.2))
          .isCloseTo(2.4 * math.cos(1.44), 1e-9);

      // x * exp(x^2)
      final anti3 = (x * Exp(x.pow(2))).integrate('x');
      check(anti3.evaluate({'x': 0.0})).isCloseTo(0.5, 1e-9);
      check(anti3.derivative('x').toFunction1D('x')(1.5))
          .isCloseTo(1.5 * math.exp(2.25), 1e-9);

      // 2x / (x^2 + 1)^2
      final anti4 = ((x * 2) / (x.pow(2) + 1).pow(2)).integrate('x');
      check(anti4.evaluate({'x': 1.0})).isCloseTo(-0.5, 1e-9);
      check(anti4.derivative('x').toFunction1D('x')(2.0))
          .isCloseTo(4.0 / 25.0, 1e-9);

      // 2x * cosh(x^2)
      final anti5 = ((x * 2) * Cosh(x.pow(2))).integrate('x');
      check(anti5.derivative('x').toFunction1D('x')(1.2))
          .isCloseTo(2.4 * ((math.exp(1.44) + math.exp(-1.44)) / 2.0), 1e-9);
    });

    test(
      'inverse trig quotient integrations: 1 / (1 + x^2) and 1 / sqrt(1 - x^2)',
      () {
        final exprAtan =
            const RationalNumber(1) / (const RationalNumber(1) + x.pow(2));
        final antiAtan = exprAtan.integrate('x');
        check(antiAtan.derivative('x').toFunction1D('x')(0.5))
            .isCloseTo(1.0 / (1.0 + 0.25), 1e-9);

        final exprAsin =
            const RationalNumber(1) /
            Pow(const RationalNumber(1) - x.pow(2), const RationalNumber(1, 2));
        final antiAsin = exprAsin.integrate('x');
        check(antiAsin.derivative('x').toFunction1D('x')(0.5))
            .isCloseTo(1.0 / math.sqrt(1.0 - 0.25), 1e-9);

        final exprChainAtan = (x * 2) / (const RationalNumber(1) + x.pow(4));
        final antiChainAtan = exprChainAtan.integrate('x');
        check(antiChainAtan.derivative('x').toFunction1D('x')(0.8))
            .isCloseTo((2.0 * 0.8) / (1.0 + math.pow(0.8, 4)), 1e-9);
      },
    );
  });

  group('Fundamental Theorem of Calculus Parity (d/dx F(x) == f(x))', () {
    test('standard elementary functions: d/dx int f(x) dx == f(x)', () {
      final functions = <(Expr, double, double)>[
        (const Tan(x), -1.3, 1.3),
        (const Asin(x), -0.9, 0.9),
        (const Acos(x), -0.9, 0.9),
        (const Atan(x), -5.0, 5.0),
        (const Sinh(x), -3.0, 3.0),
        (const Cosh(x), -3.0, 3.0),
        (const Tanh(x), -4.0, 4.0),
        (const Abs(x), 0.2, 5.0),
        (const Abs(x), -5.0, -0.2),
        (const Pow(x, RationalNumber(1, 2)), 0.1, 10.0),
        (const Div(Ln(x), Ln(RationalNumber(3))), 0.2, 8.0),
      ];

      for (final (f, minT, maxT) in functions) {
        final anti = f.integrate('x');
        final dAnti = anti.derivative('x').simplify();
        final fFn = f.toFunction1D('x');
        final dAntiFn = dAnti.toFunction1D('x');

        for (var i = 0; i < 30; i++) {
          final t = minT + ((maxT - minT) / 29.0) * i;
          final fVal = fFn(t);
          final dAntiVal = dAntiFn(t);
          check(dAntiVal).isCloseTo(fVal, 1e-7);
        }
      }
    });

    test('affine linear forms: d/dx int f(ax + b) dx == f(ax + b)', () {
      final affineFunctions = <(Expr, double, double)>[
        (Tan((x * 2) + const RationalNumber(1, 2)), -0.8, 0.4),
        (
          Asin((x * const RationalNumber(1, 2)) - const RationalNumber(1, 5)),
          -1.4,
          1.4,
        ),
        (Atan((x * 2) + 1), -4.0, 4.0),
        (
          Sinh((x * const RationalNumber(3, 2)) - const RationalNumber(1, 2)),
          -2.0,
          2.0,
        ),
        (Tanh(x * 2), -3.0, 3.0),
        (Pow((x * 2) + 1, const RationalNumber(1, 2)), 0.1, 8.0),
      ];

      for (final (f, minT, maxT) in affineFunctions) {
        final anti = f.integrate('x');
        final dAnti = anti.derivative('x').simplify();
        final fFn = f.toFunction1D('x');
        final dAntiFn = dAnti.toFunction1D('x');

        for (var i = 0; i < 25; i++) {
          final t = minT + ((maxT - minT) / 24.0) * i;
          final fVal = fFn(t);
          final dAntiVal = dAntiFn(t);
          check(dAntiVal).isCloseTo(fVal, 1e-7);
        }
      }
    });
  });

  group('Definite Integration: Analytical & Numerical Parity', () {
    test('definite integral of polynomials and elementary functions', () {
      // int_0^2 (3x^2 + 2x + 1) dx = 14
      final poly = (x.pow(2) * 3) + (x * 2) + 1;
      check(poly.integrate('x', from: 0, to: 2))
          .equals(const RationalNumber(14));

      // int_0^pi sin(x) dx = 2
      final resSin = const Sin(x).integrate('x', from: 0, to: math.pi);
      check(resSin.evaluate(const {})).isCloseTo(2.0, 1e-9);

      // int_1^e (1 / x) dx = 1
      final resLn = (const RationalNumber(1) / x).integrate(
        'x',
        from: 1,
        to: math.e,
      );
      check(resLn.evaluate(const {})).isCloseTo(1.0, 1e-9);
    });

    test('definite integrals match Gauss-Kronrod numerical quadrature', () {
      final testCases = <(Expr, double, double)>[
        (const Tan(x), 0.0, 0.5),
        (const Tan(x), -1.0, 1.0),
        (const Sinh(x), 0.0, 1.0),
        (const Sinh(x), -2.0, 2.0),
        (const Cosh(x), 0.0, 1.0),
        (const Tanh(x), 0.0, 1.0),
        (const Atan(x), 0.0, 1.0),
        (const Asin(x), -0.8, 0.8),
        (const Acos(x), -0.8, 0.8),
        (const Pow(x, RationalNumber(1, 2)), 1.0, 4.0),
      ];

      for (final (expr, a, b) in testCases) {
        final symDefinite = expr.integrate('x', from: a, to: b);
        final symVal = symDefinite.evaluate(const {});
        final numVal = integrate(expr.toFunction1D('x'), a, b);

        check(symVal).isCloseTo(numVal, 1e-5);
      }
    });

    test('reversal of limits and equal limits identities', () {
      const expr = Sinh(x);
      final forward = expr
          .integrate('x', from: 0.5, to: 2.5)
          .evaluate(const {});
      final backward = expr
          .integrate('x', from: 2.5, to: 0.5)
          .evaluate(const {});
      check(backward).isCloseTo(-forward, 1e-9);

      final zeroRange = expr.integrate('x', from: 2.5, to: 2.5);
      check(zeroRange.evaluate(const {})).equals(0.0);
    });

    test('multivariable definite integral: int_0^1 (x + y) dx = y + 0.5', () {
      final expr = x + y;
      final result = expr.integrate('x', from: 0, to: 1);

      check(result.freeVariables).unorderedEquals({'y'});
      check(result.evaluate({'y': 3.0})).equals(3.5);
      check(result.evaluate({'y': 0.0})).equals(0.5);
      check(result.evaluate({'y': -0.5})).equals(0.0);
    });

    test('definite integration of non-elementary expressions throws UnsupportedError', () {
      // Gaussian integral: exp(-x^2) has no elementary anti-derivative
      final exprGauss = Exp(-x.pow(2));
      check(() => exprGauss.integrate('x', from: 0, to: 1))
          .throws<UnsupportedError>();

      // Fresnel integral: sin(x^2) has no elementary anti-derivative
      final exprFresnel = Sin(x.pow(2));
      check(() => exprFresnel.integrate('x', from: 0, to: 1))
          .throws<UnsupportedError>();
    });
  });

  group('Integration Error Handling & Boundaries', () {
    test('asymmetric bounds throw ArgumentError', () {
      check(() => x.integrate('x', from: 0)).throws<ArgumentError>();
      check(() => x.integrate('x', to: 1)).throws<ArgumentError>();
    });

    test('indefinite integration of non-elementary expressions throws UnsupportedError', () {
      check(() => Exp(-x.pow(2)).integrate('x')).throws<UnsupportedError>();
      check(() => Sin(x.pow(2)).integrate('x')).throws<UnsupportedError>();
    });

    test(
      'adversarial non-elementary definite integrals throw UnsupportedError',
      () {
        final nonElementary = <Expr>[
          Exp(-x.pow(2)), // Gaussian
          Sin(x.pow(2)), // Fresnel sine
          Cos(x.pow(2)), // Fresnel cosine
          const Sin(x) / x, // Sine integral Si(x)
          const Exp(x) / x, // Exponential integral Ei(x)
          const RationalNumber(1) / const Ln(x), // Logarithmic integral li(x)
          x.pow(x), // Sophomore's dream
          const RationalNumber(1) /
              Pow(
                x.pow(3) + const RationalNumber(1),
                const RationalNumber(1, 2),
              ), // Elliptic
        ];

        for (final expr in nonElementary) {
          check(() => expr.integrate('x', from: 0.5, to: 1.5))
              .throws<UnsupportedError>();
        }
      },
    );

    test('resolvable analytical integrals maintain exact closed forms', () {
      // 1. Polynomial
      final poly =
          const RationalNumber(3) * x.pow(2) +
          const RationalNumber(5) * x -
          const RationalNumber(7);
      final polyInt = poly.integrate('x');
      check(polyInt.derivative('x').simplify()).equals(poly.simplify());
      check(poly.integrate('x', from: 0, to: 2))
          .equals(const RationalNumber(4));

      // 2. Trigonometric
      check(const Sin(x).integrate('x')).equals(-const Cos(x));
      check(const Cos(x).integrate('x')).equals(const Sin(x));
      check(const Tan(x).integrate('x')).equals(-const Ln(Cos(x)));

      // 3. Exponential & Logarithm
      check(
        Exp(const RationalNumber(2) * x).integrate('x'),
      ).equals(const RationalNumber(1, 2) * Exp(const RationalNumber(2) * x));
      check(const Ln(x).integrate('x')).equals(x * const Ln(x) - x);

      // 4. Rational / Inverse Trigonometric
      check((const RationalNumber(1) / x).integrate('x')).equals(const Ln(x));
      check(
        (const RationalNumber(1) / (const RationalNumber(1) + x.pow(2)))
            .integrate('x'),
      ).equals(const Atan(x));
      check(
        (const RationalNumber(1) /
                Pow(
                  const RationalNumber(1) - x.pow(2),
                  const RationalNumber(1, 2),
                ))
            .integrate('x'),
      ).equals(const Asin(x));

      // 5. Integration by parts & substitution
      final byPartsExp = (x * const Exp(x)).integrate('x');
      check(byPartsExp.derivative('x').expand().simplify())
          .equals((x * const Exp(x)).simplify());

      final byPartsTrig = (x * const Cos(x)).integrate('x');
      check(byPartsTrig.derivative('x').expand().simplify())
          .equals((x * const Cos(x)).simplify());

      final chainRule = (const RationalNumber(2) * x * Exp(x.pow(2))).integrate(
        'x',
      );
      check(chainRule).equals(Exp(x.pow(2)));
    });
  });
}
