import 'dart:math';

import 'package:more/printer.dart';

import '../../../special/utils.dart';
import '../continuous.dart';
import '../errors.dart';
import '../utils.dart';

/// The Logistic distribution is a continuous probability distribution
/// parameterized by its [location] and [scale] parameters. Its cumulative
/// distribution function is the logistic function.
///
/// See https://en.wikipedia.org/wiki/Logistic_distribution.
///
/// ```dart
/// final distribution = LogisticDistribution(0, 1);
/// print(distribution.mean);  // 0.0
/// ```
class LogisticDistribution extends ContinuousDistribution {
  /// A Logistic distribution with [location] and [scale].
  new([this.location = 0.0, this.scale = 1.0]) {
    if (!location.isFinite) {
      throw ArgumentError.value(
        location,
        'location',
        'Location must be finite',
      );
    }
    if (!scale.isFinite || scale <= 0) {
      throw ArgumentError.value(scale, 'scale', 'Scale must be positive');
    }
  }

  /// A standard Logistic distribution with location 0 and scale 1.
  const new standard() : this._(0.0, 1.0);

  const new _(this.location, this.scale);

  /// Fits a Logistic distribution to [samples] using the method of moments.
  factory fit(Iterable<num> samples) {
    final stats = welfordSampleStats(samples);
    var scale = (sqrt(3.0) / pi) * sqrt(stats.variance);
    if (scale <= 0.0 || !scale.isFinite) {
      scale = 1.0;
    }
    return LogisticDistribution(stats.mean, scale);
  }

  /// The location parameter.
  final double location;

  /// The scale parameter.
  final double scale;

  @override
  double get lowerBound => double.negativeInfinity;

  @override
  double get upperBound => double.infinity;

  @override
  double get mean => location;

  @override
  double get median => location;

  @override
  double get mode => location;

  @override
  double get variance => pi * pi * scale * scale / 3;

  @override
  double get skewness => 0;

  @override
  double get excessKurtosis => 1.2;

  @override
  double probability(double x) {
    if (x.isNaN) return double.nan;
    if (x.isInfinite) return 0.0;
    final z = (x - location) / scale;
    final ez = exp(-z.abs());
    return ez / (scale * (1.0 + ez) * (1.0 + ez));
  }

  @override
  double logProbability(double x) {
    if (x.isNaN) return double.nan;
    if (x.isInfinite) return double.negativeInfinity;
    final az = (x - location).abs() / scale;
    return -az - log(scale) - 2.0 * log1p(exp(-az));
  }

  @override
  double cumulativeProbability(double x) {
    if (x.isNaN) return double.nan;
    final z = (x - location) / scale;
    if (z >= 0.0) {
      return 1.0 / (1.0 + exp(-z));
    }
    final ez = exp(z);
    return ez / (1.0 + ez);
  }

  @override
  double survival(double x) {
    if (x.isNaN) return double.nan;
    final z = (x - location) / scale;
    if (z >= 0.0) {
      final emz = exp(-z);
      return emz / (1.0 + emz);
    }
    return 1.0 / (1.0 + exp(z));
  }

  @override
  double inverseCumulativeProbability(num probability) {
    InvalidProbability.check(probability);
    if (probability == 0) return double.negativeInfinity;
    if (probability == 1) return double.infinity;
    final pd = probability.toDouble();
    return location + scale * log(pd / (1.0 - pd));
  }

  @override
  double inverseSurvival(num probability) {
    InvalidProbability.check(probability);
    if (probability == 0) return double.infinity;
    if (probability == 1) return double.negativeInfinity;
    final pd = probability.toDouble();
    return location - scale * log(pd / (1.0 - pd));
  }

  @override
  double sample({Random? random}) {
    final uniform = nextOpenUnit(random ?? defaultRandom);
    return inverseCumulativeProbability(uniform);
  }

  @override
  bool operator ==(Object other) =>
      other is LogisticDistribution &&
      location == other.location &&
      scale == other.scale;

  @override
  int get hashCode => Object.hash(LogisticDistribution, location, scale);

  @override
  ObjectPrinter get toStringPrinter => super.toStringPrinter
    ..addValue(location, name: 'location')
    ..addValue(scale, name: 'scale');
}
