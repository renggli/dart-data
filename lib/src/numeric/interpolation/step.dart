import 'interpolator.dart';
import 'search.dart';

/// 1D Nearest neighbor interpolation.
class NearestInterpolation implements Interpolator {
  /// Constructs a nearest-neighbor interpolator from strictly increasing points
  /// [xs] and [ys].
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
      if (!(_xs[i] < _xs[i + 1])) {
        throw ArgumentError('xs must be strictly monotonically increasing.');
      }
    }
  }

  /// When an evaluation point is equidistant between two points, whether to
  /// prefer the lower point.
  final bool preferLower;
  final List<double> _xs;
  final List<double> _ys;

  @override
  double call(num x) {
    final xd = x.toDouble();
    if (xd.isNaN) return double.nan;
    if (xd <= _xs.first) return _ys.first;
    if (xd >= _xs.last) return _ys.last;
    final idx = binarySearchInterval(_xs, xd);
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
  /// Constructs a step-wise previous interpolator from strictly increasing
  /// points [xs] and [ys].
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
      if (!(_xs[i] < _xs[i + 1])) {
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
    if (xd.isNaN) return double.nan;
    if (xd < _xs.first) return left;
    if (xd >= _xs.last) return _ys.last;
    final idx = binarySearchInterval(_xs, xd);
    return _ys[idx];
  }
}

/// 1D Step-wise next value interpolation.
class NextInterpolation implements Interpolator {
  /// Constructs a step-wise next interpolator from strictly increasing points
  /// [xs] and [ys].
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
      if (!(_xs[i] < _xs[i + 1])) {
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
    if (xd.isNaN) return double.nan;
    if (xd <= _xs.first) return _ys.first;
    if (xd > _xs.last) return right;
    final idx = binarySearchInterval(_xs, xd);
    return xd == _xs[idx] ? _ys[idx] : _ys[idx + 1];
  }
}
