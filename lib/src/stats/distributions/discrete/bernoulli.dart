import 'dart:math';

import 'package:more/printer.dart';

import '../continuous/uniform.dart';
import '../discrete.dart';

/// The Bernoulli distribution is a discrete probability distribution which
/// takes value 1 with probability `p` and value 0 with probability `q = 1 − p`.
///
/// See https://en.wikipedia.org/wiki/Bernoulli_distribution.
class BernoulliDistribution extends DiscreteDistribution {
  /// A bernoulli distribution with parameter [p].
  const BernoulliDistribution(this.p) : assert(0 <= p && p <= 1, '0 <= p <= 1');

  /// Success probability for each trial (0..1).
  final double p;

  /// Failure probability for each trial (0..1).
  double get q => 1 - p;

  @override
  int get lowerBound => 0;

  @override
  int get upperBound => 1;

  @override
  double get mean => p;

  @override
  double get median => p < 0.5
      ? 0
      : p > 0.5
          ? 1
          : 0.5;

  @override
  double get mode => p <= 0.5 ? 0 : 1;

  @override
  double get variance => p * q;

  @override
  double get skewness => (q - p) / sqrt(p * q);

  @override
  double get kurtosisExcess => (1 - 6 * p * q) / (p * q);

  @override
  double probability(int k) => k == 0
      ? q
      : k == 1
          ? p
          : 0;

  @override
  double cumulativeProbability(int k) => k < 0
      ? 0
      : k < 1
          ? q
          : 1;

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
  ObjectPrinter get toStringPrinter => super.toStringPrinter
    ..addValue(p, name: 'p')
    ..addValue(q, name: 'q');
}
