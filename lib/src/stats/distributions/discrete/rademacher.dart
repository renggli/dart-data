import 'dart:math';

import '../discrete.dart';

/// The Rademacher distribution is a discrete probability function which takes
/// value 1 with probability 1/2 and value −1 with probability 1/2.
///
/// See https://en.wikipedia.org/wiki/Rademacher_distribution.
///
/// ```dart
/// final distribution = RademacherDistribution();
/// print(distribution.probability(1));  // 0.5
/// ```
class RademacherDistribution extends DiscreteDistribution {
  /// A Rademacher distribution.
  const new();

  /// Validates that [samples] consist of values in {-1, 1} and returns a
  /// [RademacherDistribution].
  factory fit(Iterable<num> samples) {
    var count = 0;
    for (final x in samples) {
      if (x != -1 && x != 1) {
        throw ArgumentError.value(
          x,
          'samples',
          'Rademacher samples must be -1 or 1',
        );
      }
      count++;
    }
    if (count == 0) {
      throw ArgumentError.value(samples, 'samples', 'Cannot fit empty samples');
    }
    return const RademacherDistribution();
  }

  @override
  int get lowerBound => -1;

  @override
  int get upperBound => 1;

  @override
  double get mean => 0;

  @override
  double get median => 0;

  @override
  double get mode => double.nan;

  @override
  double get variance => 1;

  @override
  double get skewness => 0;

  @override
  double get excessKurtosis => -2;

  @override
  double probability(int k) => k == -1 || k == 1 ? 0.5 : 0;

  @override
  double cumulativeProbability(int k) => k < -1
      ? 0
      : k < 1
      ? 0.5
      : 1;

  @override
  int sample({Random? random}) =>
      (random ?? _random).nextDouble() < 0.5 ? -1 : 1;

  @override
  bool operator ==(Object other) => other is RademacherDistribution;

  @override
  int get hashCode => 70196453;
}

final _random = Random();
