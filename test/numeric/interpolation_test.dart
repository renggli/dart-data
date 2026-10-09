import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/src/numeric/interpolation.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('Interpolation', () {
    test('linear interpolation', () {
      final xs = [0.0, 1.0, 2.0, 3.0];
      final ys = [0.0, 10.0, 20.0, 30.0];

      final interp = LinearInterpolation(xs, ys);
      check(interp(0.5)).isCloseTo(5.0, 1e-9);
      check(interp(1.5)).isCloseTo(15.0, 1e-9);
      check(interp(2.0)).isCloseTo(20.0, 1e-9);
    });

    test('natural cubic spline interpolation', () {
      // Points from sin(x)
      final xs = [
        0.0,
        math.pi / 2.0,
        math.pi,
        3.0 * math.pi / 2.0,
        2.0 * math.pi,
      ];
      final ys = [0.0, 1.0, 0.0, -1.0, 0.0];

      final spline = CubicSpline(xs, ys, boundary: CubicSplineBoundary.natural);

      // Must interpolate nodes exactly
      for (var i = 0; i < xs.length; i++) {
        check(spline(xs[i])).isCloseTo(ys[i], 1e-9);
      }

      // Midpoints should closely approximate sin(x)
      check(spline(math.pi / 4.0)).isCloseTo(math.sin(math.pi / 4.0), 0.05);
    });

    test('clamped cubic spline interpolation', () {
      final xs = [0.0, 1.0, 2.0];
      // y = x^3 => y' = 3x^2 => y'(0) = 0, y'(2) = 12
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

    test(
      'monotonic PCHIP interpolation preserves monotonicity without overshoot',
      () {
        // Step-like monotonic data
        final xs = [0.0, 1.0, 2.0, 3.0, 4.0, 5.0];
        final ys = [0.0, 0.0, 0.0, 1.0, 1.0, 1.0];

        final pchip = PchipInterpolation(xs, ys);

        // Interpolation on flat section [0, 2] must stay exactly 0.0
        check(pchip(0.5)).isCloseTo(0.0, 1e-9);
        check(pchip(1.5)).isCloseTo(0.0, 1e-9);

        // Interpolation on transition [2, 3] must be strictly between 0 and 1
        final mid = pchip(2.5);
        check(mid).isGreaterThan(0.0);
        check(mid).isLessThan(1.0);

        // Flat section [3, 5] must stay 1.0 (no overshoot!)
        check(pchip(3.5)).isCloseTo(1.0, 1e-9);
        check(pchip(4.5)).isCloseTo(1.0, 1e-9);
      },
    );
  });
}
