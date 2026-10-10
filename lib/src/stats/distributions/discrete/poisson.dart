import 'dart:math';

import 'package:more/printer.dart';

import '../../../special/gamma.dart';
import '../continuous/normal.dart';
import '../continuous/uniform.dart';
import '../discrete.dart';

/// The Poisson distribution.
///
/// See https://en.wikipedia.org/wiki/Poisson_distribution.
class PoissonDistribution extends DiscreteDistribution {
  /// A Poisson distribution with expected arrival [rate] $\lambda$.
  const new(this.rate) : assert(rate > 0, 'λ > 0');

  /// Fits a Poisson distribution to [samples] using maximum likelihood estimation.
  factory fit(Iterable<num> samples) {
    var count = 0;
    var sum = 0.0;
    for (final x in samples) {
      if (x < 0 || x.round() != x) {
        throw ArgumentError.value(
          x,
          'samples',
          'Samples must be non-negative integers',
        );
      }
      count++;
      sum += x;
    }
    if (count == 0) {
      throw ArgumentError.value(samples, 'samples', 'Cannot fit empty samples');
    }
    final mean = sum / count;
    return PoissonDistribution(mean > 0 ? mean : 1e-6);
  }

  /// Arrival rate $\lambda$.
  final double rate;

  @override
  int get lowerBound => 0;

  @override
  double get mean => rate;

  @override
  double get median => (rate + 1.0 / 3.0 - 0.02 / rate).floorToDouble();

  @override
  double get mode => rate.floorToDouble();

  @override
  double get variance => rate;

  @override
  double get skewness => 1.0 / sqrt(rate);

  @override
  double get excessKurtosis => 1.0 / rate;

  @override
  double probability(int k) =>
      k < 0 ? 0.0 : exp(k * log(rate) - rate - factorialLn(k));

  @override
  double cumulativeProbability(int k) =>
      k < 0 ? 0.0 : 1.0 - lowRegGamma(k + 1.0, rate);

  @override
  int sample({Random? random}) {
    if (rate < 30.0) {
      final limit = exp(-rate);
      var count = 0;
      var prod = 1.0;
      const uniform = UniformDistribution.standard();
      do {
        count++;
        prod *= uniform.sample(random: random);
      } while (prod > limit);
      return count - 1;
    } else {
      final normal = NormalDistribution(rate, sqrt(rate));
      final val = normal.sample(random: random).round();
      return val < 0 ? 0 : val;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is PoissonDistribution && rate == other.rate;

  @override
  int get hashCode => Object.hash(PoissonDistribution, rate);

  @override
  ObjectPrinter get toStringPrinter =>
      super.toStringPrinter..addValue(rate, name: 'λ');
}
