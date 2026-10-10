import 'dart:math';

import 'package:more/printer.dart';

import '../../../special/erf.dart';
import '../continuous.dart';
import '../errors.dart';
import 'uniform.dart';

/// Normal (or Gaussian) distribution described by [mean] μ and [standardDeviation] σ.
///
/// See https://en.wikipedia.org/wiki/Normal_distribution.
class NormalDistribution extends ContinuousDistribution {
  /// A normal distribution with parameters [mean] μ and [standardDeviation] σ.
  const new(this.mean, this.standardDeviation)
    : assert(standardDeviation > 0, 'σ > 0');

  /// A standard normal distribution centered around 0 with standard deviation 1.
  const new standard() : this(0.0, 1.0);

  /// Fits a normal distribution to [samples] using maximum likelihood estimation.
  factory fit(Iterable<num> samples) {
    var count = 0;
    var sum = 0.0;
    for (final x in samples) {
      count++;
      sum += x;
    }
    if (count < 2) {
      throw ArgumentError.value(
        samples,
        'samples',
        'At least 2 samples required to estimate variance',
      );
    }
    final mean = sum / count;
    var sumSqDiff = 0.0;
    for (final x in samples) {
      final diff = x - mean;
      sumSqDiff += diff * diff;
    }
    final variance = sumSqDiff / (count - 1);
    final stdDev = sqrt(variance);
    return NormalDistribution(mean, stdDev > 0 ? stdDev : 1e-15);
  }

  @override
  final double mean;

  @override
  final double standardDeviation;

  @override
  double get median => mean;

  @override
  double get mode => mean;

  @override
  double get variance => standardDeviation * standardDeviation;

  @override
  double get skewness => 0.0;

  @override
  double get excessKurtosis => 0.0;

  @override
  double probability(double x) {
    final z = (x - mean) / (sqrt2 * standardDeviation);
    return exp(-z * z) / (sqrt2 * sqrt(pi) * standardDeviation);
  }

  @override
  double cumulativeProbability(double x) {
    final z = (x - mean) / (sqrt2 * standardDeviation);
    return 0.5 * (1.0 + erf(z));
  }

  @override
  double inverseCumulativeProbability(num probability) {
    InvalidProbability.check(probability);
    return -1.41421356237309505 *
            standardDeviation *
            erfcInv(2.0 * probability) +
        mean;
  }

  @override
  double sample({Random? random}) => samples(random: random).first;

  @override
  Iterable<double> samples({Random? random}) sync* {
    const uniform = UniformDistribution(-1.0, 1.0);
    for (;;) {
      double xVal, yVal, rSq;
      do {
        xVal = uniform.sample(random: random);
        yVal = uniform.sample(random: random);
        rSq = xVal * xVal + yVal * yVal;
      } while (rSq >= 1.0 || rSq == 0.0);
      final factor = standardDeviation * sqrt(-2.0 * log(rSq) / rSq);
      yield mean + xVal * factor;
      yield mean + yVal * factor;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is NormalDistribution &&
      mean == other.mean &&
      standardDeviation == other.standardDeviation;

  @override
  int get hashCode => Object.hash(NormalDistribution, mean, standardDeviation);

  @override
  ObjectPrinter get toStringPrinter => super.toStringPrinter
    ..addValue(mean, name: 'μ')
    ..addValue(standardDeviation, name: 'σ');
}
