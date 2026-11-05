import 'dart:math';

import 'package:more/printer.dart';

import '../../../special/erf.dart';
import '../continuous.dart';
import '../errors.dart';
import 'normal.dart';

/// Log-normal distribution of a random variable whose logarithm is normally
/// distributed.
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

  /// Fits a log-normal distribution to positive [samples] using maximum likelihood estimation.
  factory fit(Iterable<num> samples) {
    var count = 0;
    var sumLog = 0.0;
    final logVals = <double>[];
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
      logVals.add(lVal);
      sumLog += lVal;
      count++;
    }
    if (count == 0) {
      throw ArgumentError.value(samples, 'samples', 'Cannot fit empty samples');
    }
    final mu = sumLog / count;
    var sumSq = 0.0;
    for (final lVal in logVals) {
      final diff = lVal - mu;
      sumSq += diff * diff;
    }
    final variance = count > 1 ? sumSq / (count - 1) : 0.0;
    var sigma = sqrt(variance);
    if (sigma <= 0.0 || !sigma.isFinite) sigma = 1.0;
    return LogNormalDistribution(mu, sigma);
  }

  /// The parameter μ (mean of logarithm).
  final double mu;

  /// The parameter σ (standard deviation of logarithm).
  final double sigma;

  @override
  double get lowerBound => 0.0;

  @override
  double get mean => exp(mu + sigma * sigma / 2);

  @override
  double get median => exp(mu);

  @override
  double get mode => exp(mu - sigma * sigma);

  @override
  double get variance => (exp(sigma * sigma) - 1) * exp(2 * mu + sigma * sigma);

  @override
  double get skewness =>
      (exp(sigma * sigma) + 2) * sqrt(exp(sigma * sigma) - 1);

  @override
  double get excessKurtosis =>
      exp(4 * sigma * sigma) +
      2 * exp(3 * sigma * sigma) +
      3 * exp(2 * sigma * sigma) -
      6;

  @override
  double probability(double x) => x <= 0
      ? 0
      : exp(
          -log(x) -
              0.5 * log(2 * pi) -
              log(sigma) -
              pow(log(x) - mu, 2) / (2 * sigma * sigma),
        );

  @override
  double cumulativeProbability(double x) =>
      x <= 0.0 ? 0.0 : 0.5 * erfc(-(log(x) - mu) / (sqrt2 * sigma));

  @override
  double inverseCumulativeProbability(num probability) {
    InvalidProbability.check(probability);
    return exp(-sqrt2 * sigma * erfcInv(2 * probability) + mu);
  }

  @override
  double sample({Random? random}) => exp(
    const NormalDistribution.standard().sample(random: random) * sigma + mu,
  );

  @override
  Iterable<double> samples({Random? random}) {
    const normal = NormalDistribution.standard();
    return normal
        .samples(random: random)
        .map((value) => exp(value * sigma + mu));
  }

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
