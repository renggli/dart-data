import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/special.dart';
import 'package:more/number.dart' show Complex;
import 'package:test/scaffolding.dart';

void main() {
  group('hypergeometric1F1', () {
    test(
      'evaluates direct series, Kummer transform, and terminating cases',
      () {
        check(hypergeometric1F1(2, 2, 0.5)).isCloseTo(math.exp(0.5), 1e-14);
        check(hypergeometric1F1(5, 5, 1.2)).isCloseTo(math.exp(1.2), 1e-14);
        check(hypergeometric1F1(0, 3.5, 2.5)).equals(1.0);
        check(hypergeometric1F1(-2, 3, 6.0)).isCloseTo(0.0, 1e-14);
        check(hypergeometric1F1(-1, -3, 3.0)).isCloseTo(2.0, 1e-14);

        // b - a non-positive integer with negative z uses Kummer termination
        check(hypergeometric1F1(3, 1, -2.0)).isCloseTo(-math.exp(-2.0), 1e-13);
        check(hypergeometric1F1(3, 1, -720.0)).equals(0.0);
      },
    );

    test('evaluates negative-z asymptotics accurately', () {
      check(hypergeometric1F1(1, 2, -50.0)).isCloseTo(0.02, 1e-14);
      check(hypergeometric1F1(1, 2, -750.0)).isCloseTo(1.0 / 750.0, 1e-9);
      check(hypergeometric1F1(1, 2, -1000.0)).isCloseTo(0.001, 1e-9);
      check(hypergeometric1F1(2, 4, -800.0))
          .isCloseTo(6.0 / (800.0 * 800.0), 2e-2 * 6.0 / (800.0 * 800.0));
      final contiguousResidual =
          198.0 * hypergeometric1F1(1, 200, -500.0) +
          (4.0 - 200.0 - 500.0) * hypergeometric1F1(2, 200, -500.0) -
          2.0 * hypergeometric1F1(3, 200, -500.0);
      check(contiguousResidual).isCloseTo(0.0, 1e-11);
    });

    test('handles poles and non-finite inputs', () {
      check(hypergeometric1F1(1, 0, 0.5)).isNaN;
      check(hypergeometric1F1(1, -2, 0.5)).isNaN;
      check(hypergeometric1F1(1, 2, double.infinity)).isNaN;
      check(hypergeometric1F1(1, 2, double.negativeInfinity)).isNaN;
      check(hypergeometric1F1(double.nan, 2, 0.5)).isNaN;
    });
  });

  group('hypergeometric1F1Complex', () {
    test('evaluates positive, negative-Re, and terminating cases', () {
      check(
        hypergeometric1F1Complex(
          const Complex(2.0),
          const Complex(2.0),
          const Complex(0.5),
        ).a,
      ).isCloseTo(math.exp(0.5), 1e-14);

      const z1 = Complex(0.8, -0.6);
      check(
        (hypergeometric1F1Complex(Complex.one, Complex.one, z1) - z1.exp())
            .abs(),
      ).isLessThan(1e-14);

      const zNeg = Complex(-2.0, 1.0);
      final expectedNeg = (zNeg.exp() - Complex.one) / zNeg;
      check(
        (hypergeometric1F1Complex(Complex.one, const Complex(2.0), zNeg) -
                expectedNeg)
            .abs(),
      ).isLessThan(1e-13);

      const zPoly = Complex(1.0, 1.0);
      final expectedPoly =
          Complex.one +
          const Complex(2.0 / 3.0) * zPoly +
          const Complex(1.0 / 6.0) * zPoly * zPoly;
      check(
        (hypergeometric1F1Complex(const Complex(-2), const Complex(-3), zPoly) -
                expectedPoly)
            .abs(),
      ).isLessThan(1e-13);
      check(
        hypergeometric1F1Complex(Complex.one, Complex.zero, Complex.one).isNaN,
      ).isTrue;
    });
  });

  group('hypergeometric2F1', () {
    test('evaluates direct series, Pfaff transform, and z = 1 boundaries', () {
      check(hypergeometric2F1(1, 2, 2, 0.5)).isCloseTo(2.0, 1e-14);
      check(hypergeometric2F1(2, 3, 3, 0.5)).isCloseTo(4.0, 1e-14);
      check(hypergeometric2F1(3, 1.5, 1.5, 0.2))
          .isCloseTo(1.0 / (0.8 * 0.8 * 0.8), 1e-14);
      check(hypergeometric2F1(0, 2.5, 4.5, 0.7)).equals(1.0);
      check(hypergeometric2F1(1, 2, 3, -2.0))
          .isCloseTo(0.45069385566594444, 1e-13);

      const zPfaff = -0.75;
      final expectedPfaff =
          2.0 * (-math.log(1.0 - zPfaff) - zPfaff) / (zPfaff * zPfaff);
      check(hypergeometric2F1(1, 2, 3, zPfaff)).isCloseTo(expectedPfaff, 1e-14);
      check(hypergeometric2F1(0.5, 0.5, 1.5, 0.95))
          .isCloseTo(1.3802311542699408, 1e-13);
      check(hypergeometric2F1(0.5, 1.5, 1.5, 0.95))
          .isCloseTo(math.pow(1.0 - 0.95, -0.5), 1e-13);
      check(hypergeometric2F1(1.5, 0.5, 1.5, 0.95))
          .isCloseTo(math.pow(1.0 - 0.95, -0.5), 1e-13);
      check(hypergeometric2F1(1.0, 1.0, 3.0, 1.0)).isCloseTo(2.0, 1e-14);
      check(hypergeometric2F1(1.0, 1.0, 200.0, 1.0))
          .isCloseTo(199.0 / 198.0, 1e-12);
      check(hypergeometric2F1(600.0, 600.0, 1200.5, 1.0))
          .equals(double.infinity);
      check(hypergeometric2F1(-0.5, 1.5, 1.0, 1.0))
          .equals(double.negativeInfinity);
    });

    test(
      'evaluates terminating polynomials, logarithmic 2F1, and -infinity',
      () {
        check(hypergeometric2F1(-2, 1, 2, 3.0)).isCloseTo(1.0, 1e-14);
        check(hypergeometric2F1(1, -2, 2, -3.0)).isCloseTo(7.0, 1e-14);
        check(hypergeometric2F1(-2, -3, 2, 0.5)).isCloseTo(2.75, 1e-14);
        check(hypergeometric2F1(-2, 1.5, 3, 0.95))
            .isCloseTo(1.0 - 0.95 + 0.95 * 0.95 * 5.0 / 16.0, 1e-14);
        check(hypergeometric2F1(-3, 2, -1, 0.5)).isNaN;

        check(hypergeometric2F1(2, 2, 3, 0.95))
            .isCloseTo(35.466521277442666, 1e-12);

        const zLog = 0.95;
        final expected114 =
            (-3.0 * (1.0 - zLog) * (1.0 - zLog) * math.log(1.0 - zLog) -
                3.0 * zLog +
                4.5 * zLog * zLog) /
            (zLog * zLog * zLog);
        check(hypergeometric2F1(1, 1, 4, zLog)).isCloseTo(expected114, 1e-12);

        check(hypergeometric2F1(1, 2, 3, double.negativeInfinity)).equals(0.0);
        check(hypergeometric2F1(2, 1, 3, double.negativeInfinity)).equals(0.0);
        check(hypergeometric2F1(-0.5, -0.5, -0.5, double.negativeInfinity))
            .equals(0.0);
        check(hypergeometric2F1(-0.5, -0.5, 1.0, double.negativeInfinity))
            .equals(double.negativeInfinity);
        check(hypergeometric2F1(-0.5, 0.5, 2.0, double.negativeInfinity))
            .equals(double.infinity);
      },
    );
  });

  group('hypergeometric2F1Complex', () {
    test('evaluates terminating polynomials and poles', () {
      const z = Complex(0.5, 0.3);
      check(
        (hypergeometric2F1Complex(
                  const Complex(-2),
                  const Complex(-3),
                  const Complex(2),
                  z,
                ) -
                (Complex.one + const Complex(3.0) * z + z * z))
            .abs(),
      ).isLessThan(1e-14);
      check(
        (hypergeometric2F1Complex(
                  const Complex(-1),
                  const Complex(1.5),
                  const Complex(3),
                  z,
                ) -
                (Complex.one - const Complex(0.5) * z))
            .abs(),
      ).isLessThan(1e-14);
      check(
        (hypergeometric2F1Complex(
                  const Complex(1.5),
                  const Complex(-1),
                  const Complex(3),
                  z,
                ) -
                (Complex.one - const Complex(0.5) * z))
            .abs(),
      ).isLessThan(1e-14);
      check(
        hypergeometric2F1Complex(
          const Complex(-3),
          const Complex(2),
          const Complex(-1),
          z,
        ).isNaN,
      ).isTrue;
    });

    test('covers Pfaff, 1 - z, logarithmic, and 1/z continuation sectors', () {
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
      ).isLessThan(1e-14);

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
      ).isLessThan(1e-13);

      // Integer c - a - b near z = 1: m = 0, m < 0, and m >= 2
      const zNearOne = Complex(0.99, 0.01);
      final expectedM0 = -(Complex.one - zNearOne).log() / zNearOne;
      check(
        (hypergeometric2F1Complex(
                  Complex.one,
                  Complex.one,
                  const Complex(2),
                  zNearOne,
                ) -
                expectedM0)
            .abs(),
      ).isLessThan(1e-12);

      final expectedMNeg =
          const Complex(2.0) *
          ((Complex.one - zNearOne).reciprocal() +
              ((Complex.one - zNearOne).log() + zNearOne) /
                  (zNearOne * zNearOne));
      check(
        (hypergeometric2F1Complex(
                  const Complex(2),
                  const Complex(2),
                  const Complex(3),
                  zNearOne,
                ) -
                expectedMNeg)
            .abs(),
      ).isLessThan(1e-11);

      final expectedM2 =
          (const Complex(-3.0) *
                  (Complex.one - zNearOne) *
                  (Complex.one - zNearOne) *
                  (Complex.one - zNearOne).log() -
              const Complex(3.0) * zNearOne +
              const Complex(4.5) * zNearOne * zNearOne) /
          (zNearOne * zNearOne * zNearOne);
      check(
        (hypergeometric2F1Complex(
                  Complex.one,
                  Complex.one,
                  const Complex(4),
                  zNearOne,
                ) -
                expectedM2)
            .abs(),
      ).isLessThan(1e-12);

      // Non-integer c - a - b near z = 1: 2F1(0.5, 0.5, 1.5, z) = asin(sqrt(z))/sqrt(z)
      final sNear = zNearOne.sqrt();
      final expectedAsin = sNear.asin() / sNear;
      check(
        (hypergeometric2F1Complex(
                  const Complex(0.5),
                  const Complex(0.5),
                  const Complex(1.5),
                  zNearOne,
                ) -
                expectedAsin)
            .abs(),
      ).isLessThan(1e-12);

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

  group('hypergeometricPFQ', () {
    test('handles 0F0, 1F0, 0F1, 1F1, 2F1, 3F2, and pole precedence', () {
      check(hypergeometricPFQ([], [], 1.5)).isCloseTo(math.exp(1.5), 1e-14);
      check(hypergeometricPFQ([2.5], [], 0.3))
          .isCloseTo(math.pow(0.7, -2.5), 1e-14);
      check(hypergeometricPFQ([], [1.0], -1.6 * 1.6 / 4.0))
          .isCloseTo(besselJ(0, 1.6), 1e-12);
      check(hypergeometricPFQ([2.0], [2.0], 0.5))
          .isCloseTo(math.exp(0.5), 1e-14);
      check(hypergeometricPFQ([1.0, 2.0], [2.0], 0.5)).isCloseTo(2.0, 1e-14);
      check(hypergeometricPFQ([1.0, 1.0, 1.0], [2.0, 2.0], 0.4))
          .isCloseTo(polylog(2, 0.4) / 0.4, 1e-14);
      check(hypergeometricPFQ([0.0, 2.0], [0.0, 3.0], 0.5)).equals(1.0);
      check(hypergeometricPFQ([1.0, 2.0], [0.0, 3.0], 0.0)).isNaN;
    });
  });

  group('hypergeometricPFQComplex', () {
    test('handles 0F0, 1F0, 1F1, 2F1, 3F2, terminating, and poles', () {
      const z0 = Complex(0.7, -0.5);
      check((hypergeometricPFQComplex([], [], z0) - z0.exp()).abs())
          .isLessThan(1e-14);
      check(
        (hypergeometricPFQComplex([Complex.one], [Complex.one], z0) - z0.exp())
            .abs(),
      ).isLessThan(1e-14);
      check(
        (hypergeometricPFQComplex(
                  [Complex.one, const Complex(2)],
                  [const Complex(2)],
                  z0,
                ) -
                (Complex.one - z0).reciprocal())
            .abs(),
      ).isLessThan(1e-14);

      const z32 = Complex(0.3, 0.2);
      check(
        (hypergeometricPFQComplex(
                  [Complex.one, Complex.one, Complex.one],
                  [const Complex(2), const Complex(2)],
                  z32,
                ) -
                polylogComplex(const Complex(2), z32) / z32)
            .abs(),
      ).isLessThan(1e-13);

      const zPoly = Complex(0.5, 0.5);
      final expected3F2Poly =
          Complex.one -
          const Complex(0.5) * zPoly +
          const Complex(1.0 / 9.0) * zPoly * zPoly;
      check(
        (hypergeometricPFQComplex(
                  [const Complex(-2), Complex.one, Complex.one],
                  [const Complex(2), const Complex(2)],
                  zPoly,
                ) -
                expected3F2Poly)
            .abs(),
      ).isLessThan(1e-14);

      check(
        hypergeometricPFQComplex(
          [Complex.one, const Complex(2), const Complex(3)],
          [const Complex(2), const Complex(4)],
          Complex.zero,
        ),
      ).equals(Complex.one);
      check(
        hypergeometricPFQComplex(
          [Complex.one, const Complex(2)],
          [Complex.zero, const Complex(3)],
          Complex.zero,
        ).isNaN,
      ).isTrue;
    });

    test(
      'handles near-integer c - a - b, |z| > 1.25 integer a - b, and corner z',
      () {
        // Near-integer c - a - b = 0 within floating-point rounding near z = 1
        const zNear1 = Complex(0.75, 0.1);
        final epsA = const Complex(1.0 / 3.0 + 4.0 / 3.0) + const Complex(1.0);
        const epsB = Complex(1.0 / 3.0);
        final epsC = const Complex(3.0) - const Complex(1e-15);
        final expectedLog = (-Complex.one + zNear1).abs() > 0
            ? hypergeometric2F1Complex(
                const Complex(8.0 / 3.0),
                const Complex(1.0 / 3.0),
                const Complex(3.0),
                zNear1,
              )
            : Complex.nan;
        check(
          (hypergeometric2F1Complex(epsA, epsB, epsC, zNear1) - expectedLog)
              .abs(),
        ).isLessThan(1e-12);
        check(
          (hypergeometric2F1(8.0 / 3.0, 1.0 / 3.0, 3.0 - 1e-15, 0.95) -
                  hypergeometric2F1(8.0 / 3.0, 1.0 / 3.0, 3.0, 0.95))
              .abs(),
        ).isLessThan(1e-12);

        // |z| > 1.25 with integer a - b and integer c - b:
        // 2F1(1, 2; 3; z) = -2/z - 2*ln(1 - z)/z^2
        for (final z in const [
          Complex(-2.5, 0.4),
          Complex(0.6, 1.8),
          Complex(2.2, -0.9),
        ]) {
          final expected123 =
              const Complex(-2.0) / z -
              const Complex(2.0) * (Complex.one - z).log() / (z * z);
          check(
            (hypergeometric2F1Complex(
                      Complex.one,
                      const Complex(2.0),
                      const Complex(3.0),
                      z,
                    ) -
                    expected123)
                .abs(),
          ).isLessThan(1e-11);
        }

        // |z| > 1.25 with integer a - b = 0 and non-integer c - b:
        // 2F1(1/2, 1/2; 3/2; -z^2) = asinh(z) / z
        const zArg = Complex(1.2, 0.7);
        final zSqNeg = -(zArg * zArg);
        check(
          (hypergeometric2F1Complex(
                    const Complex(0.5),
                    const Complex(0.5),
                    const Complex(1.5),
                    zSqNeg,
                  ) -
                  zArg.asinh() / zArg)
              .abs(),
        ).isLessThan(1e-11);

        // Corner near exp(±i*pi/3): |z| >= 0.8, |1 - z| >= 0.8, |w| >= 0.8, |z| <= 1.25
        // 2F1(1, 1; 2; z) = -ln(1 - z) / z
        for (final zCorner in const [
          Complex(0.5, 0.8660254037844386),
          Complex(0.45, -0.9),
          Complex(0.95, 0.78),
          Complex(0.08, 1.2),
        ]) {
          final exactCorner = -(Complex.one - zCorner).log() / zCorner;
          check(
            (hypergeometric2F1Complex(
                      Complex.one,
                      Complex.one,
                      const Complex(2.0),
                      zCorner,
                    ) -
                    exactCorner)
                .abs(),
          ).isLessThan(1e-12);
        }
      },
    );
  });

  group('appellF1 and appellF1Complex', () {
    test('handles degeneracies, terminating polynomials, and poles', () {
      check(appellF1(0.5, 1.0, 2.0, 1.5, 0.0, 0.0)).equals(1.0);
      check(appellF1(0.0, 1.0, 2.0, 1.5, 0.4, -0.7)).equals(1.0);
      check(
        (appellF1(0.5, 0.0, 2.0, 1.5, 0.4, 0.3) -
                hypergeometric2F1(0.5, 2.0, 1.5, 0.3))
            .abs(),
      ).isLessThan(1e-13);
      check(
        (appellF1(0.5, 1.0, 2.0, 1.5, 0.4, 0.4) -
                hypergeometric2F1(0.5, 3.0, 1.5, 0.4))
            .abs(),
      ).isLessThan(1e-13);
      check(
        (appellF1(1.5, 2.0, -1.5, 1.5, 0.3, -0.6) -
                math.pow(0.7, -2.0).toDouble() * math.pow(1.6, 1.5).toDouble())
            .abs(),
      ).isLessThan(1e-13);
      check(appellF1(0.5, 1.0, 2.0, -1.0, 0.2, 0.3).isNaN).isTrue;
      check(appellF1(0.5, 1.0, 2.0, 1.5, 1.2, 0.3).isNaN).isTrue;

      // Terminating polynomial in a = -2
      check(
        (appellF1Complex(
                  const Complex(-2.0),
                  const Complex(3.0),
                  const Complex(4.0),
                  const Complex(5.0),
                  const Complex(0.2, 0.1),
                  const Complex(-0.3, 0.2),
                ) -
                appellF1Complex(
                  const Complex(-2.0),
                  const Complex(4.0),
                  const Complex(3.0),
                  const Complex(5.0),
                  const Complex(-0.3, 0.2),
                  const Complex(0.2, 0.1),
                ))
            .abs(),
      ).isLessThan(1e-14);
    });

    test('evaluates inside unit bidisc and analytically continues outside', () {
      // Closed form: F1(1; 1, 1; 2; x, y) = (ln(1 - y) - ln(1 - x)) / (x - y)
      for (final (x, y) in const [
        (Complex(0.2, 0.15), Complex(-0.35, 0.25)),
        (Complex(-2.4, 0.3), Complex(-1.7, -0.4)),
        (Complex(1.5, 0.8), Complex(-0.9, 1.4)),
        (Complex(0.4, 1.3), Complex(-1.2, 0.7)),
      ]) {
        final expected =
            ((Complex.one - y).log() - (Complex.one - x).log()) / (x - y);
        check(
          (appellF1Complex(
                    Complex.one,
                    Complex.one,
                    Complex.one,
                    const Complex(2.0),
                    x,
                    y,
                  ) -
                  expected)
              .abs(),
        ).isLessThan(1e-11);
      }

      // Real negative-argument continuation matching closed form
      const rx = -2.5;
      const ry = -1.2;
      final expectedReal =
          (math.log(1.0 - ry) - math.log(1.0 - rx)) / (rx - ry);
      check((appellF1(1.0, 1.0, 1.0, 2.0, rx, ry) - expectedReal).abs())
          .isLessThan(1e-11);
    });
  });
}
