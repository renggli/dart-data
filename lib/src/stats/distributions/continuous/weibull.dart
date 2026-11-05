import 'dart:math';

import 'package:more/printer.dart';

import '../../../special/gamma.dart';
import '../continuous.dart';
import '../errors.dart';
import 'uniform.dart';

/// The Weibull distribution.
///
/// See https://en.wikipedia.org/wiki/Weibull_distribution.
///
/// ```dart
/// final distribution = WeibullDistribution(1, 1);
/// print(distribution.mean);  // 1.0
/// ```
class WeibullDistribution extends ContinuousDistribution {
  /// A weibull distribution with parameters [shape] k and [scale] λ.
  new(this.shape, this.scale) {
    if (!shape.isFinite || shape <= 0) {
      throw ArgumentError.value(shape, 'shape', 'Shape must be positive');
    }
    if (!scale.isFinite || scale <= 0) {
      throw ArgumentError.value(scale, 'scale', 'Scale must be positive');
    }
  }

  /// A standard weibull distribution with shape 1 and scale 1.
  const new standard() : this._(1.0, 1.0);

  const new _(this.shape, this.scale);

  /// Fits a Weibull distribution to positive [samples] using log-moments estimation.
  factory fit(Iterable<num> samples) {
    var count = 0;
    var sumLog = 0.0;
    final logVals = <double>[];
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
      logVals.add(lVal);
      sumLog += lVal;
      count++;
    }
    if (count == 0) {
      throw ArgumentError.value(samples, 'samples', 'Cannot fit empty samples');
    }
    final meanLog = sumLog / count;
    var sumSq = 0.0;
    for (final lVal in logVals) {
      final diff = lVal - meanLog;
      sumSq += diff * diff;
    }
    final varLog = count > 1 ? sumSq / (count - 1) : 0.0;
    final stdLog = sqrt(varLog);
    var shape = stdLog > 1e-12 ? (pi / (sqrt(6.0) * stdLog)) : 1.0;
    if (shape <= 0.0 || !shape.isFinite) shape = 1.0;
    const eulerGamma = 0.5772156649015329;
    var scale = exp(meanLog + eulerGamma / shape);
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
  double get mean => scale * gamma(1 + 1 / shape);

  @override
  double get median => scale * pow(ln2, 1 / shape);

  @override
  double get mode =>
      shape > 1 ? scale * pow((shape - 1) / shape, 1 / shape) : 0;

  @override
  double get variance =>
      scale * scale * (gamma(1 + 2 / shape) - pow(gamma(1 + 1 / shape), 2));

  @override
  double get skewness {
    final mu = mean, tau = standardDeviation;
    return (gamma(1 + 3 / shape) * pow(scale, 3) -
            3 * mu * pow(tau, 2) -
            pow(mu, 3)) /
        pow(tau, 3);
  }

  @override
  double get excessKurtosis {
    final g1 = gamma(1 + 1 / shape);
    final g2 = gamma(1 + 2 / shape);
    final g3 = gamma(1 + 3 / shape);
    final g4 = gamma(1 + 4 / shape);
    final mu = scale * g1;
    final sigma2 = scale * scale * (g2 - g1 * g1);
    return (g4 * pow(scale, 4) -
                4 * g3 * pow(scale, 3) * mu +
                6 * g2 * scale * scale * mu * mu -
                3 * pow(mu, 4)) /
            (sigma2 * sigma2) -
        3;
  }

  @override
  double probability(double x) {
    if (x.isNaN) return double.nan;
    if (x < 0 || x == double.infinity) return 0;
    final logP = logProbability(x);
    if (logP.isNaN) return double.nan;
    if (logP <= -745.0) return 0.0;
    return exp(logP);
  }

  @override
  double logProbability(double x) {
    if (x.isNaN) return double.nan;
    if (x <= 0 || x == double.infinity) return double.negativeInfinity;
    final xOverScale = x / scale;
    final term = pow(xOverScale, shape).toDouble();
    if (term.isInfinite) return double.negativeInfinity;
    return log(shape) - log(scale) + (shape - 1) * log(xOverScale) - term;
  }

  @override
  double cumulativeProbability(double x) =>
      x < 0 ? 0 : 1 - exp(-pow(x / scale, shape));

  @override
  double inverseCumulativeProbability(num probability) {
    InvalidProbability.check(probability);
    return scale * pow(-log(1 - probability), 1 / shape);
  }

  @override
  double sample({Random? random}) {
    const uniform = UniformDistribution.standard();
    return scale * pow(-log(1.0 - uniform.sample(random: random)), 1 / shape);
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
