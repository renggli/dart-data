import 'dart:math';

import 'package:more/printer.dart';

import '../continuous.dart';
import '../errors.dart';
import 'uniform.dart';

/// The exponential distribution.
///
/// See https://en.wikipedia.org/wiki/Exponential_distribution.
class ExponentialDistribution extends ContinuousDistribution {
  /// An exponential distribution with [rate] $\lambda$.
  const new(this.rate) : assert(rate > 0, 'λ > 0');

  /// Fits an exponential distribution to [samples] using maximum likelihood estimation.
  factory fit(Iterable<num> samples) {
    var count = 0;
    var sum = 0.0;
    for (final x in samples) {
      if (x < 0) {
        throw ArgumentError.value(x, 'samples', 'Samples must be non-negative');
      }
      count++;
      sum += x;
    }
    if (count == 0) {
      throw ArgumentError.value(samples, 'samples', 'Cannot fit empty samples');
    }
    final mean = sum / count;
    return ExponentialDistribution(mean > 0 ? 1.0 / mean : 1.0);
  }

  /// The rate parameter $\lambda$.
  final double rate;

  @override
  double get lowerBound => 0.0;

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
  double probability(double x) => x >= 0.0 ? rate * exp(-rate * x) : 0.0;

  @override
  double cumulativeProbability(double x) =>
      x >= 0.0 ? 1.0 - exp(-rate * x) : 0.0;

  @override
  double inverseCumulativeProbability(num probability) {
    InvalidProbability.check(probability);
    return -log(1.0 - probability) / rate;
  }

  @override
  double sample({Random? random}) {
    const uniform = UniformDistribution.standard();
    return -log(1.0 - uniform.sample(random: random)) / rate;
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
