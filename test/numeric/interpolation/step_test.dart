import 'package:checks/checks.dart';
import 'package:data/numeric.dart';
import 'package:test/test.dart';

void main() {
  group('Step Interpolation', () {
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

      check(interp(double.nan)).isNaN();
      check(preferHigher(double.nan)).isNaN();
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
      check(interp(double.nan)).isNaN();
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
      check(interp(double.nan)).isNaN();
    });

    test('constructor errors', () {
      final xs2 = [1.0, 2.0];
      final ys2 = [1.0, 2.0];
      final ys1 = [1.0];
      final xsNonInc = [2.0, 1.0];

      // Nearest
      check(() => NearestInterpolation(xs2, ys1)).throws<ArgumentError>();
      check(() => NearestInterpolation(<double>[], <double>[]))
          .throws<ArgumentError>();
      check(() => NearestInterpolation(xsNonInc, ys2)).throws<ArgumentError>();
      check(() => NearestInterpolation([1.0, double.nan], ys2))
          .throws<ArgumentError>();

      // Previous
      check(() => PreviousInterpolation(xs2, ys1)).throws<ArgumentError>();
      check(() => PreviousInterpolation(<double>[], <double>[]))
          .throws<ArgumentError>();
      check(() => PreviousInterpolation(xsNonInc, ys2)).throws<ArgumentError>();
      check(() => PreviousInterpolation([1.0, double.nan], ys2))
          .throws<ArgumentError>();

      // Next
      check(() => NextInterpolation(xs2, ys1)).throws<ArgumentError>();
      check(() => NextInterpolation(<double>[], <double>[]))
          .throws<ArgumentError>();
      check(() => NextInterpolation(xsNonInc, ys2)).throws<ArgumentError>();
      check(() => NextInterpolation([1.0, double.nan], ys2))
          .throws<ArgumentError>();
    });
  });
}
