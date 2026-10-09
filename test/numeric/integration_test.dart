import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/src/numeric/integration.dart';
import 'package:data/symbolic.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('Numerical Integration (Quadrature)', () {
    test('adaptive Simpson on polynomial', () {
      // \int_0^2 (3x^2 + 2x + 1) dx = [x^3 + x^2 + x]_0^2 = 8 + 4 + 2 = 14
      double f(double x) => 3.0 * x * x + 2.0 * x + 1.0;
      check(adaptiveSimpson(f, 0.0, 2.0)).isCloseTo(14.0, 1e-8);
    });

    test('adaptive Simpson on trigonometric with Expr', () {
      // \int_0^pi sin(x) dx = [-cos(x)]_0^pi = -(-1) - (-1) = 2
      const x = Variable('x');
      const f = Sin(x);
      check(adaptiveSimpson(f, 0.0, math.pi, variable: 'x'))
          .isCloseTo(2.0, 1e-8);
    });

    test('Gauss-Kronrod (GK15) on Gaussian integral', () {
      // \int_0^1 exp(-x^2) dx = sqrt(pi)/2 * erf(1)
      double f(double x) => math.exp(-x * x);
      final result = gaussKronrod(f, 0.0, 1.0);
      check(result).isCloseTo(0.746824132812427, 1e-8);
    });

    test('integration with a > b inverts sign', () {
      double f(double x) => x * x;
      check(adaptiveSimpson(f, 2.0, 0.0)).isCloseTo(-8.0 / 3.0, 1e-8);
      check(gaussKronrod(f, 2.0, 0.0)).isCloseTo(-8.0 / 3.0, 1e-8);
    });
  });
}
