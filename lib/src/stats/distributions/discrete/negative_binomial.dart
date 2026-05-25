import 'dart:math';

import 'package:more/printer.dart';

import '../../../special/gamma.dart';
import '../continuous/gamma.dart';
import '../discrete.dart';
import 'poisson.dart';

/// The Negative Binomial distribution is a discrete probability distribution
/// which models the number of successes in a sequence of independent and
/// identically distributed Bernoulli trials before a specified (non-random)
/// number of failures (denoted r) occurs.
///
/// See https://en.wikipedia.org/wiki/Negative_binomial_distribution.
///
/// ```dart
/// final distribution = NegativeBinomialDistribution(1, 0.5);
/// print(distribution.probability(0));  // 0.5
/// ```
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
      k < 0 ? 0 : exp(combinationLn(k + r - 1, k) + k * log(p) + r * log(q));

  @override
  int sample({Random? random}) {
    final gammaDistribution = GammaDistribution(r, p / q);
    final lambda = gammaDistribution.sample(random: random);
    if (lambda == 0) return 0;
    return PoissonDistribution(lambda).sample(random: random);
  }

  @override
  bool operator ==(Object other) =>
      other is NegativeBinomialDistribution && r == other.r && p == other.p;

  @override
  int get hashCode => Object.hash(NegativeBinomialDistribution, r, p);

  @override
  ObjectPrinter get toStringPrinter => super.toStringPrinter
    ..addValue(r, name: 'r')
    ..addValue(p, name: 'p')
    ..addValue(q, name: 'q');
}
