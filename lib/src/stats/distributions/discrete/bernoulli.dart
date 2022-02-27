import 'dart:math';

import '../continuous/uniform.dart';
import '../discrete.dart';

/// The Bernoulli distribution is a discrete probability distribution which
/// takes the value 1 with a probability [p] and 0 otherwise.
///
/// See https://en.wikipedia.org/wiki/Bernoulli_distribution.
class BernoulliDistribution extends DiscreteDistribution {
  const BernoulliDistribution(this.p)
      : assert(0 <= p, '0 <= p'),
        assert(p <= 1.0, 'p <= 1');

  /// Success probability for each trial (0..1).
  final double p;

  /// Failure probability for each trial (0..1).
  double get q => 1.0 - p;

  @override
  int get lowerBound => 0;

  @override
  int get upperBound => 1;

  @override
  double get mean => p;

  @override
  double get median => p < 0.5
      ? 0.0
      : p > 0.5
          ? 1
          : 0.5;

  @override
  double get mode => p <= 0.5 ? 0 : 1;

  @override
  double get variance => p * q;

  @override
  double probability(int k) => k == 0
      ? q
      : k == 1
          ? p
          : 0.0;

  @override
  double cumulativeProbability(int k) => k < 0
      ? 0.0
      : k < 1
          ? q
          : 1.0;

  @override
  int sample({Random? random}) {
    const uniform = UniformDistribution.standard();
    return uniform.sample(random: random) < p ? 1 : 0;
  }

  @override
  bool operator ==(Object other) =>
      other is BernoulliDistribution && p == other.p;

  @override
  int get hashCode => Object.hash(BernoulliDistribution, p);

  @override
  String toString() => 'BernoulliDistribution{p: $p, q: $q}';
}
