import 'dart:math';

import 'package:more/printer.dart';

import '../discrete.dart';
import '../errors.dart';

/// The discrete uniform distribution over integers between [min] and [max] inclusive.
///
/// See https://en.wikipedia.org/wiki/Discrete_uniform_distribution.
class UniformDiscreteDistribution extends DiscreteDistribution {
  /// A discrete uniform distribution with integer bounds [min] and [max].
  const new(this.min, this.max) : assert(min <= max, 'min <= max');

  /// Fits a discrete uniform distribution to [samples] using min and max values.
  factory fit(Iterable<num> samples) {
    if (samples.isEmpty) {
      throw ArgumentError.value(samples, 'samples', 'Cannot fit empty samples');
    }
    var minVal = maxSafeInteger;
    var maxVal = minSafeInteger;
    for (final x in samples) {
      final k = x.round();
      if (k < minVal) minVal = k;
      if (k > maxVal) maxVal = k;
    }
    return UniformDiscreteDistribution(minVal, maxVal);
  }

  /// Minimum value of the distribution.
  final int min;

  /// Maximum value of the distribution.
  final int max;

  /// Number of possible outcomes $n = \text{max} - \text{min} + 1$.
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
  double get mean => 0.5 * (min + max);

  @override
  double get median => mean;

  @override
  double get mode => double.nan;

  @override
  double get variance => (n * n - 1.0) / 12.0;

  @override
  double get skewness => 0.0;

  @override
  double get excessKurtosis => -6.0 * (n * n + 1.0) / (5.0 * (n * n - 1.0));

  @override
  double probability(int k) => (min <= k && k <= max) ? 1.0 / n : 0.0;

  @override
  double cumulativeProbability(int k) {
    if (k < min) {
      return 0.0;
    } else if (k > max) {
      return 1.0;
    } else {
      return (k - min + 1.0) / n;
    }
  }

  @override
  int inverseCumulativeProbability(num p) {
    InvalidProbability.check(p);
    return min + (p * n).floor().clamp(0, n - 1);
  }

  @override
  int sample({Random? random}) {
    final r = random ?? Random();
    return min + r.nextInt(n);
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
