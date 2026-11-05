import 'dart:math';

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
  new(this.shape, this.scale) {
    if (!shape.isFinite || shape <= 0) {
      throw ArgumentError.value(shape, 'shape', 'Must be positive');
    }
    if (!scale.isFinite || scale <= 0) {
      throw ArgumentError.value(scale, 'scale', 'Must be positive');
    }
  }

  /// Fits an inverse gamma distribution to positive [samples] using method of moments.
  factory fit(Iterable<num> samples) {
    var count = 0;
    var sum = 0.0;
    for (final x in samples) {
      final val = x.toDouble();
      if (!val.isFinite || val <= 0.0) {
        throw ArgumentError.value(
          x,
          'samples',
          'Inverse gamma samples must be strictly positive and finite',
        );
      }
      count++;
      sum += val;
    }
    if (count < 2) {
      throw ArgumentError.value(
        samples,
        'samples',
        'At least 2 samples required',
      );
    }
    final mean = sum / count;
    var sumSqDiff = 0.0;
    for (final x in samples) {
      final diff = x.toDouble() - mean;
      sumSqDiff += diff * diff;
    }
    final variance = sumSqDiff / (count - 1);
    var shape = variance > 1e-12 ? (mean * mean / variance + 2.0) : 3.0;
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
  double probability(double x) => x <= 0.0
      ? 0.0
      : exp(
          -(shape + 1.0) * log(x) -
              scale / x -
              gammaLn(shape) +
              shape * log(scale),
        );

  @override
  double cumulativeProbability(double x) =>
      x <= 0.0 ? 0.0 : gammaq(shape, scale / x);

  @override
  double inverseCumulativeProbability(num probability) {
    InvalidProbability.check(probability);
    return scale / gammapInv(1.0 - probability, shape);
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
