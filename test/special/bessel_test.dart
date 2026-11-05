import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/special.dart';
import 'package:test/test.dart';

void main() {
  group('Bessel functions', () {
    test('Bessel J0 and J1 exact and reference values', () {
      check(besselJ0(0)).equals(1.0);
      check(besselJ1(0)).equals(0.0);
      check(besselJ0(1.0)).isCloseTo(0.7651976865579666, 1e-6);
      check(besselJ0(5.0)).isCloseTo(-0.1775967713143383, 1e-6);
      check(besselJ0(10.0)).isCloseTo(-0.2459357644513483, 1e-6);
      check(besselJ1(1.0)).isCloseTo(0.4400505857449335, 1e-6);
      check(besselJ1(5.0)).isCloseTo(-0.327579137591465, 1e-6);
      check(besselJ1(10.0)).isCloseTo(0.0434727461688614, 1e-6);
      check(besselJ0(-1.0)).isCloseTo(besselJ0(1.0), 1e-9);
      check(besselJ1(-1.0)).isCloseTo(-besselJ1(1.0), 1e-9);
    });

    test('Bessel Y0 and Y1 boundary and reference values', () {
      check(besselY0(0)).isNaN();
      check(besselY0(-1)).isNaN();
      check(besselY1(0)).isNaN();
      check(besselY1(-1)).isNaN();
      check(besselY0(1.0)).isCloseTo(0.0882569642156765, 1e-6);
      check(besselY0(5.0)).isCloseTo(-0.308517623137123, 1e-6);
      check(besselY0(10.0)).isCloseTo(0.0556711672835994, 1e-6);
      check(besselY1(1.0)).isCloseTo(-0.7812128213002889, 1e-6);
      check(besselY1(5.0)).isCloseTo(0.147863143391227, 1e-6);
      check(besselY1(10.0)).isCloseTo(0.2490154242069538, 1e-6);
    });

    test('Modified Bessel I0 and I1 reference values', () {
      check(besselI0(0)).equals(1.0);
      check(besselI1(0)).equals(0.0);
      check(besselI0(1.0)).isCloseTo(1.2660658777520083, 1e-6);
      check(besselI0(5.0)).isCloseTo(27.23987182441066, 1e-4);
      check(besselI1(1.0)).isCloseTo(0.5651591039924850, 1e-6);
      check(besselI1(5.0)).isCloseTo(24.33564214245648, 1e-4);
      // Symmetry
      check(besselI0(-2.0)).isCloseTo(besselI0(2.0), 1e-9);
      check(besselI1(-2.0)).isCloseTo(-besselI1(2.0), 1e-9);
    });

    test('Modified Bessel K0 and K1 reference values', () {
      check(besselK0(0)).isNaN();
      check(besselK0(-1)).isNaN();
      check(besselK1(0)).isNaN();
      check(besselK1(-1)).isNaN();
      check(besselK0(1.0)).isCloseTo(0.4210244382407083, 1e-6);
      check(besselK0(5.0)).isCloseTo(0.00369110762356937, 1e-6);
      check(besselK1(1.0)).isCloseTo(0.6019072301972346, 1e-6);
      check(besselK1(5.0)).isCloseTo(0.00404457497148563, 1e-6);
    });

    test('infinite and NaN arguments', () {
      check(besselI0(double.infinity)).equals(double.infinity);
      check(besselI0(double.negativeInfinity)).equals(double.infinity);
      check(besselI1(double.infinity)).equals(double.infinity);
      check(besselI1(double.negativeInfinity)).equals(double.negativeInfinity);
      check(besselK0(double.infinity)).equals(0.0);
      check(besselK1(double.infinity)).equals(0.0);
      check(besselJ0(double.infinity)).equals(0.0);
      check(besselJ0(double.negativeInfinity)).equals(0.0);
      check(besselJ1(double.infinity)).equals(0.0);
      check(besselJ1(double.negativeInfinity)).equals(0.0);
      check(besselY0(double.infinity)).equals(0.0);
      check(besselY1(double.infinity)).equals(0.0);

      // Infinite nu returns NaN
      check(besselJ(double.infinity, 5.0)).isNaN();
      check(besselJ(double.negativeInfinity, 5.0)).isNaN();
      check(besselY(double.infinity, 5.0)).isNaN();
      check(besselY(double.negativeInfinity, 5.0)).isNaN();
      check(besselI(double.infinity, 5.0)).isNaN();
      check(besselI(double.negativeInfinity, 5.0)).isNaN();
      check(besselK(double.infinity, 5.0)).isNaN();
      check(besselK(double.negativeInfinity, 5.0)).isNaN();

      // Infinite x
      check(besselJ(2.5, double.infinity)).equals(0.0);
      check(besselY(2.5, double.infinity)).equals(0.0);
      check(besselI(2.5, double.infinity)).equals(double.infinity);
      check(besselK(2.5, double.infinity)).equals(0.0);

      // Small x in integer Miller recurrence
      check(besselJ(5, 1e-100).isFinite).isTrue();
      check(besselI(10, 1e-10).isFinite).isTrue();

      // Large x asymptotic accuracy for non-integer orders
      final expectedJHalf50 =
          math.sqrt(2.0 / (math.pi * 50.0)) * math.sin(50.0);
      check(besselJ(0.5, 50.0)).isCloseTo(expectedJHalf50, 1e-12);

      final expectedYHalf50 =
          -math.sqrt(2.0 / (math.pi * 50.0)) * math.cos(50.0);
      check(besselY(0.5, 50.0)).isCloseTo(expectedYHalf50, 1e-12);

      final expectedKHalf50 =
          math.sqrt(math.pi / (2.0 * 50.0)) * math.exp(-50.0);
      check(besselK(0.5, 50.0)).isCloseTo(expectedKHalf50, 1e-25);
    });

    test('general-order besselJ', () {
      for (final x in [0.5, 1.0, 2.5, 5.0]) {
        check(besselJ(0, x)).isCloseTo(besselJ0(x), 1e-10);
        check(besselJ(1, x)).isCloseTo(besselJ1(x), 1e-10);
        check(besselJ(-1, x)).isCloseTo(-besselJ1(x), 1e-10);
        check(besselJ(-2, x)).isCloseTo(besselJ(2, x), 1e-10);

        // Recurrence: J_{n-1}(x) + J_{n+1}(x) = (2n / x) * J_n(x)
        final j0 = besselJ(0, x);
        final j1 = besselJ(1, x);
        final j2 = besselJ(2, x);
        check(j0 + j2).isCloseTo((2.0 / x) * j1, 1e-8);

        // Half-integer: J_{1/2}(x) = sqrt(2 / (pi * x)) * sin(x)
        final expectedHalf = math.sqrt(2.0 / (math.pi * x)) * math.sin(x);
        check(besselJ(0.5, x)).isCloseTo(expectedHalf, 1e-6);
      }
    });

    test('general-order besselY', () {
      for (final x in [0.5, 1.0, 2.5, 5.0]) {
        check(besselY(0, x)).isCloseTo(besselY0(x), 1e-10);
        check(besselY(1, x)).isCloseTo(besselY1(x), 1e-10);
        check(besselY(-1, x)).isCloseTo(-besselY1(x), 1e-10);

        // Recurrence: Y_{n-1}(x) + Y_{n+1}(x) = (2n / x) * Y_n(x)
        final y0 = besselY(0, x);
        final y1 = besselY(1, x);
        final y2 = besselY(2, x);
        check(y0 + y2).isCloseTo((2.0 / x) * y1, 1e-8);
      }
    });

    test('general-order besselI', () {
      for (final x in [0.5, 1.0, 2.5, 5.0]) {
        check(besselI(0, x)).isCloseTo(besselI0(x), 1e-10);
        check(besselI(1, x)).isCloseTo(besselI1(x), 1e-10);
        check(besselI(-1, x)).isCloseTo(besselI1(x), 1e-10);

        // Recurrence: I_{n-1}(x) - I_{n+1}(x) = (2n / x) * I_n(x)
        final i0 = besselI(0, x);
        final i1 = besselI(1, x);
        final i2 = besselI(2, x);
        check(i0 - i2).isCloseTo((2.0 / x) * i1, 1e-6);

        // Half-integer: I_{1/2}(x) = sqrt(2 / (pi * x)) * sinh(x)
        final sinhVal = 0.5 * (math.exp(x) - math.exp(-x));
        final expectedHalf = math.sqrt(2.0 / (math.pi * x)) * sinhVal;
        check(besselI(0.5, x)).isCloseTo(expectedHalf, 1e-6);
      }
    });

    test('general-order besselK', () {
      for (final x in [0.5, 1.0, 2.5, 5.0]) {
        check(besselK(0, x)).isCloseTo(besselK0(x), 1e-10);
        check(besselK(1, x)).isCloseTo(besselK1(x), 1e-10);
        check(besselK(-1, x)).isCloseTo(besselK1(x), 1e-10);

        // Recurrence: K_{n+1}(x) - K_{n-1}(x) = (2n / x) * K_n(x)
        final k0 = besselK(0, x);
        final k1 = besselK(1, x);
        final k2 = besselK(2, x);
        check(k2 - k0).isCloseTo((2.0 / x) * k1, 1e-8);
      }
    });
  });
}
