import 'dart:math';

import 'package:more/hash.dart';

import '../continuous.dart';

/// A continuous uniform distribution between the bounds [a] and [b]. The
/// distribution describes an experiment where there is an arbitrary outcome
/// that lies between certain bounds.
///
/// For details see https://en.wikipedia.org/wiki/Continuous_uniform_distribution.
class UniformDistribution extends ContinuousDistribution {
  const UniformDistribution(this.a, this.b);

  /// Minimum value of the distribution.
  final double a;

  /// Maximum value of the distribution.
  final double b;

  @override
  double get lowerBound => a;

  @override
  double get upperBound => b;

  @override
  double get mean => (a + b) / 2.0;

  @override
  double get median => mean;

  @override
  double get variance => pow(b - a, 2) / 12.0;

  @override
  double probability(double x) => a <= x && x <= b ? 1.0 / (b - a) : 0.0;

  @override
  double cumulativeProbability(double x) => x <= a
      ? 0.0
      : x <= b
          ? (x - a) / (b - a)
          : 1.0;

  @override
  double inverseCumulativeProbability(num p) => a + p * (b - a);

  @override
  double sample({Random? random}) =>
      a + (b - a) * ((random ?? _random).nextDouble());

  @override
  bool operator ==(Object other) =>
      other is UniformDistribution && a == other.a && b == other.b;

  @override
  int get hashCode => hash2(a, b);

  @override
  String toString() => 'UniformDistribution[$a..$b]';
}

final _random = Random();
