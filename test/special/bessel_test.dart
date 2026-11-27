import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/special.dart';
import 'package:more/number.dart' show Complex;
import 'package:test/scaffolding.dart';

void main() {
  group('besselJ', () {
    test('evaluates J0 and J1 reference values and parity', () {
      check(besselJ(0, 0)).equals(1.0);
      check(besselJ(1, 0)).equals(0.0);
      check(besselJ(0, 1.0)).isCloseTo(0.7651976865579665, 1e-14);
      check(besselJ(0, 5.0)).isCloseTo(-0.1775967713143383, 1e-14);
      check(besselJ(0, 10.0)).isCloseTo(-0.2459357644513483, 1e-14);
      check(besselJ(1, 1.0)).isCloseTo(0.4400505857449335, 1e-14);
      check(besselJ(1, 5.0)).isCloseTo(-0.3275791375914652, 1e-14);
      check(besselJ(1, 10.0)).isCloseTo(0.04347274616886144, 1e-14);
      check(besselJ(0, -1.0)).isCloseTo(besselJ(0, 1.0), 1e-14);
      check(besselJ(1, -1.0)).isCloseTo(-besselJ(1, 1.0), 1e-14);
      check(besselJ(-1, 2.0)).isCloseTo(-besselJ(1, 2.0), 1e-14);
      check(besselJ(-2, 2.0)).isCloseTo(besselJ(2, 2.0), 1e-14);
    });

    test('evaluates Miller, upward, downward, and asymptotic regimes', () {
      for (final x in [0.5, 1.0, 2.5, 5.0, 15.0, 30.0]) {
        check(besselJ(0, x) + besselJ(2, x))
            .isCloseTo((2.0 / x) * besselJ(1, x), 1e-12);
        final expectedHalf = math.sqrt(2.0 / (math.pi * x)) * math.sin(x);
        check(besselJ(0.5, x)).isCloseTo(expectedHalf, 1e-14);
      }

      // Integer and non-integer orders across x <= nu (MillerNth) and x > nu
      for (final (nu, x) in [
        (5.0, 2.0),
        (5.5, 2.0),
        (2.5, 10.0),
        (-2.5, 3.0),
        (2.5, 40.0),
      ]) {
        final lhs = besselJ(nu - 1.0, x) + besselJ(nu + 1.0, x);
        final rhs = (2.0 * nu / x) * besselJ(nu, x);
        check(lhs).isCloseTo(rhs, 1e-12);
      }

      // Large order MillerNth triggers 1e100 rescaling; verify recurrence
      for (final nu in [120.0, 120.5]) {
        final lhs = besselJ(nu - 1.0, 5.0) + besselJ(nu + 1.0, 5.0);
        final rhs = (2.0 * nu / 5.0) * besselJ(nu, 5.0);
        check(lhs).isCloseTo(rhs, 1e-12 * rhs.abs());
      }
      // Large x in _besselJMillerPair triggers 1e100 rescaling
      check(besselJ(0.5, 24.0))
          .isCloseTo(math.sqrt(2.0 / (math.pi * 24.0)) * math.sin(24.0), 1e-13);
      check(besselJ(0, 24.0) + besselJ(2, 24.0))
          .isCloseTo((2.0 / 24.0) * besselJ(1, 24.0), 1e-13);

      // Large order log-gamma series branch (nu > 100, x <= 2)
      check(math.log(besselJ(120.5, 1.5)))
          .isCloseTo(120.5 * math.log(0.75) - gammaLn(121.5), 1e-2);
      check(besselJ(200.5, 0.1)).equals(0.0);
    });

    test('handles tiny arguments, infinities, and NaN', () {
      check(besselJ(5, 1e-10)).isCloseTo(
        math.pow(0.5e-10, 5) / 120.0,
        1e-14 * math.pow(0.5e-10, 5) / 120.0,
      );
      check(besselJ(5, 1e-100)).equals(0.0);
      check(besselJ(0, double.infinity)).equals(0.0);
      check(besselJ(2, double.negativeInfinity)).equals(0.0);
      check(besselJ(0.5, double.negativeInfinity)).isNaN;
      check(besselJ(-0.5, 0.0)).isNaN;
      check(besselJ(-0.5, -1.0)).isNaN;
      check(besselJ(double.infinity, 5.0)).isNaN;
      check(besselJ(double.nan, 5.0)).isNaN;
    });
  });

  group('besselJComplex', () {
    test('satisfies branch symmetry, series, and asymptotic regimes', () {
      const nu = Complex(0.5);
      const zQ2 = Complex(-15.0, 1.0);
      const zQ3 = Complex(-15.0, -1.0);
      final jQ2 = besselJComplex(nu, zQ2);
      final jQ3 = besselJComplex(nu, zQ3);
      check((jQ3 - jQ2.conjugate()).abs()).isLessThan(1e-12);

      final expectedJQ3 =
          (const Complex(2.0 / math.pi) / zQ3).sqrt() * zQ3.sin();
      check((jQ3 - expectedJQ3).abs() / expectedJQ3.abs()).isLessThan(1e-12);

      // Small |z| power series and negative integer order
      const nuC = Complex(1.5, 0.5);
      const zSmall = Complex(2.0, 1.0);
      final recSmall =
          besselJComplex(nuC - Complex.one, zSmall) +
          besselJComplex(nuC + Complex.one, zSmall) -
          const Complex(2.0) * nuC / zSmall * besselJComplex(nuC, zSmall);
      check(recSmall.abs()).isLessThan(1e-12);

      check(
        (besselJComplex(const Complex(-3), zSmall) +
                besselJComplex(const Complex(3), zSmall))
            .abs(),
      ).isLessThan(1e-13);

      // RHP asymptotic (|z| > max(12, |nu|^2))
      const zAsymp = Complex(15.0, 2.0);
      final recAsymp =
          besselJComplex(nuC - Complex.one, zAsymp) +
          besselJComplex(nuC + Complex.one, zAsymp) -
          const Complex(2.0) * nuC / zAsymp * besselJComplex(nuC, zAsymp);
      check(recAsymp.abs() / besselJComplex(nuC, zAsymp).abs())
          .isLessThan(1e-12);
    });

    test('handles zero and non-finite boundaries', () {
      check(besselJComplex(Complex.zero, Complex.zero)).equals(Complex.one);
      check(besselJComplex(Complex.one, Complex.zero)).equals(Complex.zero);
      check(besselJComplex(const Complex(-2), Complex.zero))
          .equals(Complex.zero);
      check(besselJComplex(const Complex(-0.5), Complex.zero).isNaN).isTrue;
      check(besselJComplex(Complex.nan, Complex.one).isNaN).isTrue;
    });
  });

  group('besselY', () {
    test('evaluates Y0, Y1, negative orders, and asymptotic Wronskians', () {
      check(besselY(0, 1.0)).isCloseTo(0.08825696421567696, 1e-14);
      check(besselY(0, 5.0)).isCloseTo(-0.3085176252490338, 1e-14);
      check(besselY(0, 10.0)).isCloseTo(0.05567116728359939, 1e-14);
      check(besselY(1, 1.0)).isCloseTo(-0.7812128213002887, 1e-14);
      check(besselY(1, 5.0)).isCloseTo(0.14786314339122684, 1e-14);
      check(besselY(1, 10.0)).isCloseTo(0.24901542420695388, 1e-14);

      for (final x in [0.5, 1.0, 2.5, 5.0, 15.0, 30.0]) {
        check(besselY(0, x) + besselY(2, x))
            .isCloseTo((2.0 / x) * besselY(1, x), 1e-12);
        final expectedHalf = -math.sqrt(2.0 / (math.pi * x)) * math.cos(x);
        check(besselY(0.5, x)).isCloseTo(expectedHalf, 1e-14);
      }

      // Negative non-integer recurrence and near-integer reflection stability
      check(besselY(-3.5, 3.0) + besselY(-1.5, 3.0))
          .isCloseTo((-5.0 / 3.0) * besselY(-2.5, 3.0), 1e-12);
      check(besselY(2.0 + 1e-10, 5.0)).isCloseTo(besselY(2.0, 5.0), 1e-8);
      check(besselY(2.0 + 1e-10, 1.0)).isCloseTo(besselY(2.0, 1.0), 1e-8);

      // Hankel asymptotic Wronskian J_nu*Y_{nu+1} - J_{nu+1}*Y_nu = -2/(pi*x)
      final wronskian =
          besselJ(2.5, 40.0) * besselY(3.5, 40.0) -
          besselJ(3.5, 40.0) * besselY(2.5, 40.0);
      check(wronskian).isCloseTo(-2.0 / (math.pi * 40.0), 1e-14);
    });

    test('handles zero, negative x, infinities, and NaN', () {
      check(besselY(0, 0)).isNaN;
      check(besselY(0, -1)).isNaN;
      check(besselY(1, 0)).isNaN;
      check(besselY(1, -1)).isNaN;
      check(besselY(double.infinity, 5.0)).isNaN;
    });
  });

  group('besselYComplex', () {
    test(
      'satisfies Wronskian across integer, non-integer, and asymptotic regimes',
      () {
        check(besselYComplex(const Complex(2), const Complex(3)).a.toDouble())
            .equals(besselY(2, 3));

        for (final (nu, z, tol) in const [
          (Complex(0.5, 0.3), Complex(2.0, 1.0), 1e-12),
          (Complex(1.0), Complex(2.0, 1.0), 1e-12),
          (Complex(-2.0), Complex(2.0, 1.0), 1e-12),
          (Complex(1.5, 0.2), Complex(15.0, 2.0), 1e-12),
        ]) {
          final w =
              besselJComplex(nu, z) * besselYComplex(nu + Complex.one, z) -
              besselJComplex(nu + Complex.one, z) * besselYComplex(nu, z);
          final expected = -const Complex(2.0 / math.pi) / z;
          check((w - expected).abs()).isLessThan(tol);
        }

        check(besselYComplex(Complex.zero, Complex.zero).isNaN).isTrue;
      },
    );
  });

  group('besselI', () {
    test('evaluates I0, I1, recurrences, negative orders, and large x', () {
      check(besselI(0, 0)).equals(1.0);
      check(besselI(1, 0)).equals(0.0);
      check(besselI(0, 1.0)).isCloseTo(1.2660658777520083, 1e-14);
      check(besselI(0, 5.0)).isCloseTo(27.239871823604443, 1e-12);
      check(besselI(1, 1.0)).isCloseTo(0.5651591039924850, 1e-14);
      check(besselI(1, 5.0)).isCloseTo(24.335642142450523, 1e-12);
      check(besselI(0, -2.0)).isCloseTo(besselI(0, 2.0), 1e-14);
      check(besselI(1, -2.0)).isCloseTo(-besselI(1, 2.0), 1e-14);

      for (final x in [0.5, 1.0, 2.5, 5.0, 15.0]) {
        final rhsI = (2.0 / x) * besselI(1, x);
        check(besselI(0, x) - besselI(2, x))
            .isCloseTo(rhsI, 1e-12 * rhsI.abs());
      }

      final expectedINeg =
          besselI(1.5, 2.0) - (2.0 / math.pi) * besselK(1.5, 2.0);
      check(besselI(-1.5, 2.0)).isCloseTo(expectedINeg, 1e-13);

      // Large nu > 100 series branch and large x > 700 asymptotic branch
      check(math.log(besselI(120.5, 1.5)))
          .isCloseTo(120.5 * math.log(0.75) - gammaLn(121.5), 1e-2);
      check(besselI(200.5, 0.1)).equals(0.0);
      check(math.log(besselI(0, 705.0)))
          .isCloseTo(705.0 - 0.5 * math.log(2.0 * math.pi * 705.0), 1e-3);
    });

    test('handles tiny arguments, infinities, and NaN', () {
      final expectedTiny = math.pow(0.5e-10, 10) / 3628800.0;
      check(besselI(10, 1e-10)).isCloseTo(expectedTiny, 1e-14 * expectedTiny);
      check(besselI(0, double.infinity)).equals(double.infinity);
      check(besselI(0, double.negativeInfinity)).equals(double.infinity);
      check(besselI(1, double.negativeInfinity))
          .equals(double.negativeInfinity);
      check(besselI(-0.5, 0.0)).isNaN;
      check(besselI(double.infinity, 5.0)).isNaN;
    });
  });

  group('besselIComplex', () {
    test('satisfies branch symmetry, series, and recurrence', () {
      const nu = Complex(0.5);
      const zQ2 = Complex(-15.0, 1.0);
      const zQ3 = Complex(-15.0, -1.0);
      final iQ2 = besselIComplex(nu, zQ2);
      final iQ3 = besselIComplex(nu, zQ3);
      check((iQ3 - iQ2.conjugate()).abs() / iQ2.abs()).isLessThan(1e-12);

      // Small |z| power series and negative integer order
      const nuC = Complex(1.5, 0.5);
      const zSmall = Complex(2.0, 1.0);
      final rec =
          besselIComplex(nuC - Complex.one, zSmall) -
          besselIComplex(nuC + Complex.one, zSmall) -
          const Complex(2.0) * nuC / zSmall * besselIComplex(nuC, zSmall);
      check(rec.abs()).isLessThan(1e-12);

      check(
        (besselIComplex(const Complex(-2), zSmall) -
                besselIComplex(const Complex(2), zSmall))
            .abs(),
      ).isLessThan(1e-13);

      check(besselIComplex(Complex.zero, Complex.zero)).equals(Complex.one);
      check(besselIComplex(Complex.one, Complex.zero)).equals(Complex.zero);
      check(besselIComplex(const Complex(-2), Complex.zero))
          .equals(Complex.zero);
      check(besselIComplex(const Complex(-0.5), Complex.zero).isNaN).isTrue;
    });
  });

  group('besselK', () {
    test('evaluates small-x series, quadrature, symmetry, and asymptotics', () {
      check(besselK(0, 1.0)).isCloseTo(0.4210244382407083, 1e-14);
      check(besselK(0, 5.0)).isCloseTo(0.003691098334042594, 1e-15);
      check(besselK(1, 1.0)).isCloseTo(0.6019072301972346, 1e-14);
      check(besselK(1, 5.0)).isCloseTo(0.004044613445452164, 1e-15);
      check(besselK(-2.5, 3.0)).isCloseTo(besselK(2.5, 3.0), 1e-14);

      // Small-x mu == 0 series (_besselK0Series / _besselK1Series) and recurrence
      check(
        besselI(0, 0.1) * besselK(1, 0.1) + besselI(1, 0.1) * besselK(0, 0.1),
      ).isCloseTo(10.0, 1e-13);
      check(besselK(2, 0.1) - besselK(0, 0.1))
          .isCloseTo(20.0 * besselK(1, 0.1), 1e-12);

      // Very small x < 1e-4 with non-zero mu
      final kHalfTiny = math.sqrt(math.pi / 2e-5) * math.exp(-1e-5);
      check(besselK(0.5, 1e-5)).isCloseTo(kHalfTiny, 1e-13 * kHalfTiny);
      check(besselK(1.5, 1e-5))
          .isCloseTo(kHalfTiny * (1.0 + 1.0 / 1e-5), 1e-12 * kHalfTiny * 1e5);

      for (final x in [0.5, 1.0, 2.5, 5.0, 15.0]) {
        check(besselK(2, x) - besselK(0, x))
            .isCloseTo((2.0 / x) * besselK(1, x), 1e-12);
      }
      for (final x in [20.0, 50.0]) {
        final expected = math.sqrt(math.pi / (2.0 * x)) * math.exp(-x);
        check(besselK(0.5, x)).isCloseTo(expected, 1e-14 * expected);
      }
      final wronskian =
          besselI(2, 30.0) * besselK(3, 30.0) +
          besselI(3, 30.0) * besselK(2, 30.0);
      check(wronskian).isCloseTo(1.0 / 30.0, 1e-14);
    });

    test('handles boundaries and NaN', () {
      check(besselK(0, 0)).isNaN;
      check(besselK(0, -1)).isNaN;
      check(besselK(1, 0)).isNaN;
      check(besselK(1, -1)).isNaN;
      check(besselK(0, double.infinity)).equals(0.0);
      check(besselK(double.infinity, 5.0)).isNaN;
    });
  });

  group('besselKComplex', () {
    test('satisfies Wronskians across integer, non-integer, and asymptotic regimes', () {
      check(besselKComplex(const Complex(2), const Complex(3)).a.toDouble())
          .equals(besselK(2, 3));

      for (final (nu, z, tol) in const [
        (Complex(0.7, 0.2), Complex(2.0, 1.0), 1e-12),
        (Complex(1.0), Complex(2.0, 1.0), 1e-12),
        (Complex(-2.0), Complex(2.0, 1.0), 1e-12),
        (Complex(0.7, 0.2), Complex(15.0, 1.0), 1e-12),
      ]) {
        final w =
            besselIComplex(nu, z) * besselKComplex(nu + 1, z) +
            besselIComplex(nu + 1, z) * besselKComplex(nu, z);
        check((w - z.reciprocal()).abs()).isLessThan(tol);
      }

      check(besselKComplex(const Complex(0, 1), Complex.zero).isNaN).isTrue;
      check(besselKComplex(Complex.zero, Complex.zero).a)
          .equals(double.infinity);
      // Large nu and x <= nu^2 triggering Miller backward recurrence rescaling
      check(besselJ(20, 200.0).isFinite).isTrue;
      check(besselJ(20.25, 200.0).isFinite).isTrue;
    });
  });
}
