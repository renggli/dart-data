import 'dart:math';

import 'package:more/printer.dart';

import '../../../linear/decomposition/cholesky.dart';
import '../../../linear/matrix.dart';
import '../../../linear/vector.dart';
import '../../../type/data_type.dart';
import '../continuous/normal.dart';
import 'multivariate_distribution.dart';

/// Multivariate normal (Gaussian) distribution parameterized by [mean] vector
/// μ and [covariance] matrix Σ.
///
/// See https://en.wikipedia.org/wiki/Multivariate_normal_distribution.
class MultivariateNormalDistribution extends MultivariateDistribution<double> {
  /// Constructs a multivariate normal distribution with given [mean] and
  /// [covariance].
  new(this.mean, this.covariance) : dimensions = mean.length {
    if (dimensions <= 0) {
      throw ArgumentError.value(
        dimensions,
        'mean.length',
        'Dimensions must be positive.',
      );
    }
    if (mean.length != covariance.rowCount ||
        covariance.rowCount != covariance.colCount) {
      throw ArgumentError(
        'Mean length (${mean.length}) must match square covariance dimension (${covariance.rowCount}x${covariance.colCount}).',
      );
    }
    for (var i = 0; i < dimensions; i++) {
      final m = mean.getUnchecked(i);
      if (!m.isFinite) {
        throw ArgumentError.value(m, 'mean[$i]', 'Mean must be finite.');
      }
      for (var j = 0; j < dimensions; j++) {
        final c = covariance.getUnchecked(i, j);
        if (!c.isFinite) {
          throw ArgumentError.value(
            c,
            'covariance[$i][$j]',
            'Covariance entries must be finite.',
          );
        }
      }
    }
    final chol = covariance.cholesky;
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

  @override
  final Vector<double> mean;

  @override
  final Matrix<double> covariance;

  late final Matrix<double> _l;
  late final double _logDetSigma;

  @override
  double logProbability(Vector<double> x) {
    if (x.length != dimensions) {
      throw ArgumentError(
        'Vector length (${x.length}) must match distribution dimensions ($dimensions).',
      );
    }
    final n = dimensions;
    var sumSq = 0.0;
    final y = List<double>.filled(n, 0.0);
    for (var i = 0; i < n; i++) {
      var diff = x.getUnchecked(i) - mean.getUnchecked(i);
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
  double probability(Vector<double> x) => exp(logProbability(x));

  @override
  Vector<double> sample({Random? random}) {
    const normal = NormalDistribution.standard();
    final n = dimensions;
    final z = List<double>.generate(
      n,
      (_) => normal.sample(random: random),
      growable: false,
    );
    return Vector<double>.generate(n, (i) {
      var val = mean.getUnchecked(i);
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
      mean == other.mean &&
      covariance == other.covariance;

  @override
  int get hashCode =>
      Object.hash(MultivariateNormalDistribution, mean, covariance);

  @override
  ObjectPrinter get toStringPrinter => super.toStringPrinter
    ..addValue(dimensions, name: 'dimensions')
    ..addValue(mean, name: 'μ')
    ..addValue(covariance, name: 'Σ');
}

final double _ln2pi = log(2.0 * pi);
