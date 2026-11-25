import 'dart:math';

import 'package:more/printer.dart';

import '../../../linear/matrix.dart';
import '../../../linear/vector.dart';
import '../../../special/gamma.dart';
import '../../../type/data_type.dart';
import '../continuous/gamma.dart';
import '../multivariate.dart';
import '../utils.dart';

/// Dirichlet distribution parameterized by concentration vector [alpha] α.
///
/// See https://en.wikipedia.org/wiki/Dirichlet_distribution.
class DirichletDistribution extends MultivariateDistribution<double> {
  /// Constructs a Dirichlet distribution with concentration vector [alpha].
  new(Vector<double> alpha) : _alpha = alpha.copy(), dimensions = alpha.length {
    if (dimensions < 2) {
      throw ArgumentError.value(
        dimensions,
        'alpha.length',
        'Dirichlet distribution requires at least 2 dimensions.',
      );
    }
    var sum = 0.0;
    var sumGammaLn = 0.0;
    for (var i = 0; i < dimensions; i++) {
      final a = _alpha.getUnchecked(i);
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

  final Vector<double> _alpha;
  late final double _alpha0;
  late final double _logBeta;

  /// The concentration vector α.
  Vector<double> get alpha => _alpha.copy();

  @override
  Vector<double> get mean => Vector<double>.generate(
    dimensions,
    (i) => _alpha.getUnchecked(i) / _alpha0,
    type: DataType.float64,
  );

  @override
  Matrix<double> get covariance {
    final denom = _alpha0 * _alpha0 * (_alpha0 + 1.0);
    return Matrix<double>.generate(dimensions, dimensions, (r, c) {
      final ar = _alpha.getUnchecked(r);
      if (r == c) {
        return (ar * (_alpha0 - ar)) / denom;
      } else {
        return (-ar * _alpha.getUnchecked(c)) / denom;
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
    var hasNegative = false;
    var hasNonFinite = false;
    for (var i = 0; i < dimensions; i++) {
      final xi = x.getUnchecked(i);
      if (xi.isNaN) return double.nan;
      if (!xi.isFinite) hasNonFinite = true;
      if (xi < 0.0) hasNegative = true;
      sum += xi;
    }
    if (hasNegative || hasNonFinite || (sum - 1.0).abs() > 1e-5) {
      return double.negativeInfinity;
    }
    var hasPosInf = false;
    var hasNegInf = false;
    var logTerm = 0.0;
    for (var i = 0; i < dimensions; i++) {
      final xi = x.getUnchecked(i);
      final ai = _alpha.getUnchecked(i);
      if (xi == 0.0) {
        if (ai < 1.0) {
          hasPosInf = true;
        } else if (ai > 1.0) {
          hasNegInf = true;
        }
      } else {
        logTerm += (ai - 1.0) * log(xi);
      }
    }
    if (hasPosInf && hasNegInf) return double.nan;
    if (hasNegInf) return double.negativeInfinity;
    if (hasPosInf) return double.infinity;
    return logTerm - _logBeta;
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
    final gammas = List<double>.generate(
      dimensions,
      (i) => GammaDistribution(_alpha.getUnchecked(i), 1.0).sample(random: rng),
      growable: false,
    );
    var sum = 0.0;
    for (var i = 0; i < dimensions; i++) {
      sum += gammas[i];
    }
    if (sum > 0.0) {
      return Vector<double>.generate(
        dimensions,
        (i) => gammas[i] / sum,
        type: DataType.float64,
      );
    }
    // Exact log-space sampling when small alpha causes all Gamma draws to underflow.
    final logGammas = List<double>.generate(dimensions, (i) {
      final a = _alpha.getUnchecked(i);
      if (a < 1.0) {
        return log(GammaDistribution.shape(a + 1.0).sample(random: rng)) +
            log(nextOpenUnit(rng)) / a;
      }
      return log(GammaDistribution.shape(a).sample(random: rng));
    }, growable: false);
    var maxLog = logGammas[0];
    for (var i = 1; i < dimensions; i++) {
      if (logGammas[i] > maxLog) maxLog = logGammas[i];
    }
    var expSum = 0.0;
    final expShifted = List<double>.generate(dimensions, (i) {
      final e = exp(logGammas[i] - maxLog);
      expSum += e;
      return e;
    }, growable: false);
    return Vector<double>.generate(
      dimensions,
      (i) => expShifted[i] / expSum,
      type: DataType.float64,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is DirichletDistribution &&
      dimensions == other.dimensions &&
      _alpha == other._alpha;

  @override
  int get hashCode => Object.hash(DirichletDistribution, _alpha);

  @override
  ObjectPrinter get toStringPrinter => super.toStringPrinter
    ..addValue(dimensions, name: 'dimensions')
    ..addValue(_alpha, name: 'α');
}
