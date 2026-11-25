import 'dart:math';

import '../discrete.dart';
import '../errors.dart';
import '../utils.dart';

/// The Rademacher distribution over `{-1, 1}` taking each value with
/// probability `1/2`.
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

  /// Validates that [samples] consist of values in `{-1, 1}` and returns a
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
  bool get isLowerBoundOpen => false;

  @override
  int get upperBound => 1;

  @override
  bool get isUpperBoundOpen => false;

  @override
  double get mean => 0.0;

  @override
  double get median => 0.0;

  @override
  double get mode => double.nan;

  @override
  double get variance => 1.0;

  @override
  double get skewness => 0.0;

  @override
  double get excessKurtosis => -2.0;

  @override
  double probability(int k) => k == -1 || k == 1 ? 0.5 : 0.0;

  @override
  double logProbability(int x) =>
      x == -1 || x == 1 ? -ln2 : double.negativeInfinity;

  @override
  double cumulativeProbability(int k) => k < -1
      ? 0.0
      : k < 1
      ? 0.5
      : 1.0;

  @override
  double survival(int x) => x < -1
      ? 1.0
      : x < 1
      ? 0.5
      : 0.0;

  @override
  int inverseCumulativeProbability(num probability) {
    InvalidProbability.check(probability);
    return probability <= 0.5 ? -1 : 1;
  }

  @override
  int inverseSurvival(num probability) {
    InvalidProbability.check(probability);
    return probability >= 0.5 ? -1 : 1;
  }

  @override
  int sample({Random? random}) =>
      (random ?? defaultRandom).nextDouble() < 0.5 ? -1 : 1;

  @override
  bool operator ==(Object other) => other is RademacherDistribution;

  @override
  int get hashCode => 70196453;
}
