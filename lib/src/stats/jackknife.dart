import 'dart:collection' show ListBase;
import 'dart:math';

import 'package:collection/collection.dart' show NonGrowableListMixin;
import 'package:more/collection.dart' show IndicesIterableExtension;
import 'package:more/printer.dart' show ObjectPrinter, ToStringPrinter;

import '../special/erf.dart';
import 'iterable.dart';

/// A deterministic resampling technique to estimate variance, bias, and
/// confidence intervals.
///
/// For details see https://en.wikipedia.org/wiki/Jackknife_resampling.
class Jackknife<T> with ToStringPrinter {
  Jackknife(this.samples, this.statistic, {this.confidenceLevel = 0.95})
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
  late final List<List<T>> resamples =
      samples
          .indices()
          .map((index) => _JackknifeResampling<T>(samples, index))
          .toList();

  /// The bias.
  late final double bias =
      (samples.length - 1) * (_meanResampleMeasure - _sampleMeasure);

  /// The bias corrected estimate.
  late final double estimate = _sampleMeasure - bias;

  /// The standard error.
  late final double standardError = sqrt(
    (samples.length - 1) *
        _resampleMeasures
            .map((value) => value - _meanResampleMeasure)
            .map((value) => value * value)
            .arithmeticMean(),
  );

  /// The lower bound of the confidence interval.
  late final lowerBound = estimate - _zScore * standardError;

  /// The upper bound of the confidence interval.
  late final upperBound = estimate + _zScore * standardError;

  late final _sampleMeasure = statistic(samples);
  late final _resampleMeasures = resamples.map(statistic).toList();
  late final _meanResampleMeasure = _resampleMeasures.arithmeticMean();
  late final _zScore = sqrt2 * erfInv(confidenceLevel);

  @override
  ObjectPrinter get toStringPrinter =>
      super.toStringPrinter
        ..addValue(estimate, name: 'estimate')
        ..addValue(bias, name: 'bias')
        ..addValue(standardError, name: 'standardError')
        ..addValue(lowerBound, name: 'lowerBound')
        ..addValue(upperBound, name: 'upperBound')
        ..addValue(confidenceLevel, name: 'confidenceLevel');
}

/// A view of a Jackknife resampling of a [List].
class _JackknifeResampling<T> extends ListBase<T> with NonGrowableListMixin<T> {
  _JackknifeResampling(this.list, this.index)
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
