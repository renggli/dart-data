import 'dart:math' as math;

import 'package:meta/meta.dart';
import 'package:more/printer.dart' show ObjectPrinter, ToStringPrinter;

import '../descriptive.dart';
import '../distribution.dart';
import '../distributions/continuous/normal.dart';
import '../distributions/utils.dart';
import 'jackknife.dart';

/// Bootstrap resampling estimator for standard errors, bias, and confidence
/// intervals (normal, basic, percentile, and BCa).
///
/// See https://en.wikipedia.org/wiki/Bootstrapping_(statistics).
@immutable
class Bootstrap<T> with ToStringPrinter {
  /// Computes non-parametric bootstrap estimates and confidence intervals by
  /// resampling an unmodifiable copy of [samples] with replacement.
  ///
  /// Throws [ArgumentError] if `samples.length < 2`, `resamples < 10`, or
  /// [confidenceLevel] is not finite in `(0, 1)`.
  new(
    List<T> samples,
    this.statistic, {
    this.resamples = 1000,
    this.confidenceLevel = 0.95,
    this.random,
  }) : samples = List<T>.unmodifiable(samples),
       sampler = null {
    _validateParameters(samples, resamples, confidenceLevel);
  }

  /// Computes parametric bootstrap estimates and confidence intervals by
  /// generating synthetic samples via [sampler].
  ///
  /// Throws [ArgumentError] if `samples.length < 2`, `resamples < 10`, or
  /// [confidenceLevel] is not finite in `(0, 1)`.
  new parametric({
    required List<T> samples,
    required this.statistic,
    required List<T> Function(math.Random random) this.sampler,
    this.resamples = 1000,
    this.confidenceLevel = 0.95,
    this.random,
  }) : samples = List<T>.unmodifiable(samples) {
    _validateParameters(samples, resamples, confidenceLevel);
  }

  /// Computes parametric bootstrap estimates by drawing synthetic samples
  /// from a fitted probability [distribution].
  static Bootstrap<T> distribution<T extends num>({
    required List<T> samples,
    required double Function(List<T> list) statistic,
    required Distribution<T> distribution,
    int resamples = 1000,
    double confidenceLevel = 0.95,
    math.Random? random,
  }) => Bootstrap<T>.parametric(
    samples: samples,
    statistic: statistic,
    sampler: (rng) => [
      for (var i = 0; i < samples.length; i++) distribution.sample(random: rng),
    ],
    resamples: resamples,
    confidenceLevel: confidenceLevel,
    random: random,
  );

  /// An unmodifiable copy of the input sample data.
  final List<T> samples;

  /// The statistical function evaluated on each resample.
  final double Function(List<T> list) statistic;

  /// The number of bootstrap resamples.
  final int resamples;

  /// The confidence level in `(0, 1)` for confidence intervals.
  final double confidenceLevel;

  /// Optional random number generator.
  final math.Random? random;

  /// Optional custom generative sampler for parametric bootstrap.
  final List<T> Function(math.Random random)? sampler;

  /// The point estimate evaluated on [samples].
  late final double estimate = statistic(samples);

  /// The unmodifiable list of bootstrap estimates sorted in ascending order.
  late final List<double> bootstrapEstimates = _computeBootstrapEstimates();

  /// The empirical standard error of [bootstrapEstimates].
  late final double standardError = standardDeviation(bootstrapEstimates);

  /// The empirical bias `mean(bootstrapEstimates) - estimate`.
  late final double bias = mean(bootstrapEstimates) - estimate;

  /// Normal-approximation confidence interval correcting for [bias].
  late final ({double lower, double upper}) normalInterval = () {
    const normal = NormalDistribution.standard();
    final z = normal.inverseSurvival(0.5 * _alpha);
    final centered = estimate - bias;
    return (
      lower: centered - z * standardError,
      upper: centered + z * standardError,
    );
  }();

  /// Basic (reverse-percentile) bootstrap confidence interval.
  late final ({double lower, double upper}) basicInterval = (
    lower: 2.0 * estimate - percentileInterval.upper,
    upper: 2.0 * estimate - percentileInterval.lower,
  );

  /// Percentile bootstrap confidence interval `(lower, upper)`.
  late final ({double lower, double upper}) percentileInterval = (
    lower: _sortedQuantile(bootstrapEstimates, 0.5 * _alpha),
    upper: _sortedQuantile(bootstrapEstimates, 1.0 - 0.5 * _alpha),
  );

  /// Bias-corrected and accelerated (BCa) confidence interval `(lower, upper)`.
  late final ({double lower, double upper}) bcaInterval = _computeBcaInterval();

  /// The lower bound of the BCa confidence interval.
  double get lowerBound => bcaInterval.lower;

  /// The upper bound of the BCa confidence interval.
  double get upperBound => bcaInterval.upper;

  @override
  ObjectPrinter get toStringPrinter => super.toStringPrinter
    ..addValue(estimate, name: 'estimate')
    ..addValue(bias, name: 'bias')
    ..addValue(standardError, name: 'standardError')
    ..addValue(lowerBound, name: 'lowerBound')
    ..addValue(upperBound, name: 'upperBound')
    ..addValue(percentileInterval, name: 'percentileCI')
    ..addValue(bcaInterval, name: 'bcaCI')
    ..addValue(confidenceLevel, name: 'confidenceLevel');

  late final double _alpha = 1.0 - confidenceLevel;

  List<double> _computeBootstrapEstimates() {
    final rng = random ?? defaultRandom;
    final effectiveSampler = sampler;
    final sampleSize = samples.length;
    final estimates = List<double>.filled(resamples, 0.0);
    if (effectiveSampler != null) {
      for (var b = 0; b < resamples; b++) {
        estimates[b] = statistic(effectiveSampler(rng));
      }
    } else {
      final resampleBuffer = List<T>.filled(sampleSize, samples[0]);
      for (var b = 0; b < resamples; b++) {
        for (var i = 0; i < sampleSize; i++) {
          resampleBuffer[i] = samples[rng.nextInt(sampleSize)];
        }
        estimates[b] = statistic(resampleBuffer);
      }
    }
    estimates.sort();
    return List<double>.unmodifiable(estimates);
  }

  ({double lower, double upper}) _computeBcaInterval() {
    final sorted = bootstrapEstimates;
    if (sorted.first == sorted.last) {
      return (lower: sorted.first, upper: sorted.last);
    }

    const normal = NormalDistribution.standard();
    var lessCount = 0;
    for (final est in sorted) {
      if (est < estimate) lessCount++;
    }
    final fracLess = (lessCount / resamples).clamp(1e-6, 1.0 - 1e-6);
    final z0 = normal.inverseCumulativeProbability(fracLess);
    final accel = Jackknife<T>(samples, statistic).acceleration;

    final zAlphaLow = normal.inverseCumulativeProbability(0.5 * _alpha);
    final zAlphaHigh = -zAlphaLow;

    final denomLow = 1.0 - accel * (z0 + zAlphaLow);
    final qLowRaw = denomLow > 0.0
        ? normal.cumulativeProbability(z0 + (z0 + zAlphaLow) / denomLow)
        : 0.0;

    final denomHigh = 1.0 - accel * (z0 + zAlphaHigh);
    final qHighRaw = denomHigh > 0.0
        ? normal.cumulativeProbability(z0 + (z0 + zAlphaHigh) / denomHigh)
        : 1.0;

    final q1 = math.min(qLowRaw, qHighRaw).clamp(0.0, 1.0);
    final q2 = math.max(qLowRaw, qHighRaw).clamp(0.0, 1.0);

    return (
      lower: _sortedQuantile(sorted, q1),
      upper: _sortedQuantile(sorted, q2),
    );
  }

  static double _sortedQuantile(List<double> sorted, double q) {
    if (sorted.any((v) => v.isNaN)) return double.nan;
    if (q <= 0.0) return sorted.first;
    if (q >= 1.0) return sorted.last;
    final idx = q * (sorted.length - 1);
    final baseIdx = idx.floor();
    final frac = idx - baseIdx;
    if (baseIdx >= sorted.length - 1) return sorted.last;
    return sorted[baseIdx] + frac * (sorted[baseIdx + 1] - sorted[baseIdx]);
  }

  static void _validateParameters(
    List<Object?> samples,
    int resamples,
    double confidenceLevel,
  ) {
    if (samples.length < 2) {
      throw ArgumentError.value(
        samples,
        'samples',
        'At least 2 samples required for bootstrap',
      );
    }
    if (resamples < 10) {
      throw ArgumentError.value(
        resamples,
        'resamples',
        'At least 10 resamples required',
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
}
