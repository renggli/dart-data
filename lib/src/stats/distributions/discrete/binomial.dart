import 'dart:math';

import 'package:more/printer.dart';

import '../../../special/gamma.dart';
import '../continuous/uniform.dart';
import '../discrete.dart';

/// The Binomial distribution is a discrete probability distribution which
/// takes the value 1 with a probability [p] and 0 otherwise.
///
/// See https://en.wikipedia.org/wiki/Binomial_distribution.
class BinomialDistribution extends DiscreteDistribution {
  /// A binomial distribution with parameters [n] and [p].
  const BinomialDistribution(this.n, this.p)
      : assert(0 <= n, 'n <= 0'),
        assert(0 <= p && p <= 1, '0 <= p <= 1');

  /// Number of trials.
  final int n;

  /// Success probability of each trial (0..1).
  final double p;

  /// Failure probability of each trial (0..1).
  double get q => 1 - p;

  @override
  int get lowerBound => 0;

  @override
  int get upperBound => n;

  @override
  double get mean => n * p;

  @override
  double get median => mean.roundToDouble();

  @override
  double get mode => ((n + 1) * p).floorToDouble();

  @override
  double get variance => n * p * q;

  @override
  double get skewness => (q - p) / sqrt(n * p * q);

  @override
  double get kurtosisExcess => (1 - 6 * p * q) / (n * p * q);

  @override
  double probability(int k) =>
      0 <= k && k <= n ? combination(n, k) * pow(p, k) * pow(q, n - k) : 0;

  @override
  int sample({Random? random}) {
    const uniform = UniformDistribution.standard();
    var sum = 0;
    for (var i = 0; i < n; i++) {
      if (uniform.sample(random: random) < p) {
        sum++;
      }
    }
    return sum;
  }

  @override
  bool operator ==(Object other) =>
      other is BinomialDistribution && n == other.n && p == other.p;

  @override
  int get hashCode => Object.hash(BinomialDistribution, n, p);

  @override
  ObjectPrinter get toStringPrinter => super.toStringPrinter
    ..addValue(n, name: 'n')
    ..addValue(p, name: 'p')
    ..addValue(q, name: 'q');
}
