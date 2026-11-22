import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/special.dart';
import 'package:more/number.dart' show Complex;
import 'package:test/test.dart';

void main() {
  group('Hypergeometric functions', () {
    test('confluent hypergeometric 1F1 standard cases', () {
      check(hypergeometric1F1(2, 2, 0.5)).isCloseTo(math.exp(0.5), 1e-12);
      check(hypergeometric1F1(5, 5, 1.2)).isCloseTo(math.exp(1.2), 1e-12);
      check(hypergeometric1F1(0, 3.5, 2.5)).equals(1.0);
      check(hypergeometric1F1(1, 0, 0.5)).isNaN;
      check(hypergeometric1F1(1, -2, 0.5)).isNaN;
      check(hypergeometric1F1(1, 2, double.infinity)).isNaN;
      check(hypergeometric1F1(1, 2, double.negativeInfinity)).isNaN;
      // 1F1(1, 2, z) = (exp(z) - 1)/z. For z = -50, (exp(-50) - 1)/(-50) = 1/50 = 0.02
      check(hypergeometric1F1(1, 2, -50.0)).isCloseTo(0.02, 1e-12);
      check(hypergeometric1F1(1, 2, -750.0)).isCloseTo(1.0 / 750.0, 1e-6);
      check(hypergeometric1F1(1, 2, -1000.0)).isCloseTo(0.001, 1e-6);
      check(hypergeometric1F1(2, 4, -800.0).isFinite).isTrue;
    });

    test('Gauss hypergeometric 2F1 standard cases', () {
      check(hypergeometric2F1(1, 2, 2, 0.5)).isCloseTo(2.0, 1e-12);
      check(hypergeometric2F1(2, 3, 3, 0.5)).isCloseTo(4.0, 1e-12);
      check(hypergeometric2F1(3, 1.5, 1.5, 0.2))
          .isCloseTo(1.0 / (0.8 * 0.8 * 0.8), 1e-12);
      check(hypergeometric2F1(0, 2.5, 4.5, 0.7)).equals(1.0);
    });

    test('Gauss hypergeometric 2F1 transformations and boundaries', () {
      check(hypergeometric2F1(1, 2, 3, -2.0))
          .isCloseTo(0.45069385566594444, 1e-12);
      // z in (-1.0, -0.5]: 2F1(1, 2; 3; z) = 2(-ln(1-z) - z)/z^2 for z = -0.75
      const zPfaff = -0.75;
      final expectedPfaff =
          2.0 * (-math.log(1.0 - zPfaff) - zPfaff) / (zPfaff * zPfaff);
      check(hypergeometric2F1(1, 2, 3, zPfaff)).isCloseTo(expectedPfaff, 1e-12);
      check(hypergeometric2F1(0.5, 0.5, 1.5, 0.95))
          .isCloseTo(1.3802311542699408, 1e-12);
      // Pole annihilation at z in [0.9, 1.0] when c - b or c - a is a non-positive integer
      check(hypergeometric2F1(0.5, 1.5, 1.5, 0.95))
          .isCloseTo(math.pow(1.0 - 0.95, -0.5), 1e-12);
      check(hypergeometric2F1(1.5, 0.5, 1.5, 0.95))
          .isCloseTo(math.pow(1.0 - 0.95, -0.5), 1e-12);
      check(hypergeometric2F1(1.0, 1.0, 3.0, 1.0)).isCloseTo(2.0, 1e-12);
      // Large negative z with integer b - a: 2F1(1, 2; 3; z) = 2(-ln(1-z) - z)/z^2
      const zNeg = -20.0;
      final expected = 2.0 * (-math.log(1.0 - zNeg) - zNeg) / (zNeg * zNeg);
      check(hypergeometric2F1(1, 2, 3, zNeg)).isCloseTo(expected, 1e-12);
      check(hypergeometric2F1(1, 2, 3, double.negativeInfinity)).equals(0.0);
    });

    test('terminating polynomial cases for 1F1 and 2F1', () {
      // 1F1(-2; 3; z) = 1 - 2/3 z + 2/24 z^2 = 1 - 2/3 z + 1/12 z^2
      check(hypergeometric1F1(-2, 3, 6.0)).isCloseTo(0.0, 1e-12);
      // 1F1(-1; -3; z) = 1 + 1/3 z (terminates before denominator hits 0)
      check(hypergeometric1F1(-1, -3, 3.0)).isCloseTo(2.0, 1e-12);
      // 2F1(-2, 1; 2; z) = 1 - z + 1/3 z^2 (valid even for z > 1 and z < -1)
      check(hypergeometric2F1(-2, 1, 2, 3.0)).isCloseTo(1.0, 1e-12);
      check(hypergeometric2F1(1, -2, 2, -3.0)).isCloseTo(7.0, 1e-12);
      check(hypergeometric2F1(-2, 1.5, 3, 0.95))
          .isCloseTo(1.0 - 0.95 + 0.95 * 0.95 * 5.0 / 16.0, 1e-12);
      check(hypergeometric2F1(-2, -3, 1, 0.5)).isCloseTo(4.75, 1e-12);
      check(hypergeometric2F1(-3, 2, -1, 0.5)).isNaN;
      check(hypergeometric2F1(2, 2, 3, 0.95))
          .isCloseTo(35.466521277442666, 1e-10);
      check(hypergeometric2F1(1, 1, 4, 0.95)).isGreaterThan(0.0);
    });

    test('hypergeometric1F1Complex and hypergeometric2F1Complex', () {
      check(
        hypergeometric1F1Complex(
          const Complex(2.0),
          const Complex(2.0),
          const Complex(0.5),
        ).a,
      ).isCloseTo(math.exp(0.5), 1e-12);

      // 1F1(1; 1; z) = exp(z)
      const z1 = Complex(0.8, -0.6);
      check(
        (hypergeometric1F1Complex(Complex.one, Complex.one, z1) - z1.exp())
            .abs(),
      ).isLessThan(1e-12);

      // 2F1(1, 1; 2; z) = -ln(1 - z) / z
      const z2 = Complex(0.3, 0.4);
      final expected2 = -(Complex.one - z2).log() / z2;
      check(
        (hypergeometric2F1Complex(
                  Complex.one,
                  Complex.one,
                  const Complex(2),
                  z2,
                ) -
                expected2)
            .abs(),
      ).isLessThan(1e-12);

      // Pfaff transformation region |z| >= 0.8
      const zLarge = Complex(-2.0, 0.5);
      final expectedLarge = -(Complex.one - zLarge).log() / zLarge;
      check(
        (hypergeometric2F1Complex(
                  Complex.one,
                  Complex.one,
                  const Complex(2),
                  zLarge,
                ) -
                expectedLarge)
            .abs(),
      ).isLessThan(1e-12);

      // Terminating polynomial when both a and b (or c) are non-positive integers
      // 1F1(-2; -3; z) = 1 + (-2)/(-3)*z + (-2)(-1)/((-3)(-2))*z^2/2 = 1 + 2/3 z + 1/6 z^2
      const zPoly = Complex(1.0, 1.0);
      final expected1F1Poly =
          Complex.one +
          const Complex(2.0 / 3.0) * zPoly +
          const Complex(1.0 / 6.0) * zPoly * zPoly;
      check(
        (hypergeometric1F1Complex(const Complex(-2), const Complex(-3), zPoly) -
                expected1F1Poly)
            .abs(),
      ).isLessThan(1e-12);

      // 2F1(-1, 2; -2; z) = 1 + (-1)(2)/(-2)*z = 1 + z
      check(
        (hypergeometric2F1Complex(
                  const Complex(-1),
                  const Complex(2),
                  const Complex(-2),
                  zPoly,
                ) -
                (Complex.one + zPoly))
            .abs(),
      ).isLessThan(1e-12);

      // 1/z linear transformation for |z| > 1.25 with Re(z) > 1
      // 2F1(1/2, 1; 3/2; z) = atanh(sqrt(z)) / sqrt(z) = 0.5 * ln((1+sqrt(z))/(1-sqrt(z))) / sqrt(z)
      const zOut = Complex(2.0, 0.5);
      final sqrtZ = zOut.sqrt();
      final expectedOut =
          const Complex(0.5) *
          ((Complex.one + sqrtZ) / (Complex.one - sqrtZ)).log() /
          sqrtZ;
      final actualOut = hypergeometric2F1Complex(
        const Complex(0.5),
        Complex.one,
        const Complex(1.5),
        zOut,
      );
      check((actualOut - expectedOut).abs()).isLessThan(1e-11);
    });
  });
}
