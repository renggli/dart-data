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

  const NormalDistribution(this.mean, this.standardDeviation);

  @override
  final double mean;

  @override
  double get median => mean;

  @override
  final double standardDeviation;

  @override
  double get variance => standardDeviation * standardDeviation;

  @override
  double probability(num x) {
    final z = (x - mean) / (sqrt2 * standardDeviation);
    return exp(-z * z) / (sqrt2 * pi * standardDeviation);
  }

  @override
  double cumulativeProbability(num x) {
    final z = (x - mean) / (sqrt2 * standardDeviation);
    return 0.5 * (1.0 + errorFunction(z));
  }

  @override
  double inverseCumulativeProbability(double p) =>
      -1.41421356237309505 *
          standardDeviation *
          inverseComplementaryErrorFunction(2 * p) +
      mean;

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
      other is NormalDistribution &&
      mean == other.mean &&
      standardDeviation == other.standardDeviation;

  @override
  int get hashCode => hash2(mean, standardDeviation);

  @override
  String toString() =>
      'NormalDistribution{mean: $mean, standardDeviation: $standardDeviation}';
}
