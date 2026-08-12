import 'dart:math';

import 'package:more/printer.dart';

import '../../../special/gamma.dart';
import '../discrete.dart';

/// The Poisson distribution is a discrete probability distribution that
/// expresses the probability of a given number of events occurring in a fixed
/// interval of time or space if these events occur with a known constant mean
/// rate and independently of the time since the last event.
///
/// See https://en.wikipedia.org/wiki/Poisson_distribution.
///
/// ```dart
/// final distribution = PoissonDistribution(2.5);
/// print(distribution.probability(2));  // 0.2565156207038153
/// ```
class PoissonDistribution extends DiscreteDistribution {
  /// A poisson distribution with parameter [lambda] λ.
  const new(this.lambda) : assert(0 <= lambda, '0 <= lambda');

  /// The parameter λ (rate, inverse scale).
  final double lambda;

  @override
  int get lowerBound => 0;

  @override
  double get mean => lambda;

  @override
  double get median => lambda;

  @override
  double get mode => lambda.floorToDouble();

  @override
  double get variance => lambda;

  @override
  double get skewness => 1 / sqrt(lambda);

  @override
  double get kurtosisExcess => 1 / lambda;

  @override
  double probability(int k) {
    if (k < 0) return 0;
    if (k == 0) return exp(-lambda);
    return exp(k * log(lambda) - lambda - factorialLn(k));
  }

  @override
  int sample({Random? random}) {
    final rand = random ?? _random;
    return lambda < 30
        ? _sampleKnuth(rand)
        : _sampleTransformedRejectionSqueeze(rand);
  }

  int _sampleKnuth(Random rand) {
    final L = exp(-lambda);
    var k = 0;
    var p = 1.0;
    do {
      k++;
      p *= rand.nextDouble();
    } while (p > L);
    return k - 1;
  }

  int _sampleTransformedRejectionSqueeze(Random rand) {
    final slam = sqrt(lambda);
    final loglam = log(lambda);
    final b = 0.931 + 2.53 * slam;
    final a = -0.059 + 0.02483 * b;
    final invalpha = 1.1239 + 1.1328 / (b - 3.4);
    final vr = 0.9277 - 3.6224 / (b - 2.0);
    for (;;) {
      final u = rand.nextDouble() - 0.5;
      final v = rand.nextDouble();
      final us = 0.5 - u.abs();
      final k = ((2.0 * a / us + b) * u + lambda + 0.43).floor();
      if (k < 0) continue;
      final g = v * invalpha;
      if (us >= 0.07 && g <= vr) {
        return k;
      }
      if (log(g) <= k * loglam - lambda - factorialLn(k)) {
        return k;
      }
    }
  }

  @override
  bool operator ==(Object other) =>
      other is PoissonDistribution && lambda == other.lambda;

  @override
  int get hashCode => Object.hash(PoissonDistribution, lambda);

  @override
  ObjectPrinter get toStringPrinter =>
      super.toStringPrinter..addValue(lambda, name: 'lambda');
}

final _random = Random();
