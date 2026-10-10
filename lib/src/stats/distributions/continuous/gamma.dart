import 'dart:math';

import 'package:more/printer.dart';

import '../../../special/gamma.dart';
import '../continuous.dart';
import '../errors.dart';
import 'normal.dart';
import 'uniform.dart';

/// The gamma distribution.
///
/// See https://en.wikipedia.org/wiki/Gamma_distribution.
class GammaDistribution extends ContinuousDistribution {
  /// A gamma distribution with parameters [shape] α and [scale] β.
  const new(this.shape, this.scale)
    : assert(shape > 0, 'α > 0'),
      assert(scale > 0, 'β > 0');

  /// Creates a standard gamma distribution with given [shape] and unit scale 1.
  const new shape(double shape) : this(shape, 1.0);

  /// Fits a gamma distribution to [samples] using method of moments.
  factory fit(Iterable<num> samples) {
    var count = 0;
    var sum = 0.0;
    for (final x in samples) {
      if (x <= 0) {
        throw ArgumentError.value(x, 'samples', 'All samples must be positive');
      }
      count++;
      sum += x;
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
      final diff = x - mean;
      sumSqDiff += diff * diff;
    }
    final variance = sumSqDiff / (count - 1);
    final scale = variance / mean;
    final shape = mean / scale;
    return GammaDistribution(
      shape > 0 ? shape : 1e-6,
      scale > 0 ? scale : 1e-6,
    );
  }

  /// The shape parameter α.
  final double shape;

  /// The scale parameter β.
  final double scale;

  @override
  double get lowerBound => 0.0;

  @override
  double get mean => shape * scale;

  @override
  double get median => double.nan;

  @override
  double get mode => shape > 1 ? (shape - 1) * scale : 0.0;

  @override
  double get variance => shape * scale * scale;

  @override
  double get skewness => 2.0 / sqrt(shape);

  @override
  double get excessKurtosis => 6.0 / shape;

  @override
  double probability(double x) => x <= 0.0
      ? 0.0
      : exp(
          (shape - 1.0) * log(x) -
              x / scale -
              gammaLn(shape) -
              shape * log(scale),
        );

  @override
  double cumulativeProbability(double x) =>
      x <= 0.0 ? 0.0 : lowRegGamma(shape, x / scale);

  @override
  double inverseCumulativeProbability(num probability) {
    InvalidProbability.check(probability);
    return gammapInv(probability, shape) * scale;
  }

  @override
  double sample({Random? random}) {
    const normal = NormalDistribution.standard();
    const uniform = UniformDistribution.standard();
    final correctedShape = shape < 1.0 ? shape + 1.0 : shape;
    double uSample, vVal, x;
    final a1 = correctedShape - 1.0 / 3.0;
    final a2 = 1.0 / sqrt(9.0 * a1);
    do {
      do {
        x = normal.sample(random: random);
        vVal = 1.0 + a2 * x;
      } while (vVal <= 0.0);
      vVal = vVal * vVal * vVal;
      uSample = uniform.sample(random: random);
    } while (uSample > 1.0 - 0.331 * pow(x, 4) &&
        log(uSample) > 0.5 * x * x + a1 * (1.0 - vVal + log(vVal)));
    if (shape == correctedShape) {
      return a1 * vVal * scale;
    }
    do {
      uSample = uniform.sample(random: random);
    } while (uSample == 0.0);
    return pow(uSample, 1.0 / shape) * a1 * vVal * scale;
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
    ..addValue(shape, name: 'α')
    ..addValue(scale, name: 'β');
}
