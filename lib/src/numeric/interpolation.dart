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
    final tFrac = (xd - x0) / (x1 - x0);
    return y0 + tFrac * (y1 - y0);
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
    final count = _xs.length;
    if (count != _ys.length) {
      throw ArgumentError('xs and ys must have identical length.');
    }
    if (count < 2) {
      throw ArgumentError('At least 2 points required for cubic spline.');
    }
    for (var i = 0; i < count - 1; i++) {
      if (_xs[i] >= _xs[i + 1]) {
        throw ArgumentError('xs must be strictly monotonically increasing.');
      }
    }

    _a = List<double>.of(_ys);
    _b = List<double>.filled(count - 1, 0.0);
    _c = List<double>.filled(count, 0.0);
    _d = List<double>.filled(count - 1, 0.0);

    final stepSizes = List<double>.generate(
      count - 1,
      (i) => _xs[i + 1] - _xs[i],
    );
    final delta = List<double>.generate(
      count - 1,
      (i) => (_ys[i + 1] - _ys[i]) / stepSizes[i],
    );

    // Tridiagonal matrix solver for c coefficients
    final alpha = List<double>.filled(count, 0.0);
    final diag = List<double>.filled(count, 1.0);
    final mu = List<double>.filled(count, 0.0);
    final z = List<double>.filled(count, 0.0);

    if (boundary == CubicSplineBoundary.natural) {
      diag[0] = 1.0;
      mu[0] = 0.0;
      z[0] = 0.0;
      for (var i = 1; i < count - 1; i++) {
        alpha[i] = 3.0 * (delta[i] - delta[i - 1]);
        diag[i] =
            2.0 * (_xs[i + 1] - _xs[i - 1]) - stepSizes[i - 1] * mu[i - 1];
        mu[i] = stepSizes[i] / diag[i];
        z[i] = (alpha[i] - stepSizes[i - 1] * z[i - 1]) / diag[i];
      }
      diag[count - 1] = 1.0;
      z[count - 1] = 0.0;
      _c[count - 1] = 0.0;
    } else {
      // Clamped boundary
      alpha[0] = 3.0 * (delta[0] - leftSlope) / stepSizes[0];
      diag[0] = 2.0;
      mu[0] = 0.5;
      z[0] = alpha[0] / diag[0];
      for (var i = 1; i < count - 1; i++) {
        alpha[i] = 3.0 * (delta[i] - delta[i - 1]);
        diag[i] =
            2.0 * (_xs[i + 1] - _xs[i - 1]) - stepSizes[i - 1] * mu[i - 1];
        mu[i] = stepSizes[i] / diag[i];
        z[i] = (alpha[i] - stepSizes[i - 1] * z[i - 1]) / diag[i];
      }
      alpha[count - 1] =
          3.0 * (rightSlope - delta[count - 2]) / stepSizes[count - 2];
      diag[count - 1] = 2.0 - mu[count - 2];
      z[count - 1] = (alpha[count - 1] - z[count - 2]) / diag[count - 1];
      _c[count - 1] = z[count - 1];
    }

    for (var j = count - 2; j >= 0; j--) {
      _c[j] = z[j] - mu[j] * _c[j + 1];
      _b[j] = delta[j] - stepSizes[j] * (2.0 * _c[j] + _c[j + 1]) / 3.0;
      _d[j] = (_c[j + 1] - _c[j]) / (3.0 * stepSizes[j]);
    }
  }

  /// The boundary condition used by this spline.
  final CubicSplineBoundary boundary;
  final List<double> _xs;
  final List<double> _ys;
  late final List<double> _a;
  late final List<double> _b;
  late final List<double> _c;
  late final List<double> _d;

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
    final idx = _binarySearchInterval(_xs, xd);
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

/// 1D Nearest neighbor interpolation.
class NearestInterpolation implements Interpolator {
  /// Constructs a nearest-neighbor interpolator from strictly increasing points [xs] and [ys].
  new(Iterable<num> xs, Iterable<num> ys, {this.preferLower = true})
    : _xs = [for (final x in xs) x.toDouble()],
      _ys = [for (final y in ys) y.toDouble()] {
    if (_xs.length != _ys.length) {
      throw ArgumentError('xs and ys must have identical length.');
    }
    if (_xs.isEmpty) {
      throw ArgumentError('At least 1 point required for interpolation.');
    }
    for (var i = 0; i < _xs.length - 1; i++) {
      if (_xs[i] >= _xs[i + 1]) {
        throw ArgumentError('xs must be strictly monotonically increasing.');
      }
    }
  }

  /// When an evaluation point is equidistant between two points, whether to prefer the lower point.
  final bool preferLower;
  final List<double> _xs;
  final List<double> _ys;

  @override
  double call(num x) {
    final xd = x.toDouble();
    if (xd <= _xs.first) return _ys.first;
    if (xd >= _xs.last) return _ys.last;
    final idx = _binarySearchInterval(_xs, xd);
    final dLo = xd - _xs[idx];
    final dHi = _xs[idx + 1] - xd;
    if (dLo < dHi || (dLo == dHi && preferLower)) {
      return _ys[idx];
    } else {
      return _ys[idx + 1];
    }
  }
}

/// 1D Step-wise previous value interpolation.
class PreviousInterpolation implements Interpolator {
  /// Constructs a step-wise previous interpolator from strictly increasing points [xs] and [ys].
  new(Iterable<num> xs, Iterable<num> ys, {this.left = double.nan})
    : _xs = [for (final x in xs) x.toDouble()],
      _ys = [for (final y in ys) y.toDouble()] {
    if (_xs.length != _ys.length) {
      throw ArgumentError('xs and ys must have identical length.');
    }
    if (_xs.isEmpty) {
      throw ArgumentError('At least 1 point required for interpolation.');
    }
    for (var i = 0; i < _xs.length - 1; i++) {
      if (_xs[i] >= _xs[i + 1]) {
        throw ArgumentError('xs must be strictly monotonically increasing.');
      }
    }
  }

  /// Value to return for coordinates strictly less than the first point.
  final double left;
  final List<double> _xs;
  final List<double> _ys;

  @override
  double call(num x) {
    final xd = x.toDouble();
    if (xd < _xs.first) return left;
    if (xd >= _xs.last) return _ys.last;
    final idx = _binarySearchInterval(_xs, xd);
    return _ys[idx];
  }
}

/// 1D Step-wise next value interpolation.
class NextInterpolation implements Interpolator {
  /// Constructs a step-wise next interpolator from strictly increasing points [xs] and [ys].
  new(Iterable<num> xs, Iterable<num> ys, {this.right = double.nan})
    : _xs = [for (final x in xs) x.toDouble()],
      _ys = [for (final y in ys) y.toDouble()] {
    if (_xs.length != _ys.length) {
      throw ArgumentError('xs and ys must have identical length.');
    }
    if (_xs.isEmpty) {
      throw ArgumentError('At least 1 point required for interpolation.');
    }
    for (var i = 0; i < _xs.length - 1; i++) {
      if (_xs[i] >= _xs[i + 1]) {
        throw ArgumentError('xs must be strictly monotonically increasing.');
      }
    }
  }

  /// Value to return for coordinates strictly greater than the last point.
  final double right;
  final List<double> _xs;
  final List<double> _ys;

  @override
  double call(num x) {
    final xd = x.toDouble();
    if (xd <= _xs.first) return _ys.first;
    if (xd > _xs.last) return right;
    final idx = _binarySearchInterval(_xs, xd);
    return xd == _xs[idx] ? _ys[idx] : _ys[idx + 1];
  }
}

/// Polynomial interpolation through sample points using Lagrange barycentric formula.
class LagrangeInterpolation implements Interpolator {
  /// Constructs a Lagrange polynomial interpolator through sample points [xs] and [ys].
  new(Iterable<num> xs, Iterable<num> ys)
    : _xs = [for (final x in xs) x.toDouble()],
      _ys = [for (final y in ys) y.toDouble()] {
    if (_xs.length != _ys.length) {
      throw ArgumentError('xs and ys must have identical length.');
    }
    if (_xs.isEmpty) {
      throw ArgumentError('At least 1 point required for interpolation.');
    }
    _weights = List<double>.filled(_xs.length, 1.0);
    for (var i = 0; i < _xs.length; i++) {
      var prod = 1.0;
      for (var j = 0; j < _xs.length; j++) {
        if (i != j) {
          prod *= _xs[i] - _xs[j];
        }
      }
      _weights[i] = 1.0 / prod;
    }
  }

  final List<double> _xs;
  final List<double> _ys;
  late final List<double> _weights;

  @override
  double call(num x) {
    final xd = x.toDouble();
    for (var i = 0; i < _xs.length; i++) {
      if (xd == _xs[i]) return _ys[i];
    }
    var numerator = 0.0;
    var denominator = 0.0;
    for (var i = 0; i < _xs.length; i++) {
      final term = _weights[i] / (xd - _xs[i]);
      numerator += term * _ys[i];
      denominator += term;
    }
    return numerator / denominator;
  }
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
