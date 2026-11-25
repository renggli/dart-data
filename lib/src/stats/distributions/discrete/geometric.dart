import 'dart:math';

import 'package:more/printer.dart';

import '../../../special/utils.dart';
import '../discrete.dart';
import '../errors.dart';
import '../utils.dart';

/// The Geometric distribution modeling the number of failures before the first
/// success in independent Bernoulli trials with success probability [p].
///
/// See https://en.wikipedia.org/wiki/Geometric_distribution.
///
/// ```dart
/// final distribution = GeometricDistribution(0.5);
/// print(distribution.mean);  // 1.0
/// ```
class GeometricDistribution extends DiscreteDistribution {
  /// A geometric distribution with success probability [p] in `(0, 1]`.
  new(this.p) {
    if (p.isNaN || p <= 0.0 || p > 1.0) {
      throw ArgumentError.value(p, 'p', 'Must be in (0.0, 1.0]');
    }
  }

  /// Fits a geometric distribution to non-negative integer [samples].
  factory fit(Iterable<num> samples) {
    final stats = welfordSampleStats(
      samples,
      isValid: (value) => value >= 0.0 && value.roundToDouble() == value,
      invalidMessage: 'Geometric samples must be non-negative integers',
    );
    return GeometricDistribution(1.0 / (1.0 + stats.mean));
  }

  /// Success probability of each trial in `(0, 1]`.
  final double p;

  @override
  int get lowerBound => 0;

  @override
  bool get isLowerBoundOpen => false;

  @override
  double get mean => (1.0 - p) / p;

  @override
  double get median => p == 1.0 ? 0.0 : (-ln2 / log1p(-p)).ceilToDouble() - 1.0;

  @override
  double get mode => 0.0;

  @override
  double get variance => (1.0 - p) / (p * p);

  @override
  double get skewness => p == 1.0 ? double.nan : (2.0 - p) / sqrt(1.0 - p);

  @override
  double get excessKurtosis =>
      p == 1.0 ? double.nan : 6.0 + (p * p) / (1.0 - p);

  @override
  double probability(int k) {
    if (k < 0) return 0.0;
    if (p == 1.0) return k == 0 ? 1.0 : 0.0;
    return exp(k * log1p(-p)) * p;
  }

  @override
  double logProbability(int x) {
    if (x < 0) return double.negativeInfinity;
    if (p == 1.0) return x == 0 ? 0.0 : double.negativeInfinity;
    return x * log1p(-p) + log(p);
  }

  @override
  double cumulativeProbability(int k) {
    if (k < 0) return 0.0;
    if (p == 1.0) return 1.0;
    return -expm1((k + 1) * log1p(-p));
  }

  @override
  double survival(int x) {
    if (x < 0) return 1.0;
    if (p == 1.0) return 0.0;
    return exp((x + 1) * log1p(-p));
  }

  @override
  int inverseCumulativeProbability(num probability) {
    InvalidProbability.check(probability);
    if (p == 1.0 || probability == 0) return 0;
    if (probability == 1) return upperBound;
    final ratio = log1p(-probability.toDouble()) / log1p(-p);
    if (!ratio.isFinite) return upperBound;
    final val = ratio.ceilToDouble() - 1.0;
    if (val <= 0.0) return 0;
    if (val >= upperBound.toDouble()) return upperBound;
    return val.toInt();
  }

  @override
  int inverseSurvival(num probability) {
    InvalidProbability.check(probability);
    if (p == 1.0 || probability == 1) return 0;
    if (probability == 0) return upperBound;
    final ratio = log(probability.toDouble()) / log1p(-p);
    if (!ratio.isFinite) return upperBound;
    final val = ratio.ceilToDouble() - 1.0;
    if (val <= 0.0) return 0;
    if (val >= upperBound.toDouble()) return upperBound;
    return val.toInt();
  }

  @override
  int sample({Random? random}) {
    if (p == 1.0) return 0;
    final uniform = nextOpenUnit(random ?? defaultRandom);
    return (log(uniform) / log1p(-p)).floor();
  }

  @override
  bool operator ==(Object other) =>
      other is GeometricDistribution && p == other.p;

  @override
  int get hashCode => Object.hash(GeometricDistribution, p);

  @override
  ObjectPrinter get toStringPrinter =>
      super.toStringPrinter..addValue(p, name: 'p');
}
