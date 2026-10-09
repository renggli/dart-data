import 'dart:math';

import 'package:more/printer.dart';

import '../continuous/uniform.dart';
import '../discrete.dart';
import '../errors.dart';

/// The Bernoulli distribution over $\{0, 1\}$.
///
/// See https://en.wikipedia.org/wiki/Bernoulli_distribution.
class BernoulliDistribution extends DiscreteDistribution {
  /// A Bernoulli distribution with success probability [p].
  const new(this.p) : assert(0.0 <= p && p <= 1.0, '0 <= p <= 1');

  /// Fits a Bernoulli distribution to [samples] consisting of 0s and 1s.
  factory fit(Iterable<num> samples) {
    var count = 0;
    var sum = 0.0;
    for (final x in samples) {
      if (x != 0 && x != 1) {
        throw ArgumentError.value(
          x,
          'samples',
          'Bernoulli samples must be 0 or 1',
        );
      }
      count++;
      sum += x;
    }
    if (count == 0) {
      throw ArgumentError.value(samples, 'samples', 'Cannot fit empty samples');
    }
    return BernoulliDistribution(sum / count);
  }

  /// Probability of success $p$.
  final double p;

  /// Probability of failure $q = 1 - p$.
  double get q => 1.0 - p;

  @override
  int get lowerBound => 0;

  @override
  int get upperBound => 1;

  @override
  double get mean => p;

  @override
  double get median => p > 0.5 ? 1.0 : (p < 0.5 ? 0.0 : 0.5);

  @override
  double get mode => p > 0.5 ? 1.0 : (p < 0.5 ? 0.0 : double.nan);

  @override
  double get variance => p * q;

  @override
  double get skewness => (q - p) / sqrt(p * q);

  @override
  double get excessKurtosis => (1.0 - 6.0 * p * q) / (p * q);

  @override
  double probability(int k) => k == 1 ? p : (k == 0 ? q : 0.0);

  @override
  double cumulativeProbability(int k) {
    if (k < 0) return 0.0;
    if (k == 0) return q;
    return 1.0;
  }

  @override
  int inverseCumulativeProbability(num p) {
    InvalidProbability.check(p);
    return p <= q ? 0 : 1;
  }

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
  ObjectPrinter get toStringPrinter =>
      super.toStringPrinter..addValue(p, name: 'p');
}
