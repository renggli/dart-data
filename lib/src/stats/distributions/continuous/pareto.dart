import 'dart:math';

import 'package:more/printer.dart';

import '../continuous.dart';
import '../errors.dart';

/// The Pareto distribution is a power-law probability distribution defined on
/// the interval [scale, infinity) parameterized by shape parameter [shape] (α)
/// and scale parameter [scale] (xo).
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

  /// The shape parameter (α).
  final double shape;

  /// The scale parameter (xo).
  final double scale;

  @override
  double get lowerBound => scale;

  @override
  double get mean => shape > 1 ? shape * scale / (shape - 1) : double.infinity;

  @override
  double get median => scale * pow(2, 1 / shape).toDouble();

  @override
  double get mode => scale;

  @override
  double get variance => shape > 2
      ? shape * scale * scale / (pow(shape - 1, 2).toDouble() * (shape - 2))
      : (shape > 1 ? double.infinity : double.nan);

  @override
  double get skewness => shape > 3
      ? 2 * (1 + shape) / (shape - 3) * sqrt((shape - 2) / shape)
      : double.nan;

  @override
  double get excessKurtosis => shape > 4
      ? 6 *
            (pow(shape, 3).toDouble() +
                pow(shape, 2).toDouble() -
                6 * shape -
                2) /
            (shape * (shape - 3) * (shape - 4))
      : double.nan;

  @override
  double probability(double x) {
    if (x.isNaN) return double.nan;
    if (x < scale) return 0.0;
    if (shape <= 50.0 && scale <= 1e10 && x <= 1e10) {
      final numVal = shape * pow(scale, shape).toDouble();
      final denVal = pow(x, shape + 1).toDouble();
      if (numVal.isFinite && denVal.isFinite && denVal > 0.0) {
        return numVal / denVal;
      }
    }
    final logP = logProbability(x);
    if (logP.isNaN) return double.nan;
    if (logP <= -745.0) return 0.0;
    return exp(logP);
  }

  @override
  double logProbability(double x) {
    if (x.isNaN) return double.nan;
    if (x < scale) return double.negativeInfinity;
    return log(shape) + shape * log(scale) - (shape + 1) * log(x);
  }

  @override
  double cumulativeProbability(double x) =>
      x < scale ? 0.0 : 1.0 - pow(scale / x, shape).toDouble();

  @override
  double inverseCumulativeProbability(num probability) {
    InvalidProbability.check(probability);
    return scale / pow(1 - probability, 1 / shape).toDouble();
  }

  @override
  double sample({Random? random}) {
    final uniform = (random ?? _random).nextDouble();
    return scale / pow(1.0 - uniform, 1 / shape).toDouble();
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

final _random = Random();
