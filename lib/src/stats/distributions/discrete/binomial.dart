import 'dart:math';

import 'package:more/printer.dart';

import '../../../special/beta.dart';
import '../../../special/binomial.dart';
import '../../../special/factorial.dart';
import '../../../special/utils.dart';
import '../discrete.dart';
import '../utils.dart';

/// The Binomial distribution over `{0, 1, ..., n}` with [n] trials and success
/// probability [p].
///
/// See https://en.wikipedia.org/wiki/Binomial_distribution.
class BinomialDistribution extends DiscreteDistribution {
  /// A binomial distribution with [n] trials and success probability [p].
  new(this.n, this.p) {
    if (n < 0) {
      throw ArgumentError.value(n, 'n', 'Must be non-negative');
    }
    if (p.isNaN || p < 0.0 || p > 1.0) {
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
      if (!x.isFinite || x < 0 || x.round() != x) {
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
    if (n != null && n < maxVal) {
      throw ArgumentError.value(
        n,
        'n',
        'Number of trials must be at least maximum sample value ($maxVal)',
      );
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

  /// Success probability of each trial in `[0, 1]`.
  final double p;

  /// Failure probability of each trial in `[0, 1]`.
  double get q => 1.0 - p;

  @override
  int get lowerBound => 0;

  @override
  bool get isLowerBoundOpen => false;

  @override
  int get upperBound => n;

  @override
  bool get isUpperBoundOpen => false;

  @override
  double get mean => n * p;

  @override
  double get median => inverseCumulativeProbability(0.5).toDouble();

  @override
  double get mode => p == 1.0 ? n.toDouble() : ((n + 1) * p).floorToDouble();

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
    return exp(logProbability(k));
  }

  @override
  double logProbability(int x) {
    if (x < 0 || x > n) return double.negativeInfinity;
    if (p == 0.0) return x == 0 ? 0.0 : double.negativeInfinity;
    if (p == 1.0) return x == n ? 0.0 : double.negativeInfinity;
    return binomialLn(n, x) + x * log(p) + (n - x) * log1p(-p);
  }

  @override
  double cumulativeProbability(int k) {
    if (k < 0) return 0.0;
    if (k >= n) return 1.0;
    if (p == 0.0) return 1.0;
    if (p == 1.0) return 0.0;
    return betaI(q, n - k, k + 1);
  }

  @override
  double survival(int x) {
    if (x < 0) return 1.0;
    if (x >= n) return 0.0;
    if (p == 0.0) return 0.0;
    if (p == 1.0) return 1.0;
    return betaI(p, x + 1, n - x);
  }

  @override
  int sample({Random? random}) {
    final rng = random ?? defaultRandom;
    if (n == 0 || p == 0.0) return 0;
    if (p == 1.0) return n;
    final flipped = p > 0.5;
    final prob = flipped ? q : p;
    final int successes;
    if (n <= 20) {
      var sum = 0;
      for (var i = 0; i < n; i++) {
        if (rng.nextDouble() < prob) sum++;
      }
      successes = sum;
    } else if (n * prob < 10.0) {
      // Exact waiting-time method via geometric gaps when n * prob is small.
      final logQ = log1p(-prob);
      var k = 0;
      var sum = 0;
      for (;;) {
        final gap = (log(nextOpenUnit(rng)) / logQ).floor() + 1;
        sum += gap;
        if (sum > n) break;
        k++;
      }
      successes = k;
    } else {
      successes = _sampleBtrs(n, prob, rng);
    }
    return flipped ? n - successes : successes;
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

/// Hörmann's BTRS transformed-rejection sampler for `n * p >= 10, p <= 0.5`.
int _sampleBtrs(int n, double p, Random rng) {
  final spq = sqrt(n * p * (1.0 - p));
  final b = 1.15 + 2.53 * spq;
  final a = -0.0873 + 0.0248 * b + 0.01 * p;
  final c = n * p + 0.5;
  final alpha = (2.83 + 5.1 / b) * spq;
  final lpq = log(p / (1.0 - p));
  final m = ((n + 1) * p).floor();
  final h = factorialLn(m) + factorialLn(n - m);

  for (;;) {
    final u = rng.nextDouble() - 0.5;
    final us = 0.5 - u.abs();
    final k = ((2.0 * a / us + b) * u + c).floor();
    if (k < 0 || k > n) continue;
    final v = nextOpenUnit(rng);
    final logRatio = log(v * alpha / (a / (us * us) + b));
    final target = h - factorialLn(k) - factorialLn(n - k) + (k - m) * lpq;
    if (logRatio <= target) {
      return k;
    }
  }
}
