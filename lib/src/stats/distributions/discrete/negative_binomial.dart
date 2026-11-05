import 'dart:math';

import 'package:more/printer.dart';

import '../../../special/beta.dart';
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
  new(this.r, this.p) {
    if (!r.isFinite || r <= 0) {
      throw ArgumentError.value(r, 'r', 'Must be positive');
    }
    if (p.isNaN || p <= 0.0 || p >= 1.0) {
      throw ArgumentError.value(p, 'p', 'Must be strictly between 0.0 and 1.0');
    }
  }

  /// Fits a negative binomial distribution to non-negative integer [samples]
  /// using method of moments, with optional pre-specified [r].
  factory fit(Iterable<num> samples, {num? r}) {
    var count = 0;
    var sum = 0.0;
    for (final x in samples) {
      if (x < 0 || x.roundToDouble() != x) {
        throw ArgumentError.value(
          x,
          'samples',
          'Negative binomial samples must be non-negative integers',
        );
      }
      count++;
      sum += x;
    }
    if (count == 0) {
      throw ArgumentError.value(samples, 'samples', 'Cannot fit empty samples');
    }
    final mean = sum / count;
    if (r != null) {
      final rd = r.toDouble();
      if (rd <= 0.0 || !rd.isFinite) {
        throw ArgumentError.value(r, 'r', 'Must be positive and finite');
      }
      final p = mean / (mean + rd);
      final pClamped = p.clamp(1e-6, 1.0 - 1e-6);
      return NegativeBinomialDistribution(rd, pClamped);
    }
    var sumSq = 0.0;
    for (final x in samples) {
      final diff = x.toDouble() - mean;
      sumSq += diff * diff;
    }
    final variance = count > 1 ? sumSq / (count - 1) : 0.0;
    if (variance > mean) {
      final p = (1.0 - mean / variance).clamp(1e-6, 1.0 - 1e-6);
      final rEst = (mean * (1.0 - p) / p).clamp(1e-6, 1e9);
      return NegativeBinomialDistribution(rEst, p);
    } else {
      final p = (mean / (mean + 1.0)).clamp(1e-6, 1.0 - 1e-6);
      return NegativeBinomialDistribution(1.0, p);
    }
  }

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
  double get median => inverseCumulativeProbability(0.5).toDouble();

  @override
  double get mode => r > 1 ? (p * (r - 1) / q).floorToDouble() : 0;

  @override
  double get variance => p * r / pow(q, 2);

  @override
  double get skewness => (1 + p) / sqrt(p * r);

  @override
  double get excessKurtosis => 6 / r + pow(1 - p, 2) / (p * r);

  @override
  double probability(int k) {
    if (k < 0) return 0;
    return exp(combinationLn(k + r - 1, k) + k * log(p) + r * log(q));
  }

  @override
  double cumulativeProbability(int k) {
    if (k < 0) return 0.0;
    return ibeta(q, r, k + 1);
  }

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
