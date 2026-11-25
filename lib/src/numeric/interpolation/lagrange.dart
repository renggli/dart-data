import 'dart:math' as math;

import 'interpolator.dart';

/// Polynomial interpolation through sample points using Lagrange barycentric
/// formula.
class LagrangeInterpolation implements Interpolator {
  /// Constructs a Lagrange polynomial interpolator through finite sample points
  /// [xs] and [ys].
  new(Iterable<num> xs, Iterable<num> ys)
    : _xs = [for (final x in xs) x.toDouble()],
      _ys = [for (final y in ys) y.toDouble()] {
    final count = _xs.length;
    if (count != _ys.length) {
      throw ArgumentError('xs and ys must have identical length.');
    }
    if (count == 0) {
      throw ArgumentError('At least 1 point required for interpolation.');
    }
    var minX = double.infinity;
    var maxX = double.negativeInfinity;
    for (final x in _xs) {
      if (!x.isFinite) {
        throw ArgumentError('xs must contain only finite values.');
      }
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
    }
    _weights = List<double>.filled(count, 1.0);
    if (count == 1) return;

    // Normalize differences by 0.25 * (maxX - minX) without overflowing
    // `maxX - minX`; barycentric weights are invariant to uniform scaling.
    final rawScale = 0.25 * maxX - 0.25 * minX;
    if (rawScale == 0.0) {
      throw ArgumentError('xs must not contain duplicate values.');
    }
    final scale = math.max(rawScale, 1e-300);
    for (var i = 0; i < count; i++) {
      final xi = _xs[i];
      var prod = 1.0;
      for (var j = 0; j < count; j++) {
        if (i != j) {
          final xj = _xs[j];
          if (xi == xj) {
            throw ArgumentError('xs must not contain duplicate values.');
          }
          prod *= (xi / scale) - (xj / scale);
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
    if (xd.isNaN) return double.nan;
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
