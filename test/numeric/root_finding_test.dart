import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/linear.dart';
import 'package:data/src/numeric/root_finding.dart';
import 'package:test/test.dart';

void main() {
  group('Canonical Root Finding (solve)', () {
    test('Brent-Dekker root solver on transcendental equation', () {
      // f(x) = cos(x) - x = 0 (Dottie number, approx 0.739085133215)
      double function(double x) => math.cos(x) - x;

      final root = solve(function, 0.0, b: 1.0);
      check(root).isCloseTo(0.739085133215, 1e-10);
      check(function(root)).isCloseTo(0.0, 1e-12);
    });

    test('Brent-Dekker root solver with method: RootMethod.brent', () {
      // x^3 - 2*x - 5 = 0, root around 2.0945514815
      double function(double x) => x * x * x - 2.0 * x - 5.0;

      final root = solve(function, 1.0, b: 3.0, method: RootMethod.brent);
      check(root).isCloseTo(2.0945514815, 1e-8);
    });

    test('Brent-Dekker with NaN returns NaN', () {
      check(solve((double x) => double.nan, 0.0, b: 1.0)).isNaN();
    });

    test('Newton-Raphson root solver (method: RootMethod.newtonRaphson)', () {
      // x^2 - 2 = 0 => x = sqrt(2)
      double function(double x) => x * x - 2.0;

      final root = solve(function, 1.0, method: RootMethod.newtonRaphson);
      check(root).isCloseTo(math.sqrt(2.0), 1e-10);
    });

    test(
      'Newton-Raphson with explicit derivative and zero derivative error',
      () {
        double function(double x) => x * x - 4.0;
        double df(double x) => 2.0 * x;
        check(
          solve(
            function,
            1.0,
            method: RootMethod.newtonRaphson,
            derivative: df,
          ),
        ).isCloseTo(2.0, 1e-9);

        // Derivative near zero throws StateError
        double fZeroDeriv(double x) => x * x + 1.0;
        check(() => solve(fZeroDeriv, 0.0, method: RootMethod.newtonRaphson))
            .throws<StateError>();
      },
    );

    test('Bisection root solver (method: RootMethod.bisection)', () {
      double function(double x) => x * x * x - 27.0; // root at 3.0
      final root = solve(function, 0.0, b: 5.0, method: RootMethod.bisection);
      check(root).isCloseTo(3.0, 1e-9);
    });

    test('Bracketed methods require bound b', () {
      double function(double x) => x * x - 4.0;
      check(() => solve(function, 1.0, method: RootMethod.brent))
          .throws<ArgumentError>();
      check(() => solve(function, 1.0, method: RootMethod.bisection))
          .throws<ArgumentError>();
    });

    test('Unbracketed root throws ArgumentError', () {
      double function(double x) => x * x + 1.0;
      check(() => solve(function, 1.0, b: 2.0, method: RootMethod.brent))
          .throws<ArgumentError>();
      check(() => solve(function, 1.0, b: 2.0, method: RootMethod.bisection))
          .throws<ArgumentError>();
    });
  });

  group('Canonical Multivariable Root Finding (solveSystem)', () {
    test('solves linear 2x2 system', () {
      // 3x + 2y - 12 = 0
      // x - y - 1 = 0
      // (3x + 2(x - 1) = 12 => 5x = 14 => x = 2.8, y = 1.8)
      final eq = <double Function(Vector<double>)>[
        (v) => 3.0 * v[0] + 2.0 * v[1] - 12.0,
        (v) => v[0] - v[1] - 1.0,
      ];
      final res = solveSystem(eq, Vector.fromList([0.0, 0.0]));
      check(res[0]).isCloseTo(2.8, 1e-9);
      check(res[1]).isCloseTo(1.8, 1e-9);
    });

    test('solves nonlinear trigonometric system', () {
      // sin(x) + cos(y) - 1.2 = 0
      // cos(x) - sin(y) - 0.2 = 0
      final eq = <double Function(Vector<double>)>[
        (v) => math.sin(v[0]) + math.cos(v[1]) - 1.2,
        (v) => math.cos(v[0]) - math.sin(v[1]) - 0.2,
      ];
      final guess = Vector.fromList([0.5, 0.5]);
      final res = solveSystem(eq, guess);
      check(eq[0](res).abs()).isLessThan(1e-9);
      check(eq[1](res).abs()).isLessThan(1e-9);
    });

    test('dimension mismatch throws ArgumentError', () {
      final eq = <double Function(Vector<double>)>[(v) => v[0]];
      check(() => solveSystem(eq, Vector.fromList([0.0, 0.0])))
          .throws<ArgumentError>();
    });
  });
}
