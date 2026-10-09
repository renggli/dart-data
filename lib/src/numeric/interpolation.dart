import 'dart:math' as math;

/// Boundary condition for cubic spline interpolation.
enum CubicSplineBoundary {
  /// Natural spline: second derivative at endpoints is zero ($S''(x_0) = S''(x_n) = 0$).
  natural,

  /// Clamped spline: first derivative at endpoints is fixed to specified values.
  clamped,
}

/// Base interface for 1D interpolators.
abstract class Interpolator {
  /// Evaluates the interpolated function at [x].
  double call(num x);
}

int _binarySearchInterval(List<double> xs, double x) {
  if (x <= xs.first) return 0;
  if (x >= xs.last) return xs.length - 2;
  var low = 0;
  var high = xs.length - 1;
  while (low <= high) {
    final mid = (low + high) >> 1;
    if (xs[mid] <= x) {
      if (mid + 1 < xs.length && x < xs[mid + 1]) {
        return mid;
      }
      low = mid + 1;
    } else {
      high = mid - 1;
    }
  }
  return math.max(0, math.min(xs.length - 2, low - 1));
}

/// 1D Piecewise linear interpolation.
class LinearInterpolation implements Interpolator {
  /// Constructs a linear interpolator from strictly increasing points [xs] and [ys].
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
    final idx = _binarySearchInterval(_xs, xd);
    final x0 = _xs[idx];
    final x1 = _xs[idx + 1];
    final y0 = _ys[idx];
    final y1 = _ys[idx + 1];
    final t = (xd - x0) / (x1 - x0);
    return y0 + t * (y1 - y0);
  }
}

/// Piecewise cubic spline interpolator with natural or clamped boundary conditions.
class CubicSpline implements Interpolator {
  /// Constructs a cubic spline interpolator.
  new(
    Iterable<num> xs,
    Iterable<num> ys, {
    this.boundary = CubicSplineBoundary.natural,
    double leftSlope = 0.0,
    double rightSlope = 0.0,
  }) : _xs = [for (final x in xs) x.toDouble()],
       _ys = [for (final y in ys) y.toDouble()] {
    final n = _xs.length;
    if (n != _ys.length) {
      throw ArgumentError('xs and ys must have identical length.');
    }
    if (n < 2) {
      throw ArgumentError('At least 2 points required for cubic spline.');
    }
    for (var i = 0; i < n - 1; i++) {
      if (_xs[i] >= _xs[i + 1]) {
        throw ArgumentError('xs must be strictly monotonically increasing.');
      }
    }

    _a = List<double>.of(_ys);
    _b = List<double>.filled(n - 1, 0.0);
    _c = List<double>.filled(n, 0.0);
    _d = List<double>.filled(n - 1, 0.0);

    final h = List<double>.generate(n - 1, (i) => _xs[i + 1] - _xs[i]);
    final delta = List<double>.generate(
      n - 1,
      (i) => (_ys[i + 1] - _ys[i]) / h[i],
    );

    // Tridiagonal matrix solver for c coefficients
    final alpha = List<double>.filled(n, 0.0);
    final l = List<double>.filled(n, 1.0);
    final mu = List<double>.filled(n, 0.0);
    final z = List<double>.filled(n, 0.0);

    if (boundary == CubicSplineBoundary.natural) {
      l[0] = 1.0;
      mu[0] = 0.0;
      z[0] = 0.0;
      for (var i = 1; i < n - 1; i++) {
        alpha[i] = 3.0 * (delta[i] - delta[i - 1]);
        l[i] = 2.0 * (_xs[i + 1] - _xs[i - 1]) - h[i - 1] * mu[i - 1];
        mu[i] = h[i] / l[i];
        z[i] = (alpha[i] - h[i - 1] * z[i - 1]) / l[i];
      }
      l[n - 1] = 1.0;
      z[n - 1] = 0.0;
      _c[n - 1] = 0.0;
    } else {
      // Clamped boundary
      alpha[0] = 3.0 * (delta[0] - leftSlope) / h[0];
      l[0] = 2.0;
      mu[0] = 0.5;
      z[0] = alpha[0] / l[0];
      for (var i = 1; i < n - 1; i++) {
        alpha[i] = 3.0 * (delta[i] - delta[i - 1]);
        l[i] = 2.0 * (_xs[i + 1] - _xs[i - 1]) - h[i - 1] * mu[i - 1];
        mu[i] = h[i] / l[i];
        z[i] = (alpha[i] - h[i - 1] * z[i - 1]) / l[i];
      }
      alpha[n - 1] = 3.0 * (rightSlope - delta[n - 2]) / h[n - 2];
      l[n - 1] = 2.0 - mu[n - 2];
      z[n - 1] = (alpha[n - 1] - z[n - 2]) / l[n - 1];
      _c[n - 1] = z[n - 1];
    }

    for (var j = n - 2; j >= 0; j--) {
      _c[j] = z[j] - mu[j] * _c[j + 1];
      _b[j] = delta[j] - h[j] * (2.0 * _c[j] + _c[j + 1]) / 3.0;
      _d[j] = (_c[j + 1] - _c[j]) / (3.0 * h[j]);
    }
  }

  final List<double> _xs;
  final List<double> _ys;
  late final List<double> _a;
  late final List<double> _b;
  late final List<double> _c;
  late final List<double> _d;

  /// The boundary condition used by this spline.
  final CubicSplineBoundary boundary;

  @override
  double call(num x) {
    final xd = x.toDouble();
    final idx = _binarySearchInterval(_xs, xd);
    final dx = xd - _xs[idx];
    return _a[idx] + _b[idx] * dx + _c[idx] * dx * dx + _d[idx] * dx * dx * dx;
  }

  /// Evaluates the first derivative of the spline at [x].
  double derivative(num x) {
    final xd = x.toDouble();
    final idx = _binarySearchInterval(_xs, xd);
    final dx = xd - _xs[idx];
    return _b[idx] + 2.0 * _c[idx] * dx + 3.0 * _d[idx] * dx * dx;
  }
}

/// Monotonic Piecewise Cubic Hermite Interpolating Polynomial (PCHIP).
///
/// Preserves shape and monotonicity of data without overshoot (Fritsch-Carlson algorithm).
class PchipInterpolation implements Interpolator {
  /// Constructs a monotonic PCHIP interpolator.
  new(Iterable<num> xs, Iterable<num> ys)
    : _xs = [for (final x in xs) x.toDouble()],
      _ys = [for (final y in ys) y.toDouble()] {
    final n = _xs.length;
    if (n != _ys.length) {
      throw ArgumentError('xs and ys must have identical length.');
    }
    if (n < 2) {
      throw ArgumentError(
        'At least 2 points required for PCHIP interpolation.',
      );
    }
    for (var i = 0; i < n - 1; i++) {
      if (_xs[i] >= _xs[i + 1]) {
        throw ArgumentError('xs must be strictly monotonically increasing.');
      }
    }

    _h = List<double>.generate(n - 1, (i) => _xs[i + 1] - _xs[i]);
    _delta = List<double>.generate(n - 1, (i) => (_ys[i + 1] - _ys[i]) / _h[i]);
    _d = List<double>.filled(n, 0.0);

    if (n == 2) {
      _d[0] = _delta[0];
      _d[1] = _delta[0];
      return;
    }

    // Interior derivatives via weighted harmonic mean
    for (var i = 1; i < n - 1; i++) {
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

    final last = n - 1;
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
    final idx = _binarySearchInterval(_xs, xd);
    final x0 = _xs[idx];
    final y0 = _ys[idx];
    final y1 = _ys[idx + 1];
    final h = _h[idx];
    final d0 = _d[idx];
    final d1 = _d[idx + 1];

    final t = (xd - x0) / h;
    final t2 = t * t;
    final t3 = t2 * t;

    // Hermite basis
    final h00 = 2.0 * t3 - 3.0 * t2 + 1.0;
    final h10 = t3 - 2.0 * t2 + t;
    final h01 = -2.0 * t3 + 3.0 * t2;
    final h11 = t3 - t2;

    return h00 * y0 + h10 * h * d0 + h01 * y1 + h11 * h * d1;
  }
}
