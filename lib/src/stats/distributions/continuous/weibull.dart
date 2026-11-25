import 'dart:math';

import 'package:more/printer.dart';

import '../../../special/gamma.dart';
import '../../../special/utils.dart';
import '../continuous.dart';
import '../errors.dart';
import '../utils.dart';

/// The Weibull distribution with [shape] k > 0 and [scale] λ > 0.
///
/// See https://en.wikipedia.org/wiki/Weibull_distribution.
///
/// ```dart
/// final distribution = WeibullDistribution(1, 1);
/// print(distribution.mean);  // 1.0
/// ```
class WeibullDistribution extends ContinuousDistribution {
  /// A Weibull distribution with parameters [shape] k and [scale] λ.
  new(this.shape, this.scale) {
    if (!shape.isFinite || shape <= 0) {
      throw ArgumentError.value(shape, 'shape', 'Shape must be positive');
    }
    if (!scale.isFinite || scale <= 0) {
      throw ArgumentError.value(scale, 'scale', 'Scale must be positive');
    }
  }

  /// A standard Weibull distribution with shape 1 and scale 1.
  const new standard() : this._(1.0, 1.0);

  const new _(this.shape, this.scale);

  /// Fits a Weibull distribution to positive [samples] using log-moments
  /// estimation.
  factory fit(Iterable<num> samples) {
    var count = 0;
    var meanLog = 0.0;
    var m2 = 0.0;
    for (final x in samples) {
      final val = x.toDouble();
      if (!val.isFinite || val <= 0.0) {
        throw ArgumentError.value(
          x,
          'samples',
          'Weibull samples must be positive and finite',
        );
      }
      final lVal = log(val);
      count++;
      final delta = lVal - meanLog;
      meanLog += delta / count;
      m2 += delta * (lVal - meanLog);
    }
    if (count == 0) {
      throw ArgumentError.value(samples, 'samples', 'Cannot fit empty samples');
    }
    final varLog = count > 1 ? m2 / (count - 1) : 0.0;
    final stdLog = sqrt(varLog);
    var shape = stdLog > 1e-12 ? (pi / (sqrt(6.0) * stdLog)) : 1.0;
    if (shape <= 0.0 || !shape.isFinite) shape = 1.0;
    var scale = exp(meanLog + eulerMascheroni / shape);
    if (scale <= 0.0 || !scale.isFinite) scale = 1.0;
    return WeibullDistribution(shape, scale);
  }

  /// The shape parameter k.
  final double shape;

  /// The scale parameter λ.
  final double scale;

  @override
  double get lowerBound => 0.0;

  @override
  bool get isLowerBoundOpen => false;

  @override
  double get mean => scale * gamma(1.0 + 1.0 / shape);

  @override
  double get median => scale * pow(ln2, 1.0 / shape);

  @override
  double get mode =>
      shape > 1.0 ? scale * pow((shape - 1.0) / shape, 1.0 / shape) : 0.0;

  @override
  double get variance {
    final g1 = gamma(1.0 + 1.0 / shape);
    final g2 = gamma(1.0 + 2.0 / shape);
    return scale * scale * (g2 - g1 * g1);
  }

  @override
  double get skewness {
    final g1 = gamma(1.0 + 1.0 / shape);
    final g2 = gamma(1.0 + 2.0 / shape);
    final g3 = gamma(1.0 + 3.0 / shape);
    final sigma2 = g2 - g1 * g1;
    final sigma = sqrt(sigma2);
    return (g3 - 3.0 * g1 * g2 + 2.0 * g1 * g1 * g1) / (sigma2 * sigma);
  }

  @override
  double get excessKurtosis {
    final g1 = gamma(1.0 + 1.0 / shape);
    final g2 = gamma(1.0 + 2.0 / shape);
    final g3 = gamma(1.0 + 3.0 / shape);
    final g4 = gamma(1.0 + 4.0 / shape);
    final g1Sq = g1 * g1;
    final sigma2 = g2 - g1Sq;
    return (g4 - 4.0 * g3 * g1 + 6.0 * g2 * g1Sq - 3.0 * g1Sq * g1Sq) /
            (sigma2 * sigma2) -
        3.0;
  }

  @override
  double probability(double x) {
    if (x.isNaN) return double.nan;
    if (x < 0.0 || x == double.infinity) return 0.0;
    if (x == 0.0) {
      if (shape < 1.0) return double.infinity;
      if (shape == 1.0) return 1.0 / scale;
      return 0.0;
    }
    final logP = logProbability(x);
    if (logP <= -745.0) return 0.0;
    return exp(logP);
  }

  @override
  double logProbability(double x) {
    if (x.isNaN) return double.nan;
    if (x < 0.0 || x == double.infinity) return double.negativeInfinity;
    if (x == 0.0) {
      if (shape < 1.0) return double.infinity;
      if (shape == 1.0) return -log(scale);
      return double.negativeInfinity;
    }
    final xOverScale = x / scale;
    final term = pow(xOverScale, shape).toDouble();
    if (term.isInfinite) return double.negativeInfinity;
    return log(shape) - log(scale) + (shape - 1.0) * log(xOverScale) - term;
  }

  @override
  double cumulativeProbability(double x) {
    if (x.isNaN) return double.nan;
    if (x <= 0.0) return 0.0;
    return -expm1(-pow(x / scale, shape).toDouble());
  }

  @override
  double survival(double x) {
    if (x.isNaN) return double.nan;
    if (x <= 0.0) return 1.0;
    return exp(-pow(x / scale, shape).toDouble());
  }

  @override
  double inverseCumulativeProbability(num probability) {
    InvalidProbability.check(probability);
    if (probability == 0.0) return 0.0;
    if (probability == 1.0) return double.infinity;
    return scale * pow(-log1p(-probability.toDouble()), 1.0 / shape).toDouble();
  }

  @override
  double inverseSurvival(num probability) {
    InvalidProbability.check(probability);
    if (probability == 0.0) return double.infinity;
    if (probability == 1.0) return 0.0;
    return scale * pow(-log(probability.toDouble()), 1.0 / shape).toDouble();
  }

  @override
  double sample({Random? random}) {
    final uniform = nextOpenUnit(random ?? defaultRandom);
    return scale * pow(-log(uniform), 1.0 / shape).toDouble();
  }

  @override
  bool operator ==(Object other) =>
      other is WeibullDistribution &&
      shape == other.shape &&
      scale == other.scale;

  @override
  int get hashCode => Object.hash(WeibullDistribution, shape, scale);

  @override
  ObjectPrinter get toStringPrinter => super.toStringPrinter
    ..addValue(shape, name: 'shape')
    ..addValue(scale, name: 'scale');
}
