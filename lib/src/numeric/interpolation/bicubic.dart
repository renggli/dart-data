import 'dart:math' as math;

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

    _values = Matrix<double>.generate(
      nx,
      ny,
      (int r, int c) => values.getUnchecked(r, c).toDouble(),
      type: DataType.float64,
    );

    // Precompute partial derivatives at grid nodes: fx, fy, fxy
    _fx = Matrix<double>.filled(nx, ny, 0.0, type: DataType.float64);
    _fy = Matrix<double>.filled(nx, ny, 0.0, type: DataType.float64);
    _fxy = Matrix<double>.filled(nx, ny, 0.0, type: DataType.float64);

    for (var i = 0; i < nx; i++) {
      for (var j = 0; j < ny; j++) {
        // df/dx
        if (i == 0) {
          _fx.setUnchecked(
            i,
            j,
            (_values.getUnchecked(1, j) - _values.getUnchecked(0, j)) /
                (_xs[1] - _xs[0]),
          );
        } else if (i == nx - 1) {
          _fx.setUnchecked(
            i,
            j,
            (_values.getUnchecked(nx - 1, j) -
                    _values.getUnchecked(nx - 2, j)) /
                (_xs[nx - 1] - _xs[nx - 2]),
          );
        } else {
          _fx.setUnchecked(
            i,
            j,
            (_values.getUnchecked(i + 1, j) - _values.getUnchecked(i - 1, j)) /
                (_xs[i + 1] - _xs[i - 1]),
          );
        }

        // df/dy
        if (j == 0) {
          _fy.setUnchecked(
            i,
            j,
            (_values.getUnchecked(i, 1) - _values.getUnchecked(i, 0)) /
                (_ys[1] - _ys[0]),
          );
        } else if (j == ny - 1) {
          _fy.setUnchecked(
            i,
            j,
            (_values.getUnchecked(i, ny - 1) -
                    _values.getUnchecked(i, ny - 2)) /
                (_ys[ny - 1] - _ys[ny - 2]),
          );
        } else {
          _fy.setUnchecked(
            i,
            j,
            (_values.getUnchecked(i, j + 1) - _values.getUnchecked(i, j - 1)) /
                (_ys[j + 1] - _ys[j - 1]),
          );
        }
      }
    }

    // d2f/dxdy
    for (var i = 0; i < nx; i++) {
      for (var j = 0; j < ny; j++) {
        if (j == 0) {
          _fxy.setUnchecked(
            i,
            j,
            (_fx.getUnchecked(i, 1) - _fx.getUnchecked(i, 0)) /
                (_ys[1] - _ys[0]),
          );
        } else if (j == ny - 1) {
          _fxy.setUnchecked(
            i,
            j,
            (_fx.getUnchecked(i, ny - 1) - _fx.getUnchecked(i, ny - 2)) /
                (_ys[ny - 1] - _ys[ny - 2]),
          );
        } else {
          _fxy.setUnchecked(
            i,
            j,
            (_fx.getUnchecked(i, j + 1) - _fx.getUnchecked(i, j - 1)) /
                (_ys[j + 1] - _ys[j - 1]),
          );
        }
      }
    }
  }

  final List<double> _xs;
  final List<double> _ys;
  late final Matrix<double> _values;
  late final Matrix<double> _fx;
  late final Matrix<double> _fy;
  late final Matrix<double> _fxy;

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

    final a = _computeCoefficients(i, j, dx, dy);

    var result = 0.0;
    var uPow = 1.0;
    for (var r = 0; r < 4; r++) {
      var vPow = 1.0;
      for (var c = 0; c < 4; c++) {
        result += a[r][c] * uPow * vPow;
        vPow *= v;
      }
      uPow *= u;
    }
    return result;
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

    final a = _computeCoefficients(i, j, dx, dy);

    var dfDu = 0.0;
    var dfDv = 0.0;

    for (var r = 0; r < 4; r++) {
      for (var c = 0; c < 4; c++) {
        final coeff = a[r][c];
        if (r > 0) {
          dfDu += r * coeff * math.pow(u, r - 1) * math.pow(v, c);
        }
        if (c > 0) {
          dfDv += c * coeff * math.pow(u, r) * math.pow(v, c - 1);
        }
      }
    }

    final dfDx = (x < _xs.first || x > _xs.last) ? 0.0 : dfDu / dx;
    final dfDy = (y < _ys.first || y > _ys.last) ? 0.0 : dfDv / dy;

    return Vector<double>.fromList([dfDx, dfDy], type: DataType.float64);
  }

  List<List<double>> _computeCoefficients(int i, int j, double dx, double dy) {
    final f00 = _values.getUnchecked(i, j);
    final f10 = _values.getUnchecked(i + 1, j);
    final f01 = _values.getUnchecked(i, j + 1);
    final f11 = _values.getUnchecked(i + 1, j + 1);

    final fx00 = _fx.getUnchecked(i, j) * dx;
    final fx10 = _fx.getUnchecked(i + 1, j) * dx;
    final fx01 = _fx.getUnchecked(i, j + 1) * dx;
    final fx11 = _fx.getUnchecked(i + 1, j + 1) * dx;

    final fy00 = _fy.getUnchecked(i, j) * dy;
    final fy10 = _fy.getUnchecked(i + 1, j) * dy;
    final fy01 = _fy.getUnchecked(i, j + 1) * dy;
    final fy11 = _fy.getUnchecked(i + 1, j + 1) * dy;

    final fxy00 = _fxy.getUnchecked(i, j) * dx * dy;
    final fxy10 = _fxy.getUnchecked(i + 1, j) * dx * dy;
    final fxy01 = _fxy.getUnchecked(i, j + 1) * dx * dy;
    final fxy11 = _fxy.getUnchecked(i + 1, j + 1) * dx * dy;

    final fMat = [
      [f00, f01, fy00, fy01],
      [f10, f11, fy10, fy11],
      [fx00, fx01, fxy00, fxy01],
      [fx10, fx11, fxy10, fxy11],
    ];

    return _multiply4x4(
      _multiply4x4(_hermiteMatrix, fMat),
      _hermiteMatrixTransposed,
    );
  }
}

const List<List<double>> _hermiteMatrix = [
  [1.0, 0.0, 0.0, 0.0],
  [0.0, 0.0, 1.0, 0.0],
  [-3.0, 3.0, -2.0, -1.0],
  [2.0, -2.0, 1.0, 1.0],
];

const List<List<double>> _hermiteMatrixTransposed = [
  [1.0, 0.0, -3.0, 2.0],
  [0.0, 0.0, 3.0, -2.0],
  [0.0, 1.0, -2.0, 1.0],
  [0.0, 0.0, -1.0, 1.0],
];

List<List<double>> _multiply4x4(List<List<double>> a, List<List<double>> b) {
  final res = List.generate(4, (_) => List<double>.filled(4, 0.0));
  for (var r = 0; r < 4; r++) {
    for (var c = 0; c < 4; c++) {
      var sum = 0.0;
      for (var k = 0; k < 4; k++) {
        sum += a[r][k] * b[k][c];
      }
      res[r][c] = sum;
    }
  }
  return res;
}
