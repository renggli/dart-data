import 'dart:math';

import 'package:more/printer.dart';

import '../../../special/utils.dart';
import '../continuous.dart';
import '../errors.dart';
import '../utils.dart';

/// The Pareto distribution is a power-law probability distribution defined on
/// `[scale, infinity)` parameterized by shape parameter [shape] (α) and scale
/// parameter [scale] (x₀).
///
/// See https://en.wikipedia.org/wiki/Pareto_distribution.
///
/// ```dart
/// final distribution = ParetoDistribution(3, 1);
/// print(distribution.mean);  // 1.5
/// ```
class ParetoDistribution extends ContinuousDistribution {
  /// A Pareto distribution with parameters [shape] and [scale].
  new(this.shape, this.scale) {
    if (!shape.isFinite || shape <= 0) {
      throw ArgumentError.value(shape, 'shape', 'Shape must be positive');
    }
    if (!scale.isFinite || scale <= 0) {
      throw ArgumentError.value(scale, 'scale', 'Scale must be positive');
    }
  }

  /// A standard Pareto distribution with shape 1 and scale 1.
  const new standard() : this._(1.0, 1.0);

  const new _(this.shape, this.scale);

  /// Fits a Pareto distribution to positive [samples] using maximum likelihood
  /// estimation.
  factory fit(Iterable<num> samples) {
    var minVal = double.infinity;
    final list = <double>[];
    for (final x in samples) {
      final val = x.toDouble();
      if (!val.isFinite || val <= 0.0) {
        throw ArgumentError.value(
          x,
          'samples',
          'Pareto samples must be strictly positive and finite',
        );
      }
      list.add(val);
      if (val < minVal) minVal = val;
    }
    if (list.isEmpty) {
      throw ArgumentError.value(samples, 'samples', 'Cannot fit empty samples');
    }
    var sumLogRatio = 0.0;
    for (final val in list) {
      sumLogRatio += log(val / minVal);
    }
    var shape = sumLogRatio > 0.0 ? list.length / sumLogRatio : 1.0;
    if (shape <= 0.0 || !shape.isFinite) shape = 1.0;
    return ParetoDistribution(shape, minVal);
  }

  /// The shape parameter (α).
  final double shape;

  /// The scale parameter (x₀).
  final double scale;

  @override
  double get lowerBound => scale;

  @override
  bool get isLowerBoundOpen => false;

  @override
  double get mean => shape > 1 ? shape * scale / (shape - 1) : double.infinity;

  @override
  double get median => scale * pow(2, 1 / shape).toDouble();

  @override
  double get mode => scale;

  @override
  double get variance => shape > 2
      ? shape * scale * scale / ((shape - 1.0) * (shape - 1.0) * (shape - 2.0))
      : (shape > 1 ? double.infinity : double.nan);

  @override
  double get skewness => shape > 3
      ? 2 * (1 + shape) / (shape - 3) * sqrt((shape - 2) / shape)
      : double.nan;

  @override
  double get excessKurtosis {
    if (shape <= 4.0) return double.nan;
    final s2 = shape * shape;
    return 6.0 *
        (s2 * shape + s2 - 6.0 * shape - 2.0) /
        (shape * (shape - 3.0) * (shape - 4.0));
  }

  @override
  double probability(double x) {
    if (x.isNaN) return double.nan;
    if (x < scale || x == double.infinity) return 0.0;
    if (x == scale) return shape / scale;
    final logP = logProbability(x);
    if (logP <= -745.0) return 0.0;
    return exp(logP);
  }

  @override
  double logProbability(double x) {
    if (x.isNaN) return double.nan;
    if (x < scale || x == double.infinity) return double.negativeInfinity;
    if (x == scale) return log(shape) - log(scale);
    return log(shape) - log(x) + shape * log(scale / x);
  }

  @override
  double cumulativeProbability(double x) {
    if (x.isNaN) return double.nan;
    if (x < scale) return 0.0;
    if (x == double.infinity) return 1.0;
    return -expm1(shape * log(scale / x));
  }

  @override
  double survival(double x) {
    if (x.isNaN) return double.nan;
    if (x < scale) return 1.0;
    if (x == double.infinity) return 0.0;
    return exp(shape * log(scale / x));
  }

  @override
  double inverseCumulativeProbability(num probability) {
    InvalidProbability.check(probability);
    if (probability == 0.0) return scale;
    if (probability == 1.0) return double.infinity;
    return scale * exp(-log1p(-probability.toDouble()) / shape);
  }

  @override
  double inverseSurvival(num probability) {
    InvalidProbability.check(probability);
    if (probability == 0.0) return double.infinity;
    if (probability == 1.0) return scale;
    return scale * exp(-log(probability.toDouble()) / shape);
  }

  @override
  double sample({Random? random}) {
    final uniform = nextOpenUnit(random ?? defaultRandom);
    return scale * exp(-log(uniform) / shape);
  }

  @override
  bool operator ==(Object other) =>
      other is ParetoDistribution &&
      shape == other.shape &&
      scale == other.scale;

  @override
  int get hashCode => Object.hash(ParetoDistribution, shape, scale);

  @override
  ObjectPrinter get toStringPrinter => super.toStringPrinter
    ..addValue(shape, name: 'shape')
    ..addValue(scale, name: 'scale');
}
