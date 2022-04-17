import 'dart:math';

import 'package:more/printer.dart';

import '../../../special/gamma.dart';
import '../continuous.dart';
import 'uniform.dart';

/// The Weibull distribution.
///
/// See https://en.wikipedia.org/wiki/Weibull_distribution
class WeibullDistribution extends ContinuousDistribution {
  /// A weibull distribution with parameters [scale] λ and [shape] k.
  const WeibullDistribution(this.scale, this.shape)
      : assert(scale > 0, 'λ > 0'),
        assert(shape > 0, 'k > 0');

  /// The scale parameter λ.
  final double scale;

  /// The shape parameter k.
  final double shape;

  @override
  double get lowerBound => 0;

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
  double get kurtosisExcess => throw UnimplementedError();

  @override
  double probability(double x) => x < 0
      ? 0
      : shape / scale * pow(x / scale, shape - 1) * exp(-pow(x / scale, shape));

  @override
  double cumulativeProbability(double x) =>
      x < 0 ? 0 : 1 - exp(-pow(x / scale, shape));

  @override
  double inverseCumulativeProbability(num p) =>
      scale * pow(-log(1 - p), 1 / shape);

  @override
  double sample({Random? random}) {
    const uniform = UniformDistribution.standard();
    return scale * pow(-log(uniform.sample(random: random)), 1 / shape);
  }

  @override
  bool operator ==(Object other) =>
      other is WeibullDistribution &&
      scale == other.scale &&
      shape == other.shape;

  @override
  int get hashCode => Object.hash(WeibullDistribution, scale, shape);

  @override
  ObjectPrinter get toStringPrinter => super.toStringPrinter
    ..addValue(scale, name: 'λ')
    ..addValue(shape, name: 'k');
}
