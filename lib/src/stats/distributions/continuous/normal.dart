import 'dart:math';

import 'package:more/printer.dart';

import '../../../special/erf.dart';
import '../continuous.dart';
import '../errors.dart';
import '../utils.dart';

/// Normal (or Gaussian) distribution described by [mean] μ and
/// [standardDeviation] σ.
///
/// See https://en.wikipedia.org/wiki/Normal_distribution.
class NormalDistribution extends ContinuousDistribution {
  /// A normal distribution with parameters [mean] μ and
  /// [standardDeviation] σ.
  new(this.mean, this.standardDeviation) {
    if (!mean.isFinite) {
      throw ArgumentError.value(mean, 'mean', 'Mean must be finite');
    }
    if (!standardDeviation.isFinite || standardDeviation <= 0) {
      throw ArgumentError.value(
        standardDeviation,
        'standardDeviation',
        'Standard deviation must be strictly positive',
      );
    }
  }

  /// A standard normal distribution centered around 0 with standard deviation
  /// 1.
  const new standard() : this._(0.0, 1.0);

  const new _(this.mean, this.standardDeviation);

  /// Fits a normal distribution to [samples] using maximum likelihood
  /// estimation.
  factory fit(Iterable<num> samples) {
    final stats = welfordSampleStats(samples, minCount: 2);
    final stdDev = sqrt(stats.variance);
    return NormalDistribution(stats.mean, stdDev > 0 ? stdDev : 1e-15);
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
  double logProbability(double x) {
    if (x.isNaN) return double.nan;
    if (x.isInfinite) return double.negativeInfinity;
    final z = (x - mean) / standardDeviation;
    return -0.5 * _ln2pi - log(standardDeviation) - 0.5 * z * z;
  }

  @override
  double cumulativeProbability(double x) {
    final z = (x - mean) / (sqrt2 * standardDeviation);
    return z < 0.0 ? 0.5 * erfc(-z) : 0.5 * (1.0 + erf(z));
  }

  @override
  double survival(double x) {
    final z = (x - mean) / (sqrt2 * standardDeviation);
    return z < 0.0 ? 0.5 * (1.0 + erf(-z)) : 0.5 * erfc(z);
  }

  @override
  double inverseCumulativeProbability(num probability) {
    InvalidProbability.check(probability);
    if (probability == 0.0) return double.negativeInfinity;
    if (probability == 1.0) return double.infinity;
    return probability < 0.5
        ? -sqrt2 * standardDeviation * erfcInv(2.0 * probability) + mean
        : sqrt2 * standardDeviation * erfcInv(2.0 * (1.0 - probability)) + mean;
  }

  @override
  double inverseSurvival(num probability) {
    InvalidProbability.check(probability);
    if (probability == 0.0) return double.infinity;
    if (probability == 1.0) return double.negativeInfinity;
    return probability < 0.5
        ? sqrt2 * standardDeviation * erfcInv(2.0 * probability) + mean
        : -sqrt2 * standardDeviation * erfcInv(2.0 * (1.0 - probability)) +
              mean;
  }

  @override
  double sample({Random? random}) {
    final rng = random ?? defaultRandom;
    double xVal, yVal, rSq;
    do {
      xVal = 2.0 * rng.nextDouble() - 1.0;
      yVal = 2.0 * rng.nextDouble() - 1.0;
      rSq = xVal * xVal + yVal * yVal;
    } while (rSq >= 1.0 || rSq == 0.0);
    return mean + standardDeviation * xVal * sqrt(-2.0 * log(rSq) / rSq);
  }

  @override
  Iterable<double> samples({Random? random}) sync* {
    final rng = random ?? defaultRandom;
    for (;;) {
      double xVal, yVal, rSq;
      do {
        xVal = 2.0 * rng.nextDouble() - 1.0;
        yVal = 2.0 * rng.nextDouble() - 1.0;
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

final double _ln2pi = log(2.0 * pi);
