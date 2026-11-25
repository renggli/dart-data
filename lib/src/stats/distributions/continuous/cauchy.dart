import 'dart:math';

import 'package:more/printer.dart';

import '../../../special/utils.dart';
import '../continuous.dart';
import '../errors.dart';
import '../utils.dart';

/// The Cauchy distribution, also called the Lorentz distribution, is a
/// continuous probability distribution parameterized by [location] and [scale]
/// (γ).
///
/// See https://en.wikipedia.org/wiki/Cauchy_distribution.
///
/// ```dart
/// final distribution = CauchyDistribution(0, 1);
/// print(distribution.median);  // 0.0
/// ```
class CauchyDistribution extends ContinuousDistribution {
  /// A Cauchy distribution with [location] and [scale].
  new([this.location = 0.0, this.scale = 1.0]) {
    if (!location.isFinite) {
      throw ArgumentError.value(
        location,
        'location',
        'Location must be finite',
      );
    }
    if (!scale.isFinite || scale <= 0) {
      throw ArgumentError.value(scale, 'scale', 'Scale must be positive');
    }
  }

  /// A standard Cauchy distribution with location 0 and scale 1.
  const new standard() : this._(0.0, 1.0);

  const new _(this.location, this.scale);

  /// Fits a Cauchy distribution to [samples] using median and interquartile
  /// range.
  factory fit(Iterable<num> samples) {
    final list = <double>[];
    for (final x in samples) {
      final val = x.toDouble();
      if (!val.isFinite) {
        throw ArgumentError.value(x, 'samples', 'Samples must be finite');
      }
      list.add(val);
    }
    if (list.isEmpty) {
      throw ArgumentError.value(samples, 'samples', 'Cannot fit empty samples');
    }
    list.sort();
    final n = list.length;
    final median = n.isOdd
        ? list[n ~/ 2]
        : 0.5 * (list[n ~/ 2 - 1] + list[n ~/ 2]);
    final q1 = list[(0.25 * (n - 1)).round()];
    final q3 = list[(0.75 * (n - 1)).round()];
    var scale = 0.5 * (q3 - q1);
    if (scale <= 0.0) {
      scale = 1.0;
    }
    return CauchyDistribution(median, scale);
  }

  /// The location parameter.
  final double location;

  /// The scale parameter.
  final double scale;

  @override
  double get lowerBound => double.negativeInfinity;

  @override
  double get upperBound => double.infinity;

  @override
  double get mean => double.nan;

  @override
  double get median => location;

  @override
  double get mode => location;

  @override
  double get variance => double.nan;

  @override
  double get skewness => double.nan;

  @override
  double get excessKurtosis => double.nan;

  @override
  double probability(double x) {
    if (x.isNaN) return double.nan;
    if (x.isInfinite) return 0.0;
    final z = (x - location) / scale;
    return 1.0 / (pi * scale * (1.0 + z * z));
  }

  @override
  double logProbability(double x) {
    if (x.isNaN) return double.nan;
    if (x.isInfinite) return double.negativeInfinity;
    final z = (x - location).abs() / scale;
    if (z > 1e8) {
      return -log(pi) - log(scale) - 2.0 * log(z) - log1p(1.0 / (z * z));
    }
    return -log(pi * scale) - log1p(z * z);
  }

  @override
  double cumulativeProbability(double x) {
    if (x.isNaN) return double.nan;
    return atan2(scale, location - x) / pi;
  }

  @override
  double survival(double x) {
    if (x.isNaN) return double.nan;
    return atan2(scale, x - location) / pi;
  }

  @override
  double inverseCumulativeProbability(num probability) {
    InvalidProbability.check(probability);
    if (probability == 0) return double.negativeInfinity;
    if (probability == 1) return double.infinity;
    final pd = probability.toDouble();
    if (pd < 0.25) {
      return location - scale / tan(pi * pd);
    }
    return location + scale * tan(pi * (pd - 0.5));
  }

  @override
  double inverseSurvival(num probability) {
    InvalidProbability.check(probability);
    if (probability == 0) return double.infinity;
    if (probability == 1) return double.negativeInfinity;
    final pd = probability.toDouble();
    if (pd < 0.25) {
      return location + scale / tan(pi * pd);
    }
    return location - scale * tan(pi * (pd - 0.5));
  }

  @override
  double sample({Random? random}) {
    final uniform = nextOpenUnit(random ?? defaultRandom);
    return location + scale * tan(pi * (uniform - 0.5));
  }

  @override
  bool operator ==(Object other) =>
      other is CauchyDistribution &&
      location == other.location &&
      scale == other.scale;

  @override
  int get hashCode => Object.hash(CauchyDistribution, location, scale);

  @override
  ObjectPrinter get toStringPrinter => super.toStringPrinter
    ..addValue(location, name: 'location')
    ..addValue(scale, name: 'scale');
}
