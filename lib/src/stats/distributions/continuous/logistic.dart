import 'dart:math';

import 'package:more/printer.dart';

import '../continuous.dart';
import '../errors.dart';

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
    if (scale <= 0) {
      throw ArgumentError.value(scale, 'scale', 'Scale must be positive');
    }
  }

  /// A standard Logistic distribution with location 0 and scale 1.
  const new standard() : this._(0.0, 1.0);

  const new _(this.location, this.scale);

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
    final z = (x - location) / scale;
    final ez = exp(-z.abs());
    return ez / (scale * pow(1 + ez, 2));
  }

  @override
  double cumulativeProbability(double x) {
    final z = (x - location) / scale;
    return 1 / (1 + exp(-z));
  }

  @override
  double inverseCumulativeProbability(num probability) {
    InvalidProbability.check(probability);
    if (probability == 0) return double.negativeInfinity;
    if (probability == 1) return double.infinity;
    return location + scale * log(probability / (1 - probability));
  }

  @override
  double sample({Random? random}) {
    final uniform = (random ?? _random).nextDouble();
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

final _random = Random();
