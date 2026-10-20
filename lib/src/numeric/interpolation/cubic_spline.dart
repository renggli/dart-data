import 'dart:typed_data';

import '../../../linear.dart';
import '../../../type.dart';
import 'interpolator.dart';
import 'search.dart';

/// Boundary condition for cubic spline interpolation.
enum CubicSplineBoundary {
  /// Natural spline: second derivative at endpoints is zero
  /// ($S''(x_0) = S''(x_n) = 0$).
  natural,

  /// Clamped spline: first derivative at endpoints is fixed to specified
  /// values.
  clamped,
}

/// Piecewise cubic spline interpolator with natural or clamped boundary
/// conditions.
///
/// Conceptually, rather than connecting data points with straight lines or
/// sharp angles, a cubic spline fits a smooth curve through every point with
/// continuous curvature. Formally, it constructs a $C^2$ twice continuously
/// differentiable piecewise cubic polynomial satisfying continuity of $S(x)$,
/// $S'(x)$, and $S''(x)$ across all knots via a tridiagonal linear system.
///
/// ```dart
/// final spline = CubicSpline([0.0, 1.0, 2.0], [0.0, 1.0, 8.0]);
/// print(spline(1.5));
/// ```
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
    _d = List<double>.filled(count - 1, 0.0);

    final stepSizes = List<double>.generate(
      count - 1,
      (i) => _xs[i + 1] - _xs[i],
    );
    final delta = List<double>.generate(
      count - 1,
      (i) => (_ys[i + 1] - _ys[i]) / stepSizes[i],
    );

    // Formulate tridiagonal linear system for c coefficients: A * c = rhs
    final sub = Float64List(count - 1);
    final diag = Float64List(count);
    final sup = Float64List(count - 1);
    final rhs = Float64List(count);

    if (boundary == CubicSplineBoundary.natural) {
      diag[0] = 1.0;
      sup[0] = 0.0;
      rhs[0] = 0.0;
      for (var i = 1; i < count - 1; i++) {
        sub[i - 1] = stepSizes[i - 1];
        diag[i] = 2.0 * (_xs[i + 1] - _xs[i - 1]);
        sup[i] = stepSizes[i];
        rhs[i] = 3.0 * (delta[i] - delta[i - 1]);
      }
      sub[count - 2] = 0.0;
      diag[count - 1] = 1.0;
      rhs[count - 1] = 0.0;
    } else {
      // Clamped boundary
      diag[0] = 2.0;
      sup[0] = 1.0;
      rhs[0] = 3.0 * (delta[0] - leftSlope) / stepSizes[0];
      for (var i = 1; i < count - 1; i++) {
        sub[i - 1] = stepSizes[i - 1];
        diag[i] = 2.0 * (_xs[i + 1] - _xs[i - 1]);
        sup[i] = stepSizes[i];
        rhs[i] = 3.0 * (delta[i] - delta[i - 1]);
      }
      sub[count - 2] = 1.0;
      diag[count - 1] = 2.0;
      rhs[count - 1] =
          3.0 * (rightSlope - delta[count - 2]) / stepSizes[count - 2];
    }

    final cVec = solveTridiagonal(
      Vector<double>.fromList(sub, type: DataType.float64),
      Vector<double>.fromList(diag, type: DataType.float64),
      Vector<double>.fromList(sup, type: DataType.float64),
      Vector<double>.fromList(rhs, type: DataType.float64),
    );
    _c = cVec.toList();

    for (var j = count - 2; j >= 0; j--) {
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
    final idx = binarySearchInterval(_xs, xd);
    final dx = xd - _xs[idx];
    return _a[idx] + _b[idx] * dx + _c[idx] * dx * dx + _d[idx] * dx * dx * dx;
  }

  /// Evaluates the first derivative of the spline at [x].
  double derivative(num x) {
    final xd = x.toDouble();
    final idx = binarySearchInterval(_xs, xd);
    final dx = xd - _xs[idx];
    return _b[idx] + 2.0 * _c[idx] * dx + 3.0 * _d[idx] * dx * dx;
  }
}
