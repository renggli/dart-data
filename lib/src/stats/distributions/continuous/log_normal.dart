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
class LogNormalDistribution extends ContinuousDistribution {
  /// A log-normal distribution with parameters [mu] μ and [sigma] σ.
  const LogNormalDistribution(this.mu, this.sigma)
    : assert(sigma > 0, 'sigma > 0');

  /// The parameter μ (mean of logarithm).
  final double mu;

  // The parameter σ (standard deviation of logarithm).
  final double sigma;

  @override
  double get lowerBound => double.minPositive;

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
  double get kurtosisExcess =>
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
      x < 0 ? 0 : 0.5 * (1 + erf((log(x) - mu) / (sqrt2 * sigma)));

  @override
  double inverseCumulativeProbability(num p) {
    InvalidProbability.check(p);
    return exp(-sqrt2 * sigma * erfcInv(2 * p) + mu);
  }

  @override
  double sample({Random? random}) => samples(random: random).first;

  @override
  Iterable<double> samples({Random? random}) {
    const uniform = NormalDistribution.standard();
    return uniform
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
