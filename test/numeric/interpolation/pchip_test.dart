import 'package:checks/checks.dart';
import 'package:data/numeric.dart';
import 'package:test/test.dart';

void main() {
  group('PchipInterpolation', () {
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

    test('constructor errors', () {
      final xs2 = [1.0, 2.0];
      final ys2 = [1.0, 2.0];
      final xs1 = [1.0];
      final ys1 = [1.0];
      final xsNonInc = [2.0, 1.0];

      check(() => PchipInterpolation(xs2, ys1)).throws<ArgumentError>();
      check(() => PchipInterpolation(xs1, ys1)).throws<ArgumentError>();
      check(() => PchipInterpolation(xsNonInc, ys2)).throws<ArgumentError>();
    });
  });
}
