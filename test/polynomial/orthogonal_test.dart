import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/polynomial.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('Orthogonal polynomial generators', () {
    test('Chebyshev T_n known polynomials and identity', () {
      check(Polynomial.chebyshevT(0).coefficients).deepEquals([1.0]);
      check(Polynomial.chebyshevT(1).coefficients).deepEquals([0.0, 1.0]);
      check(Polynomial.chebyshevT(2).coefficients).deepEquals([-1.0, 0.0, 2.0]);
      check(Polynomial.chebyshevT(3).coefficients)
          .deepEquals([0.0, -3.0, 0.0, 4.0]);
      check(Polynomial.chebyshevT(4).coefficients)
          .deepEquals([1.0, 0.0, -8.0, 0.0, 8.0]);

      for (var deg = 0; deg <= 4; deg++) {
        final poly = Polynomial.chebyshevT(deg);
        const theta = 0.7;
        final x = math.cos(theta);
        check(poly.evaluateDouble(x)).isCloseTo(math.cos(deg * theta), 1e-9);
      }
      check(() => Polynomial.chebyshevT(-1)).throws<RangeError>();
    });

    test('Chebyshev U_n known polynomials', () {
      check(Polynomial.chebyshevU(0).coefficients).deepEquals([1.0]);
      check(Polynomial.chebyshevU(1).coefficients).deepEquals([0.0, 2.0]);
      check(Polynomial.chebyshevU(2).coefficients).deepEquals([-1.0, 0.0, 4.0]);
      check(Polynomial.chebyshevU(3).coefficients)
          .deepEquals([0.0, -4.0, 0.0, 8.0]);
      check(() => Polynomial.chebyshevU(-1)).throws<RangeError>();
    });

    test('Legendre P_n known polynomials', () {
      check(Polynomial.legendreP(0).coefficients).deepEquals([1.0]);
      check(Polynomial.legendreP(1).coefficients).deepEquals([0.0, 1.0]);
      final p2 = Polynomial.legendreP(2);
      check(p2[0]).isCloseTo(-0.5, 1e-9);
      check(p2[1]).isCloseTo(0.0, 1e-9);
      check(p2[2]).isCloseTo(1.5, 1e-9);
      final p3 = Polynomial.legendreP(3);
      check(p3[0]).isCloseTo(0.0, 1e-9);
      check(p3[1]).isCloseTo(-1.5, 1e-9);
      check(p3[2]).isCloseTo(0.0, 1e-9);
      check(p3[3]).isCloseTo(2.5, 1e-9);
      check(() => Polynomial.legendreP(-1)).throws<RangeError>();
    });

    test('Hermite H_n and He_n known polynomials', () {
      check(Polynomial.hermiteH(0).coefficients).deepEquals([1.0]);
      check(Polynomial.hermiteH(1).coefficients).deepEquals([0.0, 2.0]);
      check(Polynomial.hermiteH(2).coefficients).deepEquals([-2.0, 0.0, 4.0]);
      check(Polynomial.hermiteH(3).coefficients)
          .deepEquals([0.0, -12.0, 0.0, 8.0]);

      check(Polynomial.hermiteHe(0).coefficients).deepEquals([1.0]);
      check(Polynomial.hermiteHe(1).coefficients).deepEquals([0.0, 1.0]);
      check(Polynomial.hermiteHe(2).coefficients).deepEquals([-1.0, 0.0, 1.0]);
      check(Polynomial.hermiteHe(3).coefficients)
          .deepEquals([0.0, -3.0, 0.0, 1.0]);
      check(() => Polynomial.hermiteH(-1)).throws<RangeError>();
      check(() => Polynomial.hermiteHe(-1)).throws<RangeError>();
    });

    test('Laguerre L_n^(alpha) known polynomials and validation', () {
      check(Polynomial.laguerreL(0).coefficients).deepEquals([1.0]);
      check(Polynomial.laguerreL(1).coefficients).deepEquals([1.0, -1.0]);
      final l2 = Polynomial.laguerreL(2);
      check(l2[0]).isCloseTo(1.0, 1e-12);
      check(l2[1]).isCloseTo(-2.0, 1e-12);
      check(l2[2]).isCloseTo(0.5, 1e-12);

      final l2Alpha = Polynomial.laguerreL(2, alpha: 1.0);
      check(l2Alpha[0]).isCloseTo(3.0, 1e-12);
      check(l2Alpha[1]).isCloseTo(-3.0, 1e-12);
      check(l2Alpha[2]).isCloseTo(0.5, 1e-12);

      check(() => Polynomial.laguerreL(-1)).throws<RangeError>();
      check(() => Polynomial.laguerreL(0, alpha: double.nan))
          .throws<ArgumentError>();
      check(() => Polynomial.laguerreL(2, alpha: double.infinity))
          .throws<ArgumentError>();
    });

    test('high-degree generators avoid FFT noise and match endpoints', () {
      // T_70(1) == 1, T_70(-1) == 1, T_70(0) == -1
      final t70 = Polynomial.chebyshevT(70);
      check(t70.degree).equals(70);
      check(t70[0]).equals(-1.0);
      check(t70[1]).equals(0.0);
      check(t70[70]).equals(math.pow(2.0, 69).toDouble());

      // U_70(0) == -1, P_65(1) == 1
      final u70 = Polynomial.chebyshevU(70);
      check(u70[0]).equals(-1.0);
      final p65 = Polynomial.legendreP(65);
      check(p65.degree).equals(65);
      check(p65[0]).equals(0.0);
      check(p65.evaluateDouble(0.0)).equals(0.0);
    });
  });

  group('Orthogonal single-point and Clenshaw evaluation', () {
    test('evaluateOrthogonal matches all polynomial generators', () {
      for (final family in OrthogonalFamily.values) {
        for (var n = 0; n <= 6; n++) {
          final poly = switch (family) {
            OrthogonalFamily.chebyshevT => Polynomial.chebyshevT(n),
            OrthogonalFamily.chebyshevU => Polynomial.chebyshevU(n),
            OrthogonalFamily.legendreP => Polynomial.legendreP(n),
            OrthogonalFamily.hermiteH => Polynomial.hermiteH(n),
            OrthogonalFamily.hermiteHe => Polynomial.hermiteHe(n),
            OrthogonalFamily.laguerreL => Polynomial.laguerreL(n, alpha: 0.75),
          };
          for (final x in [0.0, 0.5, 1.25]) {
            check(evaluateOrthogonal(n, x, family: family, alpha: 0.75))
                .isCloseTo(poly.evaluateDouble(x), 1e-9);
          }
        }
      }
      check(
        () => evaluateOrthogonal(-1, 0.5, family: OrthogonalFamily.chebyshevT),
      ).throws<RangeError>();
      check(
        () => evaluateOrthogonal(
          0,
          0.5,
          family: OrthogonalFamily.laguerreL,
          alpha: double.nan,
        ),
      ).throws<ArgumentError>();
    });

    test('Clenshaw evaluation matches explicit linear combinations and handles edge inputs', () {
      final coeffs = [2.5, -1.2, 0.8, 0.3];
      const x = 0.65;

      for (final family in OrthogonalFamily.values) {
        var direct = 0.0;
        for (var k = 0; k < coeffs.length; k++) {
          direct +=
              coeffs[k] * evaluateOrthogonal(k, x, family: family, alpha: 0.5);
        }
        check(evaluateOrthogonalSeries(coeffs, x, family: family, alpha: 0.5))
            .isCloseTo(direct, 1e-9);
      }

      check(
        evaluateOrthogonalSeries(
          const [],
          0.5,
          family: OrthogonalFamily.legendreP,
        ),
      ).equals(0.0);
      check(
        evaluateOrthogonalSeries(
          const [3.5],
          0.5,
          family: OrthogonalFamily.legendreP,
        ),
      ).equals(3.5);
      check(
        () => evaluateOrthogonalSeries(
          const [],
          0.5,
          family: OrthogonalFamily.laguerreL,
          alpha: double.infinity,
        ),
      ).throws<ArgumentError>();
    });
  });
}
