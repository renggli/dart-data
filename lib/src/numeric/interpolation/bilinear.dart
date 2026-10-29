import '../../linear/matrix.dart';
import '../../linear/vector.dart';
import '../../type/data_type.dart';
import 'interpolator.dart';
import 'search.dart';

/// 2D Bilinear surface interpolation over a rectilinear grid.
class BilinearInterpolation implements Interpolator2D {
  /// Constructs a bilinear interpolator.
  ///
  /// Points in [xs] and [ys] must be strictly monotonically increasing with
  /// length $\ge 2$. [values] must have shape `[xs.length, ys.length]`.
  new(Iterable<num> xs, Iterable<num> ys, Matrix<num> values)
    : _xs = [for (final x in xs) x.toDouble()],
      _ys = [for (final y in ys) y.toDouble()] {
    if (_xs.length < 2) {
      throw ArgumentError('xs must contain at least 2 points.');
    }
    if (_ys.length < 2) {
      throw ArgumentError('ys must contain at least 2 points.');
    }
    for (var i = 0; i < _xs.length - 1; i++) {
      if (!(_xs[i] < _xs[i + 1])) {
        throw ArgumentError('xs must be strictly monotonically increasing.');
      }
    }
    for (var j = 0; j < _ys.length - 1; j++) {
      if (!(_ys[j] < _ys[j + 1])) {
        throw ArgumentError('ys must be strictly monotonically increasing.');
      }
    }
    if (values.rowCount != _xs.length || values.colCount != _ys.length) {
      throw ArgumentError(
        'Values matrix shape (${values.rowCount}x${values.colCount}) must '
        'match grid dimensions (${_xs.length}x${_ys.length}).',
      );
    }
    _values = Matrix<double>.generate(
      _xs.length,
      _ys.length,
      (int r, int c) => values.getUnchecked(r, c).toDouble(),
      type: DataType.float64,
    );
  }

  final List<double> _xs;
  final List<double> _ys;
  late final Matrix<double> _values;

  @override
  double call(double x, double y) {
    final xClamped = x.clamp(_xs.first, _xs.last);
    final yClamped = y.clamp(_ys.first, _ys.last);

    final i = binarySearchInterval(_xs, xClamped);
    final j = binarySearchInterval(_ys, yClamped);

    final x0 = _xs[i];
    final x1 = _xs[i + 1];
    final y0 = _ys[j];
    final y1 = _ys[j + 1];

    final u = (xClamped - x0) / (x1 - x0);
    final v = (yClamped - y0) / (y1 - y0);

    final q00 = _values.getUnchecked(i, j);
    final q10 = _values.getUnchecked(i + 1, j);
    final q01 = _values.getUnchecked(i, j + 1);
    final q11 = _values.getUnchecked(i + 1, j + 1);

    return (1.0 - u) * (1.0 - v) * q00 +
        u * (1.0 - v) * q10 +
        (1.0 - u) * v * q01 +
        u * v * q11;
  }

  /// Computes the partial gradient
  /// $(\frac{\partial f}{\partial x}, \frac{\partial f}{\partial y})$ at ([x],
  /// [y]).
  Vector<double> gradient(double x, double y) {
    final xClamped = x.clamp(_xs.first, _xs.last);
    final yClamped = y.clamp(_ys.first, _ys.last);

    final i = binarySearchInterval(_xs, xClamped);
    final j = binarySearchInterval(_ys, yClamped);

    final x0 = _xs[i];
    final x1 = _xs[i + 1];
    final y0 = _ys[j];
    final y1 = _ys[j + 1];

    final dx = x1 - x0;
    final dy = y1 - y0;

    final u = (xClamped - x0) / dx;
    final v = (yClamped - y0) / dy;

    final q00 = _values.getUnchecked(i, j);
    final q10 = _values.getUnchecked(i + 1, j);
    final q01 = _values.getUnchecked(i, j + 1);
    final q11 = _values.getUnchecked(i + 1, j + 1);

    final dfDx = (x < _xs.first || x > _xs.last)
        ? 0.0
        : ((1.0 - v) * (q10 - q00) + v * (q11 - q01)) / dx;
    final dfDy = (y < _ys.first || y > _ys.last)
        ? 0.0
        : ((1.0 - u) * (q01 - q00) + u * (q11 - q10)) / dy;

    return Vector<double>.fromList([dfDx, dfDy], type: DataType.float64);
  }
}
