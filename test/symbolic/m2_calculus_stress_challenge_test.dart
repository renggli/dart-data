import 'dart:math' as math;
import 'dart:typed_data';

import 'package:checks/checks.dart';
import 'package:data/numeric.dart';
import 'package:data/symbolic.dart';
import 'package:test/scaffolding.dart';

void main() {
  const x = Variable('x');

  group(
    'Empirical Challenge 1: Calculus Parity Across Fine Sampling Grids',
    () {
      test('first-order derivative parity across fine sampling grids', () {
        // 1. Tan(x) on (-1.4, 1.4)
        const exprTan = Tan(x);
        final symDTan = exprTan.derivative('x').toFunction1D('x');
        final numTan = exprTan.toFunction1D('x');
        for (var i = 0; i < 50; i++) {
          final t = -1.4 + (2.8 / 49.0) * i;
          final symVal = symDTan(t);
          final numVal = derivative(numTan, t, order: 1);
          final exact = 1.0 / (math.cos(t) * math.cos(t));
          check(symVal).isCloseTo(exact, 1e-9);
          check(numVal).isCloseTo(symVal, 1e-4);
        }

        // 2. Asin(x) on (-0.95, 0.95)
        const exprAsin = Asin(x);
        final symDAsin = exprAsin.derivative('x').toFunction1D('x');
        final numAsin = exprAsin.toFunction1D('x');
        for (var i = 0; i < 50; i++) {
          final t = -0.95 + (1.9 / 49.0) * i;
          final symVal = symDAsin(t);
          final numVal = derivative(numAsin, t, order: 1);
          final exact = 1.0 / math.sqrt(1.0 - t * t);
          check(symVal).isCloseTo(exact, 1e-9);
          check(numVal).isCloseTo(symVal, 1e-4);
        }

        // 3. Acos(x) on (-0.95, 0.95)
        const exprAcos = Acos(x);
        final symDAcos = exprAcos.derivative('x').toFunction1D('x');
        final numAcos = exprAcos.toFunction1D('x');
        for (var i = 0; i < 50; i++) {
          final t = -0.95 + (1.9 / 49.0) * i;
          final symVal = symDAcos(t);
          final numVal = derivative(numAcos, t, order: 1);
          final exact = -1.0 / math.sqrt(1.0 - t * t);
          check(symVal).isCloseTo(exact, 1e-9);
          check(numVal).isCloseTo(symVal, 1e-4);
        }

        // 4. Atan(x) on (-5.0, 5.0)
        const exprAtan = Atan(x);
        final symDAtan = exprAtan.derivative('x').toFunction1D('x');
        final numAtan = exprAtan.toFunction1D('x');
        for (var i = 0; i < 50; i++) {
          final t = -5.0 + (10.0 / 49.0) * i;
          final symVal = symDAtan(t);
          final numVal = derivative(numAtan, t, order: 1);
          final exact = 1.0 / (1.0 + t * t);
          check(symVal).isCloseTo(exact, 1e-9);
          check(numVal).isCloseTo(symVal, 1e-4);
        }

        // 5. Sinh(x) on (-4.0, 4.0)
        const exprSinh = Sinh(x);
        final symDSinh = exprSinh.derivative('x').toFunction1D('x');
        final numSinh = exprSinh.toFunction1D('x');
        for (var i = 0; i < 50; i++) {
          final t = -4.0 + (8.0 / 49.0) * i;
          final symVal = symDSinh(t);
          final numVal = derivative(numSinh, t, order: 1);
          final exact = (math.exp(t) + math.exp(-t)) / 2.0;
          check(symVal).isCloseTo(exact, 1e-9);
          check(numVal).isCloseTo(symVal, 1e-4);
        }

        // 6. Cosh(x) on (-4.0, 4.0)
        const exprCosh = Cosh(x);
        final symDCosh = exprCosh.derivative('x').toFunction1D('x');
        final numCosh = exprCosh.toFunction1D('x');
        for (var i = 0; i < 50; i++) {
          final t = -4.0 + (8.0 / 49.0) * i;
          final symVal = symDCosh(t);
          final numVal = derivative(numCosh, t, order: 1);
          final exact = (math.exp(t) - math.exp(-t)) / 2.0;
          check(symVal).isCloseTo(exact, 1e-9);
          check(numVal).isCloseTo(symVal, 1e-4);
        }

        // 7. Tanh(x) on (-4.0, 4.0)
        const exprTanh = Tanh(x);
        final symDTanh = exprTanh.derivative('x').toFunction1D('x');
        final numTanh = exprTanh.toFunction1D('x');
        for (var i = 0; i < 50; i++) {
          final t = -4.0 + (8.0 / 49.0) * i;
          final symVal = symDTanh(t);
          final numVal = derivative(numTanh, t, order: 1);
          final ch = (math.exp(t) + math.exp(-t)) / 2.0;
          final exact = 1.0 / (ch * ch);
          check(symVal).isCloseTo(exact, 1e-9);
          check(numVal).isCloseTo(symVal, 1e-4);
        }

        // 8. Abs(x) on positive [0.1, 5.0] and negative [-5.0, -0.1]
        const exprAbs = Abs(x);
        final symDAbs = exprAbs.derivative('x').toFunction1D('x');
        final numAbs = exprAbs.toFunction1D('x');
        for (var i = 0; i < 25; i++) {
          final posT = 0.1 + (4.9 / 24.0) * i;
          check(symDAbs(posT)).isCloseTo(1.0, 1e-9);
          check(derivative(numAbs, posT, order: 1)).isCloseTo(1.0, 1e-4);

          final negT = -5.0 + (4.9 / 24.0) * i;
          check(symDAbs(negT)).isCloseTo(-1.0, 1e-9);
          check(derivative(numAbs, negT, order: 1)).isCloseTo(-1.0, 1e-4);
        }

        // 9. Sqrt(x) on (0.1, 20.0)
        const exprSqrt = Sqrt(x);
        final symDSqrt = exprSqrt.derivative('x').toFunction1D('x');
        final numSqrt = exprSqrt.toFunction1D('x');
        for (var i = 0; i < 50; i++) {
          final t = 0.1 + (19.9 / 49.0) * i;
          final symVal = symDSqrt(t);
          final numVal = derivative(numSqrt, t, order: 1);
          final exact = 1.0 / (2.0 * math.sqrt(t));
          check(symVal).isCloseTo(exact, 1e-9);
          check(numVal).isCloseTo(symVal, 1e-4);
        }

        // 10. Log(base 2, x) on (0.1, 10.0)
        const exprLog = Log(RationalNumber(2), x);
        final symDLog = exprLog.derivative('x').toFunction1D('x');
        final numLog = exprLog.toFunction1D('x');
        for (var i = 0; i < 50; i++) {
          final t = 0.1 + (9.9 / 49.0) * i;
          final symVal = symDLog(t);
          final numVal = derivative(numLog, t, order: 1);
          final exact = 1.0 / (t * math.ln2);
          check(symVal).isCloseTo(exact, 1e-9);
          check(numVal).isCloseTo(symVal, 1e-4);
        }
      });

      test('second-order derivative parity across fine sampling grids', () {
        // 1. Tan''(x) = 2 * sin(x) / cos^3(x) = 2 * tan(x) / cos^2(x)
        const exprTan = Tan(x);
        final symD2Tan = exprTan.derivative('x', order: 2).toFunction1D('x');
        final numTan = exprTan.toFunction1D('x');
        for (var i = 0; i < 20; i++) {
          final t = -1.0 + (2.0 / 19.0) * i;
          final symVal = symD2Tan(t);
          final numVal = derivative(numTan, t, order: 2);
          final c = math.cos(t);
          final exact = (2.0 * math.sin(t)) / (c * c * c);
          check(symVal).isCloseTo(exact, 1e-9);
          check(numVal).isCloseTo(symVal, 1e-2);
        }

        // 2. Sinh''(x) = sinh(x)
        const exprSinh = Sinh(x);
        final symD2Sinh = exprSinh.derivative('x', order: 2).toFunction1D('x');
        final numSinh = exprSinh.toFunction1D('x');
        for (var i = 0; i < 20; i++) {
          final t = -2.0 + (4.0 / 19.0) * i;
          final symVal = symD2Sinh(t);
          final numVal = derivative(numSinh, t, order: 2);
          final exact = (math.exp(t) - math.exp(-t)) / 2.0;
          check(symVal).isCloseTo(exact, 1e-9);
          check(numVal).isCloseTo(symVal, 1e-2);
        }

        // 3. Cosh''(x) = cosh(x)
        const exprCosh = Cosh(x);
        final symD2Cosh = exprCosh.derivative('x', order: 2).toFunction1D('x');
        final numCosh = exprCosh.toFunction1D('x');
        for (var i = 0; i < 20; i++) {
          final t = -2.0 + (4.0 / 19.0) * i;
          final symVal = symD2Cosh(t);
          final numVal = derivative(numCosh, t, order: 2);
          final exact = (math.exp(t) + math.exp(-t)) / 2.0;
          check(symVal).isCloseTo(exact, 1e-9);
          check(numVal).isCloseTo(symVal, 1e-2);
        }

        // 4. Atan''(x) = -2x / (1 + x^2)^2
        const exprAtan = Atan(x);
        final symD2Atan = exprAtan.derivative('x', order: 2).toFunction1D('x');
        final numAtan = exprAtan.toFunction1D('x');
        for (var i = 0; i < 20; i++) {
          final t = -3.0 + (6.0 / 19.0) * i;
          final symVal = symD2Atan(t);
          final numVal = derivative(numAtan, t, order: 2);
          final denom = 1.0 + t * t;
          final exact = (-2.0 * t) / (denom * denom);
          check(symVal).isCloseTo(exact, 1e-9);
          check(numVal).isCloseTo(symVal, 1e-2);
        }

        // 5. Sqrt''(x) = -1 / (4 * x^(3/2))
        const exprSqrt = Sqrt(x);
        final symD2Sqrt = exprSqrt.derivative('x', order: 2).toFunction1D('x');
        final numSqrt = exprSqrt.toFunction1D('x');
        for (var i = 0; i < 20; i++) {
          final t = 0.5 + (9.5 / 19.0) * i;
          final symVal = symD2Sqrt(t);
          final numVal = derivative(numSqrt, t, order: 2);
          final exact = -1.0 / (4.0 * math.pow(t, 1.5));
          check(symVal).isCloseTo(exact, 1e-9);
          check(numVal).isCloseTo(symVal, 1e-2);
        }
      });

      test('chain rule derivative parity on affine composite expressions', () {
        final cases = <(Expr, double, double, double Function(double))>[
          (
            Tan((x * 2) + 1),
            -1.0,
            0.1,
            (t) => 2.0 / math.pow(math.cos(2.0 * t + 1.0), 2),
          ),
          (
            Asin(
              (x * const RationalNumber(1, 2)) + const RationalNumber(1, 10),
            ),
            -1.5,
            1.5,
            (t) => 0.5 / math.sqrt(1.0 - math.pow(0.5 * t + 0.1, 2)),
          ),
          (
            Acos(
              (x * const RationalNumber(1, 2)) + const RationalNumber(1, 10),
            ),
            -1.5,
            1.5,
            (t) => -0.5 / math.sqrt(1.0 - math.pow(0.5 * t + 0.1, 2)),
          ),
          (
            Atan((x * 3) - 1),
            -3.0,
            3.0,
            (t) => 3.0 / (1.0 + math.pow(3.0 * t - 1.0, 2)),
          ),
          (
            Sinh((x * 2) - 1),
            -1.5,
            1.5,
            (t) =>
                2.0 *
                (math.exp(2.0 * t - 1.0) + math.exp(-(2.0 * t - 1.0))) /
                2.0,
          ),
          (
            Cosh((x * const RationalNumber(3, 2)) + const RationalNumber(1, 2)),
            -1.5,
            1.5,
            (t) =>
                1.5 *
                (math.exp(1.5 * t + 0.5) - math.exp(-(1.5 * t + 0.5))) /
                2.0,
          ),
          (
            Tanh((x * 2) + 1),
            -2.0,
            2.0,
            (t) {
              final ch =
                  (math.exp(2.0 * t + 1.0) + math.exp(-(2.0 * t + 1.0))) / 2.0;
              return 2.0 / (ch * ch);
            },
          ),
          (
            Sqrt((x * 2) + 3),
            -1.0,
            5.0,
            (t) => 2.0 / (2.0 * math.sqrt(2.0 * t + 3.0)),
          ),
        ];

        for (final (expr, minT, maxT, exactDeriv) in cases) {
          final symD = expr.derivative('x').toFunction1D('x');
          final numF = expr.toFunction1D('x');
          for (var i = 0; i < 20; i++) {
            final t = minT + ((maxT - minT) / 19.0) * i;
            final symVal = symD(t);
            final numVal = derivative(numF, t, order: 1);
            final exactVal = exactDeriv(t);
            check(symVal).isCloseTo(exactVal, 1e-9);
            check(numVal).isCloseTo(symVal, 1e-4);
          }
        }
      });
    },
  );

  group('Empirical Challenge 2: Fundamental Theorem of Calculus Parity (d/dx F(x) == f(x))', () {
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
        (const Sqrt(x), 0.1, 10.0),
        (const Log(RationalNumber(3), x), 0.2, 8.0),
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
        (
          Acos((x * const RationalNumber(1, 2)) + const RationalNumber(1, 10)),
          -1.4,
          1.4,
        ),
        (Atan((x * 2) + 1), -4.0, 4.0),
        (
          Sinh((x * const RationalNumber(3, 2)) - const RationalNumber(1, 2)),
          -2.0,
          2.0,
        ),
        (
          Cosh((x * const RationalNumber(3, 2)) + const RationalNumber(1, 2)),
          -2.0,
          2.0,
        ),
        (Tanh(x * 2), -3.0, 3.0),
        (Abs((x * 3) - 2), 1.0, 5.0), // strictly positive branch
        (Abs((x * 3) - 2), -5.0, 0.0), // strictly negative branch
        (Sqrt((x * 2) + 1), 0.1, 8.0),
        (Log(const RationalNumber(5), (x * 2) + 1), 0.2, 8.0),
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

    test('integration by parts: x * sinh(x) and x * cosh(x)', () {
      final partsExpressions = <(Expr, double, double)>[
        (x * const Sinh(x), -2.0, 2.0),
        (x * const Cosh(x), -2.0, 2.0),
        (x * const Sin(x), -3.0, 3.0),
        (x * const Cos(x), -3.0, 3.0),
      ];

      for (final (f, minT, maxT) in partsExpressions) {
        final anti = f.integrate('x');
        final dAnti = anti.derivative('x').simplify();
        final fFn = f.toFunction1D('x');
        final dAntiFn = dAnti.toFunction1D('x');

        for (var i = 0; i < 20; i++) {
          final t = minT + ((maxT - minT) / 19.0) * i;
          final fVal = fFn(t);
          final dAntiVal = dAntiFn(t);
          check(dAntiVal).isCloseTo(fVal, 1e-7);
        }
      }
    });

    test('inverse trigonometric rational quotients: 1 / (1 + x^2) and 1 / sqrt(1 - x^2)', () {
      // 1 / (1 + x^2) -> atan(x)
      final invAtan =
          const RationalNumber(1) / (const RationalNumber(1) + (x * x));
      final antiAtan = invAtan.integrate('x');
      check(antiAtan).equals(const Atan(x));
      check(antiAtan.derivative('x').toFunction1D('x')(1.5))
          .isCloseTo(invAtan.toFunction1D('x')(1.5), 1e-9);

      // 1 / sqrt(1 - x^2) -> asin(x)
      final invAsin =
          const RationalNumber(1) / Sqrt(const RationalNumber(1) - (x * x));
      final antiAsin = invAsin.integrate('x');
      check(antiAsin).equals(const Asin(x));
      check(antiAsin.derivative('x').toFunction1D('x')(0.6))
          .isCloseTo(invAsin.toFunction1D('x')(0.6), 1e-9);
    });
  });

  group('Empirical Challenge 3: Definite Quadrature Parity vs Gauss-Kronrod', () {
    test(
      'definite integrals across multiple intervals match numerical quadrature',
      () {
        final testCases = <(Expr, double, double)>[
          // Tan(x)
          (const Tan(x), 0.0, 0.5),
          (const Tan(x), -1.0, 1.0), // anti-symmetric -> 0
          (const Tan(x), 0.1, 1.2),
          (const Tan(x), -0.8, 0.4),
          (const Tan(x), -1.4, 1.4),

          // Sinh(x)
          (const Sinh(x), 0.0, 1.0),
          (const Sinh(x), -2.0, 2.0), // anti-symmetric -> 0
          (const Sinh(x), 0.5, 2.5),
          (const Sinh(x), -1.5, 0.5),
          (const Sinh(x), -2.5, 2.5),

          // Cosh(x)
          (const Cosh(x), 0.0, 1.0),
          (const Cosh(x), -2.0, 2.0),
          (const Cosh(x), 0.5, 2.5),
          (const Cosh(x), -1.5, 0.5),
          (const Cosh(x), -2.5, 2.5),

          // Tanh(x)
          (const Tanh(x), 0.0, 1.0),
          (const Tanh(x), -2.0, 2.0), // anti-symmetric -> 0
          (const Tanh(x), 0.5, 3.0),
          (const Tanh(x), -3.0, 3.0),
          (const Tanh(x), -5.0, 5.0),

          // Atan(x)
          (const Atan(x), 0.0, 1.0),
          (const Atan(x), -2.0, 2.0), // anti-symmetric -> 0
          (const Atan(x), -5.0, 5.0),
          (const Atan(x), 0.5, 3.0),
          (const Atan(x), -10.0, 10.0),

          // Asin(x)
          (const Asin(x), -0.8, 0.8), // anti-symmetric -> 0
          (const Asin(x), 0.0, 0.8),
          (const Asin(x), -0.5, 0.5),

          // Acos(x)
          (const Acos(x), -0.8, 0.8),
          (const Acos(x), 0.0, 0.8),
          (const Acos(x), -0.5, 0.5),

          // Sqrt(x) on smooth intervals away from zero
          (const Sqrt(x), 1.0, 4.0),
          (const Sqrt(x), 2.0, 5.0),
        ];

        for (final (expr, a, b) in testCases) {
          final symDefinite = expr.integrate('x', from: a, to: b);
          final symVal = symDefinite.evaluate(const {});
          final numVal = integrate(expr.toFunction1D('x'), a, b);

          check(symVal).isCloseTo(numVal, 1e-5);
        }
      },
    );

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
  });

  group('Empirical Challenge 4: Corner Cases & Domain Boundaries', () {
    test('singularity asymptotics for Tan near pi/2', () {
      const exprTan = Tan(x);
      final tanFn = exprTan.toFunction1D('x');
      final dTanFn = exprTan.derivative('x').toFunction1D('x');

      for (final eps in [1e-2, 1e-4, 1e-7, 1e-10]) {
        final pt = math.pi / 2.0 - eps;
        final val = tanFn(pt);
        final expectedVal = math.tan(pt);
        check(val).isCloseTo(expectedVal, 1e-9);
        check(val.isFinite).isTrue();

        final dVal = dTanFn(pt);
        final c = math.cos(pt);
        final expectedDVal = 1.0 / (c * c);
        check(dVal).isCloseTo(expectedDVal, 1e-7);
        check(dVal.isFinite).isTrue();
      }
    });

    test('singularity asymptotics for Asin and Acos near 1.0', () {
      const exprAsin = Asin(x);
      const exprAcos = Acos(x);
      final asinFn = exprAsin.toFunction1D('x');
      final acosFn = exprAcos.toFunction1D('x');
      final dAsinFn = exprAsin.derivative('x').toFunction1D('x');
      final dAcosFn = exprAcos.derivative('x').toFunction1D('x');

      for (final eps in [1e-2, 1e-4, 1e-7, 1e-10]) {
        final pt = 1.0 - eps;

        final asinVal = asinFn(pt);
        check(asinVal).isCloseTo(math.asin(pt), 1e-9);
        check(asinVal.isFinite).isTrue();

        final acosVal = acosFn(pt);
        check(acosVal).isCloseTo(math.acos(pt), 1e-9);
        check(acosVal.isFinite).isTrue();

        final dAsinVal = dAsinFn(pt);
        final expectedDAsin = 1.0 / math.sqrt(1.0 - pt * pt);
        check(dAsinVal).isCloseTo(expectedDAsin, 1e-7);
        check(dAsinVal.isFinite).isTrue();

        final dAcosVal = dAcosFn(pt);
        final expectedDAcos = -1.0 / math.sqrt(1.0 - pt * pt);
        check(dAcosVal).isCloseTo(expectedDAcos, 1e-7);
        check(dAcosVal.isFinite).isTrue();
      }
    });

    test('boundary conditions at x = 0 for Abs(x) and Sqrt(x)', () {
      // 1. Abs(0) = 0
      const exprAbs = Abs(x);
      check(exprAbs.evaluate({'x': 0.0})).equals(0.0);
      check(exprAbs.toFunction1D('x')(0.0)).equals(0.0);

      // Derivative of Abs at 0 yields NaN (non-differentiable singularity: 0 / 0)
      final dAbsVal = exprAbs.derivative('x').evaluate({'x': 0.0});
      check(dAbsVal.isNaN).isTrue();

      // Anti-derivative of Abs at 0 is 0
      final antiAbs = exprAbs.integrate('x');
      check(antiAbs.evaluate({'x': 0.0})).equals(0.0);

      // Definite integral over symmetric range [-2, 2] = 4.0
      final intAbs = exprAbs.integrate('x', from: -2, to: 2);
      check(intAbs.evaluate(const {})).isCloseTo(4.0, 1e-9);

      // 2. Sqrt(0) = 0
      const exprSqrt = Sqrt(x);
      check(exprSqrt.evaluate({'x': 0.0})).equals(0.0);
      check(exprSqrt.toFunction1D('x')(0.0)).equals(0.0);

      // Derivative of Sqrt at 0 is Infinity (vertical tangent: 1 / (2 * 0))
      final dSqrtVal = exprSqrt.derivative('x').evaluate({'x': 0.0});
      check(dSqrtVal).equals(double.infinity);

      // Anti-derivative of Sqrt at 0 is 0
      final antiSqrt = exprSqrt.integrate('x');
      check(antiSqrt.evaluate({'x': 0.0})).equals(0.0);

      // Definite integral from 0 to 4 = 16 / 3
      final intSqrt = exprSqrt.integrate('x', from: 0, to: 4);
      check(intSqrt.evaluate(const {})).isCloseTo(16.0 / 3.0, 1e-9);
    });

    test('out of domain evaluation produces NaN as per IEEE-754 semantics', () {
      const exprSqrt = Sqrt(x);
      check(exprSqrt.toFunction1D('x')(-1.0).isNaN).isTrue();

      const exprAsin = Asin(x);
      check(exprAsin.toFunction1D('x')(1.5).isNaN).isTrue();
      check(exprAsin.toFunction1D('x')(-1.5).isNaN).isTrue();

      const exprAcos = Acos(x);
      check(exprAcos.toFunction1D('x')(1.5).isNaN).isTrue();
      check(exprAcos.toFunction1D('x')(-1.5).isNaN).isTrue();
    });
  });

  group(
    'Empirical Challenge 5: Tensor Kernel Hyperbolic Clamping & Large Inputs',
    () {
      test('Tanh tensor kernel prevents NaN with inputs > 20 and < -20', () {
        const exprTanh = Tanh(x);
        final kernel = exprTanh.compileTensorKernel(['x']);

        final largePosInputs = [
          20.0001,
          21.0,
          30.0,
          50.0,
          100.0,
          400.0,
          700.0,
          1000.0,
        ];
        final xPosBuf = Float64List.fromList(largePosInputs);
        final outPosBuf = Float64List(largePosInputs.length);

        kernel([xPosBuf], outPosBuf);

        for (var i = 0; i < largePosInputs.length; i++) {
          // Must clamp strictly to 1.0
          check(outPosBuf[i]).equals(1.0);
        }

        // Demonstration: without clamping, e^(2 * 400) = e^800 = inf, and (inf - 1) / (inf + 1) is NaN!
        final unclamped400 = (math.exp(800.0) - 1.0) / (math.exp(800.0) + 1.0);
        check(unclamped400.isNaN).isTrue();

        // But kernel output at 400.0 is 1.0
        check(outPosBuf[5]).equals(1.0);

        final largeNegInputs = [
          -20.0001,
          -21.0,
          -30.0,
          -50.0,
          -100.0,
          -400.0,
          -700.0,
          -1000.0,
        ];
        final xNegBuf = Float64List.fromList(largeNegInputs);
        final outNegBuf = Float64List(largeNegInputs.length);

        kernel([xNegBuf], outNegBuf);

        for (var i = 0; i < largeNegInputs.length; i++) {
          // Must clamp strictly to -1.0
          check(outNegBuf[i]).equals(-1.0);
        }
      });

      test(
        'Tanh compiled 1D closure and AST evaluate also enforce clamping',
        () {
          const exprTanh = Tanh(x);
          final fn = exprTanh.toFunction1D('x');

          check(fn(400.0)).equals(1.0);
          check(fn(-400.0)).equals(-1.0);
          check(exprTanh.evaluate({'x': 400.0})).equals(1.0);
          check(exprTanh.evaluate({'x': -400.0})).equals(-1.0);
        },
      );

      test(
        'Sinh and Cosh tensor kernel evaluate correctly across magnitude tiers',
        () {
          const exprSinh = Sinh(x);
          const exprCosh = Cosh(x);
          final sinhKernel = exprSinh.compileTensorKernel(['x']);
          final coshKernel = exprCosh.compileTensorKernel(['x']);

          // Tier 1: normal magnitudes [0.0 to 20.0]
          final midInputs = [0.0, 1.0, 5.0, 10.0, 15.0, 20.0];
          final midBuf = Float64List.fromList(midInputs);
          final sinhMidOut = Float64List(midInputs.length);
          final coshMidOut = Float64List(midInputs.length);

          sinhKernel([midBuf], sinhMidOut);
          coshKernel([midBuf], coshMidOut);

          for (var i = 0; i < midInputs.length; i++) {
            final v = midInputs[i];
            final expV = math.exp(v);
            final expNegV = math.exp(-v);
            final expectedSinh = (expV - expNegV) / 2.0;
            final expectedCosh = (expV + expNegV) / 2.0;
            check(sinhMidOut[i]).isCloseTo(expectedSinh, 1e-9);
            check(coshMidOut[i]).isCloseTo(expectedCosh, 1e-9);
          }

          // Tier 2: high magnitudes below double overflow [50, 100, 300, 700]
          final highInputs = [50.0, 100.0, 300.0, 700.0];
          final highBuf = Float64List.fromList(highInputs);
          final sinhHighOut = Float64List(highInputs.length);
          final coshHighOut = Float64List(highInputs.length);

          sinhKernel([highBuf], sinhHighOut);
          coshKernel([highBuf], coshHighOut);

          for (var i = 0; i < highInputs.length; i++) {
            check(sinhHighOut[i].isFinite).isTrue();
            check(coshHighOut[i].isFinite).isTrue();
            check(sinhHighOut[i]).isGreaterThan(0.0);
            check(coshHighOut[i]).isGreaterThan(0.0);
          }

          // Tier 3: IEEE 754 overflow tier (> 710)
          final overflowInputs = [800.0, 1000.0];
          final overflowBuf = Float64List.fromList(overflowInputs);
          final sinhOverflowOut = Float64List(overflowInputs.length);
          final coshOverflowOut = Float64List(overflowInputs.length);

          sinhKernel([overflowBuf], sinhOverflowOut);
          coshKernel([overflowBuf], coshOverflowOut);

          for (var i = 0; i < overflowInputs.length; i++) {
            // Must evaluate cleanly to double.infinity, NEVER NaN!
            check(sinhOverflowOut[i]).equals(double.infinity);
            check(coshOverflowOut[i]).equals(double.infinity);
          }
        },
      );

      test('high-throughput composite tensor kernel stress execution', () {
        // Composite transcendental formula combining new M2 operations:
        // f(x) = tanh(x) * cosh(x / 4) + sqrt(abs(x) + 1) - atan(x) + tan(sin(x) / 2)
        final composite =
            (const Tanh(x) * Cosh(x / const RationalNumber(4))) +
            const Sqrt(Add(Abs(x), RationalNumber(1))) -
            const Atan(x) +
            const Tan(Mul(Sin(x), RationalNumber(1, 2)));

        final kernel = composite.compileTensorKernel(['x']);

        const bufferSize = 128;
        final xBuf = Float64List(bufferSize);
        final outBuf = Float64List(bufferSize);
        final expectedBuf = Float64List(bufferSize);

        for (var i = 0; i < bufferSize; i++) {
          // Vary from -10 to +10 including 0
          final t = -10.0 + (20.0 / (bufferSize - 1)) * i;
          xBuf[i] = t;

          final ch = (math.exp(t / 4.0) + math.exp(-t / 4.0)) / 2.0;
          final th = t > 20.0
              ? 1.0
              : (t < -20.0
                    ? -1.0
                    : (math.exp(2 * t) - 1) / (math.exp(2 * t) + 1));
          final s = math.sqrt(t.abs() + 1.0);
          final at = math.atan(t);
          final tn = math.tan(math.sin(t) / 2.0);
          expectedBuf[i] = th * ch + s - at + tn;
        }

        final stopwatch = Stopwatch()..start();
        const iterations = 10000;
        for (var iter = 0; iter < iterations; iter++) {
          kernel([xBuf], outBuf);
        }
        stopwatch.stop();

        for (var i = 0; i < bufferSize; i++) {
          check(outBuf[i]).isCloseTo(expectedBuf[i], 1e-9);
        }

        // 10,000 iterations * 128 elements = 1,280,000 vector node evaluations
        // Should easily execute under 2500ms
        check(stopwatch.elapsedMilliseconds).isLessThan(2500);
      });
    },
  );

  group(
    'Empirical Challenge 6: Taylor Series Expansions for New Functions',
    () {
      test('Maclaurin series polynomial approximations around zero', () {
        // 1. Tan(x) order 3: x + (1/3) x^3
        const exprTan = Tan(x);
        final taylorTan = exprTan.taylorSeries('x', order: 3);
        final taylorTanFn = taylorTan.toFunction1D('x');
        final tanFn = exprTan.toFunction1D('x');
        for (final t in [-0.3, -0.1, 0.0, 0.1, 0.3]) {
          check(taylorTanFn(t)).isCloseTo(tanFn(t), 1e-3);
        }

        // 2. Sinh(x) order 3: x + (1/6) x^3
        const exprSinh = Sinh(x);
        final taylorSinh = exprSinh.taylorSeries('x', order: 3);
        final taylorSinhFn = taylorSinh.toFunction1D('x');
        final sinhFn = exprSinh.toFunction1D('x');
        for (final t in [-0.4, -0.2, 0.0, 0.2, 0.4]) {
          check(taylorSinhFn(t)).isCloseTo(sinhFn(t), 1e-4);
        }

        // 3. Cosh(x) order 4: 1 + (1/2) x^2 + (1/24) x^4
        const exprCosh = Cosh(x);
        final taylorCosh = exprCosh.taylorSeries('x', order: 4);
        final taylorCoshFn = taylorCosh.toFunction1D('x');
        final coshFn = exprCosh.toFunction1D('x');
        for (final t in [-0.5, -0.2, 0.0, 0.2, 0.5]) {
          check(taylorCoshFn(t)).isCloseTo(coshFn(t), 1e-4);
        }

        // 4. Atan(x) order 3: x - (1/3) x^3
        const exprAtan = Atan(x);
        final taylorAtan = exprAtan.taylorSeries('x', order: 3);
        final taylorAtanFn = taylorAtan.toFunction1D('x');
        final atanFn = exprAtan.toFunction1D('x');
        for (final t in [-0.3, -0.1, 0.0, 0.1, 0.3]) {
          check(taylorAtanFn(t)).isCloseTo(atanFn(t), 1e-3);
        }

        // 5. Asin(x) order 3: x + (1/6) x^3
        const exprAsin = Asin(x);
        final taylorAsin = exprAsin.taylorSeries('x', order: 3);
        final taylorAsinFn = taylorAsin.toFunction1D('x');
        final asinFn = exprAsin.toFunction1D('x');
        for (final t in [-0.3, -0.1, 0.0, 0.1, 0.3]) {
          check(taylorAsinFn(t)).isCloseTo(asinFn(t), 1e-3);
        }
      });

      test('Taylor expansion around non-zero point for Sqrt(x)', () {
        // Sqrt(x) around a = 1, order 2: 1 + 0.5 * (x - 1) - 0.125 * (x - 1)^2
        const exprSqrt = Sqrt(x);
        final taylorSqrt = exprSqrt.taylorSeries('x', around: 1, order: 2);
        final taylorSqrtFn = taylorSqrt.toFunction1D('x');
        final sqrtFn = exprSqrt.toFunction1D('x');

        for (final t in [0.85, 0.95, 1.0, 1.05, 1.15]) {
          check(taylorSqrtFn(t)).isCloseTo(sqrtFn(t), 1e-3);
        }
      });
    },
  );

  group('Empirical Challenge 7: Hyperbolic & Transcendental Algebraic Rewrite Reductions', () {
    test('hyperbolic and trigonometric Pythagorean identity reductions', () {
      // cosh^2(x) - sinh^2(x) => 1
      final cosh2SubSinh2 =
          const Cosh(x).pow(const RationalNumber(2)) -
          const Sinh(x).pow(const RationalNumber(2));
      check(cosh2SubSinh2.simplify()).equals(const RationalNumber(1));

      // 1 + sinh^2(x) => cosh^2(x)
      final oneAddSinh2 =
          const RationalNumber(1) + const Sinh(x).pow(const RationalNumber(2));
      check(oneAddSinh2.simplify())
          .equals(const Cosh(x).pow(const RationalNumber(2)));

      // sin^2(x) + cos^2(x) => 1
      final sin2AddCos2 =
          const Sin(x).pow(const RationalNumber(2)) +
          const Cos(x).pow(const RationalNumber(2));
      check(sin2AddCos2.simplify()).equals(const RationalNumber(1));

      // 1 - sin^2(x) => cos^2(x)
      final oneSubSin2 =
          const RationalNumber(1) - const Sin(x).pow(const RationalNumber(2));
      check(oneSubSin2.simplify())
          .equals(const Cos(x).pow(const RationalNumber(2)));
    });

    test('involutions and parity simplifications', () {
      // tan(atan(x)) => x
      check(const Tan(Atan(x)).simplify()).equals(x);

      // atan(tan(x)) => x
      check(const Atan(Tan(x)).simplify()).equals(x);

      // sin(asin(x)) => x
      check(const Sin(Asin(x)).simplify()).equals(x);

      // asin(sin(x)) => x
      check(const Asin(Sin(x)).simplify()).equals(x);

      // cos(acos(x)) => x
      check(const Cos(Acos(x)).simplify()).equals(x);

      // acos(cos(x)) => x
      check(const Acos(Cos(x)).simplify()).equals(x);

      // ||x|| => |x|
      check(const Abs(Abs(x)).simplify()).equals(const Abs(x));

      // |exp(x)| => exp(x)
      check(const Abs(Exp(x)).simplify()).equals(const Exp(x));

      // sqrt(x^2) => |x|
      check(Sqrt(x.pow(const RationalNumber(2))).simplify())
          .equals(const Abs(x));

      // e^ln(x) => x
      check(const Exp(Ln(x)).simplify()).equals(x);

      // ln(e^x) => x
      check(const Ln(Exp(x)).simplify()).equals(x);
    });

    test('constant evaluation exact reductions', () {
      check(const Tan(RationalNumber(0)).simplify())
          .equals(const RationalNumber(0));
      check(const Sinh(RationalNumber(0)).simplify())
          .equals(const RationalNumber(0));
      check(const Cosh(RationalNumber(0)).simplify())
          .equals(const RationalNumber(1));
      check(const Tanh(RationalNumber(0)).simplify())
          .equals(const RationalNumber(0));
      check(const Atan(RationalNumber(0)).simplify())
          .equals(const RationalNumber(0));
      check(const Asin(RationalNumber(0)).simplify())
          .equals(const RationalNumber(0));
      check(const Acos(RationalNumber(1)).simplify())
          .equals(const RationalNumber(0));
      check(const Sqrt(RationalNumber(0)).simplify())
          .equals(const RationalNumber(0));
      check(const Sqrt(RationalNumber(1)).simplify())
          .equals(const RationalNumber(1));
      check(const Sqrt(RationalNumber(4)).simplify())
          .equals(const RationalNumber(2));
      check(const Sqrt(RationalNumber(9, 16)).simplify())
          .equals(const RationalNumber(3, 4));
      check(const Abs(RationalNumber(-42, 5)).simplify())
          .equals(const RationalNumber(42, 5));
    });
  });
}
