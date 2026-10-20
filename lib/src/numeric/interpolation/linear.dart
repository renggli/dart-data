import 'interpolator.dart';
import 'search.dart';

/// 1D Piecewise linear interpolation.
///
/// Conceptually, this connects data points on a Cartesian grid with straight
/// line segments, allowing intermediate values between known measurements to be
/// estimated. Formally, it computes the continuous $C^0$ piecewise linear
/// interpolant $S(x) = y_i + \frac{x - x_i}{x_{i+1} - x_i}(y_{i+1} - y_i)$ on
/// $\[x_i, x_{i+1}\]$.
///
/// ```dart
/// final interp = LinearInterpolation([0.0, 1.0, 2.0], [0.0, 10.0, 20.0]);
/// print(interp(0.5)); // 5.0
/// ```
class LinearInterpolation implements Interpolator {
  /// Constructs a linear interpolator from strictly increasing points [xs] and
  /// [ys].
  new(Iterable<num> xs, Iterable<num> ys)
    : _xs = [for (final x in xs) x.toDouble()],
      _ys = [for (final y in ys) y.toDouble()] {
    if (_xs.length != _ys.length) {
      throw ArgumentError('xs and ys must have identical length.');
    }
    if (_xs.length < 2) {
      throw ArgumentError('At least 2 points required for interpolation.');
    }
    for (var i = 0; i < _xs.length - 1; i++) {
      if (_xs[i] >= _xs[i + 1]) {
        throw ArgumentError('xs must be strictly monotonically increasing.');
      }
    }
  }

  final List<double> _xs;
  final List<double> _ys;

  @override
  double call(num x) {
    final xd = x.toDouble();
    final idx = binarySearchInterval(_xs, xd);
    final x0 = _xs[idx];
    final x1 = _xs[idx + 1];
    final y0 = _ys[idx];
    final y1 = _ys[idx + 1];
    final tFrac = (xd - x0) / (x1 - x0);
    return y0 + tFrac * (y1 - y0);
  }
}
