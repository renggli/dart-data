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
    return shape /
        scale *
        pow(x / scale, shape - 1) *
        exp(-pow(x / scale, shape));
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
