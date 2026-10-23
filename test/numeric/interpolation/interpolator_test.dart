import 'package:checks/checks.dart';
import 'package:data/src/numeric/interpolation/interpolator.dart';
import 'package:test/test.dart';

class _CustomInterpolator implements Interpolator {
  @override
  double call(num x) => x.toDouble() * 2.0;
}

class _CustomInterpolator2D implements Interpolator2D {
  @override
  double call(double x, double y) => x + y;
}

void main() {
  group('Interpolator interfaces', () {
    test('Interpolator 1D evaluation', () {
      final Interpolator interp = _CustomInterpolator();
      check(interp(3.5)).equals(7.0);
      check(interp(0)).equals(0.0);
    });

    test('Interpolator2D evaluation', () {
      final Interpolator2D interp = _CustomInterpolator2D();
      check(interp(2.0, 3.5)).equals(5.5);
    });
  });
}
