import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/src/numeric/root_finding.dart';
import 'package:data/symbolic.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('Root Finding Algorithms', () {
    test('Brent-Dekker root solver on transcendental equation', () {
      // f(x) = cos(x) - x = 0 (Dottie number, approx 0.739085133215)
      double f(double x) => math.cos(x) - x;

      final root = brentRoot(f, 0.0, 1.0);
      check(root).isCloseTo(0.739085133215, 1e-10);
      check(f(root)).isCloseTo(0.0, 1e-12);
    });

    test('Brent-Dekker root solver with Expr', () {
      const x = Variable('x');
      // x^3 - 2*x - 5 = 0, root around 2.0945514815
      final f = x.pow(3) - const Constant(2.0) * x - const Constant(5.0);

      final root = brentRoot(f, 1.0, 3.0, variable: 'x');
      check(root).isCloseTo(2.0945514815, 1e-8);
    });

    test('Brent-Dekker with NaN returns NaN', () {
      check(brentRoot((double x) => double.nan, 0.0, 1.0)).isNaN();
    });

    test('Newton-Raphson root solver with automatic symbolic derivative', () {
      const x = Variable('x');
      // x^2 - 2 = 0 => x = sqrt(2)
      final f = x.pow(2) - const Constant(2.0);

      final root = newtonRaphson(f, 1.0, variable: 'x');
      check(root).isCloseTo(math.sqrt(2.0), 1e-10);
    });

    test('Newton-Raphson root solver with num Function(num)', () {
      num f(num x) => x * x - 2;
      final root = newtonRaphson(f, 1.0);
      check(root).isCloseTo(math.sqrt(2.0), 1e-10);
    });

    test('Bisection root solver', () {
      double f(double x) => x * x * x - 27.0; // root at 3.0
      final root = bisection(f, 0.0, 5.0);
      check(root).isCloseTo(3.0, 1e-9);

      // With Expr and num Function
      const x = Variable('x');
      final expr = x.pow(3) - const Constant(27.0);
      check(bisection(expr, 0.0, 5.0)).isCloseTo(3.0, 1e-9);

      num fnNum(num v) => v * v * v - 27;
      check(bisection(fnNum, 0.0, 5.0)).isCloseTo(3.0, 1e-9);
    });

    test('Newton-Raphson explicit derivatives and zero derivative error', () {
      double f(double x) => x * x - 4.0;
      double df(double x) => 2.0 * x;
      check(newtonRaphson(f, 1.0, derivative: df)).isCloseTo(2.0, 1e-9);

      num fNum(num x) => x * x - 4;
      num dfNum(num x) => 2 * x;
      check(newtonRaphson(fNum, 1.0, derivative: dfNum)).isCloseTo(2.0, 1e-9);

      // Derivative near zero throws StateError
      double fZeroDeriv(double x) => x * x + 1.0;
      check(() => newtonRaphson(fZeroDeriv, 0.0)).throws<StateError>();
    });

    test('Brent-Dekker with num Function(num)', () {
      num fn(num x) => x * x - 9;
      check(brentRoot(fn, 0.0, 5.0)).isCloseTo(3.0, 1e-9);
    });

    test('unbracketed root and invalid types throw ArgumentError', () {
      double f(double x) => x * x + 1.0;
      check(() => brentRoot(f, 1.0, 2.0)).throws<ArgumentError>();
      check(() => bisection(f, 1.0, 2.0)).throws<ArgumentError>();

      check(() => brentRoot('not-a-func', 0.0, 1.0)).throws<ArgumentError>();
      check(() => bisection('not-a-func', 0.0, 1.0)).throws<ArgumentError>();
      check(() => newtonRaphson('not-a-func', 1.0)).throws<ArgumentError>();
    });
  });
}
