import 'dart:math' as math;

import 'package:more/printer.dart' show ObjectPrinter, ToStringPrinter;

import '../../special/erf.dart';
import '../descriptive.dart';
import '../distribution.dart';
import 'jackknife.dart';

/// A Bootstrap resampling technique to estimate standard errors, bias, and
/// confidence intervals (Percentile and BCa).
///
/// See https://en.wikipedia.org/wiki/Bootstrapping_(statistics).
class Bootstrap<T> with ToStringPrinter {
  /// Computes non-parametric bootstrap estimates and confidence intervals
  /// by resampling [samples] with replacement.
  new(
    this.samples,
    this.statistic, {
    this.resamples = 1000,
    this.confidenceLevel = 0.95,
    this.random,
  }) : sampler = null {
    _validateParameters(samples, resamples, confidenceLevel);
  }

  /// Computes parametric bootstrap estimates and confidence intervals by
  /// generating synthetic samples via [sampler].
  new parametric({
    required this.samples,
    required this.statistic,
    required List<T> Function(math.Random random) this.sampler,
    this.resamples = 1000,
    this.confidenceLevel = 0.95,
    this.random,
  }) {
    _validateParameters(samples, resamples, confidenceLevel);
  }

  /// Computes parametric bootstrap estimates by drawing synthetic samples
  /// from a fitted probability [distribution].
  static Bootstrap<num> distribution({
    required List<num> samples,
    required double Function(List<num> list) statistic,
    required Distribution<num> distribution,
    int resamples = 1000,
    double confidenceLevel = 0.95,
    math.Random? random,
  }) => Bootstrap<num>.parametric(
    samples: samples,
    statistic: statistic,
    sampler: (rng) => [
      for (var i = 0; i < samples.length; i++) distribution.sample(random: rng),
    ],
    resamples: resamples,
    confidenceLevel: confidenceLevel,
    random: random,
  );

  /// The sample data.
  final List<T> samples;

  /// The statistical function to measure.
  final double Function(List<T> list) statistic;

  /// The number of bootstrap resamples.
  final int resamples;

  /// The confidence level (e.g. 0.95).
  final double confidenceLevel;

  /// Optional random number generator.
  final math.Random? random;

  /// Optional custom generative sampler for parametric bootstrap.
  final List<T> Function(math.Random random)? sampler;

  /// The point estimate evaluated on the original sample.
  late final double estimate = statistic(samples);

  /// The distribution of bootstrap estimates sorted in ascending order.
  late final List<double> bootstrapEstimates = _computeBootstrapEstimates();

  /// The empirical standard error of the bootstrap estimates.
  late final double standardError = standardDeviation(bootstrapEstimates);

  /// The empirical bias of the bootstrap estimates.
  late final double bias = mean(bootstrapEstimates) - estimate;

  /// Percentile confidence interval (lower, upper).
  late final ({double lower, double upper}) percentileInterval = (
    lower: quantile(bootstrapEstimates, _alpha / 2.0),
    upper: quantile(bootstrapEstimates, 1.0 - _alpha / 2.0),
  );

  /// Bias-corrected and accelerated (BCa) confidence interval (lower, upper).
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

  late final _alpha = 1.0 - confidenceLevel;

  List<double> _computeBootstrapEstimates() {
    final rng = random ?? math.Random();
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
    return estimates;
  }

  ({double lower, double upper}) _computeBcaInterval() {
    final sortedEstimates = bootstrapEstimates;
    final n = resamples;

    // 1. z0 bias correction
    var lessCount = 0;
    for (final est in sortedEstimates) {
      if (est < estimate) lessCount++;
    }
    final fracLess = (lessCount / n).clamp(1e-6, 1.0 - 1e-6);
    final z0 = math.sqrt2 * erfInv(2.0 * fracLess - 1.0);

    // 2. Acceleration parameter a via jackknife
    final sampleSize = samples.length;
    final jackEstimates = List<double>.filled(sampleSize, 0.0);
    for (var i = 0; i < sampleSize; i++) {
      final jackSample = JackknifeResampling<T>(samples, i);
      jackEstimates[i] = statistic(jackSample);
    }
    final jackMean = mean(jackEstimates);
    var numA = 0.0;
    var denA = 0.0;
    for (var i = 0; i < sampleSize; i++) {
      final diff = jackMean - jackEstimates[i];
      numA += diff * diff * diff;
      denA += diff * diff;
    }
    final accel = denA > 0.0 ? numA / (6.0 * math.pow(denA, 1.5)) : 0.0;

    // 3. Adjusted quantiles
    final zAlpha2 = math.sqrt2 * erfInv(2.0 * (_alpha / 2.0) - 1.0);
    final z1MinusAlpha2 = math.sqrt2 * erfInv(2.0 * (1.0 - _alpha / 2.0) - 1.0);

    double phi(double z) => 0.5 * (1.0 + erf(z / math.sqrt2));

    final denomLower = 1.0 - accel * (z0 + zAlpha2);
    final q1 = denomLower != 0.0
        ? phi(z0 + (z0 + zAlpha2) / denomLower).clamp(0.0, 1.0)
        : _alpha / 2.0;

    final denomUpper = 1.0 - accel * (z0 + z1MinusAlpha2);
    final q2 = denomUpper != 0.0
        ? phi(z0 + (z0 + z1MinusAlpha2) / denomUpper).clamp(0.0, 1.0)
        : 1.0 - _alpha / 2.0;

    final bcaLower = quantile(sortedEstimates, q1);
    final bcaUpper = quantile(sortedEstimates, q2);

    return (lower: bcaLower, upper: bcaUpper);
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
    if (!(0 < confidenceLevel && confidenceLevel < 1)) {
      throw ArgumentError.value(
        confidenceLevel,
        'confidenceLevel',
        'Confidence level must be between 0 and 1',
      );
    }
  }
}
