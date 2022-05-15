import 'dart:math';

import '../continuous/uniform.dart';
import '../discrete.dart';

/// The Rademacher distribution is a discrete probability function which takes
/// value 1 with probability 1/2 and value −1 with probability 1/2.
///
/// See https://en.wikipedia.org/wiki/Rademacher_distribution.
class RademacherDistribution extends DiscreteDistribution {
  /// A Rademacher distribution.
  const RademacherDistribution();

  @override
  int get lowerBound => -1;

  @override
  int get upperBound => 1;

  @override
  double get mean => 0;

  @override
  double get median => 0;

  @override
  double get mode => double.nan;

  @override
  double get variance => 1;

  @override
  double get skewness => 0;

  @override
  double get kurtosisExcess => -2;

  @override
  double probability(int k) => k == -1 || k == 1 ? 0.5 : 0;

  @override
  double cumulativeProbability(int k) => k < -1
      ? 0
      : k < 1
          ? 0.5
          : 1;

  @override
  int sample({Random? random}) {
    const uniform = UniformDistribution.standard();
    return uniform.sample(random: random) < 0.5 ? -1 : 1;
  }

  @override
  bool operator ==(Object other) => other is RademacherDistribution;

  @override
  int get hashCode => 70196453;
}
