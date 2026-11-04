import 'dart:typed_data';

import '../../linear/matrix.dart';
import '../../linear/vector.dart';
import '../../type/data_type.dart';
import 'interpolator.dart';
import 'search.dart';

/// 2D Bicubic surface interpolation over a rectilinear grid with $C^1$
/// continuity.
class BicubicInterpolation implements Interpolator2D {
  /// Constructs a bicubic interpolator.
  ///
  /// Points in [xs] and [ys] must be strictly monotonically increasing with
  /// length $\ge 2$. [values] must have shape `[xs.length, ys.length]`.
  new(Iterable<num> xs, Iterable<num> ys, Matrix<num> values)
    : _xs = [for (final x in xs) x.toDouble()],
      _ys = [for (final y in ys) y.toDouble()] {
    final nx = _xs.length;
    final ny = _ys.length;
    _ny = ny;
    if (nx < 2) {
      throw ArgumentError('xs must contain at least 2 points.');
    }
    if (ny < 2) {
      throw ArgumentError('ys must contain at least 2 points.');
    }
    for (var i = 0; i < nx - 1; i++) {
      if (!(_xs[i] < _xs[i + 1])) {
        throw ArgumentError('xs must be strictly monotonically increasing.');
      }
    }
    for (var j = 0; j < ny - 1; j++) {
      if (!(_ys[j] < _ys[j + 1])) {
        throw ArgumentError('ys must be strictly monotonically increasing.');
      }
    }
    if (values.rowCount != nx || values.colCount != ny) {
      throw ArgumentError(
        'Values matrix shape (${values.rowCount}x${values.colCount}) must '
        'match grid dimensions ($nx x $ny).',
      );
    }

    final valMat = Matrix<double>.generate(
      nx,
      ny,
      (int r, int c) => values.getUnchecked(r, c).toDouble(),
      type: DataType.float64,
    );

    // Precompute partial derivatives at grid nodes: fx, fy, fxy
    final fx = Matrix<double>.filled(nx, ny, 0.0, type: DataType.float64);
    final fy = Matrix<double>.filled(nx, ny, 0.0, type: DataType.float64);
    final fxy = Matrix<double>.filled(nx, ny, 0.0, type: DataType.float64);

    for (var i = 0; i < nx; i++) {
      for (var j = 0; j < ny; j++) {
        // df/dx
        if (i == 0) {
          fx.setUnchecked(
            i,
            j,
            (valMat.getUnchecked(1, j) - valMat.getUnchecked(0, j)) /
                (_xs[1] - _xs[0]),
          );
        } else if (i == nx - 1) {
          fx.setUnchecked(
            i,
            j,
            (valMat.getUnchecked(nx - 1, j) - valMat.getUnchecked(nx - 2, j)) /
                (_xs[nx - 1] - _xs[nx - 2]),
          );
        } else {
          fx.setUnchecked(
            i,
            j,
            (valMat.getUnchecked(i + 1, j) - valMat.getUnchecked(i - 1, j)) /
                (_xs[i + 1] - _xs[i - 1]),
          );
        }

        // df/dy
        if (j == 0) {
          fy.setUnchecked(
            i,
            j,
            (valMat.getUnchecked(i, 1) - valMat.getUnchecked(i, 0)) /
                (_ys[1] - _ys[0]),
          );
        } else if (j == ny - 1) {
          fy.setUnchecked(
            i,
            j,
            (valMat.getUnchecked(i, ny - 1) - valMat.getUnchecked(i, ny - 2)) /
                (_ys[ny - 1] - _ys[ny - 2]),
          );
        } else {
          fy.setUnchecked(
            i,
            j,
            (valMat.getUnchecked(i, j + 1) - valMat.getUnchecked(i, j - 1)) /
                (_ys[j + 1] - _ys[j - 1]),
          );
        }
      }
    }

    // d2f/dxdy
    for (var i = 0; i < nx; i++) {
      for (var j = 0; j < ny; j++) {
        if (j == 0) {
          fxy.setUnchecked(
            i,
            j,
            (fx.getUnchecked(i, 1) - fx.getUnchecked(i, 0)) / (_ys[1] - _ys[0]),
          );
        } else if (j == ny - 1) {
          fxy.setUnchecked(
            i,
            j,
            (fx.getUnchecked(i, ny - 1) - fx.getUnchecked(i, ny - 2)) /
                (_ys[ny - 1] - _ys[ny - 2]),
          );
        } else {
          fxy.setUnchecked(
            i,
            j,
            (fx.getUnchecked(i, j + 1) - fx.getUnchecked(i, j - 1)) /
                (_ys[j + 1] - _ys[j - 1]),
          );
        }
      }
    }

    // Precompute bicubic polynomial coefficients for all patches
    _coefficients = Float64List((nx - 1) * (ny - 1) * 16);
    for (var i = 0; i < nx - 1; i++) {
      final dx = _xs[i + 1] - _xs[i];
      for (var j = 0; j < ny - 1; j++) {
        final dy = _ys[j + 1] - _ys[j];

        final f00 = valMat.getUnchecked(i, j);
        final f10 = valMat.getUnchecked(i + 1, j);
        final f01 = valMat.getUnchecked(i, j + 1);
        final f11 = valMat.getUnchecked(i + 1, j + 1);

        final fx00 = fx.getUnchecked(i, j) * dx;
        final fx10 = fx.getUnchecked(i + 1, j) * dx;
        final fx01 = fx.getUnchecked(i, j + 1) * dx;
        final fx11 = fx.getUnchecked(i + 1, j + 1) * dx;

        final fy00 = fy.getUnchecked(i, j) * dy;
        final fy10 = fy.getUnchecked(i + 1, j) * dy;
        final fy01 = fy.getUnchecked(i, j + 1) * dy;
        final fy11 = fy.getUnchecked(i + 1, j + 1) * dy;

        final fxy00 = fxy.getUnchecked(i, j) * dx * dy;
        final fxy10 = fxy.getUnchecked(i + 1, j) * dx * dy;
        final fxy01 = fxy.getUnchecked(i, j + 1) * dx * dy;
        final fxy11 = fxy.getUnchecked(i + 1, j + 1) * dx * dy;

        // T = H * F
        // Columns k: 0: f..0, 1: f..1, 2: fy..0, 3: fy..1
        // Row 0 of T = F[0]
        final t00 = f00, t01 = f01, t02 = fy00, t03 = fy01;
        // Row 1 of T = F[2]
        final t10 = fx00, t11 = fx01, t12 = fxy00, t13 = fxy01;
        // Row 2 of T = -3*F[0] + 3*F[1] - 2*F[2] - F[3]
        final t20 = -3.0 * f00 + 3.0 * f10 - 2.0 * fx00 - fx10;
        final t21 = -3.0 * f01 + 3.0 * f11 - 2.0 * fx01 - fx11;
        final t22 = -3.0 * fy00 + 3.0 * fy10 - 2.0 * fxy00 - fxy10;
        final t23 = -3.0 * fy01 + 3.0 * fy11 - 2.0 * fxy01 - fxy11;
        // Row 3 of T = 2*F[0] - 2*F[1] + F[2] + F[3]
        final t30 = 2.0 * f00 - 2.0 * f10 + fx00 + fx10;
        final t31 = 2.0 * f01 - 2.0 * f11 + fx01 + fx11;
        final t32 = 2.0 * fy00 - 2.0 * fy10 + fxy00 + fxy10;
        final t33 = 2.0 * fy01 - 2.0 * fy11 + fxy01 + fxy11;

        // A = T * H^T
        // For each row r:
        // A[r][0] = T[r][0]
        // A[r][1] = T[r][2]
        // A[r][2] = -3*T[r][0] + 3*T[r][1] - 2*T[r][2] - T[r][3]
        // A[r][3] = 2*T[r][0] - 2*T[r][1] + T[r][2] + T[r][3]
        final offset = (i * (ny - 1) + j) * 16;
        _coefficients[offset + 0] = t00;
        _coefficients[offset + 1] = t02;
        _coefficients[offset + 2] = -3.0 * t00 + 3.0 * t01 - 2.0 * t02 - t03;
        _coefficients[offset + 3] = 2.0 * t00 - 2.0 * t01 + t02 + t03;

        _coefficients[offset + 4] = t10;
        _coefficients[offset + 5] = t12;
        _coefficients[offset + 6] = -3.0 * t10 + 3.0 * t11 - 2.0 * t12 - t13;
        _coefficients[offset + 7] = 2.0 * t10 - 2.0 * t11 + t12 + t13;

        _coefficients[offset + 8] = t20;
        _coefficients[offset + 9] = t22;
        _coefficients[offset + 10] = -3.0 * t20 + 3.0 * t21 - 2.0 * t22 - t23;
        _coefficients[offset + 11] = 2.0 * t20 - 2.0 * t21 + t22 + t23;

        _coefficients[offset + 12] = t30;
        _coefficients[offset + 13] = t32;
        _coefficients[offset + 14] = -3.0 * t30 + 3.0 * t31 - 2.0 * t32 - t33;
        _coefficients[offset + 15] = 2.0 * t30 - 2.0 * t31 + t32 + t33;
      }
    }
  }

  final List<double> _xs;
  final List<double> _ys;
  late final int _ny;
  late final Float64List _coefficients;

  @override
  double call(double x, double y) {
    final xClamped = x.clamp(_xs.first, _xs.last);
    final yClamped = y.clamp(_ys.first, _ys.last);

    final i = binarySearchInterval(_xs, xClamped);
    final j = binarySearchInterval(_ys, yClamped);

    final dx = _xs[i + 1] - _xs[i];
    final dy = _ys[j + 1] - _ys[j];

    final u = (xClamped - _xs[i]) / dx;
    final v = (yClamped - _ys[j]) / dy;

    final offset = (i * (_ny - 1) + j) * 16;
    final row0 =
        ((_coefficients[offset + 3] * v + _coefficients[offset + 2]) * v +
                _coefficients[offset + 1]) *
            v +
        _coefficients[offset + 0];
    final row1 =
        ((_coefficients[offset + 7] * v + _coefficients[offset + 6]) * v +
                _coefficients[offset + 5]) *
            v +
        _coefficients[offset + 4];
    final row2 =
        ((_coefficients[offset + 11] * v + _coefficients[offset + 10]) * v +
                _coefficients[offset + 9]) *
            v +
        _coefficients[offset + 8];
    final row3 =
        ((_coefficients[offset + 15] * v + _coefficients[offset + 14]) * v +
                _coefficients[offset + 13]) *
            v +
        _coefficients[offset + 12];

    return ((row3 * u + row2) * u + row1) * u + row0;
  }

  /// Computes the gradient
  /// $(\frac{\partial f}{\partial x}, \frac{\partial f}{\partial y})$ at ([x],
  /// [y]).
  Vector<double> gradient(double x, double y) {
    final xClamped = x.clamp(_xs.first, _xs.last);
    final yClamped = y.clamp(_ys.first, _ys.last);

    final i = binarySearchInterval(_xs, xClamped);
    final j = binarySearchInterval(_ys, yClamped);

    final dx = _xs[i + 1] - _xs[i];
    final dy = _ys[j + 1] - _ys[j];

    final u = (xClamped - _xs[i]) / dx;
    final v = (yClamped - _ys[j]) / dy;

    final offset = (i * (_ny - 1) + j) * 16;

    // Polynomial rows in v for df/du
    final row1 =
        ((_coefficients[offset + 7] * v + _coefficients[offset + 6]) * v +
                _coefficients[offset + 5]) *
            v +
        _coefficients[offset + 4];
    final row2 =
        ((_coefficients[offset + 11] * v + _coefficients[offset + 10]) * v +
                _coefficients[offset + 9]) *
            v +
        _coefficients[offset + 8];
    final row3 =
        ((_coefficients[offset + 15] * v + _coefficients[offset + 14]) * v +
                _coefficients[offset + 13]) *
            v +
        _coefficients[offset + 12];

    // df/du = 3*row3*u^2 + 2*row2*u + row1
    final dfDu = (3.0 * row3 * u + 2.0 * row2) * u + row1;

    // Derivative of each row with respect to v: d/dv(a3*v^3 + a2*v^2 + a1*v + a0) = 3*a3*v^2 + 2*a2*v + a1
    final drow0 =
        (3.0 * _coefficients[offset + 3] * v +
                2.0 * _coefficients[offset + 2]) *
            v +
        _coefficients[offset + 1];
    final drow1 =
        (3.0 * _coefficients[offset + 7] * v +
                2.0 * _coefficients[offset + 6]) *
            v +
        _coefficients[offset + 5];
    final drow2 =
        (3.0 * _coefficients[offset + 11] * v +
                2.0 * _coefficients[offset + 10]) *
            v +
        _coefficients[offset + 9];
    final drow3 =
        (3.0 * _coefficients[offset + 15] * v +
                2.0 * _coefficients[offset + 14]) *
            v +
        _coefficients[offset + 13];

    // df/dv = drow3*u^3 + drow2*u^2 + drow1*u + drow0
    final dfDv = ((drow3 * u + drow2) * u + drow1) * u + drow0;

    final dfDx = (x < _xs.first || x > _xs.last) ? 0.0 : dfDu / dx;
    final dfDy = (y < _ys.first || y > _ys.last) ? 0.0 : dfDv / dy;

    return Vector<double>.fromList([dfDx, dfDy], type: DataType.float64);
  }
}
