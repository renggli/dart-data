import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/test.dart';

void main() {
  group('Numeric approximation and rationalization', () {
    test(
      'approximate converts exact constants and rationals to RealNumber',
      () {
        final exact = Expr.parse('pi + e + sqrt(2)').simplify();
        check(exact.anyNode((n) => n is RealNumber)).isFalse();
        check(exact.anyNode((n) => n == Constant.pi)).isTrue();
        check(exact.anyNode((n) => n == Constant.e)).isTrue();

        final approx = exact.approximate();
        check(approx).isA<RealNumber>();
        check((approx as RealNumber).value)
            .isCloseTo(math.pi + math.e + math.sqrt2, 1e-12);
      },
    );

    test(
      'approximate preserves free variables while folding numeric subtrees',
      () {
        final expr = Expr.parse('pi * x + 1 / 4');
        final approx = expr.approximate();
        check(approx.dependsOn('x')).isTrue();
        check(approx.anyNode((n) => n == Constant.pi)).isFalse();
        check(approx.evaluate({'x': 2.0}))
            .isCloseTo(2.0 * math.pi + 0.25, 1e-12);
      },
    );

    test(
      'rationalize recovers exact RationalNumbers via continued fractions',
      () {
        final floatExpr = Expr.parse('0.5 * x + 0.3333333333333333');
        final exact = floatExpr.rationalize();
        check(exact.anyNode((n) => n is RealNumber)).isFalse();
        check(exact.simplify().toString()).equals('1/3 + 1/2 * x');
      },
    );
  });
}
