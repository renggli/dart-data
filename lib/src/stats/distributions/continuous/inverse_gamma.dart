import 'dart:math';

import 'package:more/printer.dart';

import '../../../special/gamma.dart';
import '../continuous.dart';
import '../errors.dart';
import '../utils.dart';
import 'gamma.dart';

/// The inverse gamma distribution with [shape] α > 0 and [scale] β > 0.
///
/// See https://en.wikipedia.org/wiki/Inverse-gamma_distribution.
class InverseGammaDistribution extends ContinuousDistribution {
  /// An inverse gamma distribution with parameters [shape] α and [scale] β.
  new(this.shape, this.scale) {
    if (!shape.isFinite || shape <= 0) {
      throw ArgumentError.value(shape, 'shape', 'Must be positive');
    }
    if (!scale.isFinite || scale <= 0) {
      throw ArgumentError.value(scale, 'scale', 'Must be positive');
    }
  }

  /// Fits an inverse gamma distribution to positive [samples] using method of
  /// moments.
  factory fit(Iterable<num> samples) {
    final stats = welfordSampleStats(
      samples,
      isValid: (value) => value > 0.0,
      invalidMessage:
          'Inverse gamma samples must be strictly positive and finite',
      minCount: 2,
    );
    final mean = stats.mean;
    var shape = stats.variance > 1e-12
        ? (mean * mean / stats.variance + 2.0)
        : 3.0;
    if (shape <= 0.0 || !shape.isFinite) shape = 3.0;
    var scale = mean * (shape - 1.0);
    if (scale <= 0.0 || !scale.isFinite) scale = 1.0;
    return InverseGammaDistribution(shape, scale);
  }

  /// The shape parameter α.
  final double shape;

  /// The scale parameter β.
  final double scale;

  @override
  double get lowerBound => 0.0;

  @override
  double get mean => shape > 1.0 ? scale / (shape - 1.0) : double.nan;

  @override
  double get mode => scale / (shape + 1.0);

  @override
  double get variance => shape > 2.0
      ? (scale * scale) / ((shape - 1.0) * (shape - 1.0) * (shape - 2.0))
      : double.nan;

  @override
  double get skewness =>
      shape > 3.0 ? 4.0 * sqrt(shape - 2.0) / (shape - 3.0) : double.nan;

  @override
  double get excessKurtosis => shape > 4.0
      ? 6.0 * (5.0 * shape - 11.0) / ((shape - 3.0) * (shape - 4.0))
      : double.nan;

  @override
  double probability(double x) {
    if (x.isNaN) return double.nan;
    if (x <= 0.0 || x == double.infinity) return 0.0;
    return exp(logProbability(x));
  }

  @override
  double logProbability(double x) {
    if (x.isNaN) return double.nan;
    if (x <= 0.0 || x == double.infinity) return double.negativeInfinity;
    return -(shape + 1.0) * log(x) -
        scale / x -
        gammaLn(shape) +
        shape * log(scale);
  }

  @override
  double cumulativeProbability(double x) {
    if (x.isNaN) return double.nan;
    if (x <= 0.0) return 0.0;
    if (x == double.infinity) return 1.0;
    return gammaQ(shape, scale / x);
  }

  @override
  double survival(double x) {
    if (x.isNaN) return double.nan;
    if (x <= 0.0) return 1.0;
    if (x == double.infinity) return 0.0;
    return gammaP(shape, scale / x);
  }

  @override
  double inverseCumulativeProbability(num probability) {
    InvalidProbability.check(probability);
    if (probability == 0.0) return 0.0;
    if (probability == 1.0) return double.infinity;
    return scale / gammaQInv(shape, probability);
  }

  @override
  double inverseSurvival(num probability) {
    InvalidProbability.check(probability);
    if (probability == 0.0) return double.infinity;
    if (probability == 1.0) return 0.0;
    return scale / gammaPInv(shape, probability);
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
    ..addValue(shape, name: 'α')
    ..addValue(scale, name: 'β');
}
