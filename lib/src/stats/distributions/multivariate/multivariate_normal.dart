import 'dart:math';

import 'package:more/printer.dart';

import '../../../linear/decomposition/cholesky.dart';
import '../../../linear/matrix.dart';
import '../../../linear/vector.dart';
import '../../../type/data_type.dart';
import '../multivariate.dart';
import '../utils.dart';

/// Multivariate normal (Gaussian) distribution parameterized by [mean] vector
/// μ and [covariance] matrix Σ.
///
/// See https://en.wikipedia.org/wiki/Multivariate_normal_distribution.
class MultivariateNormalDistribution extends MultivariateDistribution<double> {
  /// Constructs a multivariate normal distribution with given [mean] and
  /// [covariance].
  new(Vector<double> mean, Matrix<double> covariance)
    : _mean = mean.copy(),
      _covariance = covariance.copy(),
      dimensions = mean.length {
    if (dimensions <= 0) {
      throw ArgumentError.value(
        dimensions,
        'mean.length',
        'Dimensions must be positive.',
      );
    }
    if (dimensions != _covariance.rowCount ||
        _covariance.rowCount != _covariance.colCount) {
      throw ArgumentError(
        'Mean length ($dimensions) must match square covariance dimension (${_covariance.rowCount}x${_covariance.colCount}).',
      );
    }
    for (var i = 0; i < dimensions; i++) {
      final m = _mean.getUnchecked(i);
      if (!m.isFinite) {
        throw ArgumentError.value(m, 'mean[$i]', 'Mean must be finite.');
      }
      for (var j = 0; j < dimensions; j++) {
        final c = _covariance.getUnchecked(i, j);
        if (!c.isFinite) {
          throw ArgumentError.value(
            c,
            'covariance[$i][$j]',
            'Covariance entries must be finite.',
          );
        }
      }
    }
    final chol = _covariance.cholesky;
    if (!chol.isSymmetricPositiveDefinite) {
      throw ArgumentError(
        'Covariance matrix must be symmetric positive definite.',
      );
    }
    _l = chol.l;
    var logDetHalf = 0.0;
    for (var j = 0; j < dimensions; j++) {
      logDetHalf += log(_l.getUnchecked(j, j));
    }
    _logDetSigma = 2.0 * logDetHalf;
  }

  /// Constructs a standard multivariate normal distribution centered at zero
  /// with identity covariance.
  factory standard(int dimensions) {
    if (dimensions <= 0) {
      throw ArgumentError.value(
        dimensions,
        'dimensions',
        'Dimensions must be positive.',
      );
    }
    final mean = Vector<double>.filled(dimensions, 0.0, type: DataType.float64);
    final covariance = Matrix<double>.generate(
      dimensions,
      dimensions,
      (r, c) => r == c ? 1.0 : 0.0,
      type: DataType.float64,
    );
    return MultivariateNormalDistribution(mean, covariance);
  }

  @override
  final int dimensions;

  final Vector<double> _mean;
  final Matrix<double> _covariance;
  late final Matrix<double> _l;
  late final double _logDetSigma;

  @override
  Vector<double> get mean => _mean.copy();

  @override
  Matrix<double> get covariance => _covariance.copy();

  @override
  double logProbability(Vector<double> x) {
    if (x.length != dimensions) {
      throw ArgumentError(
        'Vector length (${x.length}) must match distribution dimensions ($dimensions).',
      );
    }
    final n = dimensions;
    var hasNonFinite = false;
    for (var i = 0; i < n; i++) {
      final xi = x.getUnchecked(i);
      if (xi.isNaN) return double.nan;
      if (!xi.isFinite) hasNonFinite = true;
    }
    if (hasNonFinite) return double.negativeInfinity;

    var sumSq = 0.0;
    final y = List<double>.filled(n, 0.0);
    for (var i = 0; i < n; i++) {
      var diff = x.getUnchecked(i) - _mean.getUnchecked(i);
      for (var j = 0; j < i; j++) {
        diff -= _l.getUnchecked(i, j) * y[j];
      }
      final yVal = diff / _l.getUnchecked(i, i);
      y[i] = yVal;
      sumSq += yVal * yVal;
    }
    return -0.5 * (n * _ln2pi + _logDetSigma + sumSq);
  }

  @override
  double probability(Vector<double> x) {
    final logP = logProbability(x);
    if (logP.isNaN) return double.nan;
    return logP == double.negativeInfinity ? 0.0 : exp(logP);
  }

  @override
  Vector<double> sample({Random? random}) {
    final rng = random ?? defaultRandom;
    final n = dimensions;
    final z = List<double>.filled(n, 0.0);
    for (var i = 0; i < n; i += 2) {
      double xVal, yVal, rSq;
      do {
        xVal = 2.0 * rng.nextDouble() - 1.0;
        yVal = 2.0 * rng.nextDouble() - 1.0;
        rSq = xVal * xVal + yVal * yVal;
      } while (rSq >= 1.0 || rSq == 0.0);
      final factor = sqrt(-2.0 * log(rSq) / rSq);
      z[i] = xVal * factor;
      if (i + 1 < n) {
        z[i + 1] = yVal * factor;
      }
    }
    return Vector<double>.generate(n, (i) {
      var val = _mean.getUnchecked(i);
      for (var j = 0; j <= i; j++) {
        val += _l.getUnchecked(i, j) * z[j];
      }
      return val;
    }, type: DataType.float64);
  }

  @override
  bool operator ==(Object other) =>
      other is MultivariateNormalDistribution &&
      dimensions == other.dimensions &&
      _mean == other._mean &&
      _covariance == other._covariance;

  @override
  int get hashCode =>
      Object.hash(MultivariateNormalDistribution, _mean, _covariance);

  @override
  ObjectPrinter get toStringPrinter => super.toStringPrinter
    ..addValue(dimensions, name: 'dimensions')
    ..addValue(_mean, name: 'μ')
    ..addValue(_covariance, name: 'Σ');
}

final double _ln2pi = log(2.0 * pi);
