import 'dart:math';

import 'package:more/printer.dart';

import '../../../special/gamma.dart';
import '../continuous/uniform.dart';
import '../discrete.dart';

/// The Binomial distribution is a discrete probability distribution which
/// models the number of successes in a sequence of independent and identically
/// distributed Bernoulli trials before a specified (non-random) number of
/// failures (denoted r) occurs.
///
/// See https://en.wikipedia.org/wiki/Negative_binomial_distribution.
class NegativeBinomialDistribution extends DiscreteDistribution {
  /// A negative binomial distribution with parameters [r] and [p].
  const NegativeBinomialDistribution(this.r, this.p)
    : assert(r > 0, 'r > 0'),
      assert(0 <= p && p <= 1, '0 <= p <= 1');

  /// Number of failures until the experiment is stopped.
  final double r;

  /// Success probability of each trial (0..1).
  final double p;

  /// Failure probability of each trial (0..1).
  double get q => 1 - p;

  @override
  int get lowerBound => 0;

  @override
  double get mean => p * r / q;

  @override
  double get median => mean.roundToDouble();

  @override
  double get mode => r > 1 ? (p * (r - 1) / q).floorToDouble() : 0;

  @override
  double get variance => p * r / pow(q, 2);

  @override
  double get skewness => (1 + p) / sqrt(p * r);

  @override
  double get kurtosisExcess => 6 / r + pow(1 - p, 2) / (p * r);

  @override
  double probability(int k) =>
      k < 0 ? 0 : combination(k + r - 1, k) * pow(p, k) * pow(q, r);

  @override
  int sample({Random? random}) {
    const uniform = UniformDistribution.standard();
    var failure = 0, success = 0;
    while (failure < r) {
      if (uniform.sample(random: random) < p) {
        success++;
      } else {
        failure++;
      }
    }
    return success;
  }

  @override
  bool operator ==(Object other) =>
      other is NegativeBinomialDistribution && r == other.r && p == other.p;

  @override
  int get hashCode => Object.hash(NegativeBinomialDistribution, r, p);

  @override
  ObjectPrinter get toStringPrinter =>
      super.toStringPrinter
        ..addValue(r, name: 'r')
        ..addValue(p, name: 'p')
        ..addValue(q, name: 'q');
}
