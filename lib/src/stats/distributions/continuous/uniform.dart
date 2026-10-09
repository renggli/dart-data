import 'dart:math';

import 'package:more/printer.dart';

import '../continuous.dart';
import '../errors.dart';

/// Continuous uniform distribution between [min] and [max].
///
/// See https://en.wikipedia.org/wiki/Continuous_uniform_distribution.
class UniformDistribution extends ContinuousDistribution {
  /// Creates a continuous uniform distribution with bounds [min] and [max].
  const new(this.min, this.max) : assert(min < max, 'min < max');

  /// Creates a standard uniform distribution on [0, 1].
  const new standard() : this(0.0, 1.0);

  /// Fits a uniform distribution to [samples] using minimum and maximum values.
  factory fit(Iterable<num> samples) {
    if (samples.isEmpty) {
      throw ArgumentError.value(samples, 'samples', 'Cannot fit empty samples');
    }
    var minVal = double.infinity;
    var maxVal = double.negativeInfinity;
    for (final x in samples) {
      final val = x.toDouble();
      if (val < minVal) minVal = val;
      if (val > maxVal) maxVal = val;
    }
    if (minVal == maxVal) {
      maxVal = minVal + 1.0;
    }
    return UniformDistribution(minVal, maxVal);
  }

  /// Minimum value of the distribution.
  final double min;

  /// Maximum value of the distribution.
  final double max;

  @override
  double get lowerBound => min;

  @override
  bool get isLowerBoundOpen => false;

  @override
  double get upperBound => max;

  @override
  bool get isUpperBoundOpen => false;

  @override
  double get mean => 0.5 * (min + max);

  @override
  double get median => mean;

  @override
  double get mode => double.nan;

  @override
  double get variance => (max - min) * (max - min) / 12.0;

  @override
  double get skewness => 0.0;

  @override
  double get excessKurtosis => -1.2;

  @override
  double probability(double x) =>
      (min <= x && x <= max) ? 1.0 / (max - min) : 0.0;

  @override
  double cumulativeProbability(double x) {
    if (x < min) {
      return 0.0;
    } else if (x > max) {
      return 1.0;
    } else {
      return (x - min) / (max - min);
    }
  }

  @override
  double inverseCumulativeProbability(num p) {
    InvalidProbability.check(p);
    return min + p * (max - min);
  }

  @override
  double sample({Random? random}) {
    final r = (random ?? Random()).nextDouble();
    return min + r * (max - min);
  }

  @override
  bool operator ==(Object other) =>
      other is UniformDistribution && min == other.min && max == other.max;

  @override
  int get hashCode => Object.hash(UniformDistribution, min, max);

  @override
  ObjectPrinter get toStringPrinter => super.toStringPrinter
    ..addValue(min, name: 'min')
    ..addValue(max, name: 'max');
}
