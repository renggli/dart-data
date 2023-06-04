import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'package:more/printer.dart';

import '../../data.dart';

/// The shape of an N-dimensional array.
@immutable
class Shape with ToStringPrinter {
  /// Creates a shape for a vector with a single row of `count` elements.
  factory Shape.forVector(int count) =>
      Shape._(DataType.index.newList(1, fillValue: count));

  /// Creates a shape for a matrix with a `rowCount` and `colCount` elements.
  factory Shape.forMatrix(int rowCount, int colCount) =>
      Shape._(DataType.index.newList(2)
        ..[0] = rowCount
        ..[1] = colCount);

  /// Creates a shape for an n-dimensional array.
  factory Shape.fromIterable(Iterable<int> shape) {
    final length = shape.length;
    final values = DataType.index.newList(length);
    values.setRange(0, length, shape);
    return Shape._(values);
  }

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

  /// Internal constructor.
  const Shape._(this._shape);

  final List<int> _shape;

  int operator [](int index) => _shape[index];

  int get dimensions => _shape.length;

  int get length => _shape.product();

  @override
  bool operator ==(Object other) =>
      other is Shape && const ListEquality<int>().equals(_shape, other._shape);

  @override
  int get hashCode => const ListEquality<int>().hash(_shape);

  @override
  ObjectPrinter get toStringPrinter => super.toStringPrinter
    ..addValue(_shape)
    ..addValue(dimensions, name: 'dimensions')
    ..addValue(length, name: 'length');
}
