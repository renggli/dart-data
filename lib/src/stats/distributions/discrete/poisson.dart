import 'dart:math';

import 'package:more/printer.dart';

import '../../../special/factorial.dart';
import '../../../special/gamma.dart';
import '../discrete.dart';
import '../utils.dart';

/// The Poisson distribution with arrival rate [rate] (λ > 0).
///
/// See https://en.wikipedia.org/wiki/Poisson_distribution.
class PoissonDistribution extends DiscreteDistribution {
  /// A Poisson distribution with expected arrival [rate] λ.
  new(this.rate) {
    if (!rate.isFinite || rate <= 0) {
      throw ArgumentError.value(rate, 'rate', 'Must be positive');
    }
  }

  /// Fits a Poisson distribution to [samples] using maximum likelihood
  /// estimation.
  factory fit(Iterable<num> samples) {
    final stats = welfordSampleStats(
      samples,
      isValid: (value) => value >= 0.0 && value.roundToDouble() == value,
      invalidMessage: 'Samples must be non-negative integers',
    );
    return PoissonDistribution(stats.mean > 0.0 ? stats.mean : 1e-6);
  }

  /// Arrival rate λ.
  final double rate;

  @override
  int get lowerBound => 0;

  @override
  bool get isLowerBoundOpen => false;

  @override
  double get mean => rate;

  @override
  double get median => inverseCumulativeProbability(0.5).toDouble();

  @override
  double get mode => rate.floorToDouble();

  @override
  double get variance => rate;

  @override
  double get skewness => 1.0 / sqrt(rate);

  @override
  double get excessKurtosis => 1.0 / rate;

  @override
  double probability(int k) => k < 0 ? 0.0 : exp(logProbability(k));

  @override
  double logProbability(int x) =>
      x < 0 ? double.negativeInfinity : x * log(rate) - rate - factorialLn(x);

  @override
  double cumulativeProbability(int k) => k < 0 ? 0.0 : gammaQ(k + 1.0, rate);

  @override
  double survival(int x) => x < 0 ? 1.0 : gammaP(x + 1.0, rate);

  @override
  int sample({Random? random}) {
    final rng = random ?? defaultRandom;
    if (rate < 30.0) {
      final limit = exp(-rate);
      var count = 0;
      var prod = 1.0;
      do {
        count++;
        prod *= nextOpenUnit(rng);
      } while (prod > limit);
      return count - 1;
    }
    return _samplePtrd(rate, rng);
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

/// Hörmann's PTRD transformed-rejection Poisson sampler for `rate >= 30`.
int _samplePtrd(double rate, Random rng) {
  final slam = sqrt(rate);
  final logRate = log(rate);
  final b = 0.931 + 2.53 * slam;
  final a = -0.059 + 0.02483 * b;
  final invAlpha = 1.1239 + 1.1328 / (b - 3.4);
  final vr = 0.9277 - 3.6224 / (b - 2.0);

  for (;;) {
    final u = rng.nextDouble() - 0.5;
    final us = 0.5 - u.abs();
    final v = nextOpenUnit(rng);
    final k = ((2.0 * a / us + b) * u + rate + 0.43).floor();
    if (us >= 0.07 && v <= vr) {
      return k;
    }
    if (k < 0 || (us < 0.013 && v > us)) {
      continue;
    }
    final logRatio = log(v) + log(invAlpha) - log(a / (us * us) + b);
    if (logRatio <= -rate + k * logRate - factorialLn(k)) {
      return k;
    }
  }
}
