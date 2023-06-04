import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'package:more/printer.dart';

import '../../data.dart';

/// The shape of an n-dimensional array.
@immutable
class Shape with ToStringPrinter {
  /// Creates a shape for a vector with a single row of `count` elements.
  factory Shape.forVector(int count) => Shape.fromIterable([count]);

  /// Creates a shape for a matrix with a `rowCount` and `colCount` elements.
  factory Shape.forMatrix(int rowCount, int colCount) =>
      Shape.fromIterable([rowCount, colCount]);

  /// Creates a shape from an object of iterables.
  factory Shape.fromObject(Iterable<dynamic> object) {
    final values = <int>[];
    for (Object? current = object;
        current is Iterable;
        current = current.first) {
      values.add(current.length);
    }
    return Shape.fromIterable(values);
  }

  /// Creates a shape for an n-dimensional array.
  factory Shape.fromIterable(Iterable<int> shape) =>
      Shape._(DataType.index.copyList(shape, readonly: true));

  /// Internal constructor.
  Shape._(this._shape)
      : dimensions = _shape.length,
        size = _shape.product();

  /// Internal shape data.
  final List<int> _shape;

  /// Returns the number of dimensions.
  final int dimensions;

  /// Returns the number of elements across all dimensions.
  final int size;

  int operator [](int index) => _shape[index];

  @override
  bool operator ==(Object other) =>
      other is Shape && const ListEquality<int>().equals(_shape, other._shape);

  @override
  int get hashCode => const ListEquality<int>().hash(_shape);

  @override
  ObjectPrinter get toStringPrinter => super.toStringPrinter
    ..addValue(_shape)
    ..addValue(dimensions, name: 'dimensions')
    ..addValue(size, name: 'size');
}
