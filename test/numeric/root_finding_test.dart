import 'dart:math' as math;

import 'package:checks/checks.dart';
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
}
