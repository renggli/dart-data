import 'dart:math';

import 'package:more/hash.dart';

import '../../iterable.dart';
import '../../special/erf.dart';
import '../continuous.dart';
import 'uniform.dart';

/// Normal (or Gaussian) distribution, for details see
/// https://en.wikipedia.org/wiki/Normal_distribution.
class NormalDistribution extends ContinuousDistribution {
  factory NormalDistribution.fromSamples(Iterable<num> values) =>
      NormalDistribution(values.arithmeticMean(), values.standardDeviation());

  const NormalDistribution(this.mu, this.sigma);

  /// Arithmetic mean of a normal distribution.
  final double mu;

  /// Standard deviation of a normal distribution.
  final double sigma;

  @override
  double get mean => mu;

  @override
  double get median => mu;

  @override
  double get mode => mu;

  @override
  double get variance => sigma * sigma;

  @override
  double pdf(num x) {
    final z = (x - mu) / (sqrt2 * sigma);
    return exp(-z * z) / (sqrt2 * pi * sigma);
  }

  @override
  double cdf(num x) {
    final z = (x - mu) / (sqrt2 * sigma);
    return 0.5 * (1.0 + errorFunction(z));
  }

  @override
  double inv(double p) => throw UnimplementedError();

  @override
  double sample({Random? random}) {
    const uniform = UniformDistribution(-1, 1);
    double p1, p2, p;
    do {
      p1 = uniform.sample(random: random);
      p2 = uniform.sample(random: random);
      p = p1 * p1 + p2 * p2;
    } while (p >= 1.0);
    return mean + variance * p1 * sqrt(-2 * log(p) / p);
  }

  @override
  bool operator ==(Object other) =>
      other is NormalDistribution && mu == other.mu && sigma == other.sigma;

  @override
  int get hashCode => hash2(mu, sigma);

  @override
  String toString() => 'NormalDistribution{mu: $mu, sigma: $sigma}';
}
