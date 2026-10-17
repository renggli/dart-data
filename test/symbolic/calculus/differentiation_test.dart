import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/test.dart';

void main() {
  group('Symbolic differentiation', () {
    test('differentiates polynomials, exponentials, and trig functions', () {
      check(Expr.parse('x^3 - 3*x + 1').derivative('x').simplify().toString())
          .equals('-3 + 3 * x ^ 2');

      check(Expr.parse('exp(2*x)').derivative('x').simplify().toString())
          .equals('2 * exp(2 * x)');

      check(
        Expr.parse('sin(x) * cos(x)')
            .derivative('x')
            .simplify()
            .evaluate({'x': 0.5}),
      ).isCloseTo(math.cos(1.0), 1e-12);

      check(
        Expr.parse('ln(x^2 + 1)')
            .derivative('x')
            .simplify()
            .evaluate({'x': 2.0}),
      ).isCloseTo(4.0 / 5.0, 1e-12);
    });

    test('differentiates special, inverse, and piecewise functions', () {
      check(
        Expr.parse('atan(x)').derivative('x').simplify().evaluate({'x': 1.0}),
      ).isCloseTo(0.5, 1e-12);

      check(
        Expr.parse('asinh(x)').derivative('x').simplify().evaluate({'x': 0.0}),
      ).isCloseTo(1.0, 1e-12);

      check(
        Expr.parse('erf(x)').derivative('x').simplify().evaluate({'x': 0.0}),
      ).isCloseTo(2.0 / math.sqrt(math.pi), 1e-12);

      check(
        Expr.parse('lambertw(x)')
            .derivative('x')
            .simplify()
            .evaluate({'x': 1.0}),
      ).isCloseTo(0.3618962566348892, 1e-12);

      final pw = Expr.parse('piecewise(x < 0, -x^2, x^2)').derivative('x');
      check(pw.evaluate({'x': -2.0})).equals(4.0);
      check(pw.evaluate({'x': 2.0})).equals(4.0);
    });
  });
}
