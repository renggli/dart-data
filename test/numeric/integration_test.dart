import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/src/numeric/integration.dart';
import 'package:data/symbolic.dart';
import 'package:test/test.dart';

void main() {
  group('Numerical Integration (Quadrature)', () {
    test('adaptive Simpson on polynomial', () {
      // \int_0^2 (3x^2 + 2x + 1) dx = [x^3 + x^2 + x]_0^2 = 8 + 4 + 2 = 14
      double function(double x) => 3.0 * x * x + 2.0 * x + 1.0;
      check(adaptiveSimpson(function, 0.0, 2.0)).isCloseTo(14.0, 1e-8);
    });

    test('adaptive Simpson on trigonometric with Expr', () {
      // \int_0^pi sin(x) dx = [-cos(x)]_0^pi = -(-1) - (-1) = 2
      const x = Variable('x');
      const expr = Sin(x);
      check(adaptiveSimpson(expr, 0.0, math.pi, variable: 'x'))
          .isCloseTo(2.0, 1e-8);
    });

    test('Gauss-Kronrod (GK15) on Gaussian integral', () {
      // \int_0^1 exp(-x^2) dx = sqrt(pi)/2 * erf(1)
      double function(double x) => math.exp(-x * x);
      final result = gaussKronrod(function, 0.0, 1.0);
      check(result).isCloseTo(0.746824132812427, 1e-8);
    });

    test('integration with a > b inverts sign and a == b is zero', () {
      double function(double x) => x * x;
      check(adaptiveSimpson(function, 2.0, 0.0)).isCloseTo(-8.0 / 3.0, 1e-8);
      check(gaussKronrod(function, 2.0, 0.0)).isCloseTo(-8.0 / 3.0, 1e-8);

      check(adaptiveSimpson(function, 2.0, 2.0)).equals(0.0);
      check(gaussKronrod(function, 2.0, 2.0)).equals(0.0);
    });

    test(
      'Gauss-Kronrod adaptive recursion on oscillatory function and with Expr',
      () {
        // High frequency oscillation triggers recursive subdivision
        double fOsc(double x) => math.sin(50.0 * x);
        final res = gaussKronrod(fOsc, 0.0, math.pi, tolerance: 1e-12);
        check(res).isCloseTo((1.0 - math.cos(50.0 * math.pi)) / 50.0, 1e-8);

        const x = Variable('x');
        const fExpr = Cos(x);
        check(gaussKronrod(fExpr, 0.0, math.pi / 2.0, variable: 'x'))
            .isCloseTo(1.0, 1e-8);

        num fNum(num val) => val * val;
        check(adaptiveSimpson(fNum, 0.0, 1.0)).isCloseTo(1.0 / 3.0, 1e-8);
        check(gaussKronrod(fNum, 0.0, 1.0)).isCloseTo(1.0 / 3.0, 1e-8);

        check(() => adaptiveSimpson('invalid', 0.0, 1.0))
            .throws<ArgumentError>();
        check(() => gaussKronrod('invalid', 0.0, 1.0)).throws<ArgumentError>();
      },
    );
  });
}
