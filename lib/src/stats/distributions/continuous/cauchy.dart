import 'dart:math';

import 'package:more/printer.dart';

import '../continuous.dart';
import '../errors.dart';

/// The Cauchy distribution, also called the Lorentz distribution, is a
/// continuous probability distribution parameterized by [location] parameter
/// and [scale] parameter (γ).
///
/// See https://en.wikipedia.org/wiki/Cauchy_distribution.
///
/// ```dart
/// final distribution = CauchyDistribution(0, 1);
/// print(distribution.median);  // 0.0
/// ```
class CauchyDistribution extends ContinuousDistribution {
  /// A Cauchy distribution with [location] and [scale].
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

  /// A standard Cauchy distribution with location 0 and scale 1.
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
  double get mean => double.nan;

  @override
  double get median => location;

  @override
  double get mode => location;

  @override
  double get variance => double.nan;

  @override
  double get skewness => double.nan;

  @override
  double get excessKurtosis => double.nan;

  @override
  double probability(double x) =>
      1 / (pi * scale * (1 + pow((x - location) / scale, 2)));

  @override
  double cumulativeProbability(double x) =>
      atan((x - location) / scale) / pi + 0.5;

  @override
  double inverseCumulativeProbability(num probability) {
    InvalidProbability.check(probability);
    if (probability == 0) return double.negativeInfinity;
    if (probability == 1) return double.infinity;
    return location + scale * tan(pi * (probability - 0.5));
  }

  @override
  double sample({Random? random}) {
    final uniform = (random ?? _random).nextDouble();
    return location + scale * tan(pi * (uniform - 0.5));
  }

  @override
  bool operator ==(Object other) =>
      other is CauchyDistribution &&
      location == other.location &&
      scale == other.scale;

  @override
  int get hashCode => Object.hash(CauchyDistribution, location, scale);

  @override
  ObjectPrinter get toStringPrinter => super.toStringPrinter
    ..addValue(location, name: 'location')
    ..addValue(scale, name: 'scale');
}

final _random = Random();
