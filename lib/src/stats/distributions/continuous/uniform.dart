import 'dart:math';

import 'package:more/hash.dart';

import '../continuous.dart';

/// A uniform distribution between [min] and [max], for details see
/// https://en.wikipedia.org/wiki/Continuous_uniform_distribution.
class UniformDistribution extends ContinuousDistribution {
  const UniformDistribution(this.min, this.max);

  @override
  final double min;

  @override
  final double max;

  @override
  double get mean => 0.5 * (min + max);

  @override
  double get median => mean;

  @override
  double get variance => pow(max - min, 2) / 12.0;

  @override
  double probability(double x) =>
      min <= x && x <= max ? 1.0 / (max - min) : 0.0;

  @override
  double cumulativeProbability(double x) => x <= min
      ? 0.0
      : x <= max
          ? (x - min) / (max - min)
          : 1.0;

  @override
  double inverseCumulativeProbability(num p) => min + p * (max - min);

  @override
  double sample({Random? random}) =>
      min + (max - min) * ((random ?? _random).nextDouble());

  @override
  bool operator ==(Object other) =>
      other is UniformDistribution && min == other.min && max == other.max;

  @override
  int get hashCode => hash2(min, max);

  @override
  String toString() => 'UniformDistribution[$min..$max]';
}

final _random = Random();
