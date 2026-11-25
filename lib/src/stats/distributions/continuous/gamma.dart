import 'dart:math';

import 'package:more/printer.dart';

import '../../../special/gamma.dart';
import '../continuous.dart';
import '../errors.dart';
import '../utils.dart';
import 'normal.dart';

/// The gamma distribution with [shape] α > 0 and [scale] β > 0.
///
/// See https://en.wikipedia.org/wiki/Gamma_distribution.
class GammaDistribution extends ContinuousDistribution {
  /// A gamma distribution with parameters [shape] α and [scale] β.
  new(this.shape, this.scale) {
    if (!shape.isFinite || shape <= 0) {
      throw ArgumentError.value(shape, 'shape', 'Must be positive');
    }
    if (!scale.isFinite || scale <= 0) {
      throw ArgumentError.value(scale, 'scale', 'Must be positive');
    }
  }

  /// Creates a standard gamma distribution with given [shape] and unit scale 1.
  new shape(double shape) : this(shape, 1.0);

  /// Fits a gamma distribution to [samples] using method of moments.
  factory fit(Iterable<num> samples) {
    final stats = welfordSampleStats(
      samples,
      isValid: (value) => value > 0.0,
      invalidMessage: 'All samples must be positive',
      minCount: 2,
    );
    if (stats.variance <= 0.0) {
      return GammaDistribution(1e6, stats.mean / 1e6);
    }
    final scale = stats.variance / stats.mean;
    final shape = stats.mean / scale;
    return GammaDistribution(
      shape > 0.0 && shape.isFinite ? shape : 1.0,
      scale > 0.0 && scale.isFinite ? scale : 1.0,
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
  double get mode => shape > 1 ? (shape - 1) * scale : 0.0;

  @override
  double get variance => shape * scale * scale;

  @override
  double get skewness => 2.0 / sqrt(shape);

  @override
  double get excessKurtosis => 6.0 / shape;

  @override
  double probability(double x) {
    if (x.isNaN) return double.nan;
    if (x < 0.0 || x == double.infinity) return 0.0;
    if (x == 0.0) {
      if (shape < 1.0) return double.infinity;
      if (shape == 1.0) return 1.0 / scale;
      return 0.0;
    }
    return exp(logProbability(x));
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
    return (shape - 1.0) * log(x) -
        x / scale -
        gammaLn(shape) -
        shape * log(scale);
  }

  @override
  double cumulativeProbability(double x) {
    if (x.isNaN) return double.nan;
    return x <= 0.0 ? 0.0 : gammaP(shape, x / scale);
  }

  @override
  double survival(double x) {
    if (x.isNaN) return double.nan;
    return x <= 0.0 ? 1.0 : gammaQ(shape, x / scale);
  }

  @override
  double inverseCumulativeProbability(num probability) {
    InvalidProbability.check(probability);
    return gammaPInv(shape, probability) * scale;
  }

  @override
  double inverseSurvival(num probability) {
    InvalidProbability.check(probability);
    return gammaQInv(shape, probability) * scale;
  }

  @override
  double sample({Random? random}) {
    final rng = random ?? defaultRandom;
    const normal = NormalDistribution.standard();
    final correctedShape = shape < 1.0 ? shape + 1.0 : shape;
    double uSample, vVal, x, x2;
    final a1 = correctedShape - 1.0 / 3.0;
    final a2 = 1.0 / sqrt(9.0 * a1);
    do {
      do {
        x = normal.sample(random: rng);
        vVal = 1.0 + a2 * x;
      } while (vVal <= 0.0);
      vVal = vVal * vVal * vVal;
      x2 = x * x;
      uSample = rng.nextDouble();
    } while (uSample > 1.0 - 0.331 * x2 * x2 &&
        log(uSample) > 0.5 * x2 + a1 * (1.0 - vVal + log(vVal)));
    if (shape == correctedShape) {
      return a1 * vVal * scale;
    }
    final boost = nextOpenUnit(rng);
    return pow(boost, 1.0 / shape) * a1 * vVal * scale;
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
