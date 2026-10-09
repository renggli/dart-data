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
    });

    test('unbracketed root throws ArgumentError', () {
      double f(double x) => x * x + 1.0;
      check(() => brentRoot(f, 1.0, 2.0)).throws<ArgumentError>();
      check(() => bisection(f, 1.0, 2.0)).throws<ArgumentError>();
    });
  });
}
