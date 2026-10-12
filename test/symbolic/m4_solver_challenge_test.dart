import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/scaffolding.dart';

void main() {
  const x = Variable('x');

  group('M4 Challenger 1: Quadratic Equations with Negative Discriminants', () {
    test('x^2 + 3 = 0 has roots yielding zero on evaluation', () {
      final eq = x.pow(const RationalNumber(2)) + const RationalNumber(3);
      final roots = eq.solve('x');
      check(roots.length).equals(2);

      for (final root in roots) {
        final cVal = root.evaluateComplex();
        // root should be pure imaginary +/- sqrt(3)*i
        check(cVal.a.abs()).isLessThan(1e-12);
        check((cVal.b.abs() - math.sqrt(3)).abs()).isLessThan(1e-12);

        // Evaluating equation at root must yield 0
        final eqVal = eq.evaluateComplex({'x': cVal});
        check(eqVal.a.abs()).isLessThan(1e-12);
        check(eqVal.b.abs()).isLessThan(1e-12);

        final symSub = eq.substitute('x', root).simplify();
        check(symSub.evaluateComplex().abs()).isLessThan(1e-12);
        check(eq.substitute('x', root).expand().simplify())
            .equals(RationalNumber.zero);
      }
    });

    test('4x^2 + 4x + 5 = 0 has roots yielding zero on evaluation', () {
      // 4x^2 + 4x + 5 = 0 -> roots: -1/2 + i, -1/2 - i
      final eq =
          const RationalNumber(4) * x.pow(const RationalNumber(2)) +
          const RationalNumber(4) * x +
          const RationalNumber(5);
      final roots = eq.solve('x');
      check(roots.length).equals(2);

      for (final root in roots) {
        final cVal = root.evaluateComplex();
        check((cVal.a - (-0.5)).abs()).isLessThan(1e-12);
        check((cVal.b.abs() - 1.0).abs()).isLessThan(1e-12);

        final eqVal = eq.evaluateComplex({'x': cVal});
        check(eqVal.a.abs()).isLessThan(1e-12);
        check(eqVal.b.abs()).isLessThan(1e-12);

        final symSub = eq.substitute('x', root).expand().simplify();
        check(symSub).equals(RationalNumber.zero);
      }
    });

    test('2x^2 + 3 = 0 has roots yielding zero on evaluation', () {
      // 2x^2 + 3 = 0 -> roots: +/- i * sqrt(3/2)
      final eq =
          const RationalNumber(2) * x.pow(const RationalNumber(2)) +
          const RationalNumber(3);
      final roots = eq.solve('x');
      check(roots.length).equals(2);

      for (final root in roots) {
        final cVal = root.evaluateComplex();
        check(cVal.a.abs()).isLessThan(1e-12);
        check((cVal.b.abs() - math.sqrt(1.5)).abs()).isLessThan(1e-12);

        final eqVal = eq.evaluateComplex({'x': cVal});
        check(eqVal.a.abs()).isLessThan(1e-12);
        check(eqVal.b.abs()).isLessThan(1e-12);

        check(eq.substitute('x', root).expand().simplify())
            .equals(RationalNumber.zero);
      }
    });

    test('fractional negative discriminant: (1/3)x^2 + (1/2)x + 1 = 0', () {
      // a = 1/3, b = 1/2, c = 1 -> disc = 1/4 - 4/3 = -13/12
      final eq =
          const RationalNumber(1, 3) * x.pow(const RationalNumber(2)) +
          const RationalNumber(1, 2) * x +
          const RationalNumber(1);
      final roots = eq.solve('x');
      check(roots.length).equals(2);

      for (final root in roots) {
        final cVal = root.evaluateComplex();
        // real part = -b / (2a) = (-1/2) / (2/3) = -3/4 = -0.75
        check((cVal.a - (-0.75)).abs()).isLessThan(1e-12);

        final eqVal = eq.evaluateComplex({'x': cVal});
        check(eqVal.a.abs()).isLessThan(1e-12);
        check(eqVal.b.abs()).isLessThan(1e-12);
      }
    });

    test('fractional negative discriminant: x^2 + x + 1/2 = 0', () {
      // a = 1, b = 1, c = 1/2 -> disc = 1 - 2 = -1 -> roots -1/2 +/- 1/2*i
      final eq =
          x.pow(const RationalNumber(2)) + x + const RationalNumber(1, 2);
      final roots = eq.solve('x');
      check(roots.length).equals(2);

      for (final root in roots) {
        final cVal = root.evaluateComplex();
        check((cVal.a - (-0.5)).abs()).isLessThan(1e-12);
        check((cVal.b.abs() - 0.5).abs()).isLessThan(1e-12);

        final eqVal = eq.evaluateComplex({'x': cVal});
        check(eqVal.a.abs()).isLessThan(1e-12);
        check(eqVal.b.abs()).isLessThan(1e-12);
      }
    });

    test('fractional quadratic: x^2 + 1/4 = 0', () {
      final eq = x.pow(const RationalNumber(2)) + const RationalNumber(1, 4);
      final roots = eq.solve('x');
      check(roots.length).equals(2);

      for (final root in roots) {
        final cVal = root.evaluateComplex();
        check(cVal.a.abs()).isLessThan(1e-12);
        check((cVal.b.abs() - 0.5).abs()).isLessThan(1e-12);

        final eqVal = eq.evaluateComplex({'x': cVal});
        check(eqVal.a.abs()).isLessThan(1e-12);
        check(eqVal.b.abs()).isLessThan(1e-12);
      }
    });

    test(
      'quadratic with larger non-square discriminant: 5x^2 - 2x + 1 = 0',
      () {
        // a = 5, b = -2, c = 1 -> disc = 4 - 20 = -16 -> roots (2 +/- 4i) / 10 = 1/5 +/- 2/5 i
        final eq =
            const RationalNumber(5) * x.pow(const RationalNumber(2)) -
            const RationalNumber(2) * x +
            const RationalNumber(1);
        final roots = eq.solve('x');
        check(roots.length).equals(2);

        for (final root in roots) {
          final cVal = root.evaluateComplex();
          check((cVal.a - 0.2).abs()).isLessThan(1e-12);
          check((cVal.b.abs() - 0.4).abs()).isLessThan(1e-12);

          final eqVal = eq.evaluateComplex({'x': cVal});
          check(eqVal.a.abs()).isLessThan(1e-12);
          check(eqVal.b.abs()).isLessThan(1e-12);
        }
      },
    );
  });

  group('M4 Challenger 1: Trigonometric Equations', () {
    test('affine arguments', () {
      // sin(2x) = 0 -> roots in [0, pi]
      final eq1 = Sin(const RationalNumber(2) * x);
      final sol1 = eq1.solve('x');
      check(sol1).contains(RationalNumber.zero);
      check(sol1).contains(const Mul(RationalNumber(1, 2), ConstantNumber.pi));

      for (final r in sol1) {
        final v = r.evaluate(const {});
        check(math.sin(2 * v).abs()).isLessThan(1e-12);
      }

      // cos(2x) = 0 -> roots 2x = pi/2, 3pi/2 -> x = pi/4, 3pi/4
      final eq2 = Cos(const RationalNumber(2) * x);
      final sol2 = eq2.solve('x');
      check(sol2).contains(const Mul(RationalNumber(1, 4), ConstantNumber.pi));
      check(sol2).contains(const Mul(RationalNumber(3, 4), ConstantNumber.pi));

      for (final r in sol2) {
        final v = r.evaluate(const {});
        check(math.cos(2 * v).abs()).isLessThan(1e-12);
      }

      // tan(2x) = 0 -> 2x = 0, pi -> x = 0, pi/2
      final eq3 = Tan(const RationalNumber(2) * x);
      final sol3 = eq3.solve('x');
      check(sol3).contains(RationalNumber.zero);
      check(sol3).contains(const Mul(RationalNumber(1, 2), ConstantNumber.pi));
    });

    test('scaled constants', () {
      // 4*cos(x) - 2 = 0 -> cos(x) = 1/2 -> x = pi/3, 5pi/3
      final eqCos =
          const RationalNumber(4) * const Cos(x) - const RationalNumber(2);
      final solCos = eqCos.solve('x');
      check(solCos)
          .contains(const Mul(RationalNumber(1, 3), ConstantNumber.pi));
      check(solCos)
          .contains(const Mul(RationalNumber(5, 3), ConstantNumber.pi));

      // 6*sin(x) - 3 = 0 -> sin(x) = 1/2 -> x = pi/6, 5pi/6
      final eqSin =
          const RationalNumber(6) * const Sin(x) - const RationalNumber(3);
      final solSin = eqSin.solve('x');
      check(solSin)
          .contains(const Mul(RationalNumber(1, 6), ConstantNumber.pi));
      check(solSin)
          .contains(const Mul(RationalNumber(5, 6), ConstantNumber.pi));

      // 3*tan(x) - 3 = 0 -> tan(x) = 1 -> x = pi/4, 5pi/4
      final eqTan =
          const RationalNumber(3) * const Tan(x) - const RationalNumber(3);
      final solTan = eqTan.solve('x');
      check(solTan)
          .contains(const Mul(RationalNumber(1, 4), ConstantNumber.pi));
      check(solTan)
          .contains(const Mul(RationalNumber(5, 4), ConstantNumber.pi));

      // Arbitrary constant: sin(x) - 1/3 = 0 -> should yield asin(1/3) and pi - asin(1/3)
      final eqSinArb = const Sin(x) - const RationalNumber(1, 3);
      final solSinArb = eqSinArb.solve('x');
      check(solSinArb.length).equals(2);
      check(solSinArb).contains(const Asin(RationalNumber(1, 3)));
      check(solSinArb)
          .contains(ConstantNumber.pi - const Asin(RationalNumber(1, 3)));

      // Arbitrary constant: cos(x) - 1/3 = 0 -> should yield acos(1/3) and 2pi - acos(1/3)
      final eqCosArb = const Cos(x) - const RationalNumber(1, 3);
      final solCosArb = eqCosArb.solve('x');
      check(solCosArb.length).equals(2);
      check(solCosArb).contains(const Acos(RationalNumber(1, 3)));
      check(solCosArb).contains(
        const Mul(RationalNumber(2), ConstantNumber.pi) -
            const Acos(RationalNumber(1, 3)),
      );
    });

    test('out-of-bounds trigonometric values', () {
      // sin(x) = 2 -> empty
      final eq1 = const Sin(x) - const RationalNumber(2);
      check(eq1.solve('x')).isEmpty();

      // sin(x) = -1.5 -> empty
      final eq2 = const Sin(x) + const RationalNumber(3, 2);
      check(eq2.solve('x')).isEmpty();

      // cos(x) = 3 -> empty
      final eq3 = const Cos(x) - const RationalNumber(3);
      check(eq3.solve('x')).isEmpty();

      // 2*cos(x) + 5 = 0 -> cos(x) = -5/2 -> empty
      final eq4 =
          const RationalNumber(2) * const Cos(x) + const RationalNumber(5);
      check(eq4.solve('x')).isEmpty();
    });

    test('trigonometric products', () {
      // sin(x) * cos(x) = 0 -> roots: 0, pi, pi/2, 3pi/2
      final prod1 = const Sin(x) * const Cos(x);
      final sol1 = prod1.solve('x');
      check(sol1).contains(RationalNumber.zero);
      check(sol1).contains(ConstantNumber.pi);
      check(sol1).contains(const Mul(RationalNumber(1, 2), ConstantNumber.pi));
      check(sol1).contains(const Mul(RationalNumber(3, 2), ConstantNumber.pi));

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

    test('reciprocal divisors', () {
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

      // 1 / sin(x) + 2 = 0 -> sin(x) = -1/2 -> 7pi/6, 11pi/6
      final eq4 =
          (const RationalNumber(1) / const Sin(x)) + const RationalNumber(2);
      final sol4 = eq4.solve('x');
      check(sol4).contains(const Mul(RationalNumber(7, 6), ConstantNumber.pi));
      check(sol4).contains(const Mul(RationalNumber(11, 6), ConstantNumber.pi));

      // 1 / sin(x) - 1/2 = 0 -> sin(x) = 2 -> empty
      final eq5 =
          (const RationalNumber(1) / const Sin(x)) - const RationalNumber(1, 2);
      check(eq5.solve('x')).isEmpty();

      // 1 / cos(x) - 1/2 = 0 -> cos(x) = 2 -> empty
      final eq6 =
          (const RationalNumber(1) / const Cos(x)) - const RationalNumber(1, 2);
      check(eq6.solve('x')).isEmpty();
    });

    test('reciprocal divisor with zero RHS (1 / sin(x) = 0)', () {
      // 1 / sin(x) = 0 has no solutions in R or C.
      // Calling solve should return empty list rather than throwing UnsupportedError.
      final eq = const RationalNumber(1) / const Sin(x);
      final sol = eq.solve('x');
      check(sol).isEmpty();
    });

    test('reciprocal variable with zero RHS (1 / x = 0)', () {
      // 1 / x = 0 has no solutions.
      // Calling solve should return empty list rather than throwing UnsupportedError.
      final eq = const RationalNumber(1) / x;
      final sol = eq.solve('x');
      check(sol).isEmpty();
    });
  });

  group('M4 Challenger 1: Degree 3, 4, 5+ Polynomials', () {
    test('cubic with rational roots: x^3 - 4x = 0', () {
      final eq = x.pow(const RationalNumber(3)) - const RationalNumber(4) * x;
      final sol = eq.solve('x');
      check(sol.length).equals(3);
      check(sol).contains(RationalNumber.zero);
      check(sol).contains(const RationalNumber(2));
      check(sol).contains(const RationalNumber(-2));
    });

    test('cubic with fractional rational roots: 2x^3 - 3x^2 - 11x + 6 = 0', () {
      // (x + 2)(2x - 1)(x - 3) = 0 -> x = -2, 1/2, 3
      final eq =
          const RationalNumber(2) * x.pow(const RationalNumber(3)) -
          const RationalNumber(3) * x.pow(const RationalNumber(2)) -
          const RationalNumber(11) * x +
          const RationalNumber(6);
      final sol = eq.solve('x');
      check(sol).contains(const RationalNumber(-2));
      check(sol).contains(const RationalNumber(1, 2));
      check(sol).contains(const RationalNumber(3));
    });

    test('quartic: (x - 1)(x - 2)(x - 3)(x - 4) = 0', () {
      final eq =
          (x - const RationalNumber(1)) *
          (x - const RationalNumber(2)) *
          (x - const RationalNumber(3)) *
          (x - const RationalNumber(4));
      final sol = eq.solve('x');
      check(sol.length).equals(4);
      check(sol).contains(const RationalNumber(1));
      check(sol).contains(const RationalNumber(2));
      check(sol).contains(const RationalNumber(3));
      check(sol).contains(const RationalNumber(4));
    });

    test('biquadratic with mixed real and complex roots: x^4 - 1 = 0', () {
      final eq = x.pow(const RationalNumber(4)) - const RationalNumber(1);
      final sol = eq.solve('x');
      check(sol.length).equals(4);
      check(sol).contains(const RationalNumber(1));
      check(sol).contains(const RationalNumber(-1));
      check(sol).contains(i);
      check(sol).contains(-i);

      for (final root in sol) {
        final cVal = root.evaluateComplex();
        final eqVal = eq.evaluateComplex({'x': cVal});
        check(eqVal.a.abs()).isLessThan(1e-12);
        check(eqVal.b.abs()).isLessThan(1e-12);
      }
    });

    test('biquadratic with 4 complex roots: x^4 + 5x^2 + 4 = 0', () {
      final eq =
          x.pow(const RationalNumber(4)) +
          const RationalNumber(5) * x.pow(const RationalNumber(2)) +
          const RationalNumber(4);
      final sol = eq.solve('x');
      check(sol.length).equals(4);
      check(sol).contains(i);
      check(sol).contains(-i);
      check(sol).contains(const RationalNumber(2) * i);
      check(sol).contains(const RationalNumber(-2) * i);

      for (final root in sol) {
        final cVal = root.evaluateComplex();
        final eqVal = eq.evaluateComplex({'x': cVal});
        check(eqVal.a.abs()).isLessThan(1e-12);
        check(eqVal.b.abs()).isLessThan(1e-12);
      }
    });

    test('biquadratic: x^4 - 3x^2 - 4 = 0', () {
      // u^2 - 3u - 4 = (u - 4)(u + 1) = 0 -> u = 4 (x = +/-2), u = -1 (x = +/-i)
      final eq =
          x.pow(const RationalNumber(4)) -
          const RationalNumber(3) * x.pow(const RationalNumber(2)) -
          const RationalNumber(4);
      final sol = eq.solve('x');
      check(sol.length).equals(4);
      check(sol).contains(const RationalNumber(2));
      check(sol).contains(const RationalNumber(-2));
      check(sol).contains(i);
      check(sol).contains(-i);

      for (final root in sol) {
        final cVal = root.evaluateComplex();
        final eqVal = eq.evaluateComplex({'x': cVal});
        check(eqVal.a.abs()).isLessThan(1e-12);
        check(eqVal.b.abs()).isLessThan(1e-12);
      }
    });

    test('biquadratic: x^4 + 13x^2 + 36 = 0', () {
      // (x^2 + 4)(x^2 + 9) = 0 -> roots: +/- 2i, +/- 3i
      final eq =
          x.pow(const RationalNumber(4)) +
          const RationalNumber(13) * x.pow(const RationalNumber(2)) +
          const RationalNumber(36);
      final sol = eq.solve('x');
      check(sol.length).equals(4);
      check(sol).contains(const RationalNumber(2) * i);
      check(sol).contains(const RationalNumber(-2) * i);
      check(sol).contains(const RationalNumber(3) * i);
      check(sol).contains(const RationalNumber(-3) * i);

      for (final root in sol) {
        final cVal = root.evaluateComplex();
        final eqVal = eq.evaluateComplex({'x': cVal});
        check(eqVal.a.abs()).isLessThan(1e-12);
        check(eqVal.b.abs()).isLessThan(1e-12);
      }
    });

    test('negative roots: x^3 = -8 -> x^3 + 8 = 0', () {
      final eq = x.pow(const RationalNumber(3)) + const RationalNumber(8);
      final sol = eq.solve('x');
      check(sol).contains(const RationalNumber(-2));
      // Does factor() decompose x^3 + 8 into (x + 2)(x^2 - 2x + 4)?
      // Roots should be -2, 1 + i*sqrt(3), 1 - i*sqrt(3) -> 3 roots!
      check(sol.length).equals(3);

      // Check all returned roots satisfy eq
      for (final root in sol) {
        final cVal = root.evaluateComplex();
        final eqVal = eq.evaluateComplex({'x': cVal});
        check(eqVal.a.abs()).isLessThan(1e-12);
        check(eqVal.b.abs()).isLessThan(1e-12);
      }
    });

    test('negative roots: x^5 = -32 -> x^5 + 32 = 0', () {
      final eq = x.pow(const RationalNumber(5)) + const RationalNumber(32);
      final sol = eq.solve('x');
      check(sol).contains(const RationalNumber(-2));

      final cVal = const RationalNumber(-2).evaluateComplex();
      final eqVal = eq.evaluateComplex({'x': cVal});
      check(eqVal.a.abs()).isLessThan(1e-12);
      check(eqVal.b.abs()).isLessThan(1e-12);
    });

    test('negative roots: x^3 + 27 = 0', () {
      final eq = x.pow(const RationalNumber(3)) + const RationalNumber(27);
      final sol = eq.solve('x');
      check(sol).contains(const RationalNumber(-3));
    });

    test('negative roots: (x + 3)^3 + 8 = 0 -> x = -5', () {
      final eq =
          (x + const RationalNumber(3)).pow(const RationalNumber(3)) +
          const RationalNumber(8);
      final sol = eq.solve('x');
      check(sol).contains(const RationalNumber(-5));
    });

    test('degree 6 polynomial: x^6 - 1 = 0', () {
      final eq = x.pow(const RationalNumber(6)) - const RationalNumber(1);
      final sol = eq.solve('x');
      check(sol).contains(const RationalNumber(1));
      check(sol).contains(const RationalNumber(-1));
      for (final root in sol) {
        final cVal = root.evaluateComplex();
        final eqVal = eq.evaluateComplex({'x': cVal});
        check(eqVal.a.abs()).isLessThan(1e-12);
        check(eqVal.b.abs()).isLessThan(1e-12);
      }
    });
  });
}
