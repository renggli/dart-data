import 'dart:math';

import 'package:more/printer.dart';

import '../../../special/gamma.dart';
import '../continuous.dart';
import '../errors.dart';
import 'normal.dart';
import 'uniform.dart';

/// The gamma distribution.
///
/// See https://en.wikipedia.org/wiki/Gamma-distribution
class GammaDistribution extends ContinuousDistribution {
  /// A gamma distribution with parameters [shape] k and [scale] θ.
  const GammaDistribution(this.shape, this.scale)
      : assert(shape > 0, 'shape > 0'),
        assert(scale > 0, 'scale > 0');

  factory GammaDistribution.shape(double shape) => GammaDistribution(shape, 1);

  /// The shape parameter k.
  final double shape;

  /// The scale parameter θ.
  final double scale;

  @override
  double get lowerBound => double.minPositive;

  @override
  double get mean => shape * scale;

  @override
  double get median => throw UnsupportedError('No simple closed form');

  @override
  double get mode => shape > 1 ? (shape - 1) * scale : double.nan;

  @override
  double get variance => shape * scale * scale;

  @override
  double get skewness => 2 / sqrt(shape);

  @override
  double get kurtosisExcess => 6 / shape;

  @override
  double probability(double x) => x < 0
      ? 0
      : exp((shape - 1) * log(x) -
          x / scale -
          gammaLn(shape) -
          shape * log(scale));

  @override
  double cumulativeProbability(double x) =>
      x < 0 ? 0 : lowRegGamma(shape, x / scale);

  @override
  double inverseCumulativeProbability(num p) {
    InvalidProbability.check(p);
    return gammapInv(p, shape) * scale;
  }

  @override
  double sample({Random? random}) {
    const normal = NormalDistribution.standard();
    const uniform = UniformDistribution.standard();
    final correctedShape = shape < 1 ? shape + 1 : shape;
    double u, v, x;
    final a1 = correctedShape - 1 / 3;
    final a2 = 1 / sqrt(9 * a1);
    do {
      do {
        x = normal.sample(random: random);
        v = 1 + a2 * x;
      } while (v <= 0);
      v = v * v * v;
      u = uniform.sample(random: random);
    } while (u > 1 - 0.331 * pow(x, 4) &&
        log(u) > 0.5 * x * x + a1 * (1 - v + log(v)));
    if (shape == correctedShape) {
      return a1 * v * scale;
    }
    do {
      u = uniform.sample(random: random);
    } while (u == 0);
    return pow(u, 1 / shape) * a1 * v * scale;
  }

  @override
  bool operator ==(Object other) =>
      other is GammaDistribution &&
      shape == other.shape &&
      scale == other.scale;

  @override
  int get hashCode => Object.hash(GammaDistribution, shape, scale);

  @override
  ObjectPrinter get toStringPrinter => super.toStringPrinter
    ..addValue(shape, name: 'shape')
    ..addValue(scale, name: 'scale');
}
