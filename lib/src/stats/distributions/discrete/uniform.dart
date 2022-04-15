import 'dart:math';

import 'package:more/printer.dart';

import '../continuous/uniform.dart';
import '../discrete.dart';

/// A discrete uniform distribution between [a] and [b], for details see
/// https://en.wikipedia.org/wiki/Discrete_uniform_distribution.
class UniformDiscreteDistribution extends DiscreteDistribution {
  const UniformDiscreteDistribution(this.a, this.b) : assert(a <= b, 'a <= b');

  /// Minimum value of the distribution.
  final int a;

  /// Maximum value of the distribution.
  final int b;

  // Returns the number of elements in this distribution.
  int get n => b - a + 1;

  @override
  int get lowerBound => a;

  @override
  int get upperBound => b;

  @override
  double get mean => 0.5 * (a + b);

  @override
  double get median => mean;

  @override
  double get mode => double.nan;

  @override
  double get variance => (n * n - 1) / 12;

  @override
  double get skewness => 0;

  @override
  double get excessKurtosis => -6 / 5 * (n * n + 1) / (n * n - 1);

  @override
  double probability(int k) => a <= k && k <= b ? 1 / n : 0;

  @override
  double cumulativeProbability(int k) => k < a
      ? 0
      : k <= b
          ? (k - a + 1) / n
          : 1;

  @override
  int sample({Random? random}) {
    const uniform = UniformDistribution.standard();
    return a + (n * uniform.sample(random: random)).floor();
  }

  @override
  bool operator ==(Object other) =>
      other is UniformDiscreteDistribution && a == other.a && b == other.b;

  @override
  int get hashCode => Object.hash(UniformDiscreteDistribution, a, b);

  @override
  ObjectPrinter get toStringPrinter => super.toStringPrinter
    ..addValue(a, name: 'a')
    ..addValue(b, name: 'b');
}
