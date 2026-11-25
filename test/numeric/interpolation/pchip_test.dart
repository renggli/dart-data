import 'package:checks/checks.dart';
import 'package:data/numeric.dart';
import 'package:test/scaffolding.dart';

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
        check(pchip.derivative(0.5)).isCloseTo(0.0, 1e-9);

        // Interpolation on transition [2, 3] must be strictly between 0 and 1
        final mid = pchip(2.5);
        check(mid).isGreaterThan(0.0);
        check(mid).isLessThan(1.0);
        check(pchip.derivative(2.5)).isGreaterThan(0.0);

        // Flat section [3, 5] must stay 1.0 (no overshoot!)
        check(pchip(3.5)).isCloseTo(1.0, 1e-9);
        check(pchip(4.5)).isCloseTo(1.0, 1e-9);
        check(pchip(double.nan)).isNaN;
        check(pchip.derivative(double.nan)).isNaN;
      },
    );

    test(
      'PCHIP 2 points, local extrema flat derivative, and endpoint clipping',
      () {
        final pchip2 = PchipInterpolation([0.0, 1.0], [2.0, 5.0]);
        check(pchip2(0.5)).isCloseTo(3.5, 1e-6);
        check(pchip2.derivative(0.5)).isCloseTo(3.0, 1e-6);

        // Local extrema where delta[i-1] and delta[i] have opposite signs
        final pchipExtrema = PchipInterpolation(
          [0.0, 1.0, 2.0],
          [0.0, 10.0, 5.0],
        );
        check(pchipExtrema(1.0)).isCloseTo(10.0, 1e-9);
        check(pchipExtrema.derivative(1.0)).isCloseTo(0.0, 1e-9);

        // Left and right endpoint derivative clipping to 3 * delta when steep reversal occurs
        final pchipClip = PchipInterpolation(
          [0.0, 1.0, 2.0, 3.0],
          [0.0, 1.0, -9.0, -8.0],
        );
        check(pchipClip(0.5)).isGreaterThan(0.0);
        check(pchipClip.derivative(0.0)).isCloseTo(3.0, 1e-9);
        check(pchipClip.derivative(3.0)).isCloseTo(3.0, 1e-9);
      },
    );

    test('preserves nonzero derivatives for tiny-slope data (1e-200)', () {
      final pchip = PchipInterpolation(
        [0.0, 1.0, 2.0, 3.0],
        [0.0, 1e-200, 2e-200, 3e-200],
      );
      check(pchip(1.5)).isCloseTo(1.5e-200, 1e-209);
      check(pchip.derivative(1.5)).isCloseTo(1e-200, 1e-209);
    });

    test('constructor errors', () {
      final xs2 = [1.0, 2.0];
      final ys2 = [1.0, 2.0];
      final xs1 = [1.0];
      final ys1 = [1.0];
      final xsNonInc = [2.0, 1.0];

      check(() => PchipInterpolation(xs2, ys1)).throws<ArgumentError>();
      check(() => PchipInterpolation(xs1, ys1)).throws<ArgumentError>();
      check(() => PchipInterpolation(xsNonInc, ys2)).throws<ArgumentError>();
      check(() => PchipInterpolation([1.0, double.infinity], ys2))
          .throws<ArgumentError>();
    });
  });
}
