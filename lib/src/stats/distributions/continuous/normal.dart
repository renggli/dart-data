import 'dart:math';

import '../../../special/erf.dart';
import '../continuous.dart';
import 'uniform.dart';

/// Normal (or Gaussian) distribution described by the [mean] or expectation of
/// the distribution and its [standardDeviation].
///
/// For details see https://en.wikipedia.org/wiki/Normal_distribution.
class NormalDistribution extends ContinuousDistribution {
  /// A standard normal distribution with [mean] and [standardDeviation].
  const NormalDistribution(this.mean, this.standardDeviation);

  /// A standard normal distribution centered around 0.
  const NormalDistribution.standard() : this(0.0, 1.0);

  @override
  final double mean;

  @override
  double get median => mean;

  @override
  final double standardDeviation;

  @override
  double get variance => standardDeviation * standardDeviation;

  @override
  double probability(double x) {
    final z = (x - mean) / (sqrt2 * standardDeviation);
    return exp(-z * z) / (sqrt2 * sqrt(pi) * standardDeviation);
  }

  @override
  double cumulativeProbability(double x) {
    final z = (x - mean) / (sqrt2 * standardDeviation);
    return 0.5 * (1.0 + errorFunction(z));
  }

  @override
  double inverseCumulativeProbability(num p) =>
      -1.41421356237309505 *
          standardDeviation *
          inverseComplementaryErrorFunction(2 * p) +
      mean;

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
      } while (p >= 1.0);
      p = standardDeviation * sqrt(-2.0 * log(p) / p);
      yield mean + p1 * p;
      yield mean + p2 * p;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is NormalDistribution &&
      mean == other.mean &&
      standardDeviation == other.standardDeviation;

  @override
  int get hashCode => Object.hash(mean, standardDeviation);

  @override
  String toString() =>
      'NormalDistribution{mean: $mean, standardDeviation: $standardDeviation}';
}
