import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/special.dart';
import 'package:more/number.dart' show Complex;
import 'package:test/scaffolding.dart';

void main() {
  group('ellipticK', () {
    test('evaluates standard values and domain boundaries', () {
      check(ellipticK(0)).equals(math.pi / 2.0);
      check(ellipticK(1)).equals(double.infinity);
      check(ellipticK(-1)).equals(double.infinity);
      check(ellipticK(0.5)).isCloseTo(1.685750354812596, 1e-14);
      check(ellipticK(-0.5)).isCloseTo(1.685750354812596, 1e-14);
      check(ellipticK(0.9)).isCloseTo(2.280549138422770, 1e-14);
      check(ellipticK(1.01)).isNaN;
      check(ellipticK(-1.01)).isNaN;
      check(ellipticK(double.nan)).isNaN;
    });
  });

  group('ellipticKComplex', () {
    test('matches real values and complex inputs', () {
      check(ellipticKComplex(const Complex(0.5)).a)
          .isCloseTo(ellipticK(0.5), 1e-14);
      check(ellipticKComplex(Complex.zero).a).isCloseTo(math.pi / 2.0, 1e-14);
      check(ellipticKComplex(Complex.one).a).equals(double.infinity);
      check(
        (ellipticKComplex(const Complex(0.4, 0.3)) -
                ellipticFComplex(
                  const Complex(math.pi / 2.0),
                  const Complex(0.4, 0.3),
                ))
            .abs(),
      ).isLessThan(1e-13);
      check(ellipticKComplex(Complex.nan).isNaN).isTrue;
    });
  });

  group('ellipticE', () {
    test('evaluates complete integral values and boundaries', () {
      check(ellipticE(0)).equals(math.pi / 2.0);
      check(ellipticE(1)).equals(1.0);
      check(ellipticE(-1)).equals(1.0);
      check(ellipticE(0.5)).isCloseTo(1.4674622093394272, 1e-14);
      check(ellipticE(-0.5)).isCloseTo(1.4674622093394272, 1e-14);
      check(ellipticE(0.9)).isCloseTo(1.1716970527816176, 1e-14);
      check(ellipticE(1.01)).isNaN;
      check(ellipticE(-1.01)).isNaN;
      check(ellipticE(double.nan)).isNaN;
    });

    test('evaluates incomplete integral quasi-periodicity and boundaries', () {
      check(ellipticE(0.5, phi: 0)).equals(0.0);
      check(ellipticE(0, phi: 1.2)).isCloseTo(1.2, 1e-14);
      check(ellipticE(0.5, phi: math.pi / 2.0))
          .isCloseTo(ellipticE(0.5), 1e-14);
      check(ellipticE(0.8, phi: math.pi / 2.0))
          .isCloseTo(ellipticE(0.8), 1e-14);
      check(ellipticE(1.0, phi: 0.7)).isCloseTo(math.sin(0.7), 1e-14);
      check(ellipticE(0.5, phi: -0.7))
          .isCloseTo(-ellipticE(0.5, phi: 0.7), 1e-14);

      final eBase = ellipticE(0.4, phi: 0.6);
      final eShifted = ellipticE(0.4, phi: 0.6 + math.pi);
      check(eShifted).isCloseTo(eBase + 2.0 * ellipticE(0.4), 1e-14);

      check(ellipticE(1.2, phi: 0.5)).isNaN;
      check(ellipticE(0.5, phi: double.nan)).isNaN;
      check(ellipticE(0.5, phi: double.infinity)).equals(double.infinity);
    });
  });

  group('ellipticEComplex', () {
    test('matches real values, complex derivative, and boundaries', () {
      check(ellipticEComplex(const Complex(0.5)).a)
          .isCloseTo(ellipticE(0.5), 1e-14);
      check(ellipticEComplex(const Complex(0.5), phi: const Complex(0.7)).a)
          .isCloseTo(ellipticE(0.5, phi: 0.7), 1e-14);
      check(ellipticEComplex(Complex.one)).equals(Complex.one);

      const phi = Complex(0.6, 0.3);
      const k = Complex(0.4, 0.25);
      const h = Complex(1e-7);
      final sinPhi = phi.sin();
      final deltaSqrt = (Complex.one - k * k * sinPhi * sinPhi).sqrt();
      final dE =
          (ellipticEComplex(k, phi: phi + h) -
              ellipticEComplex(k, phi: phi - h)) /
          (const Complex(2.0) * h);
      check((dE - deltaSqrt).abs()).isLessThan(1e-8);
      check(ellipticEComplex(Complex.nan).isNaN).isTrue;
    });
  });

  group('ellipticF', () {
    test('satisfies quasi-periodicity and domain boundaries', () {
      check(ellipticF(0, 0.5)).equals(0.0);
      check(ellipticF(1.2, 0)).isCloseTo(1.2, 1e-14);
      check(ellipticF(math.pi / 2.0, 0.5)).isCloseTo(ellipticK(0.5), 1e-14);
      check(ellipticF(math.pi / 2.0, 0.8)).isCloseTo(ellipticK(0.8), 1e-14);
      check(ellipticF(-0.7, 0.5)).isCloseTo(-ellipticF(0.7, 0.5), 1e-14);

      final fBase = ellipticF(0.6, 0.4);
      final fShifted = ellipticF(0.6 + math.pi, 0.4);
      check(fShifted).isCloseTo(fBase + 2.0 * ellipticK(0.4), 1e-14);

      check(ellipticF(0.5, 1.2)).isNaN;
      check(ellipticF(double.nan, 0.5)).isNaN;
      check(ellipticF(double.infinity, 0.5)).equals(double.infinity);
      check(ellipticF(double.negativeInfinity, 0.5))
          .equals(double.negativeInfinity);
      check(ellipticF(math.pi / 2.0, 1.0)).equals(double.infinity);
      check(ellipticF(-math.pi / 2.0, 1.0)).equals(double.negativeInfinity);
    });
  });

  group('ellipticFComplex', () {
    test('matches real values and complex derivative', () {
      check(ellipticFComplex(const Complex(0.7), const Complex(0.5)).a)
          .isCloseTo(ellipticF(0.7, 0.5), 1e-14);

      const phi = Complex(0.6, 0.3);
      const k = Complex(0.4, 0.25);
      const h = Complex(1e-7);
      final sinPhi = phi.sin();
      final deltaSqrt = (Complex.one - k * k * sinPhi * sinPhi).sqrt();
      final dF =
          (ellipticFComplex(phi + h, k) - ellipticFComplex(phi - h, k)) /
          (const Complex(2.0) * h);
      check((dF - Complex.one / deltaSqrt).abs()).isLessThan(1e-8);
      check(ellipticFComplex(Complex.nan, k).isNaN).isTrue;
    });
  });

  group('ellipticPi', () {
    test('handles complete, incomplete, and singular boundaries', () {
      check(ellipticPi(0, 0.5)).isCloseTo(ellipticK(0.5), 1e-14);
      check(ellipticPi(0, 0.5, phi: 0.7)).isCloseTo(ellipticF(0.7, 0.5), 1e-14);
      check(ellipticPi(0.5, 0.5, phi: math.pi / 2.0))
          .isCloseTo(ellipticPi(0.5, 0.5), 1e-14);
      check(ellipticPi(1.0, 0.5)).equals(double.infinity);
      check(ellipticPi(1.2, 0.5)).isNaN;
      check(ellipticPi(0.5, 1.0)).equals(double.infinity);
      check(ellipticPi(0.5, 1.0, phi: math.pi / 2.0)).equals(double.infinity);
      check(ellipticPi(1.0, 0.5, phi: double.infinity)).isNaN;
      check(ellipticPi(double.nan, 0.5)).isNaN;
    });
  });

  group('ellipticPiComplex', () {
    test('matches real values, complex derivative, and singularities', () {
      check(ellipticPiComplex(const Complex(0.3), const Complex(0.5)).a)
          .isCloseTo(ellipticPi(0.3, 0.5), 1e-14);
      check(ellipticPiComplex(Complex.one, const Complex(0.5)).a)
          .equals(double.infinity);
      check(
        ellipticPiComplex(
          const Complex(double.infinity),
          const Complex(0.5),
        ).isNaN,
      ).isTrue;

      const phi = Complex(0.6, 0.3);
      const k = Complex(0.4, 0.25);
      const n = Complex(0.3, -0.2);
      const h = Complex(1e-7);
      final sinPhi = phi.sin();
      final sin2 = sinPhi * sinPhi;
      final deltaSqrt = (Complex.one - k * k * sin2).sqrt();
      final dPi =
          (ellipticPiComplex(n, k, phi: phi + h) -
              ellipticPiComplex(n, k, phi: phi - h)) /
          (const Complex(2.0) * h);
      final expectedDPi = Complex.one / ((Complex.one - n * sin2) * deltaSqrt);
      check((dPi - expectedDPi).abs()).isLessThan(1e-8);
    });
  });
}
