import 'dart:math';

import 'package:more/printer.dart';

import '../../../special/erf.dart';
import '../continuous.dart';
import '../errors.dart';
import '../utils.dart';
import 'normal.dart';

/// Log-normal distribution of a random variable whose logarithm is normally
/// distributed with mean [mu] and standard deviation [sigma].
///
/// See https://en.wikipedia.org/wiki/Log-normal_distribution.
///
/// ```dart
/// final distribution = LogNormalDistribution(0, 1);
/// print(distribution.mean);  // 1.6487212707001282
/// ```
class LogNormalDistribution extends ContinuousDistribution {
  /// A log-normal distribution with parameters [mu] μ and [sigma] σ.
  new(this.mu, this.sigma) {
    if (!mu.isFinite) {
      throw ArgumentError.value(mu, 'mu', 'Mu must be finite');
    }
    if (!sigma.isFinite || sigma <= 0) {
      throw ArgumentError.value(
        sigma,
        'sigma',
        'Sigma must be strictly positive',
      );
    }
  }

  /// A standard log-normal distribution with μ = 0 and σ = 1.
  const new standard() : this._(0.0, 1.0);

  const new _(this.mu, this.sigma);

  /// Fits a log-normal distribution to positive [samples] using maximum
  /// likelihood estimation.
  factory fit(Iterable<num> samples) {
    var count = 0;
    var mean = 0.0;
    var m2 = 0.0;
    for (final x in samples) {
      final val = x.toDouble();
      if (!val.isFinite || val <= 0.0) {
        throw ArgumentError.value(
          x,
          'samples',
          'LogNormal samples must be strictly positive and finite',
        );
      }
      final lVal = log(val);
      count++;
      final delta = lVal - mean;
      mean += delta / count;
      m2 += delta * (lVal - mean);
    }
    if (count == 0) {
      throw ArgumentError.value(samples, 'samples', 'Cannot fit empty samples');
    }
    final variance = count > 1 ? m2 / (count - 1) : 0.0;
    var sigma = sqrt(variance);
    if (sigma <= 0.0 || !sigma.isFinite) sigma = 1.0;
    return LogNormalDistribution(mean, sigma);
  }

  /// The parameter μ (mean of logarithm).
  final double mu;

  /// The parameter σ (standard deviation of logarithm).
  final double sigma;

  @override
  double get lowerBound => 0.0;

  @override
  double get mean => exp(mu + 0.5 * sigma * sigma);

  @override
  double get median => exp(mu);

  @override
  double get mode => exp(mu - sigma * sigma);

  @override
  double get variance {
    final s2 = sigma * sigma;
    return expm1(s2) * exp(2.0 * mu + s2);
  }

  @override
  double get skewness {
    final s2 = sigma * sigma;
    return (exp(s2) + 2.0) * sqrt(expm1(s2));
  }

  @override
  double get excessKurtosis {
    final s2 = sigma * sigma;
    return exp(4.0 * s2) + 2.0 * exp(3.0 * s2) + 3.0 * exp(2.0 * s2) - 6.0;
  }

  @override
  double probability(double x) {
    if (x.isNaN) return double.nan;
    if (x <= 0.0 || x == double.infinity) return 0.0;
    return exp(logProbability(x));
  }

  @override
  double logProbability(double x) {
    if (x.isNaN) return double.nan;
    if (x <= 0.0 || x == double.infinity) return double.negativeInfinity;
    final z = (log(x) - mu) / sigma;
    return -log(x) - 0.5 * _ln2pi - log(sigma) - 0.5 * z * z;
  }

  @override
  double cumulativeProbability(double x) {
    if (x.isNaN) return double.nan;
    if (x <= 0.0) return 0.0;
    if (x == double.infinity) return 1.0;
    final z = (log(x) - mu) / (sqrt2 * sigma);
    return z < 0.0 ? 0.5 * erfc(-z) : 0.5 * (1.0 + erf(z));
  }

  @override
  double survival(double x) {
    if (x.isNaN) return double.nan;
    if (x <= 0.0) return 1.0;
    if (x == double.infinity) return 0.0;
    final z = (log(x) - mu) / (sqrt2 * sigma);
    return z < 0.0 ? 0.5 * (1.0 + erf(-z)) : 0.5 * erfc(z);
  }

  @override
  double inverseCumulativeProbability(num probability) {
    InvalidProbability.check(probability);
    if (probability == 0.0) return 0.0;
    if (probability == 1.0) return double.infinity;
    final pd = probability.toDouble();
    final z = pd < 0.5
        ? -sqrt2 * erfcInv(2.0 * pd)
        : sqrt2 * erfcInv(2.0 * (1.0 - pd));
    return exp(mu + sigma * z);
  }

  @override
  double inverseSurvival(num probability) {
    InvalidProbability.check(probability);
    if (probability == 0.0) return double.infinity;
    if (probability == 1.0) return 0.0;
    final pd = probability.toDouble();
    final z = pd < 0.5
        ? sqrt2 * erfcInv(2.0 * pd)
        : -sqrt2 * erfcInv(2.0 * (1.0 - pd));
    return exp(mu + sigma * z);
  }

  @override
  double sample({Random? random}) => exp(
    const NormalDistribution.standard().sample(random: random) * sigma + mu,
  );

  @override
  Iterable<double> samples({Random? random}) =>
      const NormalDistribution.standard()
          .samples(random: random)
          .map((value) => exp(value * sigma + mu));

  @override
  bool operator ==(Object other) =>
      other is LogNormalDistribution && mu == other.mu && sigma == other.sigma;

  @override
  int get hashCode => Object.hash(LogNormalDistribution, mu, sigma);

  @override
  ObjectPrinter get toStringPrinter => super.toStringPrinter
    ..addValue(mu, name: 'mu')
    ..addValue(sigma, name: 'sigma');
}

final double _ln2pi = log(2.0 * pi);
