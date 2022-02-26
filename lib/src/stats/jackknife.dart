import 'dart:collection' show ListBase;
import 'dart:math';

import 'package:collection/collection.dart' show NonGrowableListMixin;
import 'package:more/collection.dart' show IntegerRange;

import '../special/erf.dart';
import 'iterable.dart';

/// A deterministic resampling technique to estimate variance, bias, and
/// confidence intervals.
///
/// For details see https://en.wikipedia.org/wiki/Jackknife_resampling.
class Jackknife<T> {
  Jackknife(this.samples, this.statistic, {this.confidenceLevel = 0.95})
      : assert(samples.isNotEmpty, 'empty samples'),
        assert(0 < confidenceLevel && confidenceLevel < 1,
            'confidence level out of range');

  /// The sample data.
  final List<T> samples;

  /// The statistical function to measure.
  final double Function(List<T> list) statistic;

  /// The confidence level for the confidence interval.
  final double confidenceLevel;

  /// The resamples of the data.
  late final List<List<T>> resamples = IntegerRange(samples.length)
      .map((index) => JackknifeResampling<T>(samples, index))
      .toList();

  /// The bias.
  late final double bias =
      (samples.length - 1) * (meanResampleMeasure_ - sampleMeasure_);

  /// The bias corrected estimate.
  late final double estimate = sampleMeasure_ - bias;

  /// The standard error.
  late final double standardError = sqrt((samples.length - 1) *
      (resampleMeasures_
          .map((value) => value - meanResampleMeasure_)
          .map((value) => value * value)
          .arithmeticMean()));

  /// The lower bound of the confidence interval.
  late final lowerBound = estimate - zScore_ * standardError;

  /// The upper bound of the confidence interval.
  late final upperBound = estimate + zScore_ * standardError;

  late final sampleMeasure_ = statistic(samples);
  late final resampleMeasures_ = resamples.map(statistic).toList();
  late final meanResampleMeasure_ = resampleMeasures_.arithmeticMean();
  late final zScore_ = sqrt2 * inverseErrorFunction(confidenceLevel);
}

/// A view of a Jackknife resampling of a [List].
class JackknifeResampling<T> extends ListBase<T> with NonGrowableListMixin<T> {
  JackknifeResampling(this.list, this.index)
      : assert(list.isNotEmpty, 'Non empty list expected'),
        assert(0 <= index && index < list.length, 'Index out of bounds');

  /// Original sample from which the resampling is created.
  final List<T> list;

  /// The index of the resampling.
  final int index;

  @override
  int get length => list.length - 1;

  @override
  T operator [](int index) =>
      index < this.index ? list[index] : list[index + 1];

  @override
  void operator []=(int index, T value) => throw UnimplementedError();
}
