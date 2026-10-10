import 'dart:math';

import 'package:more/printer.dart';

import '../../../special/gamma.dart';
import '../continuous/uniform.dart';
import '../discrete.dart';

/// The Binomial distribution.
///
/// See https://en.wikipedia.org/wiki/Binomial_distribution.
class BinomialDistribution extends DiscreteDistribution {
  /// A binomial distribution with [n] trials and success probability [p].
  const new(this.n, this.p)
    : assert(0 <= n, 'n >= 0'),
      assert(0.0 <= p && p <= 1.0, '0 <= p <= 1');

  /// Fits a binomial distribution to [samples] with given number of trials [n].
  ///
  /// If [n] is omitted, the maximum value in [samples] is used as [n].
  factory fit(Iterable<num> samples, {int? n}) {
    var count = 0;
    var sum = 0.0;
    var maxVal = 0;
    for (final x in samples) {
      if (x < 0 || x.round() != x) {
        throw ArgumentError.value(
          x,
          'samples',
          'Samples must be non-negative integers',
        );
      }
      final intVal = x.round();
      if (intVal > maxVal) maxVal = intVal;
      count++;
      sum += intVal;
    }
    if (count == 0) {
      throw ArgumentError.value(samples, 'samples', 'Cannot fit empty samples');
    }
    final actualN = n ?? maxVal;
    if (actualN == 0) {
      return const BinomialDistribution(0, 0.0);
    }
    final mean = sum / count;
    final prob = (mean / actualN).clamp(0.0, 1.0);
    return BinomialDistribution(actualN, prob);
  }

  /// Number of trials.
  final int n;

  /// Success probability of each trial (0..1).
  final double p;

  /// Failure probability of each trial (0..1).
  double get q => 1.0 - p;

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
  double get excessKurtosis => (1.0 - 6.0 * p * q) / (n * p * q);

  @override
  double probability(int k) {
    if (k < 0 || k > n) return 0.0;
    if (p == 0.0) return k == 0 ? 1.0 : 0.0;
    if (p == 1.0) return k == n ? 1.0 : 0.0;
    return exp(combinationLn(n, k) + k * log(p) + (n - k) * log(q));
  }

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
    ..addValue(p, name: 'p');
}
