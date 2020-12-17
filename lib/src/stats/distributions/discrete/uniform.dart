import 'dart:math';

import 'package:more/hash.dart';

import '../continuous/uniform.dart';
import '../discrete.dart';

/// A discrete uniform distribution between [min] and [max], for details see
/// https://en.wikipedia.org/wiki/Discrete_uniform_distribution.
class UniformDiscreteDistribution extends DiscreteDistribution {
  const UniformDiscreteDistribution(this.min, this.max);

  @override
  final int min;

  @override
  final int max;

  // Returns the number of elements in this distribution.
  int get count => max - min + 1;

  @override
  double get mean => 0.5 * (min + max);

  @override
  double get median => mean;

  @override
  double get variance => (count * count - 1) / 12;

  @override
  double probability(int k) => min <= k && k <= max ? 1.0 / count : 0.0;

  @override
  double cumulativeProbability(int k) => k < min
      ? 0.0
      : k <= max
          ? (k - min + 1) / count
          : 1.0;

  @override
  int sample({Random? random}) =>
      min + (count * _uniform.sample(random: random)).floor();

  @override
  bool operator ==(Object other) =>
      other is UniformDiscreteDistribution &&
      min == other.min &&
      max == other.max;

  @override
  int get hashCode => hash2(min, max);

  @override
  String toString() => 'UniformDiscreteDistribution[$min..$max]';
}

const _uniform = UniformDistribution(0, 1);
