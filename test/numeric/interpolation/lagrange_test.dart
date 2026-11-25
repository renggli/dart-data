import 'package:checks/checks.dart';
import 'package:data/numeric.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('LagrangeInterpolation', () {
    test('lagrange polynomial interpolation', () {
      // y = 2*x^2 - 3*x + 1
      final xs = [-1.0, 0.0, 1.0, 2.0];
      final ys = [6.0, 1.0, 0.0, 3.0];

      final interp = LagrangeInterpolation(xs, ys);
      for (var i = 0; i < xs.length; i++) {
        check(interp(xs[i])).isCloseTo(ys[i], 1e-9);
      }
      // Test at intermediate points
      // At x = 0.5: 2*(0.25) - 1.5 + 1 = 0.0
      check(interp(0.5)).isCloseTo(0.0, 1e-9);
      // At x = 1.5: 2*(2.25) - 4.5 + 1 = 1.0
      check(interp(1.5)).isCloseTo(1.0, 1e-9);
      // At x = 3.0: 2*(9) - 9 + 1 = 10.0
      check(interp(3.0)).isCloseTo(10.0, 1e-9);
      check(interp(double.nan)).isNaN;
    });

    test(
      'handles single point and extreme knot scales without overflow/underflow',
      () {
        final single = LagrangeInterpolation([5.0], [42.0]);
        check(single(10.0)).equals(42.0);
        check(single(double.nan)).isNaN;

        // Wide scale (1e100) where unscaled pairwise product overflows
        final wide = LagrangeInterpolation(
          [0.0, 1e100, 2e100, 3e100, 4e100],
          [0.0, 1.0, 2.0, 3.0, 4.0],
        );
        check(wide(1.5e100)).isCloseTo(1.5, 1e-9);

        // Narrow scale (1e-100) where unscaled pairwise product underflows
        final narrow = LagrangeInterpolation(
          [0.0, 1e-100, 2e-100, 3e-100, 4e-100],
          [0.0, 1.0, 2.0, 3.0, 4.0],
        );
        check(narrow(2.5e-100)).isCloseTo(2.5, 1e-9);
      },
    );

    test('constructor errors', () {
      final xs2 = [1.0, 2.0];
      final ys1 = [1.0];

      check(() => LagrangeInterpolation(xs2, ys1)).throws<ArgumentError>();
      check(() => LagrangeInterpolation(<double>[], <double>[]))
          .throws<ArgumentError>();
      check(() => LagrangeInterpolation([1.0, 1.0], [2.0, 3.0]))
          .throws<ArgumentError>();
      check(() => LagrangeInterpolation([1.0, 2.0, 1.0], [2.0, 3.0, 4.0]))
          .throws<ArgumentError>();
      check(() => LagrangeInterpolation([1.0, double.nan], [2.0, 3.0]))
          .throws<ArgumentError>();
      check(() => LagrangeInterpolation([1.0, double.infinity], [2.0, 3.0]))
          .throws<ArgumentError>();
    });
  });
}
