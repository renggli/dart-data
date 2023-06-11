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
  Shape._(this.values)
      : dimensions = values.length,
        size = values.product();

  /// Returns the shape counts.
  final List<int> values;

  /// Returns the number of dimensions.
  final int dimensions;

  /// Returns the number of elements across all dimensions.
  final int size;

  /// Returns an iterator over the indices of this shape.
  Iterator<List<int>> get iterator => ShapeIterator(this);

  int operator [](int index) => values[index];

  @override
  bool operator ==(Object other) =>
      other is Shape && const ListEquality<int>().equals(values, other.values);

  @override
  int get hashCode => const ListEquality<int>().hash(values);

  @override
  ObjectPrinter get toStringPrinter => super.toStringPrinter
    ..addValue(dimensions, name: 'dimensions')
    ..addValue(size, name: 'size')
    ..addValue(values);
}

class ShapeIterator implements Iterator<List<int>> {
  ShapeIterator(this.shape)
      : current = DataType.index.newList(shape.dimensions)..last = -1;

  final Shape shape;

  @override
  final List<int> current;

  @override
  bool moveNext() {
    for (var i = current.length - 1; i >= 0; i--) {
      current[i]++;
      if (current[i] < shape[i]) {
        return true;
      }
      current[i] = 0;
    }
    return false;
  }
}
