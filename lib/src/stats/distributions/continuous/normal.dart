import 'dart:math';

import 'package:more/printer.dart';

import '../../../special/erf.dart';
import '../continuous.dart';
import '../errors.dart';
import 'uniform.dart';

/// Normal (or Gaussian) distribution described by the mean or expectation of
/// the distribution and its standard deviation.
///
/// See https://en.wikipedia.org/wiki/Normal_distribution.
class NormalDistribution extends ContinuousDistribution {
  /// A normal distribution with parameter [mu] μ (mean) and [sigma] σ (standard
  /// deviation).
  const NormalDistribution(this.mu, this.sigma)
    : assert(sigma > 0, 'sigma > 0');

  /// A standard normal distribution centered around 0.
  const NormalDistribution.standard() : this(0, 1);

  /// The mean parameter μ.
  final double mu;

  // The standard deviation parameter σ.
  final double sigma;

  @override
  double get mean => mu;

  @override
  double get median => mu;

  @override
  double get mode => mu;

  @override
  double get standardDeviation => sigma;

  @override
  double get variance => sigma * sigma;

  @override
  double get skewness => 0;

  @override
  double get kurtosisExcess => 0;

  @override
  double probability(double x) {
    final z = (x - mu) / (sqrt2 * sigma);
    return exp(-z * z) / (sqrt2 * sqrt(pi) * sigma);
  }

  @override
  double cumulativeProbability(double x) {
    final z = (x - mu) / (sqrt2 * sigma);
    return 0.5 * (1 + erf(z));
  }

  @override
  double inverseCumulativeProbability(num p) {
    InvalidProbability.check(p);
    return -sqrt2 * sigma * erfcInv(2 * p) + mu;
  }

  @override
  double sample({Random? random}) => samples(random: random).first;

  @override
  Iterable<double> samples({Random? random}) sync* {
    // https://en.wikipedia.org/wiki/Marsaglia_polar_method
    const uniform = UniformDistribution(-1, 1);
    for (;;) {
      double p1, p2, p;
      do {
        p1 = uniform.sample(random: random);
        p2 = uniform.sample(random: random);
        p = p1 * p1 + p2 * p2;
      } while (p >= 1);
      p = sigma * sqrt(-2 * log(p) / p);
      yield mu + p1 * p;
      yield mu + p2 * p;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is NormalDistribution && mu == other.mu && sigma == other.sigma;

  @override
  int get hashCode => Object.hash(NormalDistribution, mu, sigma);

  @override
  ObjectPrinter get toStringPrinter => super.toStringPrinter
    ..addValue(mu, name: 'mu')
    ..addValue(sigma, name: 'sigma');
}
