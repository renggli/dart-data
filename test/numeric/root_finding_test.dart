import 'dart:math' as math;

import 'package:data/src/numeric/root_finding.dart';
import 'package:data/symbolic.dart';
import 'package:test/test.dart';

void main() {
  group('Root Finding Algorithms', () {
    test('Brent-Dekker root solver on transcendental equation', () {
      // f(x) = cos(x) - x = 0 (Dottie number, approx 0.739085133215)
      double f(double x) => math.cos(x) - x;

      final root = brentRoot(f, 0.0, 1.0);
      expect(root, closeTo(0.739085133215, 1e-10));
      expect(f(root), closeTo(0.0, 1e-12));
    });

    test('Brent-Dekker root solver with Expr', () {
      const x = Variable('x');
      // x^3 - 2*x - 5 = 0, root around 2.0945514815
      final f = x.pow(3) - const Constant(2.0) * x - const Constant(5.0);

      final root = brentRoot(f, 1.0, 3.0, variable: 'x');
      expect(root, closeTo(2.0945514815, 1e-8));
    });

    test('Newton-Raphson root solver with automatic symbolic derivative', () {
      const x = Variable('x');
      // x^2 - 2 = 0 => x = sqrt(2)
      final f = x.pow(2) - const Constant(2.0);

      final root = newtonRaphson(f, 1.0, variable: 'x');
      expect(root, closeTo(math.sqrt(2.0), 1e-10));
    });

    test('Bisection root solver', () {
      double f(double x) => x * x * x - 27.0; // root at 3.0
      final root = bisection(f, 0.0, 5.0);
      expect(root, closeTo(3.0, 1e-9));
    });

    test('unbracketed root throws ArgumentError', () {
      double f(double x) => x * x + 1.0;
      expect(() => brentRoot(f, 1.0, 2.0), throwsArgumentError);
      expect(() => bisection(f, 1.0, 2.0), throwsArgumentError);
    });
  });
}
