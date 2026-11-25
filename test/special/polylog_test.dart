import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/special.dart';
import 'package:more/number.dart' show Complex;
import 'package:test/scaffolding.dart';

void main() {
  group('polylog', () {
    test('evaluates special values, negative integers, and branch cuts', () {
      check(polylog(2, 0.0)).equals(0.0);
      check(polylog(2, 1.0)).isCloseTo(math.pi * math.pi / 6.0, 1e-14);
      check(polylog(2, -1.0)).isCloseTo(-math.pi * math.pi / 12.0, 1e-14);
      check(polylog(2, 0.5)).isCloseTo(
        math.pi * math.pi / 12.0 - 0.5 * math.pow(math.ln2, 2),
        1e-14,
      );
      check(polylog(2, -2.0)).isCloseTo(-1.436746366883681, 1e-14);
      check(polylog(2, -0.9)).isCloseTo(-0.7521631792172616, 1e-14);
      check(polylog(2, 0.8)).isCloseTo(1.0747946000082484, 1e-14);
      check(polylog(3, 1.0)).isCloseTo(zeta(3.0), 1e-14);
      check(polylog(1, 0.5)).isCloseTo(math.ln2, 1e-14);
      check(polylog(0, 0.5)).isCloseTo(1.0, 1e-14);
      check(polylog(-1, 0.5)).isCloseTo(2.0, 1e-14);
      check(polylog(-2, 0.5)).isCloseTo(6.0, 1e-14);
      check(polylog(-2, -2.0)).isCloseTo(2.0 / 27.0, 1e-14);
      check(polylog(0.5, -1.0))
          .isCloseTo(-(1.0 - math.pow(2.0, 0.5)) * zeta(0.5), 1e-13);
      check(polylog(2, 1.5)).isNaN;
      check(polylog(2, double.negativeInfinity))
          .equals(double.negativeInfinity);
      check(polylog(0, double.negativeInfinity)).equals(-1.0);
      check(polylog(-2, double.negativeInfinity)).equals(0.0);
    });

    test('maintains continuity and derivative accuracy across x = -1', () {
      const h = 1e-6;
      for (final x in [-1.2, -1.05, -1.01, -1.001, -0.999, -0.95, -0.7]) {
        final fd = (polylog(2, x + h) - polylog(2, x - h)) / (2.0 * h);
        final expectedDeriv = -math.log(1.0 - x) / x;
        check(fd).isCloseTo(expectedDeriv, 1e-8);
      }
    });
  });

  group('polylogComplex', () {
    test(
      'evaluates negative integers, unit disk boundaries, and mid-disk series',
      () {
        const z = Complex(0.3, 0.4);
        final liNeg1 = polylogComplex(const Complex(-1), z);
        final expectedNeg1 = z / ((Complex.one - z) * (Complex.one - z));
        check((liNeg1 - expectedNeg1).abs()).isLessThan(1e-14);

        final liNeg3 = polylogComplex(const Complex(-3), z);
        final expectedNeg3 =
            (z + z * z * 4.0 + z * z * z) / (Complex.one - z).pow(4);
        check((liNeg3 - expectedNeg3).abs()).isLessThan(1e-14);

        // Direct series in 0.5 < |z| <= 1 away from +-1: Re(Li_2(i*y)) = 0.25*Li_2(-y^2)
        final liImag = polylogComplex(
          const Complex(2),
          const Complex(0.0, 0.8),
        );
        check(liImag.a.toDouble()).isCloseTo(0.25 * polylog(2, -0.64), 1e-13);

        check(polylogComplex(const Complex(2), Complex.one).a.toDouble())
            .isCloseTo(math.pi * math.pi / 6.0, 1e-14);
        check(polylogComplex(const Complex(0.5), Complex.one).a.toDouble())
            .equals(double.infinity);
      },
    );

    test('evaluates near-1 log series, near--1 duplication, and complex orders', () {
      final nearOne = polylogComplex(
        const Complex(3),
        const Complex(0.85, 0.1),
      );
      check(nearOne.a.toDouble()).isCloseTo(0.9740526927552886, 1e-13);
      check(nearOne.b.toDouble()).isCloseTo(0.13829433431735538, 1e-13);

      final nearNegOne = polylogComplex(
        const Complex(3),
        const Complex(-0.9999),
      );
      final dupCheck =
          const Complex(0.25) *
              polylogComplex(const Complex(3), const Complex(0.99980001)) -
          polylogComplex(const Complex(3), const Complex(0.9999));
      check((nearNegOne - dupCheck).abs()).isLessThan(1e-13);

      // Complex order near z = 1 verified via z * d/dz Li_s(z) = Li_{s - 1}(z)
      const sC = Complex(2.0, 1.0);
      const zC = Complex(0.96, 0.02);
      const h = 1e-6;
      final df =
          (polylogComplex(sC, zC + h) - polylogComplex(sC, zC - h)) / (2.0 * h);
      final expectedDeriv = polylogComplex(sC - Complex.one, zC) / zC;
      check((df - expectedDeriv).abs() / expectedDeriv.abs()).isLessThan(1e-7);

      check(polylogComplex(Complex.nan, Complex.zero).isNaN).isTrue;
      check(polylogComplex(const Complex(2), Complex.nan).isNaN).isTrue;
    });
  });
}
