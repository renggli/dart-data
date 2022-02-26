import 'dart:math';

import '../../../special/gamma.dart';
import '../continuous.dart';
import '../errors.dart';
import 'normal.dart';
import 'uniform.dart';

/// The gamma distribution.
///
/// For details see https://en.wikipedia.org/wiki/Gamma-distribution
class GammaDistribution extends ContinuousDistribution {
  const GammaDistribution(this.shape, this.scale)
      : assert(shape > 0.0, 'shape > 0.0'),
        assert(scale > 0.0, 'scale > 0.0');

  factory GammaDistribution.shape(double shape) =>
      GammaDistribution(shape, 1.0);

  /// The shape parameter.
  final double shape;

  /// The scale parameter.
  final double scale;

  @override
  double get lowerBound => 0.0;

  @override
  double get mean => shape * scale;

  @override
  double get median => throw UnsupportedError('No simple closed form');

  @override
  double get mode => shape > 1.0 ? (shape - 1.0) * scale : double.nan;

  @override
  double get variance => shape * scale * scale;

  @override
  double probability(double x) => x < 0.0
      ? 0.0
      : exp((shape - 1.0) * log(x) -
          x / scale -
          gammaLn(shape) -
          shape * log(scale));

  @override
  double cumulativeProbability(double x) =>
      x < 0.0 ? 0.0 : lowRegGamma(shape, x / scale);

  @override
  double inverseCumulativeProbability(num p) {
    InvalidProbability.check(p);
    return gammapInv(p, shape) * scale;
  }

  @override
  double sample({Random? random}) {
    const normal = NormalDistribution.standard();
    const uniform = UniformDistribution.standard();
    final correctedShape = shape < 1.0 ? shape + 1.0 : shape;
    double u, v, x;
    final a1 = correctedShape - 1.0 / 3.0;
    final a2 = 1.0 / sqrt(9.0 * a1);
    do {
      do {
        x = normal.sample(random: random);
        v = 1.0 + a2 * x;
      } while (v <= 0.0);
      v = v * v * v;
      u = uniform.sample(random: random);
    } while (u > 1.0 - 0.331 * pow(x, 4.0) &&
        log(u) > 0.5 * x * x + a1 * (1.0 - v + log(v)));
    if (shape == correctedShape) {
      return a1 * v * scale;
    }
    do {
      u = uniform.sample(random: random);
    } while (u == 0.0);
    return pow(u, 1.0 / shape) * a1 * v * scale;
  }

  @override
  bool operator ==(Object other) =>
      other is GammaDistribution &&
      shape == other.shape &&
      scale == other.scale;

  @override
  int get hashCode => Object.hash(GammaDistribution, shape, scale);

  @override
  String toString() => 'GammaDistribution{shape: $shape; scale: $scale}';
}
