import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/src/numeric/optimization/brent.dart';
import 'package:test/test.dart';

void main() {
  group('brentMinimize', () {
    test('minimizes quadratic function', () {
      // f(x) = (x - 3)^2 + 5, minimum at x = 3, value = 5
      final res = brentMinimize(
        (x) => (x - 3.0) * (x - 3.0) + 5.0,
        a: 0.0,
        b: 6.0,
      );
      check(res.point).isCloseTo(3.0, 1e-6);
      check(res.value).isCloseTo(5.0, 1e-6);
      check(res.iterations).isGreaterThan(0);
    });

    test('handles inverted interval [b, a]', () {
      final res = brentMinimize((x) => (x + 2.0) * (x + 2.0), a: 0.0, b: -4.0);
      check(res.point).isCloseTo(-2.0, 1e-6);
      check(res.value).isCloseTo(0.0, 1e-6);
    });

    test('minimizes trigonometric function', () {
      // f(x) = cos(x) on [0, 4], minimum at x = pi, value = -1
      final res = brentMinimize(math.cos, a: 0.0, b: 4.0);
      check(res.point).isCloseTo(math.pi, 1e-6);
      check(res.value).isCloseTo(-1.0, 1e-6);
    });

    test('stops after maxIterations when limit is small', () {
      final res = brentMinimize(
        (x) => (x - 10.0) * (x - 10.0),
        a: 0.0,
        b: 20.0,
        maxIterations: 2,
      );
      check(res.iterations).isLessOrEqual(2);
    });
  });
}
