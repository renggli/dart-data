import 'dart:math';

import 'package:more/interval.dart';
import 'package:more/printer.dart';

import '../../../special/gamma.dart';
import '../continuous.dart';
import '../errors.dart';
import 'gamma.dart';

/// The inverse gamma distribution.
///
/// See https://en.wikipedia.org/wiki/Inverse-gamma_distribution.
class InverseGammaDistribution extends ContinuousDistribution {
  /// An inverse gamma distribution with parameters [shape] α and [scale] β.
  const InverseGammaDistribution(this.shape, this.scale)
      : assert(shape > 0, 'shape > 0'),
        assert(scale > 0, 'scale > 0');

  /// The shape parameter α.
  final double shape;

  /// The scale parameter β.
  final double scale;

  @override
  Interval<double> get support => Interval<double>.greaterThan(0.0);

  @override
  double get mean => shape > 1 ? scale / (shape - 1) : double.nan;

  @override
  double get median => throw UnsupportedError('No simple closed form');

  @override
  double get mode => scale / (shape + 1);

  @override
  double get variance => shape > 2
      ? scale * scale / (shape - 1) / (shape - 1) / (shape - 2)
      : double.nan;

  @override
  double get skewness =>
      shape > 3 ? 4 * sqrt(shape - 2) / (shape - 3) : double.nan;

  @override
  double get kurtosisExcess =>
      shape > 4 ? 6 * (5 * shape - 11) / (shape - 3) / (shape - 4) : double.nan;

  @override
  double probability(double x) => x <= 0
      ? 0
      : exp(-(shape + 1) * log(x) -
          scale / x -
          gammaLn(shape) +
          shape * log(scale));

  @override
  double cumulativeProbability(double x) =>
      x <= 0 ? 0 : 1 - lowRegGamma(shape, scale / x);

  @override
  double inverseCumulativeProbability(num p) {
    InvalidProbability.check(p);
    return scale / gammapInv(1 - p, shape);
  }

  @override
  double sample({Random? random}) {
    final gamma = GammaDistribution.shape(shape);
    return scale / gamma.sample(random: random);
  }

  @override
  bool operator ==(Object other) =>
      other is InverseGammaDistribution &&
      shape == other.shape &&
      scale == other.scale;

  @override
  int get hashCode => Object.hash(InverseGammaDistribution, shape, scale);

  @override
  ObjectPrinter get toStringPrinter => super.toStringPrinter
    ..addValue(shape, name: 'shape')
    ..addValue(scale, name: 'scale');
}
