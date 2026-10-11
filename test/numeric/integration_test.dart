import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/src/numeric/integration.dart';
import 'package:test/test.dart';

void main() {
  group('Canonical Numerical Integration (integrate)', () {
    test(
      'adaptive Simpson on polynomial (method: IntegrationMethod.simpson)',
      () {
        // \int_0^2 (3x^2 + 2x + 1) dx = [x^3 + x^2 + x]_0^2 = 8 + 4 + 2 = 14
        double function(double x) => 3.0 * x * x + 2.0 * x + 1.0;
        check(integrate(function, 0.0, 2.0, method: IntegrationMethod.simpson))
            .isCloseTo(14.0, 1e-8);
      },
    );

    test('Gauss-Kronrod (GK15) default on Gaussian integral', () {
      // \int_0^1 exp(-x^2) dx = sqrt(pi)/2 * erf(1)
      double function(double x) => math.exp(-x * x);
      final result = integrate(function, 0.0, 1.0);
      check(result).isCloseTo(0.746824132812427, 1e-8);
    });

    test('integration with a > b inverts sign and a == b is zero', () {
      double function(double x) => x * x;
      check(integrate(function, 2.0, 0.0, method: IntegrationMethod.simpson))
          .isCloseTo(-8.0 / 3.0, 1e-8);
      check(
        integrate(function, 2.0, 0.0, method: IntegrationMethod.gaussKronrod),
      ).isCloseTo(-8.0 / 3.0, 1e-8);

      check(integrate(function, 2.0, 2.0, method: IntegrationMethod.simpson))
          .equals(0.0);
      check(
        integrate(function, 2.0, 2.0, method: IntegrationMethod.gaussKronrod),
      ).equals(0.0);
    });

    test('Gauss-Kronrod adaptive recursion on oscillatory function', () {
      // High frequency oscillation triggers recursive subdivision
      double fOsc(double x) => math.sin(50.0 * x);
      final res = integrate(fOsc, 0.0, math.pi, tolerance: 1e-12);
      check(res).isCloseTo((1.0 - math.cos(50.0 * math.pi)) / 50.0, 1e-8);
    });

    test('integration with interior poles decomposes interval', () {
      // Abs(x - 1) on [0, 2] has a derivative discontinuity at x = 1
      double f(double x) => (x - 1.0).abs();
      final res = integrate(f, 0.0, 2.0, poles: [1.0]);
      check(res).isCloseTo(1.0, 1e-8);
    });
  });
}
