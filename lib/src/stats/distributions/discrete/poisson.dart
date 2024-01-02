import 'dart:math';

import 'package:more/printer.dart';

import '../../../special/gamma.dart';
import '../continuous/uniform.dart';
import '../discrete.dart';

/// The Poisson distribution is a discrete probability distribution that
/// expresses the probability of a given number of events occurring in a fixed
/// interval of time or space if these events occur with a known constant mean
/// rate and independently of the time since the last event.
///
/// See https://en.wikipedia.org/wiki/Poisson_distribution.
class PoissonDistribution extends DiscreteDistribution {
  /// A poisson distribution with parameter [lambda] λ.
  const PoissonDistribution(this.lambda) : assert(0 <= lambda, '0 <= lambda');

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
  double probability(int k) => k < 0
      ? 0
      : k == 0
          ? exp(-lambda)
          : pow(lambda, k) * exp(-lambda) / factorial(k);

  @override
  int sample({Random? random}) {
    const uniform = UniformDistribution.standard();
    var i = 0, b = 1.0;
    while (b >= exp(-lambda)) {
      b *= uniform.sample(random: random);
      i++;
    }
    return i - 1;
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
