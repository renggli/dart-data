import 'package:checks/checks.dart';
import 'package:data/numeric.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('LinearInterpolation', () {
    test('linear interpolation and NaN evaluation', () {
      final xs = [0.0, 1.0, 2.0, 3.0];
      final ys = [0.0, 10.0, 20.0, 30.0];

      final interp = LinearInterpolation(xs, ys);
      check(interp(0.5)).isCloseTo(5.0, 1e-9);
      check(interp(1.5)).isCloseTo(15.0, 1e-9);
      check(interp(2.0)).isCloseTo(20.0, 1e-9);
      check(interp(double.nan)).isNaN;
    });

    test('constructor errors', () {
      check(() => LinearInterpolation([1.0, 2.0], [1.0]))
          .throws<ArgumentError>();
      check(() => LinearInterpolation([1.0], [1.0])).throws<ArgumentError>();
      check(() => LinearInterpolation([2.0, 1.0], [1.0, 2.0]))
          .throws<ArgumentError>();
      check(
        () => LinearInterpolation([double.negativeInfinity, 1.0], [1.0, 2.0]),
      ).throws<ArgumentError>();
      check(() => LinearInterpolation([0.0, double.infinity], [1.0, 2.0]))
          .throws<ArgumentError>();
    });
  });
}
