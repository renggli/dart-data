import 'dart:math' as math;

import 'package:data/src/numeric/interpolation.dart';
import 'package:test/test.dart';

void main() {
  group('Interpolation', () {
    test('linear interpolation', () {
      final xs = [0.0, 1.0, 2.0, 3.0];
      final ys = [0.0, 10.0, 20.0, 30.0];

      final interp = LinearInterpolation(xs, ys);
      expect(interp(0.5), closeTo(5.0, 1e-9));
      expect(interp(1.5), closeTo(15.0, 1e-9));
      expect(interp(2.0), closeTo(20.0, 1e-9));
    });

    test('natural cubic spline interpolation', () {
      // Points from sin(x)
      final xs = [0.0, math.pi / 2.0, math.pi, 3.0 * math.pi / 2.0, 2.0 * math.pi];
      final ys = [0.0, 1.0, 0.0, -1.0, 0.0];

      final spline = CubicSpline(xs, ys, boundary: CubicSplineBoundary.natural);

      // Must interpolate nodes exactly
      for (var i = 0; i < xs.length; i++) {
        expect(spline(xs[i]), closeTo(ys[i], 1e-9));
      }

      // Midpoints should closely approximate sin(x)
      expect(spline(math.pi / 4.0), closeTo(math.sin(math.pi / 4.0), 0.05));
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

      expect(spline(0.0), closeTo(0.0, 1e-9));
      expect(spline(1.0), closeTo(1.0, 1e-9));
      expect(spline(2.0), closeTo(8.0, 1e-9));
      expect(spline.derivative(0.0), closeTo(0.0, 1e-9));
      expect(spline.derivative(2.0), closeTo(12.0, 1e-9));
    });

    test('monotonic PCHIP interpolation preserves monotonicity without overshoot', () {
      // Step-like monotonic data
      final xs = [0.0, 1.0, 2.0, 3.0, 4.0, 5.0];
      final ys = [0.0, 0.0, 0.0, 1.0, 1.0, 1.0];

      final pchip = PchipInterpolation(xs, ys);

      // Interpolation on flat section [0, 2] must stay exactly 0.0
      expect(pchip(0.5), closeTo(0.0, 1e-9));
      expect(pchip(1.5), closeTo(0.0, 1e-9));

      // Interpolation on transition [2, 3] must be strictly between 0 and 1
      final mid = pchip(2.5);
      expect(mid, greaterThan(0.0));
      expect(mid, lessThan(1.0));

      // Flat section [3, 5] must stay 1.0 (no overshoot!)
      expect(pchip(3.5), closeTo(1.0, 1e-9));
      expect(pchip(4.5), closeTo(1.0, 1e-9));
    });
  });
}
