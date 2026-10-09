import 'dart:collection' show ListBase;
import 'dart:math' as math;

import 'package:collection/collection.dart' show NonGrowableListMixin;
import 'package:more/collection.dart' show IntegerRange;
import 'package:more/printer.dart' show ObjectPrinter, ToStringPrinter;

import '../../special.dart';
import 'descriptive.dart';
import 'distribution.dart';

/// Result of bootstrap resampling.
class BootstrapResult with ToStringPrinter {
  const new({
    required this.estimate,
    required this.standardError,
    required this.bias,
    required this.percentileInterval,
    required this.bcaInterval,
    required this.bootstrapEstimates,
    required this.confidenceLevel,
  });

  /// The point estimate evaluated on the original sample.
  final double estimate;

  /// The empirical standard error of the bootstrap estimates.
  final double standardError;

  /// The empirical bias of the bootstrap estimates.
  final double bias;

  /// Percentile confidence interval (lower, upper).
  final (double, double) percentileInterval;

  /// Bias-corrected and accelerated (BCa) confidence interval (lower, upper).
  final (double, double) bcaInterval;

  /// The distribution of bootstrap estimates.
  final List<double> bootstrapEstimates;

  /// The confidence level (e.g. 0.95).
  final double confidenceLevel;

  @override
  ObjectPrinter get toStringPrinter => super.toStringPrinter
    ..addValue(estimate, name: 'estimate')
    ..addValue(standardError, name: 'standardError')
    ..addValue(bias, name: 'bias')
    ..addValue(percentileInterval, name: 'percentileCI')
    ..addValue(bcaInterval, name: 'bcaCI')
    ..addValue(confidenceLevel, name: 'confidenceLevel');
}

/// Computes non-parametric bootstrap estimates and confidence intervals (Percentile and BCa).
BootstrapResult bootstrap<T>(
  List<T> samples,
  double Function(List<T>) statistic, {
  int resamples = 1000,
  double confidenceLevel = 0.95,
  math.Random? random,
}) {
  final n = samples.length;
  if (n < 2) {
    throw ArgumentError('At least 2 samples required for bootstrap');
  }
  if (resamples < 10) {
    throw ArgumentError('At least 10 resamples required');
  }
  if (confidenceLevel <= 0.0 || confidenceLevel >= 1.0) {
    throw ArgumentError('Confidence level must be between 0 and 1');
  }

  final rng = random ?? math.Random();
  final originalEstimate = statistic(samples);

  final bootEstimates = List<double>.filled(resamples, 0.0);
  final resampleBuffer = List<T>.filled(n, samples[0]);

  for (var b = 0; b < resamples; b++) {
    for (var i = 0; i < n; i++) {
      resampleBuffer[i] = samples[rng.nextInt(n)];
    }
    bootEstimates[b] = statistic(resampleBuffer);
  }

  return _computeBootstrapResult(
    sample: samples,
    originalEstimate: originalEstimate,
    bootEstimates: bootEstimates,
    statistic: statistic,
    confidenceLevel: confidenceLevel,
  );
}

/// Computes parametric bootstrap estimates and confidence intervals (Percentile and BCa).
///
/// Unlike non-parametric bootstrap which resamples with replacement from empirical observations,
/// parametric bootstrap generates synthetic samples by drawing from a fitted parametric model
/// or generative function [sampler].
BootstrapResult parametricBootstrap<T>({
  required List<T> sample,
  required double Function(List<T>) statistic,
  required List<T> Function(math.Random random) sampler,
  int resamples = 1000,
  double confidenceLevel = 0.95,
  math.Random? random,
}) {
  final n = sample.length;
  if (n < 2) {
    throw ArgumentError('At least 2 samples required for bootstrap');
  }
  if (resamples < 10) {
    throw ArgumentError('At least 10 resamples required');
  }
  if (confidenceLevel <= 0.0 || confidenceLevel >= 1.0) {
    throw ArgumentError('Confidence level must be between 0 and 1');
  }

  final rng = random ?? math.Random();
  final originalEstimate = statistic(sample);

  final bootEstimates = List<double>.generate(
    resamples,
    (_) => statistic(sampler(rng)),
    growable: false,
  );

  return _computeBootstrapResult(
    sample: sample,
    originalEstimate: originalEstimate,
    bootEstimates: bootEstimates,
    statistic: statistic,
    confidenceLevel: confidenceLevel,
  );
}

/// Computes parametric bootstrap estimates drawing from a fitted probability [distribution].
BootstrapResult parametricBootstrapDistribution({
  required List<num> sample,
  required double Function(List<num>) statistic,
  required Distribution<num> distribution,
  int resamples = 1000,
  double confidenceLevel = 0.95,
  math.Random? random,
}) {
  final n = sample.length;
  return parametricBootstrap<num>(
    sample: sample,
    statistic: statistic,
    sampler: (rng) => [
      for (var i = 0; i < n; i++) distribution.sample(random: rng),
    ],
    resamples: resamples,
    confidenceLevel: confidenceLevel,
    random: random,
  );
}

BootstrapResult _computeBootstrapResult<T>({
  required List<T> sample,
  required double originalEstimate,
  required List<double> bootEstimates,
  required double Function(List<T>) statistic,
  required double confidenceLevel,
}) {
  final n = sample.length;
  final resamples = bootEstimates.length;
  final sortedEstimates = List<double>.of(bootEstimates)..sort();

  final bootMean = mean(sortedEstimates);
  final se = standardDeviation(sortedEstimates);
  final bias = bootMean - originalEstimate;

  final alpha = 1.0 - confidenceLevel;
  final percLower = quantile(sortedEstimates, alpha / 2.0);
  final percUpper = quantile(sortedEstimates, 1.0 - alpha / 2.0);

  // Compute BCa intervals
  // 1. z0 bias correction
  var lessCount = 0;
  for (final est in sortedEstimates) {
    if (est < originalEstimate) lessCount++;
  }
  final fracLess = (lessCount / resamples).clamp(1e-6, 1.0 - 1e-6);
  final z0 = math.sqrt2 * erfInv(2.0 * fracLess - 1.0);

  // 2. Acceleration parameter a via jackknife
  final jackEstimates = List<double>.filled(n, 0.0);
  for (var i = 0; i < n; i++) {
    final jackSample = _JackknifeResampling<T>(sample, i);
    jackEstimates[i] = statistic(jackSample);
  }
  final jackMean = mean(jackEstimates);
  var numA = 0.0;
  var denA = 0.0;
  for (var i = 0; i < n; i++) {
    final diff = jackMean - jackEstimates[i];
    numA += diff * diff * diff;
    denA += diff * diff;
  }
  final a = denA > 0.0 ? numA / (6.0 * math.pow(denA, 1.5)) : 0.0;

  // 3. Adjusted quantiles
  final zAlpha2 = math.sqrt2 * erfInv(2.0 * (alpha / 2.0) - 1.0);
  final z1MinusAlpha2 = math.sqrt2 * erfInv(2.0 * (1.0 - alpha / 2.0) - 1.0);

  double phi(double z) => 0.5 * (1.0 + erf(z / math.sqrt2));

  final denomLower = 1.0 - a * (z0 + zAlpha2);
  final q1 = denomLower != 0.0
      ? phi(z0 + (z0 + zAlpha2) / denomLower).clamp(0.0, 1.0)
      : alpha / 2.0;

  final denomUpper = 1.0 - a * (z0 + z1MinusAlpha2);
  final q2 = denomUpper != 0.0
      ? phi(z0 + (z0 + z1MinusAlpha2) / denomUpper).clamp(0.0, 1.0)
      : 1.0 - alpha / 2.0;

  final bcaLower = quantile(sortedEstimates, q1);
  final bcaUpper = quantile(sortedEstimates, q2);

  return BootstrapResult(
    estimate: originalEstimate,
    standardError: se,
    bias: bias,
    percentileInterval: (percLower, percUpper),
    bcaInterval: (bcaLower, bcaUpper),
    bootstrapEstimates: sortedEstimates,
    confidenceLevel: confidenceLevel,
  );
}

/// A deterministic Jackknife resampling technique to estimate variance, bias, and confidence intervals.
///
/// See https://en.wikipedia.org/wiki/Jackknife_resampling.
class Jackknife<T> with ToStringPrinter {
  new(this.samples, this.statistic, {this.confidenceLevel = 0.95})
    : assert(samples.isNotEmpty, 'empty samples'),
      assert(
        0 < confidenceLevel && confidenceLevel < 1,
        'confidence level out of range',
      );

  /// The sample data.
  final List<T> samples;

  /// The statistical function to measure.
  final double Function(List<T> list) statistic;

  /// The confidence level for the confidence interval.
  final double confidenceLevel;

  /// The resamples of the data.
  late final List<List<T>> resamples = IntegerRange(samples.length)
      .map((index) => _JackknifeResampling<T>(samples, index))
      .toList();

  /// The bias.
  late final double bias =
      (samples.length - 1) * (_meanResampleMeasure - _sampleMeasure);

  /// The bias corrected estimate.
  late final double estimate = _sampleMeasure - bias;

  /// The standard error.
  late final double standardError = math.sqrt(
    (samples.length - 1) *
        _resampleMeasures
            .map((value) => value - _meanResampleMeasure)
            .map((value) => value * value)
            .arithmeticMean(),
  );

  /// The lower bound of the confidence interval.
  late final double lowerBound = estimate - _zScore * standardError;

  /// The upper bound of the confidence interval.
  late final double upperBound = estimate + _zScore * standardError;

  late final _sampleMeasure = statistic(samples);
  late final _resampleMeasures = resamples.map(statistic).toList();
  late final _meanResampleMeasure = _resampleMeasures.arithmeticMean();
  late final _zScore = math.sqrt2 * erfInv(confidenceLevel);

  @override
  ObjectPrinter get toStringPrinter => super.toStringPrinter
    ..addValue(estimate, name: 'estimate')
    ..addValue(bias, name: 'bias')
    ..addValue(standardError, name: 'standardError')
    ..addValue(lowerBound, name: 'lowerBound')
    ..addValue(upperBound, name: 'upperBound')
    ..addValue(confidenceLevel, name: 'confidenceLevel');
}

/// A view of a Jackknife resampling of a [List].
class _JackknifeResampling<T> extends ListBase<T> with NonGrowableListMixin<T> {
  new(this.list, this.index)
    : assert(list.isNotEmpty, 'Non empty list expected'),
      assert(0 <= index && index < list.length, 'Index out of bounds');

  final List<T> list;
  final int index;

  @override
  int get length => list.length - 1;

  @override
  T operator [](int index) =>
      index < this.index ? list[index] : list[index + 1];

  @override
  void operator []=(int index, T value) =>
      throw UnsupportedError('Cannot modify');
}
