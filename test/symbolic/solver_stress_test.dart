import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/test.dart';

void main() {
  const x = Variable('x');
  const y = Variable('y');

  /// Helper to verify empirical root residual |expr(r)| < tolerance
  void checkRootResidual(Expr equation, Expr root, {double tol = 1e-10}) {
    final rootVal = root.evaluateComplex();
    final residual = equation.evaluateComplex({'x': rootVal});
    check(residual.abs()).isLessThan(tol);
  }

  group('M4 Empirical Stress: Quadratic Complex Roots Oracle', () {
    test('standard imaginary roots x^2 + c = 0 (c > 0)', () {
      final constants = [1, 2, 3, 4, 9, 16, 25, 100];
      for (final c in constants) {
        final eq = x.pow(const RationalNumber(2)) + RationalNumber(c);
        final roots = eq.solve('x');
        check(roots.length).equals(2);
        for (final r in roots) {
          checkRootResidual(eq, r);
        }
        final c1 = roots[0].evaluateComplex();
        final c2 = roots[1].evaluateComplex();
        check(c1.a.abs()).isLessThan(1e-10);
        check(c2.a.abs()).isLessThan(1e-10);
        check((c1.b + c2.b).abs()).isLessThan(1e-10);
        check(c1.b.abs()).isCloseTo(math.sqrt(c.toDouble()), 1e-10);
      }
    });

    test('complex roots with non-zero real part: x^2 + bx + c = 0', () {
      final testCases = [
        (2, 2),
        (-2, 2),
        (2, 5),
        (-4, 13),
        (6, 10),
        (-6, 25),
        (1, 1),
        (-1, 1),
      ];
      for (final (bVal, cVal) in testCases) {
        final eq =
            x.pow(const RationalNumber(2)) +
            RationalNumber(bVal) * x +
            RationalNumber(cVal);
        final roots = eq.solve('x');
        check(roots.length).equals(2);
        for (final r in roots) {
          checkRootResidual(eq, r);
        }
        final c1 = roots[0].evaluateComplex();
        final c2 = roots[1].evaluateComplex();
        check(c1.a).isCloseTo(-bVal / 2.0, 1e-10);
        check(c2.a).isCloseTo(-bVal / 2.0, 1e-10);
        check((c1.b + c2.b).abs()).isLessThan(1e-10);
      }
    });

    test(
      'quadratic with arbitrary leading coefficient: a*x^2 + b*x + c = 0',
      () {
        final testCases = [
          (2, 2, 5),
          (3, -2, 3),
          (-1, 2, -5),
          (-2, -4, -10),
          (4, 0, 9),
        ];
        for (final (aVal, bVal, cVal) in testCases) {
          final eq =
              RationalNumber(aVal) * x.pow(const RationalNumber(2)) +
              RationalNumber(bVal) * x +
              RationalNumber(cVal);
          final roots = eq.solve('x');
          check(roots.length).equals(2);
          for (final r in roots) {
            checkRootResidual(eq, r);
          }
        }
      },
    );

    test('quadratic with RealNumber coefficients', () {
      final eq =
          const RealNumber(1.0) * x.pow(const RationalNumber(2)) +
          const RealNumber(2.0) * x +
          const RealNumber(5.0);
      final roots = eq.solve('x');
      check(roots.length).equals(2);
      for (final r in roots) {
        checkRootResidual(eq, r);
      }

      // Degenerate leading coefficient RealNumber(0.0)
      final eqDegen =
          const RealNumber(0.0) * x.pow(const RationalNumber(2)) +
          const RationalNumber(2) * x -
          const RationalNumber(4);
      final rootsDegen = eqDegen.solve('x');
      check(rootsDegen.length).equals(1);
      check(rootsDegen.first.evaluate(const {})).isCloseTo(2.0, 1e-10);
    });

    test('quadratic with complex constants and imaginary coefficients', () {
      // x^2 - i = 0 -> roots are +/- sqrt(i)
      final eq1 = x.pow(const RationalNumber(2)) - i;
      final roots1 = eq1.solve('x');
      check(roots1.length).equals(2);
      for (final r in roots1) {
        checkRootResidual(eq1, r);
      }

      // (x - i)^2 = x^2 - 2*i*x - 1 = 0 -> root is i
      final eq2 =
          x.pow(const RationalNumber(2)) -
          const RationalNumber(2) * i * x -
          const RationalNumber(1);
      final roots2 = eq2.solve('x');
      check(roots2).isNotEmpty();
      for (final r in roots2) {
        checkRootResidual(eq2, r);
      }

      // x^2 + 2*i*x + 3 = 0 -> roots are i, -3i
      final eq3 =
          x.pow(const RationalNumber(2)) +
          const RationalNumber(2) * i * x +
          const RationalNumber(3);
      final roots3 = eq3.solve('x');
      check(roots3.length).equals(2);
      for (final r in roots3) {
        checkRootResidual(eq3, r);
      }
    });
  });

  group('M4 Empirical Stress: Trigonometric Equations Oracle', () {
    test('fundamental special angles for sin(x) = c', () {
      final testCases = [
        (RationalNumber.zero, [0.0, math.pi]),
        (const RationalNumber(1), [math.pi / 2]),
        (const RationalNumber(-1), [3 * math.pi / 2]),
        (const RationalNumber(1, 2), [math.pi / 6, 5 * math.pi / 6]),
        (const RationalNumber(-1, 2), [7 * math.pi / 6, 11 * math.pi / 6]),
      ];
      for (final (c, expectedAngles) in testCases) {
        final eq = const Sin(x) - c;
        final roots = eq.solve('x');
        for (final r in roots) {
          checkRootResidual(eq, r);
        }
        for (final expAngle in expectedAngles) {
          check(
            roots.any((r) {
              final val = r.evaluateComplex();
              return (val.a - expAngle).abs() < 1e-10 && val.b.abs() < 1e-10;
            }),
          ).isTrue();
        }
      }
    });

    test('fundamental special angles for cos(x) = c', () {
      final testCases = [
        (RationalNumber.zero, [math.pi / 2, 3 * math.pi / 2]),
        (const RationalNumber(1), [0.0]),
        (const RationalNumber(-1), [math.pi]),
        (const RationalNumber(1, 2), [math.pi / 3, 5 * math.pi / 3]),
        (const RationalNumber(-1, 2), [2 * math.pi / 3, 4 * math.pi / 3]),
      ];
      for (final (c, expectedAngles) in testCases) {
        final eq = const Cos(x) - c;
        final roots = eq.solve('x');
        for (final r in roots) {
          checkRootResidual(eq, r);
        }
        for (final expAngle in expectedAngles) {
          check(
            roots.any((r) {
              final val = r.evaluateComplex();
              return (val.a - expAngle).abs() < 1e-10 && val.b.abs() < 1e-10;
            }),
          ).isTrue();
        }
      }
    });

    test('fundamental special angles for tan(x) = c', () {
      final testCases = [
        (RationalNumber.zero, [0.0, math.pi]),
        (const RationalNumber(1), [math.pi / 4, 5 * math.pi / 4]),
        (const RationalNumber(-1), [3 * math.pi / 4, 7 * math.pi / 4]),
      ];
      for (final (c, expectedAngles) in testCases) {
        final eq = const Tan(x) - c;
        final roots = eq.solve('x');
        for (final r in roots) {
          checkRootResidual(eq, r);
        }
        for (final expAngle in expectedAngles) {
          check(
            roots.any((r) {
              final val = r.evaluateComplex();
              return (val.a - expAngle).abs() < 1e-10 && val.b.abs() < 1e-10;
            }),
          ).isTrue();
        }
      }
    });

    test('non-special angle trigonometric equations', () {
      final nonSpecialVals = [
        const RationalNumber(1, 3),
        const RationalNumber(-1, 3),
        const RationalNumber(2, 5),
        const RationalNumber(-3, 4),
        const RationalNumber(1, 10),
      ];
      for (final c in nonSpecialVals) {
        final eqSin = const Sin(x) - c;
        final rootsSin = eqSin.solve('x');
        check(rootsSin).isNotEmpty();
        for (final r in rootsSin) {
          checkRootResidual(eqSin, r);
        }

        final eqCos = const Cos(x) - c;
        final rootsCos = eqCos.solve('x');
        check(rootsCos).isNotEmpty();
        for (final r in rootsCos) {
          checkRootResidual(eqCos, r);
        }

        final eqTan = const Tan(x) - c;
        final rootsTan = eqTan.solve('x');
        check(rootsTan).isNotEmpty();
        for (final r in rootsTan) {
          checkRootResidual(eqTan, r);
        }
      }
    });

    test('tan(x) outside [-1, 1]', () {
      final tanVals = [
        const RationalNumber(2),
        const RationalNumber(-5),
        const RationalNumber(10),
      ];
      for (final c in tanVals) {
        final eq = const Tan(x) - c;
        final roots = eq.solve('x');
        check(roots).isNotEmpty();
        for (final r in roots) {
          checkRootResidual(eq, r);
        }
      }
    });

    test('affine scaled arguments in trig functions', () {
      final eq1 = Sin(const RationalNumber(2) * x);
      final roots1 = eq1.solve('x');
      check(roots1).isNotEmpty();
      for (final r in roots1) {
        checkRootResidual(eq1, r);
      }

      final eq2 = Cos(const RationalNumber(3) * x);
      final roots2 = eq2.solve('x');
      check(roots2).isNotEmpty();
      for (final r in roots2) {
        checkRootResidual(eq2, r);
      }

      final eq3 = Tan(const RationalNumber(2) * x) - const RationalNumber(1);
      final roots3 = eq3.solve('x');
      check(roots3).isNotEmpty();
      for (final r in roots3) {
        checkRootResidual(eq3, r);
      }

      // 2 * sin(3x) - 1 = 0
      final eq4 =
          const RationalNumber(2) * Sin(const RationalNumber(3) * x) -
          const RationalNumber(1);
      final roots4 = eq4.solve('x');
      check(roots4).isNotEmpty();
      for (final r in roots4) {
        checkRootResidual(eq4, r);
      }
    });

    test('reciprocal trigonometric division', () {
      final eq =
          (const RationalNumber(1) / const Sin(x)) - const RationalNumber(2);
      final roots = eq.solve('x');
      check(roots).isNotEmpty();
      for (final r in roots) {
        checkRootResidual(eq, r);
      }
    });

    test('inverse trigonometric equations', () {
      final eqAsin =
          const Asin(x) - const Mul(RationalNumber(1, 6), ConstantNumber.pi);
      final rootsAsin = eqAsin.solve('x');
      check(rootsAsin.length).equals(1);
      checkRootResidual(eqAsin, rootsAsin.first);

      final eqAcos =
          const Acos(x) - const Mul(RationalNumber(1, 3), ConstantNumber.pi);
      final rootsAcos = eqAcos.solve('x');
      check(rootsAcos.length).equals(1);
      checkRootResidual(eqAcos, rootsAcos.first);

      final eqAtan =
          const Atan(x) - const Mul(RationalNumber(1, 4), ConstantNumber.pi);
      final rootsAtan = eqAtan.solve('x');
      check(rootsAtan.length).equals(1);
      checkRootResidual(eqAtan, rootsAtan.first);
    });

    test('trigonometric out-of-bounds yields no solutions', () {
      check((const Sin(x) - const RationalNumber(2)).solve('x')).isEmpty();
      check((const Sin(x) + const RationalNumber(3)).solve('x')).isEmpty();
      check((const Cos(x) - const RationalNumber(5, 2)).solve('x')).isEmpty();
      check((const Cos(x) + const RationalNumber(11, 10)).solve('x')).isEmpty();
      check((const Sin(x) - const RealNumber(1.0001)).solve('x')).isEmpty();
      check((const Cos(x) + const RealNumber(1.5)).solve('x')).isEmpty();
    });
  });

  group('M4 Empirical Stress: Higher-Degree Polynomials Oracle', () {
    test('factored cubics with 3 real roots', () {
      final eq =
          x.pow(const RationalNumber(3)) -
          const RationalNumber(4) * x.pow(const RationalNumber(2)) -
          const RationalNumber(11) * x +
          const RationalNumber(30);
      final roots = eq.solve('x');
      check(roots.length).equals(3);
      for (final r in roots) {
        checkRootResidual(eq, r);
      }
    });

    test('polynomial with factor x: x^3 - x = 0', () {
      final eq = x.pow(const RationalNumber(3)) - x;
      final roots = eq.solve('x');
      check(roots.length).equals(3);
      check(roots).contains(RationalNumber.zero);
      check(roots).contains(const RationalNumber(1));
      check(roots).contains(const RationalNumber(-1));
      for (final r in roots) {
        checkRootResidual(eq, r);
      }
    });

    test('cubics with 1 real root and 2 complex roots', () {
      final eq =
          x.pow(const RationalNumber(3)) -
          const RationalNumber(4) * x.pow(const RationalNumber(2)) +
          const RationalNumber(9) * x -
          const RationalNumber(36);
      final roots = eq.solve('x');
      check(roots.length).equals(3);
      for (final r in roots) {
        checkRootResidual(eq, r);
      }
      check(roots).contains(const RationalNumber(4));
      check(roots).contains(const RationalNumber(3) * i);
      check(roots).contains(const RationalNumber(-3) * i);
    });

    test('cubic with rational fractional roots: 12x^3 - 8x^2 - 3x + 2 = 0', () {
      final eq =
          const RationalNumber(12) * x.pow(const RationalNumber(3)) -
          const RationalNumber(8) * x.pow(const RationalNumber(2)) -
          const RationalNumber(3) * x +
          const RationalNumber(2);
      final roots = eq.solve('x');
      check(roots.length).equals(3);
      for (final r in roots) {
        checkRootResidual(eq, r);
      }
      check(roots).contains(const RationalNumber(1, 2));
      check(roots).contains(const RationalNumber(-1, 2));
      check(roots).contains(const RationalNumber(2, 3));
    });

    test('binomial cubics with positive and negative constants', () {
      final testCases = [
        (8, 2.0),
        (-8, -2.0),
        (27, 3.0),
        (-27, -3.0),
        (64, 4.0),
        (-64, -4.0),
        (125, 5.0),
        (-125, -5.0),
      ];
      for (final (cVal, expRoot) in testCases) {
        final eq = x.pow(const RationalNumber(3)) - RationalNumber(cVal);
        final roots = eq.solve('x');
        check(roots).isNotEmpty();
        for (final r in roots) {
          checkRootResidual(eq, r);
        }
        check(
          roots.any(
            (r) =>
                (r.evaluateComplex().a - expRoot).abs() < 1e-10 &&
                r.evaluateComplex().b.abs() < 1e-10,
          ),
        ).isTrue();
      }
    });

    test('biquadratics with 4 real roots', () {
      final eq =
          x.pow(const RationalNumber(4)) -
          const RationalNumber(13) * x.pow(const RationalNumber(2)) +
          const RationalNumber(36);
      final roots = eq.solve('x');
      check(roots.length).equals(4);
      for (final r in roots) {
        checkRootResidual(eq, r);
      }
      check(roots).contains(const RationalNumber(2));
      check(roots).contains(const RationalNumber(-2));
      check(roots).contains(const RationalNumber(3));
      check(roots).contains(const RationalNumber(-3));
    });

    test(
      'biquadratic with negative leading coefficient: -x^4 + 5x^2 - 4 = 0',
      () {
        final eq =
            -x.pow(const RationalNumber(4)) +
            const RationalNumber(5) * x.pow(const RationalNumber(2)) -
            const RationalNumber(4);
        final roots = eq.solve('x');
        check(roots.length).equals(4);
        for (final r in roots) {
          checkRootResidual(eq, r);
        }
        check(roots).contains(const RationalNumber(1));
        check(roots).contains(const RationalNumber(-1));
        check(roots).contains(const RationalNumber(2));
        check(roots).contains(const RationalNumber(-2));
      },
    );

    test('biquadratics with 4 complex roots', () {
      final eq =
          x.pow(const RationalNumber(4)) +
          const RationalNumber(13) * x.pow(const RationalNumber(2)) +
          const RationalNumber(36);
      final roots = eq.solve('x');
      check(roots.length).equals(4);
      for (final r in roots) {
        checkRootResidual(eq, r);
      }
      check(roots).contains(const RationalNumber(2) * i);
      check(roots).contains(const RationalNumber(-2) * i);
      check(roots).contains(const RationalNumber(3) * i);
      check(roots).contains(const RationalNumber(-3) * i);
    });

    test('biquadratic x^4 + 1 = 0 with 4 complex roots', () {
      final eq = x.pow(const RationalNumber(4)) + const RationalNumber(1);
      final roots = eq.solve('x');
      check(roots.length).equals(4);
      for (final r in roots) {
        checkRootResidual(eq, r);
      }
    });

    test('biquadratics with 2 real and 2 complex roots', () {
      final eq = x.pow(const RationalNumber(4)) - const RationalNumber(81);
      final roots = eq.solve('x');
      check(roots.length).equals(4);
      for (final r in roots) {
        checkRootResidual(eq, r);
      }
      check(roots).contains(const RationalNumber(3));
      check(roots).contains(const RationalNumber(-3));
      check(roots).contains(const RationalNumber(3) * i);
      check(roots).contains(const RationalNumber(-3) * i);
    });

    test('biquadratic with negative constant: x^4 - 2x^2 - 8 = 0', () {
      // (x^2 - 4)(x^2 + 2) = x^4 - 2x^2 - 8 = 0 -> +/- 2, +/- sqrt(2)i
      final eq =
          x.pow(const RationalNumber(4)) -
          const RationalNumber(2) * x.pow(const RationalNumber(2)) -
          const RationalNumber(8);
      final roots = eq.solve('x');
      check(roots.length).equals(4);
      for (final r in roots) {
        checkRootResidual(eq, r);
      }
      check(roots).contains(const RationalNumber(2));
      check(roots).contains(const RationalNumber(-2));
    });

    test('degree 5 polynomial factoring: x(x^2 - 1)(x^2 - 9) = 0', () {
      final eq =
          x.pow(const RationalNumber(5)) -
          const RationalNumber(10) * x.pow(const RationalNumber(3)) +
          const RationalNumber(9) * x;
      final roots = eq.solve('x');
      check(roots.length).equals(5);
      for (final r in roots) {
        checkRootResidual(eq, r);
      }
      check(roots).contains(RationalNumber.zero);
      check(roots).contains(const RationalNumber(1));
      check(roots).contains(const RationalNumber(-1));
      check(roots).contains(const RationalNumber(3));
      check(roots).contains(const RationalNumber(-3));
    });

    test('degree 5 odd power binomials without NaN', () {
      final eq1 = x.pow(const RationalNumber(5)) - const RationalNumber(243);
      final roots1 = eq1.solve('x');
      check(roots1).contains(const RationalNumber(3));
      for (final r in roots1) {
        checkRootResidual(eq1, r);
      }

      final eq2 = x.pow(const RationalNumber(5)) + const RationalNumber(243);
      final roots2 = eq2.solve('x');
      check(roots2).contains(const RationalNumber(-3));
      for (final r in roots2) {
        checkRootResidual(eq2, r);
      }
    });

    test('high-order binomial: x^6 - 64 = 0', () {
      final eq = x.pow(const RationalNumber(6)) - const RationalNumber(64);
      final roots = eq.solve('x');
      check(roots).contains(const RationalNumber(2));
      check(roots).contains(const RationalNumber(-2));
      for (final r in roots) {
        checkRootResidual(eq, r);
      }
    });

    test('randomized polynomial generator oracle', () {
      final rng = math.Random(1337);
      for (var iter = 0; iter < 50; iter++) {
        final r1 = rng.nextInt(21) - 10;
        final r2 = rng.nextInt(21) - 10;
        final eq = (x - RationalNumber(r1)) * (x - RationalNumber(r2));
        final roots = eq.solve('x');
        check(roots).isNotEmpty();
        for (final r in roots) {
          checkRootResidual(eq, r);
        }
      }

      for (var iter = 0; iter < 25; iter++) {
        final r1 = rng.nextInt(11) - 5;
        final r2 = rng.nextInt(11) - 5;
        final r3 = rng.nextInt(11) - 5;
        final eq =
            (x - RationalNumber(r1)) *
            (x - RationalNumber(r2)) *
            (x - RationalNumber(r3));
        final roots = eq.solve('x');
        check(roots).isNotEmpty();
        for (final r in roots) {
          checkRootResidual(eq, r);
        }
      }
    });
  });

  group('M4 Empirical Stress: Edge Cases and Boundaries', () {
    test('zero roots / contradictory equations', () {
      check(const RationalNumber(7).solve('x')).isEmpty();
      check(((x + const RationalNumber(2)) - x).solve('x')).isEmpty();
      check(const Exp(x).solve('x')).isEmpty();
      check((const Exp(x) + const RationalNumber(1)).solve('x')).isEmpty();
      check((const Exp(x) + const RationalNumber(5)).solve('x')).isEmpty();

      // Reciprocal divisors with zero RHS return empty list []
      check((const RationalNumber(1) / x).solve('x')).isEmpty();
      check((const RationalNumber(1) / const Sin(x)).solve('x')).isEmpty();
    });

    test('repeated roots deduplicate cleanly', () {
      final eq1 = (x - const RationalNumber(5)).pow(const RationalNumber(2));
      final roots1 = eq1.solve('x');
      check(roots1.length).equals(1);
      check(roots1.first).equals(const RationalNumber(5));

      final eq2 = (x + const RationalNumber(4)).pow(const RationalNumber(3));
      final roots2 = eq2.solve('x');
      check(roots2.length).equals(1);
      check(roots2.first).equals(const RationalNumber(-4));

      final eq3 = (x.pow(const RationalNumber(2)) + const RationalNumber(1))
          .pow(const RationalNumber(2));
      final roots3 = eq3.solve('x');
      check(roots3.length).equals(2);
      check(roots3).contains(i);
      check(roots3).contains(-i);

      final eq4 = (x - const RationalNumber(2)).pow(const RationalNumber(5));
      final roots4 = eq4.solve('x');
      check(roots4.length).equals(1);
      check(roots4.first).equals(const RationalNumber(2));
    });

    test('transcendental combinations and composite equations', () {
      final eq1 = const Sin(x) * (x - const RationalNumber(2));
      final roots1 = eq1.solve('x');
      check(roots1).contains(RationalNumber.zero);
      check(roots1).contains(ConstantNumber.pi);
      check(roots1).contains(const RationalNumber(2));
      for (final r in roots1) {
        checkRootResidual(eq1, r);
      }

      final eq2 =
          Exp(const RationalNumber(2) * x - const RationalNumber(6)) -
          const RationalNumber(1);
      final roots2 = eq2.solve('x');
      check(roots2.length).equals(1);
      check(roots2.first.evaluate(const {})).isCloseTo(3.0, 1e-10);
      checkRootResidual(eq2, roots2.first);

      final eq3 = Ln(const RationalNumber(2) * x) - const RationalNumber(1);
      final roots3 = eq3.solve('x');
      check(roots3.length).equals(1);
      checkRootResidual(eq3, roots3.first);

      // exp(x^2) - 1 = 0 -> x = 0
      final eq4 = Exp(x.pow(const RationalNumber(2))) - const RationalNumber(1);
      final roots4 = eq4.solve('x');
      check(roots4).contains(RationalNumber.zero);
      for (final r in roots4) {
        checkRootResidual(eq4, r);
      }

      // ln(x^2 + 1) = 0 -> x = 0
      final eq5 = Ln(x.pow(const RationalNumber(2)) + const RationalNumber(1));
      final roots5 = eq5.solve('x');
      check(roots5).contains(RationalNumber.zero);
      for (final r in roots5) {
        checkRootResidual(eq5, r);
      }

      // sin(x^2 - 1) = 0 -> x^2 - 1 = 0 -> x = +/- 1
      final eq6 = Sin(x.pow(const RationalNumber(2)) - const RationalNumber(1));
      final roots6 = eq6.solve('x');
      check(roots6).contains(const RationalNumber(1));
      check(roots6).contains(const RationalNumber(-1));
      for (final r in roots6) {
        checkRootResidual(eq6, r);
      }

      // 1 / x^2 - 4 = 0 -> x^2 = 1/4 -> x = +/- 1/2
      final eq7 =
          (const RationalNumber(1) / x.pow(const RationalNumber(2))) -
          const RationalNumber(4);
      final roots7 = eq7.solve('x');
      check(roots7).contains(const RationalNumber(1, 2));
      check(roots7).contains(const RationalNumber(-1, 2));
      for (final r in roots7) {
        checkRootResidual(eq7, r);
      }
    });

    test('linear systems solving edge cases', () {
      final sol1 = [const RationalNumber(3) * x - const RationalNumber(9)]
          .solveSystem(['x']);
      check(sol1).isNotNull();
      check(sol1!['x']!.evaluate(const {})).isCloseTo(3.0, 1e-10);

      final sol2 = [
        const RationalNumber(2) * x - const RationalNumber(4),
        const RationalNumber(5) * y - const RationalNumber(15),
      ].solveSystem(['x', 'y']);
      check(sol2).isNotNull();
      check(sol2!['x']!.evaluate(const {})).isCloseTo(2.0, 1e-10);
      check(sol2['y']!.evaluate(const {})).isCloseTo(3.0, 1e-10);

      final solPivot = [
        y - const RationalNumber(4),
        x + y - const RationalNumber(7),
      ].solveSystem(['x', 'y']);
      check(solPivot).isNotNull();
      check(solPivot!['x']!.evaluate(const {})).isCloseTo(3.0, 1e-10);
      check(solPivot['y']!.evaluate(const {})).isCloseTo(4.0, 1e-10);

      final solSingular = [
        x + y - const RationalNumber(1),
        x + y - const RationalNumber(2),
      ].solveSystem(['x', 'y']);
      check(solSingular).isNull();

      final solUnder = [
        x + y - const RationalNumber(2),
        const RationalNumber(2) * x +
            const RationalNumber(2) * y -
            const RationalNumber(4),
      ].solveSystem(['x', 'y']);
      check(solUnder).isNull();
    });
  });
}
