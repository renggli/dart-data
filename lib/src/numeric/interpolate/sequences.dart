import 'dart:math';

import '../../../type.dart';
import '../../../vector.dart';

/// Generates a [Vector] with a sequence of [count] evenly spaced values over an
/// interval between [start] and [stop].
Vector<double> linearSpaced(
  double start,
  double stop, {
  int count = 10,
  bool includeEndpoint = true,
  DataType<double>? dataType,
  VectorFormat? format,
}) {
  final factor = 1.0 / (includeEndpoint ? count - 1 : count);
  return Vector.generate(
    dataType ?? DataType.float,
    count,
    (i) => start * (1.0 - factor * i) + stop * (factor * i),
    format: format,
  );
}

/// Generates a [Vector] with a sequence of [count] evenly spaced values on a
/// log scale (a geometric progression) on the interval between `base ^ start`
/// and `base ^ stop`.
Vector<double> logarithmicSpaced(
  double start,
  double stop, {
  int count = 10,
  double base = 10.0,
  bool includeEndpoint = true,
  DataType<double>? dataType,
  VectorFormat? format,
}) {
  final linear = linearSpaced(
    start,
    stop,
    count: count,
    includeEndpoint: includeEndpoint,
    dataType: dataType,
  );
  final logarithmic = linear.map((i, x) => pow(base, x).toDouble(), dataType);
  return format == null ? logarithmic : logarithmic.toVector(format: format);
}

/// Generates a [Vector] with a sequence of [count] evenly spaced values on a
/// log scale (a geometric progression) on the interval between [start] and
/// [stop].
Vector<double> geometricSpaced(
  double start,
  double stop, {
  int count = 10,
  bool includeEndpoint = true,
  DataType<double>? dataType,
  VectorFormat? format,
}) => logarithmicSpaced(
  log(start),
  log(stop),
  count: count,
  base: e,
  includeEndpoint: includeEndpoint,
  dataType: dataType,
  format: format,
);
