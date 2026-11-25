import 'dart:math';

import 'package:more/printer.dart';

import '../discrete.dart';
import '../errors.dart';
import '../utils.dart';

/// The discrete uniform distribution over integers between [min] and [max]
/// inclusive.
///
/// See https://en.wikipedia.org/wiki/Discrete_uniform_distribution.
class UniformDiscreteDistribution extends DiscreteDistribution {
  /// A discrete uniform distribution with integer bounds [min] and [max].
  new(this.min, this.max) {
    if (min > max) {
      throw ArgumentError.value(
        min,
        'min',
        'Must be less than or equal to max',
      );
    }
  }

  /// Fits a discrete uniform distribution to [samples] using min and max
  /// values.
  factory fit(Iterable<num> samples) {
    int? minVal;
    int? maxVal;
    for (final x in samples) {
      if (!x.isFinite || x.round() != x) {
        throw ArgumentError.value(x, 'samples', 'Samples must be integers');
      }
      final intVal = x.round();
      if (minVal == null || intVal < minVal) minVal = intVal;
      if (maxVal == null || intVal > maxVal) maxVal = intVal;
    }
    if (minVal == null || maxVal == null) {
      throw ArgumentError.value(samples, 'samples', 'Cannot fit empty samples');
    }
    return UniformDiscreteDistribution(minVal, maxVal);
  }

  /// Minimum value of the distribution.
  final int min;

  /// Maximum value of the distribution.
  final int max;

  /// Number of possible outcomes `n = max - min + 1`.
  int get n => max - min + 1;

  @override
  int get lowerBound => min;

  @override
  bool get isLowerBoundOpen => false;

  @override
  int get upperBound => max;

  @override
  bool get isUpperBoundOpen => false;

  @override
  double get mean => 0.5 * min + 0.5 * max;

  @override
  double get median => mean;

  @override
  double get mode => double.nan;

  @override
  double get variance {
    final nd = max.toDouble() - min.toDouble() + 1.0;
    return (nd * nd - 1.0) / 12.0;
  }

  @override
  double get skewness => min == max ? double.nan : 0.0;

  @override
  double get excessKurtosis {
    if (min == max) return double.nan;
    final nd = max.toDouble() - min.toDouble() + 1.0;
    final n2 = nd * nd;
    return -6.0 * (n2 + 1.0) / (5.0 * (n2 - 1.0));
  }

  @override
  double probability(int k) => (min <= k && k <= max)
      ? 1.0 / (max.toDouble() - min.toDouble() + 1.0)
      : 0.0;

  @override
  double logProbability(int x) => (min <= x && x <= max)
      ? -log(max.toDouble() - min.toDouble() + 1.0)
      : double.negativeInfinity;

  @override
  double cumulativeProbability(int k) {
    if (k < min) return 0.0;
    if (k >= max) return 1.0;
    return (k.toDouble() - min.toDouble() + 1.0) /
        (max.toDouble() - min.toDouble() + 1.0);
  }

  @override
  double survival(int x) {
    if (x < min) return 1.0;
    if (x >= max) return 0.0;
    return (max.toDouble() - x.toDouble()) /
        (max.toDouble() - min.toDouble() + 1.0);
  }

  @override
  int inverseCumulativeProbability(num probability) {
    InvalidProbability.check(probability);
    if (probability == 0) return min;
    if (probability == 1) return max;
    final nd = max.toDouble() - min.toDouble() + 1.0;
    return (min + (probability * nd).ceil() - 1).clamp(min, max);
  }

  @override
  int inverseSurvival(num probability) {
    InvalidProbability.check(probability);
    if (probability == 0) return max;
    if (probability == 1) return min;
    final nd = max.toDouble() - min.toDouble() + 1.0;
    return (max - (probability * nd).floor()).clamp(min, max);
  }

  @override
  int sample({Random? random}) {
    final rng = random ?? defaultRandom;
    final nd = max.toDouble() - min.toDouble() + 1.0;
    if (nd <= 0x100000000) {
      return min + rng.nextInt(n);
    }
    return min + (rng.nextDouble() * nd).floor();
  }

  @override
  bool operator ==(Object other) =>
      other is UniformDiscreteDistribution &&
      min == other.min &&
      max == other.max;

  @override
  int get hashCode => Object.hash(UniformDiscreteDistribution, min, max);

  @override
  ObjectPrinter get toStringPrinter => super.toStringPrinter
    ..addValue(min, name: 'min')
    ..addValue(max, name: 'max');
}
