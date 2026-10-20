import 'interpolator.dart';
import 'search.dart';

/// Monotonic Piecewise Cubic Hermite Interpolating Polynomial (PCHIP).
///
/// Preserves shape and monotonicity of data without overshoot (Fritsch-Carlson
/// algorithm).
class PchipInterpolation implements Interpolator {
  /// Constructs a monotonic PCHIP interpolator.
  new(Iterable<num> xs, Iterable<num> ys)
    : _xs = [for (final x in xs) x.toDouble()],
      _ys = [for (final y in ys) y.toDouble()] {
    final count = _xs.length;
    if (count != _ys.length) {
      throw ArgumentError('xs and ys must have identical length.');
    }
    if (count < 2) {
      throw ArgumentError(
        'At least 2 points required for PCHIP interpolation.',
      );
    }
    for (var i = 0; i < count - 1; i++) {
      if (_xs[i] >= _xs[i + 1]) {
        throw ArgumentError('xs must be strictly monotonically increasing.');
      }
    }

    _h = List<double>.generate(count - 1, (i) => _xs[i + 1] - _xs[i]);
    _delta = List<double>.generate(
      count - 1,
      (i) => (_ys[i + 1] - _ys[i]) / _h[i],
    );
    _d = List<double>.filled(count, 0.0);

    if (count == 2) {
      _d[0] = _delta[0];
      _d[1] = _delta[0];
      return;
    }

    // Interior derivatives via weighted harmonic mean
    for (var i = 1; i < count - 1; i++) {
      final d0 = _delta[i - 1];
      final d1 = _delta[i];
      if (d0 * d1 <= 0.0) {
        _d[i] = 0.0;
      } else {
        final w1 = 2.0 * _h[i] + _h[i - 1];
        final w2 = _h[i] + 2.0 * _h[i - 1];
        _d[i] = (w1 + w2) / (w1 / d0 + w2 / d1);
      }
    }

    // Endpoints
    _d[0] =
        ((2.0 * _h[0] + _h[1]) * _delta[0] - _h[0] * _delta[1]) /
        (_h[0] + _h[1]);
    if (_d[0] * _delta[0] <= 0.0) {
      _d[0] = 0.0;
    } else if (_delta[0] * _delta[1] <= 0.0 &&
        _d[0].abs() > 3.0 * _delta[0].abs()) {
      _d[0] = 3.0 * _delta[0];
    }

    final last = count - 1;
    _d[last] =
        ((2.0 * _h[last - 1] + _h[last - 2]) * _delta[last - 1] -
            _h[last - 1] * _delta[last - 2]) /
        (_h[last - 1] + _h[last - 2]);
    if (_d[last] * _delta[last - 1] <= 0.0) {
      _d[last] = 0.0;
    } else if (_delta[last - 1] * _delta[last - 2] <= 0.0 &&
        _d[last].abs() > 3.0 * _delta[last - 1].abs()) {
      _d[last] = 3.0 * _delta[last - 1];
    }
  }

  final List<double> _xs;
  final List<double> _ys;
  late final List<double> _h;
  late final List<double> _delta;
  late final List<double> _d;

  @override
  double call(num x) {
    final xd = x.toDouble();
    final idx = binarySearchInterval(_xs, xd);
    final x0 = _xs[idx];
    final y0 = _ys[idx];
    final y1 = _ys[idx + 1];
    final step = _h[idx];
    final d0 = _d[idx];
    final d1 = _d[idx + 1];

    final tVal = (xd - x0) / step;
    final t2 = tVal * tVal;
    final t3 = t2 * tVal;

    // Hermite basis
    final h00 = 2.0 * t3 - 3.0 * t2 + 1.0;
    final h10 = t3 - 2.0 * t2 + tVal;
    final h01 = -2.0 * t3 + 3.0 * t2;
    final h11 = t3 - t2;

    return h00 * y0 + h10 * step * d0 + h01 * y1 + h11 * step * d1;
  }
}
