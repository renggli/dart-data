import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/src/numeric/interpolation.dart';
import 'package:test/test.dart';

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

    test('nearest neighbor interpolation', () {
      final xs = [0.0, 1.0, 3.0];
      final ys = [0.0, 10.0, 30.0];

      final interp = NearestInterpolation(xs, ys);
      check(interp(0.4)).isCloseTo(0.0, 1e-9);
      check(interp(0.5)).isCloseTo(0.0, 1e-9); // preferLower default
      check(interp(0.6)).isCloseTo(10.0, 1e-9);
      check(interp(1.9)).isCloseTo(10.0, 1e-9);
      check(interp(2.1)).isCloseTo(30.0, 1e-9);

      final preferHigher = NearestInterpolation(xs, ys, preferLower: false);
      check(preferHigher(0.5)).isCloseTo(10.0, 1e-9);
    });

    test('previous step interpolation', () {
      final xs = [1.0, 2.0, 4.0];
      final ys = [10.0, 20.0, 40.0];

      final interp = PreviousInterpolation(xs, ys, left: -1.0);
      check(interp(0.5)).isCloseTo(-1.0, 1e-9);
      check(interp(1.0)).isCloseTo(10.0, 1e-9);
      check(interp(1.9)).isCloseTo(10.0, 1e-9);
      check(interp(2.0)).isCloseTo(20.0, 1e-9);
      check(interp(3.5)).isCloseTo(20.0, 1e-9);
      check(interp(4.0)).isCloseTo(40.0, 1e-9);
      check(interp(5.0)).isCloseTo(40.0, 1e-9);
    });

    test('next step interpolation', () {
      final xs = [1.0, 2.0, 4.0];
      final ys = [10.0, 20.0, 40.0];

      final interp = NextInterpolation(xs, ys, right: 99.0);
      check(interp(0.5)).isCloseTo(10.0, 1e-9);
      check(interp(1.0)).isCloseTo(10.0, 1e-9);
      check(interp(1.1)).isCloseTo(20.0, 1e-9);
      check(interp(2.0)).isCloseTo(20.0, 1e-9);
      check(interp(3.0)).isCloseTo(40.0, 1e-9);
      check(interp(4.0)).isCloseTo(40.0, 1e-9);
      check(interp(4.1)).isCloseTo(99.0, 1e-9);
    });

    test('lagrange polynomial interpolation', () {
      // y = 2*x^2 - 3*x + 1
      final xs = [-1.0, 0.0, 1.0, 2.0];
      final ys = [6.0, 1.0, 0.0, 3.0];

      final interp = LagrangeInterpolation(xs, ys);
      for (var i = 0; i < xs.length; i++) {
        check(interp(xs[i])).isCloseTo(ys[i], 1e-9);
      }
      // Test at intermediate points
      // At x = 0.5: 2*(0.25) - 1.5 + 1 = 0.5 - 1.5 + 1 = 0.0
      check(interp(0.5)).isCloseTo(0.0, 1e-9);
      // At x = 1.5: 2*(2.25) - 4.5 + 1 = 4.5 - 4.5 + 1 = 1.0
      check(interp(1.5)).isCloseTo(1.0, 1e-9);
      // At x = 3.0: 2*(9) - 9 + 1 = 10.0
      check(interp(3.0)).isCloseTo(10.0, 1e-9);
    });

    test(
      'PCHIP 2 points, local extrema flat derivative, and endpoint clipping',
      () {
        final pchip2 = PchipInterpolation([0.0, 1.0], [2.0, 5.0]);
        check(pchip2(0.5)).isCloseTo(3.5, 1e-6);

        // Local extrema where delta[i-1] * delta[i] <= 0 (derivative becomes 0)
        final pchipExtrema = PchipInterpolation(
          [0.0, 1.0, 2.0],
          [0.0, 10.0, 5.0],
        );
        check(pchipExtrema(1.0)).isCloseTo(10.0, 1e-9);

        // Large initial slope triggering endpoint clipping
        final pchipClip = PchipInterpolation(
          [0.0, 1.0, 2.0, 3.0],
          [0.0, 100.0, 101.0, 102.0],
        );
        check(pchipClip(0.5)).isGreaterThan(0.0);
      },
    );

    test('Interpolator constructor errors', () {
      final xs2 = [1.0, 2.0];
      final ys2 = [1.0, 2.0];
      final xs1 = [1.0];
      final ys1 = [1.0];
      final xsNonInc = [2.0, 1.0];

      // Linear
      check(() => LinearInterpolation(xs2, ys1)).throws<ArgumentError>();
      check(() => LinearInterpolation(xs1, ys1)).throws<ArgumentError>();
      check(() => LinearInterpolation(xsNonInc, ys2)).throws<ArgumentError>();

      // PCHIP
      check(() => PchipInterpolation(xs2, ys1)).throws<ArgumentError>();
      check(() => PchipInterpolation(xs1, ys1)).throws<ArgumentError>();
      check(() => PchipInterpolation(xsNonInc, ys2)).throws<ArgumentError>();

      // Nearest
      check(() => NearestInterpolation(xs2, ys1)).throws<ArgumentError>();
      check(() => NearestInterpolation(<double>[], <double>[]))
          .throws<ArgumentError>();
      check(() => NearestInterpolation(xsNonInc, ys2)).throws<ArgumentError>();

      // Previous
      check(() => PreviousInterpolation(xs2, ys1)).throws<ArgumentError>();
      check(() => PreviousInterpolation(<double>[], <double>[]))
          .throws<ArgumentError>();
      check(() => PreviousInterpolation(xsNonInc, ys2)).throws<ArgumentError>();

      // Next
      check(() => NextInterpolation(xs2, ys1)).throws<ArgumentError>();
      check(() => NextInterpolation(<double>[], <double>[]))
          .throws<ArgumentError>();
      check(() => NextInterpolation(xsNonInc, ys2)).throws<ArgumentError>();

      // Lagrange
      check(() => LagrangeInterpolation(xs2, ys1)).throws<ArgumentError>();
      check(() => LagrangeInterpolation(<double>[], <double>[]))
          .throws<ArgumentError>();
    });
  });
}
