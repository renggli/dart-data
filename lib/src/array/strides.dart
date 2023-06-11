import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'package:more/printer.dart';

import '../../data.dart';

/// The strides of an n-dimensional array.
@immutable
class Strides with ToStringPrinter {
  /// Constructs the default strides of the given [Shape].
  factory Strides.fromShape(Shape shape) {
    final values = List<int>.filled(shape.dimensions, 1);
    for (var i = values.length - 1; i > 0; i--) {
      values[i - 1] = values[i] * shape[i];
    }
    return Strides.fromIterable(values);
  }

  /// Constructs the strides from an [Iterable].
  factory Strides.fromIterable(Iterable<int> strides) =>
      Strides._(DataType.index.copyList(strides, readonly: true));

  /// Internal constructor.
  const Strides._(this.values) : dimensions = values.length;

  /// Returns the strides counts.
  final List<int> values;

  /// Returns the number of dimensions.
  final int dimensions;

  int operator [](int index) => values[index];

  @override
  bool operator ==(Object other) =>
      other is Strides &&
      const ListEquality<int>().equals(values, other.values);

  @override
  int get hashCode => const ListEquality<int>().hash(values);

  @override
  ObjectPrinter get toStringPrinter => super.toStringPrinter
    ..addValue(dimensions, name: 'dimensions')
    ..addValue(values);
}
