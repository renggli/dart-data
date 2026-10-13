import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/scaffolding.dart';

void main() {
  const x = Variable('x');
  const y = Variable('y');
  const z = Variable('z');

  void checkRootResidual(Expr equation, Expr root, {double tol = 1e-10}) {
    final rootVal = root.evaluateComplex();
    final residual = equation.evaluateComplex({'x': rootVal});
    check(residual.abs()).isLessThan(tol);
  }

  group('Linear equations and systems', () {
    test('linear equations', () {
      // 2x - 6 = 0 -> x = 3
      final eq1 = const RationalNumber(2) * x - const RationalNumber(6);
      final sol1 = eq1.solve('x');
      check(sol1.length).equals(1);
      check(sol1.first.evaluate(const {})).equals(3.0);

      // 5 - x = 0 -> x = 5
      final eq2 = const RationalNumber(5) - x;
      final sol2 = eq2.solve('x');
      check(sol2.length).equals(1);
      check(sol2.first.evaluate(const {})).equals(5.0);

      // Symbolic linear: 2x + y - 4 = 0 -> x = (4 - y) / 2
      final eq3 = const RationalNumber(2) * x + y - const RationalNumber(4);
      final sol3 = eq3.solve('x');
      check(sol3.length).equals(1);
      check(sol3.first.evaluate({'y': 2.0})).equals(1.0);
      check(sol3.first.evaluate({'y': 0.0})).equals(2.0);
    });

    test('2x2 linear system solving', () {
      // 2x + y - 5 = 0
      // x - y - 1 = 0
      // Solution: x = 2, y = 1
      final eq1 = const RationalNumber(2) * x + y - const RationalNumber(5);
      final eq2 = x - y - const RationalNumber(1);

      final sol = [eq1, eq2].solveSystem(['x', 'y']);
      check(sol).isNotNull();
      check(sol!['x']!.evaluate(const {})).isCloseTo(2.0, 1e-9);
      check(sol['y']!.evaluate(const {})).isCloseTo(1.0, 1e-9);
    });

    test('3x3 linear system solving', () {
      // x + y + z - 6 = 0
      // 2y + 5z - 19 = 0
      // 2x + 4y - 3z - 1 = 0
      // Solution: x = 1, y = 2, z = 3
      final eq1 = x + y + z - const RationalNumber(6);
      final eq2 =
          const RationalNumber(2) * y +
          const RationalNumber(5) * z -
          const RationalNumber(19);
      final eq3 =
          const RationalNumber(2) * x +
          const RationalNumber(4) * y -
          const RationalNumber(3) * z -
          const RationalNumber(1);

      final sol = [eq1, eq2, eq3].solveSystem(['x', 'y', 'z']);
      check(sol).isNotNull();
      check(sol!['x']!.evaluate(const {})).isCloseTo(1.0, 1e-9);
      check(sol['y']!.evaluate(const {})).isCloseTo(2.0, 1e-9);
      check(sol['z']!.evaluate(const {})).isCloseTo(3.0, 1e-9);
    });

    test('singular system returns null', () {
      // Parallel lines: x + y - 1 = 0 and x + y - 2 = 0
      final eq1 = x + y - const RationalNumber(1);
      final eq2 = x + y - const RationalNumber(2);

      final sol = [eq1, eq2].solveSystem(['x', 'y']);
      check(sol).isNull();
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

  group('Quadratic equations & complex roots', () {
    test('quadratic equations with real roots', () {
      // x^2 - 5x + 6 = 0 -> x = 2, 3
      final eq1 =
          x.pow(const RationalNumber(2)) -
          const RationalNumber(5) * x +
          const RationalNumber(6);
      final sol1 = eq1.solve('x');
      check(sol1.length).equals(2);
      final vals1 = sol1.map((s) => s.evaluate(const {})).toList()..sort();
      check(vals1[0]).isCloseTo(2.0, 1e-9);
      check(vals1[1]).isCloseTo(3.0, 1e-9);

      // x^2 - 4 = 0 -> x = -2, 2
      final eq2 = x.pow(const RationalNumber(2)) - const RationalNumber(4);
      final sol2 = eq2.solve('x');
      check(sol2.length).equals(2);
      final vals2 = sol2.map((s) => s.evaluate(const {})).toList()..sort();
      check(vals2[0]).isCloseTo(-2.0, 1e-9);
      check(vals2[1]).isCloseTo(2.0, 1e-9);

      // Double root: (x - 3)^2 = x^2 - 6x + 9 = 0 -> x = 3
      final eq3 =
          x.pow(const RationalNumber(2)) -
          const RationalNumber(6) * x +
          const RationalNumber(9);
      final sol3 = eq3.solve('x');
      check(sol3.length).equals(1);
      check(sol3.first.evaluate(const {})).isCloseTo(3.0, 1e-9);
    });

    test('quadratic equations with complex roots', () {
      // Complex roots for negative discriminant: x^2 + 1 = 0 -> x = i, -i
      final eq4 = x.pow(const RationalNumber(2)) + const RationalNumber(1);
      final sol4 = eq4.solve('x');
      check(sol4).deepEquals([i, -i]);

      // Complex roots with real and imaginary parts: x^2 + 2x + 2 = 0 -> x = -1 + i, -1 - i
      final eq5 =
          x.pow(const RationalNumber(2)) +
          const RationalNumber(2) * x +
          const RationalNumber(2);
      final sol5 = eq5.solve('x');
      check(sol5).deepEquals([
        const RationalNumber(-1) + i,
        const RationalNumber(-1) - i,
      ]);

      // Complex roots with fractional real and radical imaginary parts: x^2 + x + 1 = 0
      final eq6 = x.pow(const RationalNumber(2)) + x + const RationalNumber(1);
      final sol6 = eq6.solve('x');
      check(sol6.length).equals(2);
      check(sol6[0].toString()).equals('-1/2 + 1/2 * i * sqrt(3)');
      check(sol6[1].toString()).equals('-1/2 - 1/2 * i * sqrt(3)');
    });

    test('quadratic equations with negative discriminants evaluation', () {
      final eq = x.pow(const RationalNumber(2)) + const RationalNumber(3);
      final roots = eq.solve('x');
      check(roots.length).equals(2);

      for (final root in roots) {
        final cVal = root.evaluateComplex();
        check(cVal.a.abs()).isLessThan(1e-12);
        check((cVal.b.abs() - math.sqrt(3)).abs()).isLessThan(1e-12);

        final eqVal = eq.evaluateComplex({'x': cVal});
        check(eqVal.a.abs()).isLessThan(1e-12);
        check(eqVal.b.abs()).isLessThan(1e-12);

        final symSub = eq.substitute('x', root).simplify();
        check(symSub.evaluateComplex().abs()).isLessThan(1e-12);
        check(eq.substitute('x', root).expand().simplify())
            .equals(RationalNumber.zero);
      }

      // 4x^2 + 4x + 5 = 0 -> roots: -1/2 + i, -1/2 - i
      final eq4x =
          const RationalNumber(4) * x.pow(const RationalNumber(2)) +
          const RationalNumber(4) * x +
          const RationalNumber(5);
      final roots4x = eq4x.solve('x');
      check(roots4x.length).equals(2);
      for (final root in roots4x) {
        final cVal = root.evaluateComplex();
        check((cVal.a - (-0.5)).abs()).isLessThan(1e-12);
        check((cVal.b.abs() - 1.0).abs()).isLessThan(1e-12);
        check(eq4x.substitute('x', root).expand().simplify())
            .equals(RationalNumber.zero);
      }

      // 2x^2 + 3 = 0 -> roots: +/- i * sqrt(3/2)
      final eq2x =
          const RationalNumber(2) * x.pow(const RationalNumber(2)) +
          const RationalNumber(3);
      final roots2x = eq2x.solve('x');
      check(roots2x.length).equals(2);
      for (final root in roots2x) {
        check(eq2x.substitute('x', root).expand().simplify())
            .equals(RationalNumber.zero);
      }
    });

    test('fractional negative discriminants', () {
      // (1/3)x^2 + (1/2)x + 1 = 0
      final eq1 =
          const RationalNumber(1, 3) * x.pow(const RationalNumber(2)) +
          const RationalNumber(1, 2) * x +
          const RationalNumber(1);
      final roots1 = eq1.solve('x');
      check(roots1.length).equals(2);
      for (final root in roots1) {
        final cVal = root.evaluateComplex();
        check((cVal.a - (-0.75)).abs()).isLessThan(1e-12);
      }

      // x^2 + x + 1/2 = 0
      final eq2 =
          x.pow(const RationalNumber(2)) + x + const RationalNumber(1, 2);
      final roots2 = eq2.solve('x');
      check(roots2.length).equals(2);
      for (final root in roots2) {
        final cVal = root.evaluateComplex();
        check((cVal.a - (-0.5)).abs()).isLessThan(1e-12);
        check((cVal.b.abs() - 0.5).abs()).isLessThan(1e-12);
      }

      // x^2 + 1/4 = 0
      final eq3 = x.pow(const RationalNumber(2)) + const RationalNumber(1, 4);
      final roots3 = eq3.solve('x');
      check(roots3.length).equals(2);
      for (final root in roots3) {
        final cVal = root.evaluateComplex();
        check(cVal.a.abs()).isLessThan(1e-12);
        check((cVal.b.abs() - 0.5).abs()).isLessThan(1e-12);
      }

      // 5x^2 - 2x + 1 = 0
      final eq4 =
          const RationalNumber(5) * x.pow(const RationalNumber(2)) -
          const RationalNumber(2) * x +
          const RationalNumber(1);
      final roots4 = eq4.solve('x');
      check(roots4.length).equals(2);
      for (final root in roots4) {
        final cVal = root.evaluateComplex();
        check((cVal.a - 0.2).abs()).isLessThan(1e-12);
        check((cVal.b.abs() - 0.4).abs()).isLessThan(1e-12);
      }
    });

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

  group('Higher-degree polynomial equations', () {
    test('degree 3 polynomials', () {
      // x^3 - 6x^2 + 11x - 6 = 0 -> x = 1, 2, 3
      final eqCubic1 =
          x.pow(const RationalNumber(3)) -
          const RationalNumber(6) * x.pow(const RationalNumber(2)) +
          const RationalNumber(11) * x -
          const RationalNumber(6);
      final solCubic1 = eqCubic1.solve('x');
      check(solCubic1.length).equals(3);
      check(solCubic1).contains(const RationalNumber(1));
      check(solCubic1).contains(const RationalNumber(2));
      check(solCubic1).contains(const RationalNumber(3));

      // x^3 - x^2 - 2x + 2 = 0 -> contains x = 1
      final eqCubic2 =
          x.pow(const RationalNumber(3)) -
          x.pow(const RationalNumber(2)) -
          const RationalNumber(2) * x +
          const RationalNumber(2);
      final solCubic2 = eqCubic2.solve('x');
      check(solCubic2).contains(const RationalNumber(1));

      // x^3 - 2x^2 + x - 2 = 0 -> x = 2, i, -i
      final eqCubic3 =
          x.pow(const RationalNumber(3)) -
          const RationalNumber(2) * x.pow(const RationalNumber(2)) +
          x -
          const RationalNumber(2);
      final solCubic3 = eqCubic3.solve('x');
      check(solCubic3).contains(const RationalNumber(2));
      check(solCubic3).contains(i);
      check(solCubic3).contains(-i);

      // Fractional rational roots: 6x^3 - 23x^2 - 6x + 8 = 0 -> x = 4, 1/2, -2/3
      final eqCubic4 =
          const RationalNumber(6) * x.pow(const RationalNumber(3)) -
          const RationalNumber(23) * x.pow(const RationalNumber(2)) -
          const RationalNumber(6) * x +
          const RationalNumber(8);
      final solCubic4 = eqCubic4.solve('x');
      check(solCubic4).contains(const RationalNumber(4));
      check(solCubic4).contains(const RationalNumber(1, 2));
      check(solCubic4).contains(const RationalNumber(-2, 3));

      // 12x^3 - 8x^2 - 3x + 2 = 0
      final eqCubic5 =
          const RationalNumber(12) * x.pow(const RationalNumber(3)) -
          const RationalNumber(8) * x.pow(const RationalNumber(2)) -
          const RationalNumber(3) * x +
          const RationalNumber(2);
      final solCubic5 = eqCubic5.solve('x');
      check(solCubic5.length).equals(3);
      check(solCubic5).contains(const RationalNumber(1, 2));
      check(solCubic5).contains(const RationalNumber(-1, 2));
      check(solCubic5).contains(const RationalNumber(2, 3));

      // x^3 - 4x = 0
      final eqCubic6 =
          x.pow(const RationalNumber(3)) - const RationalNumber(4) * x;
      final solCubic6 = eqCubic6.solve('x');
      check(solCubic6.length).equals(3);
      check(solCubic6).contains(RationalNumber.zero);
      check(solCubic6).contains(const RationalNumber(2));
      check(solCubic6).contains(const RationalNumber(-2));
    });

    test('degree 3 binomials with positive and negative constants', () {
      // x^3 - 27 = 0 -> x = 3
      check(
        (x.pow(const RationalNumber(3)) - const RationalNumber(27)).solve('x'),
      ).contains(const RationalNumber(3));

      // x^3 + 8 = 0 -> contains real root x = -2 without NaN
      final eqBin2 = x.pow(const RationalNumber(3)) + const RationalNumber(8);
      final solBin2 = eqBin2.solve('x');
      check(solBin2).contains(const RationalNumber(-2));

      // x^3 + 27 = 0
      check(
        (x.pow(const RationalNumber(3)) + const RationalNumber(27)).solve('x'),
      ).contains(const RationalNumber(-3));

      // (x + 3)^3 + 8 = 0 -> x = -5
      final eqBin3 =
          (x + const RationalNumber(3)).pow(const RationalNumber(3)) +
          const RationalNumber(8);
      check(eqBin3.solve('x')).contains(const RationalNumber(-5));

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

    test('degree 4 biquadratic equations', () {
      // x^4 - 5x^2 + 4 = 0 -> x = 1, -1, 2, -2
      final eqBiq1 =
          x.pow(const RationalNumber(4)) -
          const RationalNumber(5) * x.pow(const RationalNumber(2)) +
          const RationalNumber(4);
      final solBiq1 = eqBiq1.solve('x');
      check(solBiq1.length).equals(4);
      check(solBiq1).contains(const RationalNumber(1));
      check(solBiq1).contains(const RationalNumber(-1));
      check(solBiq1).contains(const RationalNumber(2));
      check(solBiq1).contains(const RationalNumber(-2));

      // x^4 + 5x^2 + 4 = 0 -> x = i, -i, 2i, -2i
      final eqBiq2 =
          x.pow(const RationalNumber(4)) +
          const RationalNumber(5) * x.pow(const RationalNumber(2)) +
          const RationalNumber(4);
      final solBiq2 = eqBiq2.solve('x');
      check(solBiq2.length).equals(4);
      check(solBiq2).contains(i);
      check(solBiq2).contains(-i);
      check(solBiq2).contains(const RationalNumber(2) * i);
      check(solBiq2).contains(const RationalNumber(-2) * i);

      // x^4 - 1 = 0 -> x = 1, -1, i, -i
      final eqBiq3 = x.pow(const RationalNumber(4)) - const RationalNumber(1);
      final solBiq3 = eqBiq3.solve('x');
      check(solBiq3.length).equals(4);
      check(solBiq3).contains(const RationalNumber(1));
      check(solBiq3).contains(const RationalNumber(-1));
      check(solBiq3).contains(i);
      check(solBiq3).contains(-i);

      // x^4 - 16 = 0 -> x = 2, -2, 2i, -2i
      final eqBiq4 = x.pow(const RationalNumber(4)) - const RationalNumber(16);
      final solBiq4 = eqBiq4.solve('x');
      check(solBiq4.length).equals(4);
      check(solBiq4).contains(const RationalNumber(2));
      check(solBiq4).contains(const RationalNumber(-2));
      check(solBiq4).contains(const RationalNumber(2) * i);
      check(solBiq4).contains(const RationalNumber(-2) * i);

      // x^4 - 4x^2 + 1 = 0
      final eqBiq5 =
          x.pow(const RationalNumber(4)) -
          const RationalNumber(4) * x.pow(const RationalNumber(2)) +
          const RationalNumber(1);
      check(eqBiq5.solve('x').length).equals(4);

      // x^4 - 3x^2 - 4 = 0
      final eqBiq6 =
          x.pow(const RationalNumber(4)) -
          const RationalNumber(3) * x.pow(const RationalNumber(2)) -
          const RationalNumber(4);
      final solBiq6 = eqBiq6.solve('x');
      check(solBiq6.length).equals(4);
      check(solBiq6).contains(const RationalNumber(2));
      check(solBiq6).contains(const RationalNumber(-2));
      check(solBiq6).contains(i);
      check(solBiq6).contains(-i);

      // x^4 + 13x^2 + 36 = 0
      final eqBiq7 =
          x.pow(const RationalNumber(4)) +
          const RationalNumber(13) * x.pow(const RationalNumber(2)) +
          const RationalNumber(36);
      final solBiq7 = eqBiq7.solve('x');
      check(solBiq7.length).equals(4);
      check(solBiq7).contains(const RationalNumber(2) * i);
      check(solBiq7).contains(const RationalNumber(-2) * i);
      check(solBiq7).contains(const RationalNumber(3) * i);
      check(solBiq7).contains(const RationalNumber(-3) * i);

      // x^4 - 81 = 0
      final eqBiq8 = x.pow(const RationalNumber(4)) - const RationalNumber(81);
      final solBiq8 = eqBiq8.solve('x');
      check(solBiq8.length).equals(4);
      check(solBiq8).contains(const RationalNumber(3));
      check(solBiq8).contains(const RationalNumber(-3));
      check(solBiq8).contains(const RationalNumber(3) * i);
      check(solBiq8).contains(const RationalNumber(-3) * i);
    });

    test('degree 5 and 6 polynomials', () {
      // Degree 5 quintic factoring: x^5 - 5x^3 + 4x = 0 -> x = 0, 1, -1, 2, -2
      final eqQuintic =
          x.pow(const RationalNumber(5)) -
          const RationalNumber(5) * x.pow(const RationalNumber(3)) +
          const RationalNumber(4) * x;
      final solQuintic = eqQuintic.solve('x');
      check(solQuintic.length).equals(5);
      check(solQuintic).contains(RationalNumber.zero);
      check(solQuintic).contains(const RationalNumber(1));
      check(solQuintic).contains(const RationalNumber(-1));
      check(solQuintic).contains(const RationalNumber(2));
      check(solQuintic).contains(const RationalNumber(-2));

      // x^5 - 32 = 0 -> x = 2
      check(
        (x.pow(const RationalNumber(5)) - const RationalNumber(32)).solve('x'),
      ).contains(const RationalNumber(2));

      // x^5 + 32 = 0 -> x = -2
      check(
        (x.pow(const RationalNumber(5)) + const RationalNumber(32)).solve('x'),
      ).contains(const RationalNumber(-2));

      // (x - 1)^5 - 32 = 0 -> x = 3
      final eqShifted =
          (x - const RationalNumber(1)).pow(const RationalNumber(5)) -
          const RationalNumber(32);
      check(eqShifted.solve('x')).contains(const RationalNumber(3));

      // x^5 - 243 = 0 -> x = 3; x^5 + 243 = 0 -> x = -3
      check(
        (x.pow(const RationalNumber(5)) - const RationalNumber(243)).solve('x'),
      ).contains(const RationalNumber(3));
      check(
        (x.pow(const RationalNumber(5)) + const RationalNumber(243)).solve('x'),
      ).contains(const RationalNumber(-3));

      // Degree 6: x^6 - 1 = 0
      final eq6 = x.pow(const RationalNumber(6)) - const RationalNumber(1);
      final sol6 = eq6.solve('x');
      check(sol6).contains(const RationalNumber(1));
      check(sol6).contains(const RationalNumber(-1));

      // Degree 6: x^6 - 64 = 0
      final eq64 = x.pow(const RationalNumber(6)) - const RationalNumber(64);
      final sol64 = eq64.solve('x');
      check(sol64).contains(const RationalNumber(2));
      check(sol64).contains(const RationalNumber(-2));
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

  group('Trigonometric and transcendental equations', () {
    test('basic trigonometric zeros', () {
      // sin(x) = 0 -> x = 0, pi
      final solSin0 = const Sin(x).solve('x');
      check(solSin0).contains(RationalNumber.zero);
      check(solSin0).contains(ConstantNumber.pi);

      // cos(x) = 0 -> x = pi/2, 3pi/2
      final solCos0 = const Cos(x).solve('x');
      check(solCos0)
          .contains(const Mul(RationalNumber(1, 2), ConstantNumber.pi));
      check(solCos0)
          .contains(const Mul(RationalNumber(3, 2), ConstantNumber.pi));

      // tan(x) = 0 -> x = 0, pi
      final solTan0 = const Tan(x).solve('x');
      check(solTan0).contains(RationalNumber.zero);
      check(solTan0).contains(ConstantNumber.pi);
    });

    test('special angle constants', () {
      // 2 * sin(x) - 1 = 0 -> sin(x) = 1/2 -> x = pi/6, 5pi/6
      final eqSinHalf =
          const RationalNumber(2) * const Sin(x) - const RationalNumber(1);
      final solSinHalf = eqSinHalf.solve('x');
      check(solSinHalf)
          .contains(const Mul(RationalNumber(1, 6), ConstantNumber.pi));
      check(solSinHalf)
          .contains(const Mul(RationalNumber(5, 6), ConstantNumber.pi));

      // 2 * cos(x) - 1 = 0 -> cos(x) = 1/2 -> x = pi/3, 5pi/3
      final eqCosHalf =
          const RationalNumber(2) * const Cos(x) - const RationalNumber(1);
      final solCosHalf = eqCosHalf.solve('x');
      check(solCosHalf)
          .contains(const Mul(RationalNumber(1, 3), ConstantNumber.pi));
      check(solCosHalf)
          .contains(const Mul(RationalNumber(5, 3), ConstantNumber.pi));

      // tan(x) - 1 = 0 -> x = pi/4, 5pi/4
      final eqTan1 = const Tan(x) - const RationalNumber(1);
      final solTan1 = eqTan1.solve('x');
      check(solTan1)
          .contains(const Mul(RationalNumber(1, 4), ConstantNumber.pi));
      check(solTan1)
          .contains(const Mul(RationalNumber(5, 4), ConstantNumber.pi));
    });

    test('special radical angle resolution in trigonometric equations', () {
      // sin(x) = sqrt(2)/2 -> pi/4, 3pi/4
      final eqSinSqrt2 =
          const Sin(x) -
          const Div(
            Pow(RationalNumber(2), RationalNumber(1, 2)),
            RationalNumber(2),
          );
      final solSinSqrt2 = eqSinSqrt2.solve('x');
      check(solSinSqrt2)
          .contains(const Mul(RationalNumber(1, 4), ConstantNumber.pi));
      check(solSinSqrt2)
          .contains(const Mul(RationalNumber(3, 4), ConstantNumber.pi));

      // sin(x) = -sqrt(2)/2 -> 5pi/4, 7pi/4
      final eqSinNegSqrt2 =
          const Sin(x) -
          const Neg(
            Div(
              Pow(RationalNumber(2), RationalNumber(1, 2)),
              RationalNumber(2),
            ),
          );
      final solSinNegSqrt2 = eqSinNegSqrt2.solve('x');
      check(solSinNegSqrt2)
          .contains(const Mul(RationalNumber(5, 4), ConstantNumber.pi));
      check(solSinNegSqrt2)
          .contains(const Mul(RationalNumber(7, 4), ConstantNumber.pi));

      // sin(x) = sqrt(3)/2 -> pi/3, 2pi/3
      final eqSinSqrt3 =
          const Sin(x) -
          const Div(
            Pow(RationalNumber(3), RationalNumber(1, 2)),
            RationalNumber(2),
          );
      final solSinSqrt3 = eqSinSqrt3.solve('x');
      check(solSinSqrt3)
          .contains(const Mul(RationalNumber(1, 3), ConstantNumber.pi));
      check(solSinSqrt3)
          .contains(const Mul(RationalNumber(2, 3), ConstantNumber.pi));

      // sin(x) = -sqrt(3)/2 -> 4pi/3, 5pi/3
      final eqSinNegSqrt3 =
          const Sin(x) -
          const Neg(
            Div(
              Pow(RationalNumber(3), RationalNumber(1, 2)),
              RationalNumber(2),
            ),
          );
      final solSinNegSqrt3 = eqSinNegSqrt3.solve('x');
      check(solSinNegSqrt3)
          .contains(const Mul(RationalNumber(4, 3), ConstantNumber.pi));
      check(solSinNegSqrt3)
          .contains(const Mul(RationalNumber(5, 3), ConstantNumber.pi));

      // sin(x) = -1/2 -> 7pi/6, 11pi/6
      final eqSinNegHalf = const Sin(x) - const RationalNumber(-1, 2);
      final solSinNegHalf = eqSinNegHalf.solve('x');
      check(solSinNegHalf)
          .contains(const Mul(RationalNumber(7, 6), ConstantNumber.pi));
      check(solSinNegHalf)
          .contains(const Mul(RationalNumber(11, 6), ConstantNumber.pi));

      // cos(x) = sqrt(2)/2 -> pi/4, 7pi/4
      final eqCosSqrt2 =
          const Cos(x) -
          const Div(
            Pow(RationalNumber(2), RationalNumber(1, 2)),
            RationalNumber(2),
          );
      final solCosSqrt2 = eqCosSqrt2.solve('x');
      check(solCosSqrt2)
          .contains(const Mul(RationalNumber(1, 4), ConstantNumber.pi));
      check(solCosSqrt2)
          .contains(const Mul(RationalNumber(7, 4), ConstantNumber.pi));

      // cos(x) = -sqrt(2)/2 -> 3pi/4, 5pi/4
      final eqCosNegSqrt2 =
          const Cos(x) -
          const Neg(
            Div(
              Pow(RationalNumber(2), RationalNumber(1, 2)),
              RationalNumber(2),
            ),
          );
      final solCosNegSqrt2 = eqCosNegSqrt2.solve('x');
      check(solCosNegSqrt2)
          .contains(const Mul(RationalNumber(3, 4), ConstantNumber.pi));
      check(solCosNegSqrt2)
          .contains(const Mul(RationalNumber(5, 4), ConstantNumber.pi));

      // cos(x) = sqrt(3)/2 -> pi/6, 11pi/6
      final eqCosSqrt3 =
          const Cos(x) -
          const Div(
            Pow(RationalNumber(3), RationalNumber(1, 2)),
            RationalNumber(2),
          );
      final solCosSqrt3 = eqCosSqrt3.solve('x');
      check(solCosSqrt3)
          .contains(const Mul(RationalNumber(1, 6), ConstantNumber.pi));
      check(solCosSqrt3)
          .contains(const Mul(RationalNumber(11, 6), ConstantNumber.pi));

      // cos(x) = -sqrt(3)/2 -> 5pi/6, 7pi/6
      final eqCosNegSqrt3 =
          const Cos(x) -
          const Neg(
            Div(
              Pow(RationalNumber(3), RationalNumber(1, 2)),
              RationalNumber(2),
            ),
          );
      final solCosNegSqrt3 = eqCosNegSqrt3.solve('x');
      check(solCosNegSqrt3)
          .contains(const Mul(RationalNumber(5, 6), ConstantNumber.pi));
      check(solCosNegSqrt3)
          .contains(const Mul(RationalNumber(7, 6), ConstantNumber.pi));

      // cos(x) = -1/2 -> 2pi/3, 4pi/3
      final eqCosNegHalf = const Cos(x) - const RationalNumber(-1, 2);
      final solCosNegHalf = eqCosNegHalf.solve('x');
      check(solCosNegHalf)
          .contains(const Mul(RationalNumber(2, 3), ConstantNumber.pi));
      check(solCosNegHalf)
          .contains(const Mul(RationalNumber(4, 3), ConstantNumber.pi));

      // tan(x) = sqrt(3)/3 -> pi/6, 7pi/6
      final eqTanSqrt3Over3 =
          const Tan(x) -
          const Div(
            Pow(RationalNumber(3), RationalNumber(1, 2)),
            RationalNumber(3),
          );
      final solTanSqrt3Over3 = eqTanSqrt3Over3.solve('x');
      check(solTanSqrt3Over3)
          .contains(const Mul(RationalNumber(1, 6), ConstantNumber.pi));
      check(solTanSqrt3Over3)
          .contains(const Mul(RationalNumber(7, 6), ConstantNumber.pi));

      // tan(x) = -sqrt(3)/3 -> 5pi/6, 11pi/6
      final eqTanNegSqrt3Over3 =
          const Tan(x) -
          const Neg(
            Div(
              Pow(RationalNumber(3), RationalNumber(1, 2)),
              RationalNumber(3),
            ),
          );
      final solTanNegSqrt3Over3 = eqTanNegSqrt3Over3.solve('x');
      check(solTanNegSqrt3Over3)
          .contains(const Mul(RationalNumber(5, 6), ConstantNumber.pi));
      check(solTanNegSqrt3Over3)
          .contains(const Mul(RationalNumber(11, 6), ConstantNumber.pi));

      // tan(x) = -1 -> 3pi/4, 7pi/4
      final eqTanNeg1 = const Tan(x) - const RationalNumber(-1);
      final solTanNeg1 = eqTanNeg1.solve('x');
      check(solTanNeg1)
          .contains(const Mul(RationalNumber(3, 4), ConstantNumber.pi));
      check(solTanNeg1)
          .contains(const Mul(RationalNumber(7, 4), ConstantNumber.pi));

      // tan(x) = sqrt(3) -> pi/3, 4pi/3
      final eqTanSqrt3 =
          const Tan(x) - const Pow(RationalNumber(3), RationalNumber(1, 2));
      final solTanSqrt3 = eqTanSqrt3.solve('x');
      check(solTanSqrt3)
          .contains(const Mul(RationalNumber(1, 3), ConstantNumber.pi));
      check(solTanSqrt3)
          .contains(const Mul(RationalNumber(4, 3), ConstantNumber.pi));

      // tan(x) = -sqrt(3) -> 2pi/3, 5pi/3
      final eqTanNegSqrt3 =
          const Tan(x) -
          const Neg(Pow(RationalNumber(3), RationalNumber(1, 2)));
      final solTanNegSqrt3 = eqTanNegSqrt3.solve('x');
      check(solTanNegSqrt3)
          .contains(const Mul(RationalNumber(2, 3), ConstantNumber.pi));
      check(solTanNegSqrt3)
          .contains(const Mul(RationalNumber(5, 3), ConstantNumber.pi));
    });

    test('parsed trigonometric equations with algebraic radicals', () {
      // 2 * sin(x) - sqrt(2) = 0
      final s1 = Expr.parse('2 * sin(x) - sqrt(2)').solve('x');
      check(s1).contains(const Mul(RationalNumber(1, 4), ConstantNumber.pi));
      check(s1).contains(const Mul(RationalNumber(3, 4), ConstantNumber.pi));

      // 2 * sin(x) + sqrt(3) = 0
      final s2 = Expr.parse('2 * sin(x) + sqrt(3)').solve('x');
      check(s2).contains(const Mul(RationalNumber(4, 3), ConstantNumber.pi));
      check(s2).contains(const Mul(RationalNumber(5, 3), ConstantNumber.pi));

      // 2 * cos(x) - sqrt(3) = 0
      final s3 = Expr.parse('2 * cos(x) - sqrt(3)').solve('x');
      check(s3).contains(const Mul(RationalNumber(1, 6), ConstantNumber.pi));
      check(s3).contains(const Mul(RationalNumber(11, 6), ConstantNumber.pi));

      // 2 * cos(x) + sqrt(2) = 0
      final s4 = Expr.parse('2 * cos(x) + sqrt(2)').solve('x');
      check(s4).contains(const Mul(RationalNumber(3, 4), ConstantNumber.pi));
      check(s4).contains(const Mul(RationalNumber(5, 4), ConstantNumber.pi));

      // tan(x) - sqrt(3) = 0
      final s5 = Expr.parse('tan(x) - sqrt(3)').solve('x');
      check(s5).contains(const Mul(RationalNumber(1, 3), ConstantNumber.pi));
      check(s5).contains(const Mul(RationalNumber(4, 3), ConstantNumber.pi));

      // tan(x) + sqrt(3) = 0
      final s6 = Expr.parse('tan(x) + sqrt(3)').solve('x');
      check(s6).contains(const Mul(RationalNumber(2, 3), ConstantNumber.pi));
      check(s6).contains(const Mul(RationalNumber(5, 3), ConstantNumber.pi));
    });

    test('non-special angle constants and dual roots in [0, 2pi)', () {
      // sin(x) = 1/3
      final eqSin = const Sin(x) - const RationalNumber(1, 3);
      final rootsSin = eqSin.solve('x');
      check(rootsSin.length).equals(2);
      check(rootsSin).contains(const Asin(RationalNumber(1, 3)));
      check(rootsSin)
          .contains(ConstantNumber.pi - const Asin(RationalNumber(1, 3)));

      for (final root in rootsSin) {
        final val = root.evaluate(const {});
        check(val).isGreaterOrEqual(0.0);
        check(val).isLessThan(2 * math.pi);
        check((math.sin(val) - 1.0 / 3.0).abs()).isLessThan(1e-12);
      }

      // cos(x) = 1/3
      final eqCos = const Cos(x) - const RationalNumber(1, 3);
      final rootsCos = eqCos.solve('x');
      check(rootsCos.length).equals(2);
      check(rootsCos).contains(const Acos(RationalNumber(1, 3)));
      check(rootsCos).contains(
        const Mul(RationalNumber(2), ConstantNumber.pi) -
            const Acos(RationalNumber(1, 3)),
      );

      for (final root in rootsCos) {
        final val = root.evaluate(const {});
        check(val).isGreaterOrEqual(0.0);
        check(val).isLessThan(2 * math.pi);
        check((math.cos(val) - 1.0 / 3.0).abs()).isLessThan(1e-12);
      }

      // tan(x) = 1/3
      final eqTan = const Tan(x) - const RationalNumber(1, 3);
      final rootsTan = eqTan.solve('x');
      check(rootsTan.length).equals(2);
      check(rootsTan).contains(const Atan(RationalNumber(1, 3)));
      check(rootsTan).contains(
        (ConstantNumber.pi + const Atan(RationalNumber(1, 3))).simplify(),
      );

      for (final root in rootsTan) {
        final val = root.evaluate(const {});
        check(val).isGreaterOrEqual(0.0);
        check(val).isLessThan(2 * math.pi);
        check((math.tan(val) - 1.0 / 3.0).abs()).isLessThan(1e-12);
      }

      // General negative constants
      const c = RationalNumber(-1, 3);
      final negRootsSin = (const Sin(x) - c).solve('x');
      final negRootsCos = (const Cos(x) - c).solve('x');
      final negRootsTan = (const Tan(x) - c).solve('x');

      check(negRootsSin.length).equals(2);
      check(negRootsCos.length).equals(2);
      check(negRootsTan.length).equals(2);

      for (final r in negRootsSin) {
        check((math.sin(r.evaluate(const {})) - (-1.0 / 3.0)).abs())
            .isLessThan(1e-12);
      }
      for (final r in negRootsCos) {
        check((math.cos(r.evaluate(const {})) - (-1.0 / 3.0)).abs())
            .isLessThan(1e-12);
      }
      for (final r in negRootsTan) {
        check((math.tan(r.evaluate(const {})) - (-1.0 / 3.0)).abs())
            .isLessThan(1e-12);
      }
    });

    test('affine argument f(x)', () {
      // sin(2x) = 0 -> x = 0, pi/2
      final eqSin2x = Sin(const RationalNumber(2) * x);
      final solSin2x = eqSin2x.solve('x');
      check(solSin2x).contains(RationalNumber.zero);
      check(solSin2x)
          .contains(const Mul(RationalNumber(1, 2), ConstantNumber.pi));

      // cos(2x) = 0 -> x = pi/4, 3pi/4
      final eqCos2x = Cos(const RationalNumber(2) * x);
      final solCos2x = eqCos2x.solve('x');
      check(solCos2x)
          .contains(const Mul(RationalNumber(1, 4), ConstantNumber.pi));
      check(solCos2x)
          .contains(const Mul(RationalNumber(3, 4), ConstantNumber.pi));

      // tan(2x) = 0 -> x = 0, pi/2
      final eqTan2x = Tan(const RationalNumber(2) * x);
      final solTan2x = eqTan2x.solve('x');
      check(solTan2x).contains(RationalNumber.zero);
      check(solTan2x)
          .contains(const Mul(RationalNumber(1, 2), ConstantNumber.pi));
    });

    test('out of bounds trigonometric values', () {
      check((const Sin(x) - const RationalNumber(2)).solve('x')).isEmpty();
      check((const Sin(x) + const RationalNumber(3, 2)).solve('x')).isEmpty();
      check((const Cos(x) - const RationalNumber(3)).solve('x')).isEmpty();
      check(
        (const RationalNumber(2) * const Cos(x) + const RationalNumber(5))
            .solve('x'),
      ).isEmpty();
      check((const Sin(x) - const RealNumber(1.0001)).solve('x')).isEmpty();
      check((const Cos(x) + const RealNumber(1.5)).solve('x')).isEmpty();
    });

    test('inverse trigonometric equations', () {
      check(const Asin(x).solve('x')).deepEquals([RationalNumber.zero]);

      final eqAcos =
          const Acos(x) - const Mul(RationalNumber(1, 2), ConstantNumber.pi);
      check(eqAcos.solve('x')).deepEquals([RationalNumber.zero]);

      final eqAtan =
          const Atan(x) - const Mul(RationalNumber(1, 4), ConstantNumber.pi);
      final rootsAtan = eqAtan.solve('x');
      check(rootsAtan.length).equals(1);
      checkRootResidual(eqAtan, rootsAtan.first);
    });

    test('transcendental equations: exp and ln', () {
      // exp(2x - 4) - 1 = 0 -> 2x - 4 = 0 -> x = 2
      final eqExp =
          Exp(const RationalNumber(2) * x - const RationalNumber(4)) -
          const RationalNumber(1);
      final solExp = eqExp.solve('x');
      check(solExp.length).equals(1);
      check(solExp.first.evaluate(const {})).isCloseTo(2.0, 1e-9);

      // ln(x + 1) - 2 = 0 -> x = e^2 - 1
      final eqLn = Ln(x + const RationalNumber(1)) - const RationalNumber(2);
      final solLn = eqLn.solve('x');
      check(solLn.length).equals(1);
      check(solLn.first.evaluate(const {}))
          .isCloseTo(7.38905609893065 - 1.0, 1e-9);

      // (x - 2)^3 - 8 = 0 -> contains real root x = 4
      final eqPow =
          (x - const RationalNumber(2)).pow(const RationalNumber(3)) -
          const RationalNumber(8);
      final solPow = eqPow.solve('x');
      check(solPow).contains(const RationalNumber(4));

      // (x + 1)^2 - 9 = 0 -> x + 1 = +/- 3 -> x = 2, -4
      final eqPowEven =
          (x + const RationalNumber(1)).pow(const RationalNumber(2)) -
          const RationalNumber(9);
      final solPowEven = eqPowEven.solve('x');
      check(solPowEven.length).equals(2);
      final vals = solPowEven.map((s) => s.evaluate(const {})).toList()..sort();
      check(vals[0]).isCloseTo(-4.0, 1e-9);
      check(vals[1]).isCloseTo(2.0, 1e-9);
    });
  });

  group('Factored products and composite equations', () {
    test('factored polynomial products', () {
      // (x - 1) * (x - 4) = 0 -> x = 1, 4
      final eq = (x - const RationalNumber(1)) * (x - const RationalNumber(4));
      final sol = eq.solve('x');
      check(sol.length).equals(2);
      final vals = sol.map((s) => s.evaluate(const {})).toList()..sort();
      check(vals[0]).equals(1.0);
      check(vals[1]).equals(4.0);

      // Quartic product: (x - 1)(x - 2)(x - 3)(x - 4) = 0
      final eq4 =
          (x - const RationalNumber(1)) *
          (x - const RationalNumber(2)) *
          (x - const RationalNumber(3)) *
          (x - const RationalNumber(4));
      final sol4 = eq4.solve('x');
      check(sol4.length).equals(4);
      check(sol4).contains(const RationalNumber(1));
      check(sol4).contains(const RationalNumber(2));
      check(sol4).contains(const RationalNumber(3));
      check(sol4).contains(const RationalNumber(4));
    });

    test('trigonometric products', () {
      // sin(x) * cos(x) = 0
      final eqProd = const Sin(x) * const Cos(x);
      final solProd = eqProd.solve('x');
      check(solProd).contains(RationalNumber.zero);
      check(solProd)
          .contains(const Mul(RationalNumber(1, 2), ConstantNumber.pi));
      check(solProd).contains(ConstantNumber.pi);
      check(solProd)
          .contains(const Mul(RationalNumber(3, 2), ConstantNumber.pi));

      // (2*sin(x) - 1) * (2*cos(x) - 1) = 0
      final prod2 =
          (const RationalNumber(2) * const Sin(x) - const RationalNumber(1)) *
          (const RationalNumber(2) * const Cos(x) - const RationalNumber(1));
      final sol2 = prod2.solve('x');
      check(sol2).contains(const Mul(RationalNumber(1, 6), ConstantNumber.pi));
      check(sol2).contains(const Mul(RationalNumber(5, 6), ConstantNumber.pi));
      check(sol2).contains(const Mul(RationalNumber(1, 3), ConstantNumber.pi));
      check(sol2).contains(const Mul(RationalNumber(5, 3), ConstantNumber.pi));
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

      // exp(x^2) - 1 = 0 -> x = 0
      final eq4 = Exp(x.pow(const RationalNumber(2))) - const RationalNumber(1);
      final roots4 = eq4.solve('x');
      check(roots4).contains(RationalNumber.zero);

      // ln(x^2 + 1) = 0 -> x = 0
      final eq5 = Ln(x.pow(const RationalNumber(2)) + const RationalNumber(1));
      final roots5 = eq5.solve('x');
      check(roots5).contains(RationalNumber.zero);

      // sin(x^2 - 1) = 0 -> x = +/- 1
      final eq6 = Sin(x.pow(const RationalNumber(2)) - const RationalNumber(1));
      final roots6 = eq6.solve('x');
      check(roots6).contains(const RationalNumber(1));
      check(roots6).contains(const RationalNumber(-1));
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
  });

  group('Reciprocal and boundary edge cases', () {
    test('reciprocal and rational power equations', () {
      // 1 / sin(x) - 2 = 0 -> sin(x) = 1/2 -> pi/6, 5pi/6
      final eq1 =
          (const RationalNumber(1) / const Sin(x)) - const RationalNumber(2);
      final sol1 = eq1.solve('x');
      check(sol1).contains(const Mul(RationalNumber(1, 6), ConstantNumber.pi));
      check(sol1).contains(const Mul(RationalNumber(5, 6), ConstantNumber.pi));

      // 2 / cos(x) - 4 = 0 -> cos(x) = 1/2 -> pi/3, 5pi/3
      final eq2 =
          (const RationalNumber(2) / const Cos(x)) - const RationalNumber(4);
      final sol2 = eq2.solve('x');
      check(sol2).contains(const Mul(RationalNumber(1, 3), ConstantNumber.pi));
      check(sol2).contains(const Mul(RationalNumber(5, 3), ConstantNumber.pi));

      // 1 / tan(x) - 1 = 0 -> tan(x) = 1 -> pi/4, 5pi/4
      final eq3 =
          (const RationalNumber(1) / const Tan(x)) - const RationalNumber(1);
      final sol3 = eq3.solve('x');
      check(sol3).contains(const Mul(RationalNumber(1, 4), ConstantNumber.pi));
      check(sol3).contains(const Mul(RationalNumber(5, 4), ConstantNumber.pi));

      // Negative rational exponents: x^(-2) - 4 = 0 -> x = +/- 1/2
      final eqPowNeg =
          x.pow(const RationalNumber(-2)) - const RationalNumber(4);
      final solPowNeg = eqPowNeg.solve('x');
      check(solPowNeg).contains(const RationalNumber(1, 2));
      check(solPowNeg).contains(const RationalNumber(-1, 2));

      // 1 / x^2 - 4 = 0 -> x = +/- 1/2
      final eqPowNeg2 =
          (const RationalNumber(1) / x.pow(const RationalNumber(2))) -
          const RationalNumber(4);
      final rootsPowNeg2 = eqPowNeg2.solve('x');
      check(rootsPowNeg2).contains(const RationalNumber(1, 2));
      check(rootsPowNeg2).contains(const RationalNumber(-1, 2));
    });

    test(
      'reciprocal equations equated to zero return empty list without throwing',
      () {
        check((const RationalNumber(1) / x).solve('x')).isEmpty();

        final numerators = <Expr>[
          const RationalNumber(2),
          const RationalNumber(-5),
          const RationalNumber(1, 3),
          const RationalNumber(-4, 7),
          const RealNumber(1.5),
          const RealNumber(-2.7),
          i,
          const RationalNumber(2) * i,
          const RationalNumber(1) + i,
        ];
        for (final num in numerators) {
          check((num / x).solve('x')).isEmpty();
        }

        // Reciprocal trigonometric equated to zero
        check((const RationalNumber(1) / const Sin(x)).solve('x')).isEmpty();
        check((const RationalNumber(1) / const Cos(x)).solve('x')).isEmpty();
        check((const RationalNumber(1) / const Tan(x)).solve('x')).isEmpty();
        check((const RationalNumber(-3) / const Sin(x)).solve('x')).isEmpty();
        check(((const RationalNumber(1) + i) / const Sin(x)).solve('x'))
            .isEmpty();

        // Reciprocal polynomials and transcendental expressions
        check(
          (const RationalNumber(1) /
                  (x.pow(const RationalNumber(2)) + const RationalNumber(1)))
              .solve('x'),
        ).isEmpty();
        check(
          (const RationalNumber(5) / (x + const RationalNumber(3))).solve('x'),
        ).isEmpty();
        check((const RationalNumber(1) / const Exp(x)).solve('x')).isEmpty();
        check((const RationalNumber(2) / const Ln(x)).solve('x')).isEmpty();
      },
    );

    test('contradictory and empty root equations', () {
      check(const RationalNumber(7).solve('x')).isEmpty();
      check(((x + const RationalNumber(2)) - x).solve('x')).isEmpty();
      check(const Exp(x).solve('x')).isEmpty();
      check((const Exp(x) + const RationalNumber(1)).solve('x')).isEmpty();
      check((const Exp(x) + const RationalNumber(5)).solve('x')).isEmpty();
    });
  });
}
