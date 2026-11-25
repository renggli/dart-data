import 'dart:collection' show ListBase;
import 'dart:math' as math;

import 'package:collection/collection.dart' show NonGrowableListMixin;
import 'package:meta/meta.dart';
import 'package:more/printer.dart' show ObjectPrinter, ToStringPrinter;

import '../descriptive.dart';
import '../distributions/continuous/normal.dart';

/// Deterministic leave-one-out Jackknife resampling estimator for bias,
/// standard error, confidence intervals, pseudo-values, and influence values.
///
/// See https://en.wikipedia.org/wiki/Jackknife_resampling.
@immutable
class Jackknife<T> with ToStringPrinter {
  /// Constructs a Jackknife estimator over [samples] for [statistic].
  ///
  /// Throws [ArgumentError] if fewer than 2 samples are provided or
  /// [confidenceLevel] is not finite in `(0, 1)`.
  new(List<T> samples, this.statistic, {this.confidenceLevel = 0.95})
    : samples = List<T>.unmodifiable(samples) {
    if (samples.length < 2) {
      throw ArgumentError.value(
        samples,
        'samples',
        'At least 2 samples required for jackknife',
      );
    }
    if (!(confidenceLevel.isFinite &&
        0.0 < confidenceLevel &&
        confidenceLevel < 1.0)) {
      throw ArgumentError.value(
        confidenceLevel,
        'confidenceLevel',
        'Confidence level must be between 0 and 1',
      );
    }
  }

  /// An unmodifiable copy of the input sample data.
  final List<T> samples;

  /// The statistical function evaluated on each resample.
  final double Function(List<T> list) statistic;

  /// The confidence level in `(0, 1)` for [confidenceInterval].
  final double confidenceLevel;

  /// The `n` unmodifiable leave-one-out sample views.
  late final List<List<T>> resamples = List<List<T>>.unmodifiable([
    for (var i = 0; i < samples.length; i++)
      _JackknifeResampling<T>(samples, i),
  ]);

  /// The `n` leave-one-out statistic evaluations `theta_(-i)`.
  late final List<double> resampleEstimates = List<double>.unmodifiable(
    resamples.map(statistic),
  );

  /// The `n` jackknife pseudo-values `n * theta_hat - (n - 1) * theta_(-i)`.
  late final List<double> pseudoValues = List<double>.unmodifiable([
    for (final estimate in resampleEstimates)
      samples.length * _sampleMeasure - (samples.length - 1) * estimate,
  ]);

  /// The empirical influence values `(n - 1) * (theta_(.) - theta_(-i))`.
  late final List<double> influenceValues = List<double>.unmodifiable([
    for (final estimate in resampleEstimates)
      (samples.length - 1) * (_meanResampleMeasure - estimate),
  ]);

  /// BCa skewness acceleration parameter `a` computed from [influenceValues]
  /// with scale normalization to prevent overflow.
  late final double acceleration = _computeAcceleration();

  /// Estimated jackknife bias `(n - 1) * (mean(theta_(-i)) - theta_hat)`.
  late final double bias =
      (samples.length - 1) * (_meanResampleMeasure - _sampleMeasure);

  /// Bias-corrected jackknife point estimate `theta_hat - bias`.
  late final double estimate = _sampleMeasure - bias;

  /// Estimated jackknife standard error.
  late final double standardError = math.sqrt(
    (samples.length - 1) * resampleEstimates.variance(population: true),
  );

  /// Lower bound of the normal-theory jackknife confidence interval.
  late final double lowerBound = estimate - _zScore * standardError;

  /// Upper bound of the normal-theory jackknife confidence interval.
  late final double upperBound = estimate + _zScore * standardError;

  /// Normal-theory jackknife confidence interval `(lower, upper)`.
  ({double lower, double upper}) get confidenceInterval =>
      (lower: lowerBound, upper: upperBound);

  @override
  ObjectPrinter get toStringPrinter => super.toStringPrinter
    ..addValue(estimate, name: 'estimate')
    ..addValue(bias, name: 'bias')
    ..addValue(standardError, name: 'standardError')
    ..addValue(lowerBound, name: 'lowerBound')
    ..addValue(upperBound, name: 'upperBound')
    ..addValue(confidenceLevel, name: 'confidenceLevel');

  late final double _sampleMeasure = statistic(samples);
  late final double _meanResampleMeasure = resampleEstimates.mean();
  late final double _zScore = const NormalDistribution.standard()
      .inverseSurvival(0.5 * (1.0 - confidenceLevel));

  double _computeAcceleration() {
    var maxAbs = 0.0;
    for (final u in influenceValues) {
      final au = u.abs();
      if (!au.isFinite) return 0.0;
      if (au > maxAbs) maxAbs = au;
    }
    if (maxAbs == 0.0) return 0.0;
    final inv = 1.0 / maxAbs;
    var num = 0.0;
    var den = 0.0;
    for (final u in influenceValues) {
      final s = u * inv;
      final s2 = s * s;
      num += s2 * s;
      den += s2;
    }
    return den > 0.0 ? num / (6.0 * math.pow(den, 1.5)) : 0.0;
  }
}

class _JackknifeResampling<T> extends ListBase<T> with NonGrowableListMixin<T> {
  new(this.list, this.omittedIndex);

  final List<T> list;
  final int omittedIndex;

  @override
  int get length => list.length - 1;

  @override
  T operator [](int index) {
    RangeError.checkValidIndex(index, this, 'index');
    return index < omittedIndex ? list[index] : list[index + 1];
  }

  @override
  void operator []=(int index, T value) =>
      throw UnsupportedError('Cannot modify');
}
