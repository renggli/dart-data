import 'dart:math';

import 'package:more/printer.dart';

import '../continuous.dart';
import '../errors.dart';

/// The Laplace distribution is a continuous probability distribution defined by
/// its [location] and [scale] parameters. It is also known as the double
/// exponential distribution.
///
/// See https://en.wikipedia.org/wiki/Laplace_distribution.
///
/// ```dart
/// final distribution = LaplaceDistribution(0, 1);
/// print(distribution.variance);  // 2.0
/// ```
class LaplaceDistribution extends ContinuousDistribution {
  /// A Laplace distribution with [location] and [scale].
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

  /// A standard Laplace distribution with location 0 and scale 1.
  const new standard() : this._(0.0, 1.0);

  const new _(this.location, this.scale);

  /// Fits a Laplace distribution to [samples] using maximum likelihood
  /// estimation (sample median and mean absolute deviation).
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
    var madSum = 0.0;
    for (final x in list) {
      madSum += (x - median).abs();
    }
    var scale = madSum / n;
    if (scale <= 0.0) {
      scale = 1.0;
    }
    return LaplaceDistribution(median, scale);
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
  double get mean => location;

  @override
  double get median => location;

  @override
  double get mode => location;

  @override
  double get variance => 2 * scale * scale;

  @override
  double get skewness => 0;

  @override
  double get excessKurtosis => 3;

  @override
  double probability(double x) =>
      exp(-(x - location).abs() / scale) / (2 * scale);

  @override
  double cumulativeProbability(double x) {
    final diff = x - location;
    return diff < 0 ? 0.5 * exp(diff / scale) : 1 - 0.5 * exp(-diff / scale);
  }

  @override
  double inverseCumulativeProbability(num probability) {
    InvalidProbability.check(probability);
    if (probability == 0) return double.negativeInfinity;
    if (probability == 1) return double.infinity;
    if (probability < 0.5) {
      return location + scale * log(2 * probability);
    } else {
      return location - scale * log(2 * (1 - probability));
    }
  }

  @override
  double sample({Random? random}) {
    final uniform = (random ?? _random).nextDouble();
    return inverseCumulativeProbability(uniform);
  }

  @override
  bool operator ==(Object other) =>
      other is LaplaceDistribution &&
      location == other.location &&
      scale == other.scale;

  @override
  int get hashCode => Object.hash(LaplaceDistribution, location, scale);

  @override
  ObjectPrinter get toStringPrinter => super.toStringPrinter
    ..addValue(location, name: 'location')
    ..addValue(scale, name: 'scale');
}

final _random = Random();
