import 'interpolator.dart';

/// Polynomial interpolation through sample points using Lagrange barycentric
/// formula.
class LagrangeInterpolation implements Interpolator {
  /// Constructs a Lagrange polynomial interpolator through sample points [xs]
  /// and [ys].
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
          final diff = _xs[i] - _xs[j];
          if (diff == 0.0) {
            throw ArgumentError('xs must not contain duplicate values.');
          }
          prod *= diff;
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
