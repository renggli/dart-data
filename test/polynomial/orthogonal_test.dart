import 'dart:math' as math;

import 'package:data/polynomial.dart';
import 'package:test/test.dart';

void main() {
  group('Orthogonal Polynomials and Clenshaw Recurrence', () {
    test('Chebyshev T_n known polynomials and evaluation', () {
      // T_0 = 1
      expect(Polynomial.chebyshevT(0).coefficients, [1.0]);
      // T_1 = x
      expect(Polynomial.chebyshevT(1).coefficients, [0.0, 1.0]);
      // T_2 = 2x^2 - 1
      expect(Polynomial.chebyshevT(2).coefficients, [-1.0, 0.0, 2.0]);
      // T_3 = 4x^3 - 3x
      expect(Polynomial.chebyshevT(3).coefficients, [0.0, -3.0, 0.0, 4.0]);
      // T_4 = 8x^4 - 8x^2 + 1
      expect(Polynomial.chebyshevT(4).coefficients, [1.0, 0.0, -8.0, 0.0, 8.0]);

      // Trigonometric identity: T_n(cos(theta)) = cos(n * theta)
      for (var n = 0; n <= 4; n++) {
        final poly = Polynomial.chebyshevT(n);
        const theta = 0.7;
        final x = math.cos(theta);
        expect(poly.evaluateDouble(x), closeTo(math.cos(n * theta), 1e-6));
      }
    });

    test('Chebyshev U_n known polynomials', () {
      // U_0 = 1
      expect(Polynomial.chebyshevU(0).coefficients, [1.0]);
      // U_1 = 2x
      expect(Polynomial.chebyshevU(1).coefficients, [0.0, 2.0]);
      // U_2 = 4x^2 - 1
      expect(Polynomial.chebyshevU(2).coefficients, [-1.0, 0.0, 4.0]);
      // U_3 = 8x^3 - 4x
      expect(Polynomial.chebyshevU(3).coefficients, [0.0, -4.0, 0.0, 8.0]);
    });

    test('Legendre P_n known polynomials', () {
      // P_0 = 1
      expect(Polynomial.legendreP(0).coefficients, [1.0]);
      // P_1 = x
      expect(Polynomial.legendreP(1).coefficients, [0.0, 1.0]);
      // P_2 = 1.5 x^2 - 0.5
      final p2 = Polynomial.legendreP(2);
      expect(p2[0], closeTo(-0.5, 1e-9));
      expect(p2[1], closeTo(0.0, 1e-9));
      expect(p2[2], closeTo(1.5, 1e-9));
      // P_3 = 2.5 x^3 - 1.5 x
      final p3 = Polynomial.legendreP(3);
      expect(p3[0], closeTo(0.0, 1e-9));
      expect(p3[1], closeTo(-1.5, 1e-9));
      expect(p3[2], closeTo(0.0, 1e-9));
      expect(p3[3], closeTo(2.5, 1e-9));
    });

    test('Hermite H_n and He_n known polynomials', () {
      // H_0 = 1, H_1 = 2x, H_2 = 4x^2 - 2, H_3 = 8x^3 - 12x
      expect(Polynomial.hermiteH(0).coefficients, [1.0]);
      expect(Polynomial.hermiteH(1).coefficients, [0.0, 2.0]);
      expect(Polynomial.hermiteH(2).coefficients, [-2.0, 0.0, 4.0]);
      expect(Polynomial.hermiteH(3).coefficients, [0.0, -12.0, 0.0, 8.0]);

      // He_0 = 1, He_1 = x, He_2 = x^2 - 1, He_3 = x^3 - 3x
      expect(Polynomial.hermiteHe(0).coefficients, [1.0]);
      expect(Polynomial.hermiteHe(1).coefficients, [0.0, 1.0]);
      expect(Polynomial.hermiteHe(2).coefficients, [-1.0, 0.0, 1.0]);
      expect(Polynomial.hermiteHe(3).coefficients, [0.0, -3.0, 0.0, 1.0]);
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
      expect(tClenshaw, closeTo(tDirect, 1e-9));

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
      expect(uClenshaw, closeTo(uDirect, 1e-9));

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
      expect(pClenshaw, closeTo(pDirect, 1e-9));

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
      expect(hClenshaw, closeTo(hDirect, 1e-9));

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
      expect(heClenshaw, closeTo(heDirect, 1e-9));
    });
  });
}
