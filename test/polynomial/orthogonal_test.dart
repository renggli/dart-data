import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/polynomial.dart';
import 'package:test/test.dart';

void main() {
  group('Orthogonal Polynomials and Clenshaw Recurrence', () {
    test('Chebyshev T_n known polynomials and evaluation', () {
      // T_0 = 1
      check(Polynomial.chebyshevT(0).coefficients).deepEquals([1.0]);
      // T_1 = x
      check(Polynomial.chebyshevT(1).coefficients).deepEquals([0.0, 1.0]);
      // T_2 = 2x^2 - 1
      check(Polynomial.chebyshevT(2).coefficients).deepEquals([-1.0, 0.0, 2.0]);
      // T_3 = 4x^3 - 3x
      check(Polynomial.chebyshevT(3).coefficients)
          .deepEquals([0.0, -3.0, 0.0, 4.0]);
      // T_4 = 8x^4 - 8x^2 + 1
      check(Polynomial.chebyshevT(4).coefficients)
          .deepEquals([1.0, 0.0, -8.0, 0.0, 8.0]);

      // Trigonometric identity: T_n(cos(theta)) = cos(n * theta)
      for (var deg = 0; deg <= 4; deg++) {
        final poly = Polynomial.chebyshevT(deg);
        const theta = 0.7;
        final x = math.cos(theta);
        check(poly.evaluateDouble(x)).isCloseTo(math.cos(deg * theta), 1e-6);
      }
    });

    test('Chebyshev U_n known polynomials', () {
      // U_0 = 1
      check(Polynomial.chebyshevU(0).coefficients).deepEquals([1.0]);
      // U_1 = 2x
      check(Polynomial.chebyshevU(1).coefficients).deepEquals([0.0, 2.0]);
      // U_2 = 4x^2 - 1
      check(Polynomial.chebyshevU(2).coefficients).deepEquals([-1.0, 0.0, 4.0]);
      // U_3 = 8x^3 - 4x
      check(Polynomial.chebyshevU(3).coefficients)
          .deepEquals([0.0, -4.0, 0.0, 8.0]);
    });

    test('Legendre P_n known polynomials', () {
      // P_0 = 1
      check(Polynomial.legendreP(0).coefficients).deepEquals([1.0]);
      // P_1 = x
      check(Polynomial.legendreP(1).coefficients).deepEquals([0.0, 1.0]);
      // P_2 = 1.5 x^2 - 0.5
      final p2 = Polynomial.legendreP(2);
      check(p2[0]).isCloseTo(-0.5, 1e-9);
      check(p2[1]).isCloseTo(0.0, 1e-9);
      check(p2[2]).isCloseTo(1.5, 1e-9);
      // P_3 = 2.5 x^3 - 1.5 x
      final p3 = Polynomial.legendreP(3);
      check(p3[0]).isCloseTo(0.0, 1e-9);
      check(p3[1]).isCloseTo(-1.5, 1e-9);
      check(p3[2]).isCloseTo(0.0, 1e-9);
      check(p3[3]).isCloseTo(2.5, 1e-9);
    });

    test('Hermite H_n and He_n known polynomials', () {
      // H_0 = 1, H_1 = 2x, H_2 = 4x^2 - 2, H_3 = 8x^3 - 12x
      check(Polynomial.hermiteH(0).coefficients).deepEquals([1.0]);
      check(Polynomial.hermiteH(1).coefficients).deepEquals([0.0, 2.0]);
      check(Polynomial.hermiteH(2).coefficients).deepEquals([-2.0, 0.0, 4.0]);
      check(Polynomial.hermiteH(3).coefficients)
          .deepEquals([0.0, -12.0, 0.0, 8.0]);

      // He_0 = 1, He_1 = x, He_2 = x^2 - 1, He_3 = x^3 - 3x
      check(Polynomial.hermiteHe(0).coefficients).deepEquals([1.0]);
      check(Polynomial.hermiteHe(1).coefficients).deepEquals([0.0, 1.0]);
      check(Polynomial.hermiteHe(2).coefficients).deepEquals([-1.0, 0.0, 1.0]);
      check(Polynomial.hermiteHe(3).coefficients)
          .deepEquals([0.0, -3.0, 0.0, 1.0]);
    });

    test('Clenshaw evaluation matches explicit linear combination', () {
      final coeffs = [2.5, -1.2, 0.8, 0.3];
      const x = 0.65;

      // Chebyshev T
      final tDirect =
          coeffs[0] * Polynomial.chebyshevT(0).evaluateDouble(x) +
          coeffs[1] * Polynomial.chebyshevT(1).evaluateDouble(x) +
          coeffs[2] * Polynomial.chebyshevT(2).evaluateDouble(x) +
          coeffs[3] * Polynomial.chebyshevT(3).evaluateDouble(x);
      final tClenshaw = clenshawEvaluate(
        coeffs,
        x,
        family: OrthogonalFamily.chebyshevT,
      );
      check(tClenshaw).isCloseTo(tDirect, 1e-9);

      // Chebyshev U
      final uDirect =
          coeffs[0] * Polynomial.chebyshevU(0).evaluateDouble(x) +
          coeffs[1] * Polynomial.chebyshevU(1).evaluateDouble(x) +
          coeffs[2] * Polynomial.chebyshevU(2).evaluateDouble(x) +
          coeffs[3] * Polynomial.chebyshevU(3).evaluateDouble(x);
      final uClenshaw = clenshawEvaluate(
        coeffs,
        x,
        family: OrthogonalFamily.chebyshevU,
      );
      check(uClenshaw).isCloseTo(uDirect, 1e-9);

      // Legendre P
      final pDirect =
          coeffs[0] * Polynomial.legendreP(0).evaluateDouble(x) +
          coeffs[1] * Polynomial.legendreP(1).evaluateDouble(x) +
          coeffs[2] * Polynomial.legendreP(2).evaluateDouble(x) +
          coeffs[3] * Polynomial.legendreP(3).evaluateDouble(x);
      final pClenshaw = clenshawEvaluate(
        coeffs,
        x,
        family: OrthogonalFamily.legendreP,
      );
      check(pClenshaw).isCloseTo(pDirect, 1e-9);

      // Hermite H
      final hDirect =
          coeffs[0] * Polynomial.hermiteH(0).evaluateDouble(x) +
          coeffs[1] * Polynomial.hermiteH(1).evaluateDouble(x) +
          coeffs[2] * Polynomial.hermiteH(2).evaluateDouble(x) +
          coeffs[3] * Polynomial.hermiteH(3).evaluateDouble(x);
      final hClenshaw = clenshawEvaluate(
        coeffs,
        x,
        family: OrthogonalFamily.hermiteH,
      );
      check(hClenshaw).isCloseTo(hDirect, 1e-9);

      // Hermite He
      final heDirect =
          coeffs[0] * Polynomial.hermiteHe(0).evaluateDouble(x) +
          coeffs[1] * Polynomial.hermiteHe(1).evaluateDouble(x) +
          coeffs[2] * Polynomial.hermiteHe(2).evaluateDouble(x) +
          coeffs[3] * Polynomial.hermiteHe(3).evaluateDouble(x);
      final heClenshaw = clenshawEvaluate(
        coeffs,
        x,
        family: OrthogonalFamily.hermiteHe,
      );
      check(heClenshaw).isCloseTo(heDirect, 1e-9);
    });
  });
}
