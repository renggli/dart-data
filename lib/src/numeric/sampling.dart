import '../../linear.dart';
import '../../type.dart';

/// Generates a [Vector] with a sequence of [count] evenly spaced values over
/// the interval `[start, stop]`.
///
/// Conceptually, this partitions the continuous line segment between [start] and
/// [stop] into equal step increments, equivalent to NumPy's `linspace`.
///
/// When [endpoint] is `true` (the default), [stop] is included as the final
/// element of the vector. When [endpoint] is `false`, the step size is
/// `(stop - start) / count` and [stop] is excluded.
///
/// ```dart
/// final grid = linearSpaced(0.0, 1.0, count: 5);
/// // [0.0, 0.25, 0.5, 0.75, 1.0]
/// ```
Vector<double> linearSpaced(
  double start,
  double stop, {
  int count = 50,
  bool endpoint = true,
  DataType<double>? type,
  bool? native,
}) => Vector<double>.linspace(
  start,
  stop,
  count: count,
  endpoint: endpoint,
  type: type,
  native: native,
);

/// Generates a [Vector] with a sequence of [count] evenly spaced values on a
/// logarithmic scale over `[base^start, base^stop]`.
///
/// Conceptually, this evaluates base raised to powers that are linearly spaced
/// from [start] to [stop], equivalent to NumPy's `logspace`.
///
/// Base defaults to 10.0.
///
/// ```dart
/// final freq = logarithmicSpaced(0.0, 3.0, count: 4);
/// // [1.0, 10.0, 100.0, 1000.0]
/// ```
Vector<double> logarithmicSpaced(
  double start,
  double stop, {
  int count = 50,
  double base = 10.0,
  bool endpoint = true,
  DataType<double>? type,
  bool? native,
}) => Vector<double>.logspace(
  start,
  stop,
  count: count,
  base: base,
  endpoint: endpoint,
  type: type,
  native: native,
);

/// Generates a [Vector] with a sequence of [count] geometrically spaced values
/// over the interval `[start, stop]`.
///
/// Conceptually, this generates numbers spaced evenly on a log scale with the
/// start and stop points specified directly, equivalent to NumPy's `geomspace`.
/// Both [start] and [stop] must be non-zero and share the same sign.
///
/// ```dart
/// final scale = geometricSpaced(1.0, 1000.0, count: 4);
/// // [1.0, 10.0, 100.0, 1000.0]
/// ```
Vector<double> geometricSpaced(
  double start,
  double stop, {
  int count = 50,
  bool endpoint = true,
  DataType<double>? type,
  bool? native,
}) => Vector<double>.geomspace(
  start,
  stop,
  count: count,
  endpoint: endpoint,
  type: type,
  native: native,
);
