import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/numeric.dart';
import 'package:test/test.dart';

void main() {
  group('CubicSpline', () {
    test('natural cubic spline interpolation', () {
      final xs = [
        0.0,
        math.pi / 2.0,
        math.pi,
        3.0 * math.pi / 2.0,
        2.0 * math.pi,
      ];
      final ys = [0.0, 1.0, 0.0, -1.0, 0.0];

      final spline = CubicSpline(xs, ys, boundary: CubicSplineBoundary.natural);

      for (var i = 0; i < xs.length; i++) {
        check(spline(xs[i])).isCloseTo(ys[i], 1e-9);
      }

      check(spline(math.pi / 4.0)).isCloseTo(math.sin(math.pi / 4.0), 0.05);
    });

    test('clamped cubic spline interpolation', () {
      final xs = [0.0, 1.0, 2.0];
      final ys = [0.0, 1.0, 8.0];

      final spline = CubicSpline(
        xs,
        ys,
        boundary: CubicSplineBoundary.clamped,
        leftSlope: 0.0,
        rightSlope: 12.0,
      );

      check(spline(0.0)).isCloseTo(0.0, 1e-9);
      check(spline(1.0)).isCloseTo(1.0, 1e-9);
      check(spline(2.0)).isCloseTo(8.0, 1e-9);
      check(spline.derivative(0.0)).isCloseTo(0.0, 1e-9);
      check(spline.derivative(2.0)).isCloseTo(12.0, 1e-9);
    });

    test('constructor errors', () {
      check(() => CubicSpline([1.0], [1.0])).throws<ArgumentError>();
      check(() => CubicSpline([1.0, 2.0], [1.0])).throws<ArgumentError>();
      check(() => CubicSpline([2.0, 1.0], [1.0, 2.0])).throws<ArgumentError>();
    });
  });
}
