import 'dart:math';

import '../continuous/uniform.dart';
import '../discrete.dart';

/// A discrete uniform distribution between [a] and [b], for details see
/// https://en.wikipedia.org/wiki/Discrete_uniform_distribution.
class UniformDiscreteDistribution extends DiscreteDistribution {
  const UniformDiscreteDistribution(this.a, this.b);

  /// Minimum value of the distribution.
  final int a;

  /// Maximum value of the distribution.
  final int b;

  // Returns the number of elements in this distribution.
  int get count => b - a + 1;

  @override
  int get lowerBound => a;

  @override
  int get upperBound => b;

  @override
  double get mean => 0.5 * (a + b);

  @override
  double get median => mean;

  @override
  double get mode => double.nan;

  @override
  double get variance => (count * count - 1) / 12;

  @override
  double probability(int k) => a <= k && k <= b ? 1.0 / count : 0.0;

  @override
  double cumulativeProbability(int k) => k < a
      ? 0.0
      : k <= b
          ? (k - a + 1) / count
          : 1.0;

  @override
  int sample({Random? random}) {
    const uniform = UniformDistribution.standard();
    return a + (count * uniform.sample(random: random)).floor();
  }

  @override
  bool operator ==(Object other) =>
      other is UniformDiscreteDistribution && a == other.a && b == other.b;

  @override
  int get hashCode => Object.hash(a, b);

  @override
  String toString() => 'UniformDiscreteDistribution[$a..$b]';
}
