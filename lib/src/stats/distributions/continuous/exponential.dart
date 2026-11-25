import 'dart:math';

import 'package:more/printer.dart';

import '../../../special/utils.dart';
import '../continuous.dart';
import '../errors.dart';
import '../utils.dart';

/// The exponential distribution with rate parameter [rate] (λ > 0).
///
/// See https://en.wikipedia.org/wiki/Exponential_distribution.
class ExponentialDistribution extends ContinuousDistribution {
  /// An exponential distribution with [rate] λ.
  new(this.rate) {
    if (!rate.isFinite || rate <= 0) {
      throw ArgumentError.value(rate, 'rate', 'Rate must be strictly positive');
    }
  }

  /// A standard exponential distribution with λ = 1.
  const new standard() : this._(1.0);

  const new _(this.rate);

  /// Fits an exponential distribution to [samples] using maximum likelihood
  /// estimation.
  factory fit(Iterable<num> samples) {
    final stats = welfordSampleStats(
      samples,
      isValid: (value) => value >= 0.0,
      invalidMessage: 'Samples must be non-negative',
    );
    return ExponentialDistribution(stats.mean > 0.0 ? 1.0 / stats.mean : 1.0);
  }

  /// The rate parameter λ.
  final double rate;

  @override
  double get lowerBound => 0.0;

  @override
  bool get isLowerBoundOpen => false;

  @override
  double get mean => 1.0 / rate;

  @override
  double get median => ln2 / rate;

  @override
  double get mode => 0.0;

  @override
  double get variance => 1.0 / (rate * rate);

  @override
  double get skewness => 2.0;

  @override
  double get excessKurtosis => 6.0;

  @override
  double probability(double x) =>
      x.isNaN ? double.nan : (x >= 0.0 ? rate * exp(-rate * x) : 0.0);

  @override
  double logProbability(double x) {
    if (x.isNaN) return double.nan;
    if (x < 0.0 || x == double.infinity) return double.negativeInfinity;
    return log(rate) - rate * x;
  }

  @override
  double cumulativeProbability(double x) {
    if (x.isNaN) return double.nan;
    if (x <= 0.0) return 0.0;
    return -expm1(-rate * x);
  }

  @override
  double survival(double x) {
    if (x.isNaN) return double.nan;
    if (x <= 0.0) return 1.0;
    return exp(-rate * x);
  }

  @override
  double inverseCumulativeProbability(num probability) {
    InvalidProbability.check(probability);
    return -log1p(-probability.toDouble()) / rate;
  }

  @override
  double inverseSurvival(num probability) {
    InvalidProbability.check(probability);
    return -log(probability.toDouble()) / rate;
  }

  @override
  double sample({Random? random}) {
    final uniform = nextOpenUnit(random ?? defaultRandom);
    return -log(uniform) / rate;
  }

  @override
  bool operator ==(Object other) =>
      other is ExponentialDistribution && rate == other.rate;

  @override
  int get hashCode => Object.hash(ExponentialDistribution, rate);

  @override
  ObjectPrinter get toStringPrinter =>
      super.toStringPrinter..addValue(rate, name: 'λ');
}
