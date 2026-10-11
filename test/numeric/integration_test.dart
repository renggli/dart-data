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

    test('improper integrals over semi-infinite and infinite domains', () {
      // \int_0^\infty exp(-x) dx = 1.0
      double expDecay(double x) => math.exp(-x);
      check(integrate(expDecay, 0.0, double.infinity)).isCloseTo(1.0, 1e-7);
      check(
        integrate(
          expDecay,
          0.0,
          double.infinity,
          method: IntegrationMethod.simpson,
        ),
      ).isCloseTo(1.0, 1e-7);

      // \int_{-\infty}^0 exp(x) dx = 1.0
      double expGrowth(double x) => math.exp(x);
      check(integrate(expGrowth, double.negativeInfinity, 0.0))
          .isCloseTo(1.0, 1e-7);

      // \int_{-\infty}^\infty exp(-x^2) dx = sqrt(pi)
      double gaussian(double x) => math.exp(-x * x);
      check(integrate(gaussian, double.negativeInfinity, double.infinity))
          .isCloseTo(math.sqrt(math.pi), 1e-7);

      // \int_0^\infty 1 / (1 + x^2) dx = pi / 2
      double rational(double x) => 1.0 / (1.0 + x * x);
      check(integrate(rational, 0.0, double.infinity))
          .isCloseTo(math.pi / 2.0, 1e-7);
    });

    test('integration with singular pole and principal value', () {
      // 1 / sqrt(|x - 1|) on [0, 2]: singular at x = 1, anti-derivative is 2 *
      // sqrt(|x - 1|)
      // \int_0^1 (1 - x)^(-1/2) dx + \int_1^2 (x - 1)^(-1/2) dx = 2 + 2 = 4.0
      double singular(double x) {
        final diff = (x - 1.0).abs();
        if (diff == 0.0) return double.infinity;
        return 1.0 / math.sqrt(diff);
      }

      final res = integrate(singular, 0.0, 2.0, poles: [1.0], tolerance: 1e-5);
      check(res).isCloseTo(4.0, 0.01);
    });

    test('warnings and convergence errors', () {
      // 1 / x on [0, 1] diverges
      double fDivergent(double x) => x == 0.0 ? double.infinity : 1.0 / x;

      check(
        () => integrate(
          fDivergent,
          0.0,
          1.0,
          maxDepth: 3,
          method: IntegrationMethod.simpson,
        ),
      ).throws<IntegrateError>();

      // onWarning intercepts warning without throwing
      final warnings = <IntegrateWarning>[];
      final handled = integrate(
        fDivergent,
        0.0,
        1.0,
        maxDepth: 3,
        method: IntegrationMethod.simpson,
        onWarning: (type, x) => warnings.add(type),
      );
      check(warnings).isNotEmpty();
      check(handled.isNaN).isFalse();

      // NaN bounds throw ArgumentError
      check(() => integrate((x) => x, double.nan, 1.0)).throws<ArgumentError>();
      check(() => integrate((x) => x, 0.0, double.nan)).throws<ArgumentError>();
    });
  });
}
