import 'package:checks/checks.dart';
import 'package:data/numeric.dart';
import 'package:test/test.dart';

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
      // At x = 0.5: 2*(0.25) - 1.5 + 1 = 0.5 - 1.5 + 1 = 0.0
      check(interp(0.5)).isCloseTo(0.0, 1e-9);
      // At x = 1.5: 2*(2.25) - 4.5 + 1 = 4.5 - 4.5 + 1 = 1.0
      check(interp(1.5)).isCloseTo(1.0, 1e-9);
      // At x = 3.0: 2*(9) - 9 + 1 = 10.0
      check(interp(3.0)).isCloseTo(10.0, 1e-9);
    });

    test('constructor errors', () {
      final xs2 = [1.0, 2.0];
      final ys1 = [1.0];

      check(() => LagrangeInterpolation(xs2, ys1)).throws<ArgumentError>();
      check(() => LagrangeInterpolation(<double>[], <double>[]))
          .throws<ArgumentError>();
    });
  });
}
