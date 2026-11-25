import 'dart:math';

import 'package:more/printer.dart';

import '../../../special/beta.dart';
import '../../../special/binomial.dart';
import '../../../special/utils.dart';
import '../continuous/gamma.dart';
import '../discrete.dart';
import '../utils.dart';
import 'poisson.dart';

/// The Negative Binomial distribution modeling the number of successes before
/// [r] failures occur in independent Bernoulli trials with success probability
/// [p].
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
    final stats = welfordSampleStats(
      samples,
      isValid: (value) => value >= 0.0 && value.roundToDouble() == value,
      invalidMessage: 'Negative binomial samples must be non-negative integers',
    );
    final mean = stats.mean;
    if (r != null) {
      final rd = r.toDouble();
      if (rd <= 0.0 || !rd.isFinite) {
        throw ArgumentError.value(r, 'r', 'Must be positive and finite');
      }
      final p = (mean / (mean + rd)).clamp(1e-6, 1.0 - 1e-6);
      return NegativeBinomialDistribution(rd, p);
    }
    if (stats.variance > mean) {
      final p = (1.0 - mean / stats.variance).clamp(1e-6, 1.0 - 1e-6);
      final rEst = (mean * (1.0 - p) / p).clamp(1e-6, 1e9);
      return NegativeBinomialDistribution(rEst, p);
    }
    final p = (mean / (mean + 1.0)).clamp(1e-6, 1.0 - 1e-6);
    return NegativeBinomialDistribution(1.0, p);
  }

  /// Number of failures until the experiment is stopped.
  final double r;

  /// Success probability of each trial in `(0, 1)`.
  final double p;

  /// Failure probability of each trial in `(0, 1)`.
  double get q => 1.0 - p;

  @override
  int get lowerBound => 0;

  @override
  bool get isLowerBoundOpen => false;

  @override
  double get mean => p * r / q;

  @override
  double get median => inverseCumulativeProbability(0.5).toDouble();

  @override
  double get mode => r > 1.0 ? (p * (r - 1.0) / q).floorToDouble() : 0.0;

  @override
  double get variance => p * r / (q * q);

  @override
  double get skewness => (1.0 + p) / sqrt(p * r);

  @override
  double get excessKurtosis => 6.0 / r + (q * q) / (p * r);

  @override
  double probability(int k) {
    if (k < 0) return 0.0;
    return exp(logProbability(k));
  }

  @override
  double logProbability(int x) {
    if (x < 0) return double.negativeInfinity;
    return binomialLn(x + r - 1.0, x) + x * log(p) + r * log1p(-p);
  }

  @override
  double cumulativeProbability(int k) => k < 0 ? 0.0 : betaI(q, r, k + 1);

  @override
  double survival(int x) => x < 0 ? 1.0 : betaI(p, x + 1, r);

  @override
  int sample({Random? random}) {
    final rng = random ?? defaultRandom;
    final lambda = GammaDistribution(r, p / q).sample(random: rng);
    if (lambda <= 0.0) return 0;
    if (!lambda.isFinite) return upperBound;
    return PoissonDistribution(lambda).sample(random: rng);
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
