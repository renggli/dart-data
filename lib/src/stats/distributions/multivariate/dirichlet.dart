import 'dart:math';

import 'package:more/printer.dart';

import '../../../linear/matrix.dart';
import '../../../linear/vector.dart';
import '../../../special/gamma.dart';
import '../../../type/data_type.dart';
import '../continuous/gamma.dart';
import 'multivariate_distribution.dart';

/// Dirichlet distribution parameterized by concentration vector [alpha] α.
///
/// See https://en.wikipedia.org/wiki/Dirichlet_distribution.
class DirichletDistribution extends MultivariateDistribution<double> {
  /// Constructs a Dirichlet distribution with concentration vector [alpha].
  new(this.alpha) : dimensions = alpha.length {
    if (alpha.length < 2) {
      throw ArgumentError.value(
        alpha.length,
        'alpha.length',
        'Dirichlet distribution requires at least 2 dimensions.',
      );
    }
    var sum = 0.0;
    var sumGammaLn = 0.0;
    for (var i = 0; i < dimensions; i++) {
      final a = alpha.getUnchecked(i);
      if (!a.isFinite || a <= 0.0) {
        throw ArgumentError.value(
          a,
          'alpha[$i]',
          'Concentration parameters must be strictly positive.',
        );
      }
      sum += a;
      sumGammaLn += gammaLn(a);
    }
    _alpha0 = sum;
    _logBeta = sumGammaLn - gammaLn(_alpha0);
  }

  /// Constructs a symmetric Dirichlet distribution with [dimensions] and scalar
  /// concentration [alpha].
  factory symmetric(int dimensions, double alpha) {
    if (dimensions < 2) {
      throw ArgumentError.value(
        dimensions,
        'dimensions',
        'Dirichlet distribution requires at least 2 dimensions.',
      );
    }
    if (!alpha.isFinite || alpha <= 0.0) {
      throw ArgumentError.value(
        alpha,
        'alpha',
        'Concentration parameter must be strictly positive.',
      );
    }
    return DirichletDistribution(
      Vector<double>.filled(dimensions, alpha, type: DataType.float64),
    );
  }

  @override
  final int dimensions;

  /// The concentration vector α.
  final Vector<double> alpha;

  late final double _alpha0;
  late final double _logBeta;

  @override
  Vector<double> get mean => Vector<double>.generate(
    dimensions,
    (i) => alpha.getUnchecked(i) / _alpha0,
    type: DataType.float64,
  );

  @override
  Matrix<double> get covariance {
    final denom = _alpha0 * _alpha0 * (_alpha0 + 1.0);
    return Matrix<double>.generate(dimensions, dimensions, (r, c) {
      final ar = alpha.getUnchecked(r);
      if (r == c) {
        return (ar * (_alpha0 - ar)) / denom;
      } else {
        return (-ar * alpha.getUnchecked(c)) / denom;
      }
    }, type: DataType.float64);
  }

  @override
  double logProbability(Vector<double> x) {
    if (x.length != dimensions) {
      throw ArgumentError(
        'Vector length (${x.length}) must match distribution dimensions ($dimensions).',
      );
    }
    var sum = 0.0;
    var logTerm = 0.0;
    for (var i = 0; i < dimensions; i++) {
      final xi = x.getUnchecked(i);
      if (xi.isNaN) return double.nan;
      if (xi < 0.0) return double.negativeInfinity;
      sum += xi;
      final ai = alpha.getUnchecked(i);
      if (xi == 0.0) {
        if (ai < 1.0) return double.infinity;
        if (ai > 1.0) return double.negativeInfinity;
      } else {
        logTerm += (ai - 1.0) * log(xi);
      }
    }
    if ((sum - 1.0).abs() > 1e-5) {
      return double.negativeInfinity;
    }
    return logTerm - _logBeta;
  }

  @override
  double probability(Vector<double> x) {
    final logP = logProbability(x);
    return logP.isInfinite && logP < 0 ? 0.0 : exp(logP);
  }

  @override
  Vector<double> sample({Random? random}) {
    final gammas = List<double>.generate(
      dimensions,
      (i) =>
          GammaDistribution(alpha.getUnchecked(i), 1.0).sample(random: random),
      growable: false,
    );
    var sum = 0.0;
    for (var i = 0; i < dimensions; i++) {
      sum += gammas[i];
    }
    return Vector<double>.generate(
      dimensions,
      (i) => gammas[i] / sum,
      type: DataType.float64,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is DirichletDistribution &&
      dimensions == other.dimensions &&
      alpha == other.alpha;

  @override
  int get hashCode => Object.hash(DirichletDistribution, alpha);

  @override
  ObjectPrinter get toStringPrinter => super.toStringPrinter
    ..addValue(dimensions, name: 'dimensions')
    ..addValue(alpha, name: 'α');
}
