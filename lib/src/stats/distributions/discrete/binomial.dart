import 'dart:math';

import 'package:more/printer.dart';

import '../../../special/beta.dart';
import '../../../special/gamma.dart';
import '../continuous/uniform.dart';
import '../discrete.dart';

/// The Binomial distribution.
///
/// See https://en.wikipedia.org/wiki/Binomial_distribution.
class BinomialDistribution extends DiscreteDistribution {
  /// A binomial distribution with [n] trials and success probability [p].
  new(this.n, this.p) {
    if (n < 0) {
      throw ArgumentError.value(n, 'n', 'Must be non-negative');
    }
    if (p < 0.0 || p > 1.0) {
      throw ArgumentError.value(p, 'p', 'Must be between 0.0 and 1.0');
    }
  }

  const new _(this.n, this.p);

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
      return const BinomialDistribution._(0, 0.0);
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
  double get skewness =>
      n * p * q == 0.0 ? double.nan : (q - p) / sqrt(n * p * q);

  @override
  double get excessKurtosis =>
      n * p * q == 0.0 ? double.nan : (1.0 - 6.0 * p * q) / (n * p * q);

  @override
  double probability(int k) {
    if (k < 0 || k > n) return 0.0;
    if (p == 0.0) return k == 0 ? 1.0 : 0.0;
    if (p == 1.0) return k == n ? 1.0 : 0.0;
    return exp(combinationLn(n, k) + k * log(p) + (n - k) * log(q));
  }

  @override
  double cumulativeProbability(int k) {
    if (k < 0) return 0.0;
    if (k >= n) return 1.0;
    if (p == 0.0) return 1.0;
    if (p == 1.0) return 0.0;
    return ibeta(1.0 - p, n - k, k + 1);
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
