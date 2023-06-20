import 'package:more/collection.dart';
import 'package:more/printer.dart';

import '../../stats.dart';
import '../../type.dart';
import 'index.dart';
import 'printer.dart';
import 'shape.dart';
import 'strides.dart';

/// A multidimensional fixed-size container of items of the same type.
class Array<T> with ToStringPrinter {
  Array({
    required this.type,
    required this.data,
    this.offset = 0,
    required this.shape,
    required this.strides,
  }) : assert(shape.dimensions == strides.dimensions,
            'shape and strides do not match');

  /// Constructs an n-dimensional array filled with the provided [value].
  factory Array.filled(T value,
      {required Shape shape, Strides? strides, DataType<T>? type}) {
    final newType = type ?? DataType.fromInstance(value);
    final newStrides = strides ?? Strides.fromShape(shape);
    final newData = newType.newList(shape.size, fillValue: value);
    return Array(
      type: newType,
      data: newData,
      shape: shape,
      strides: newStrides,
    );
  }

  factory Array.fromIterable(Iterable<T> data,
      {Shape? shape, Strides? strides, DataType<T>? type}) {
    final newType = type ?? DataType.fromIterable(data);
    final newData = newType.copyList(data);
    final newShape = shape ?? Shape.forVector(newData.length);
    final newStrides = strides ?? Strides.fromShape(newShape);
    return Array(
      type: newType,
      data: newData,
      shape: newShape,
      strides: newStrides,
    );
  }

  factory Array.fromObject(Iterable<dynamic> object, {DataType<T>? type}) {
    final newType = type ?? DataType.fromIterable(object.deepFlatten());
    final newData = newType.copyList(object.deepFlatten());
    final newShape = Shape.fromObject(object);
    final newStrides = Strides.fromShape(newShape);
    return Array(
      type: newType,
      data: newData,
      shape: newShape,
      strides: newStrides,
    );
  }

  /// The type of this array.
  final DataType<T> type;

  /// The flat underlying data array.
  final List<T> data;

  /// The absolute offset into the underlying data array.
  final int offset;

  /// The length of each dimension in the underlying data array.
  final Shape shape;

  /// The number of indices to jump to the next value in each dimension of the
  /// underlying data array.
  final Strides strides;

  /// The number of dimensions.
  int get dimensions => shape.dimensions;

  /// Returns the value at the given indices.
  T getValue(Iterable<int> indices) => data[getOffset(indices)];

  /// Sets the value at the given indices.
  void setValue(Iterable<int> indices, T value) =>
      data[getOffset(indices)] = value;

  /// Compute the offset of the given indices in the underlying array.
  int getOffset(Iterable<int> indices) {
    assert(indices.length == dimensions,
        'Expected $dimensions indices, but got ${indices.length}');
    var axis = 0;
    var result = offset;
    for (final index in indices) {
      final adjustedIndex = index < 0 ? shape[axis] + index : index;
      assert(0 <= adjustedIndex && adjustedIndex < shape[axis],
          'Index $index on axis $axis is out of range');
      result += strides[axis] * adjustedIndex;
      axis++;
    }
    return result;
  }

  /// Returns a view with the first axis resolved to `index`.
  Array<T> operator [](Index index) => slice([index]);

  /// Returns a view with the `indices` resolved.
  Array<T> slice(Iterable<Index> indices) {
    var axis = 0;
    var newOffset = offset;
    final newShape = <int>[];
    final newStrides = <int>[];
    for (final index in indices) {
      assert(
          axis < dimensions,
          'Too many axes specified: '
          '$index on axis $axis, but expected at most $dimensions');
      switch (index) {
        case SingleIndex(index: final start):
          // Access a specific value on the current axis.
          final adjustedStart = start < 0 ? shape[axis] + start : start;
          assert(0 <= adjustedStart && adjustedStart < shape[axis],
              'Index $start of $index on axis $axis is out of range');
          newOffset += strides[axis] * adjustedStart;
          axis++;
        case RangeIndex(start: final start, end: final end, step: final step):
          // Access a range of values on the current axis.
          final adjustedStart = start < 0 ? shape[axis] + start : start;
          assert(0 <= adjustedStart && adjustedStart < shape[axis],
              'Index $start of $index on axis $axis is out of range');
          final adjustedEnd = end < 0 ? shape[axis] + end : end;
          assert(0 <= adjustedEnd && adjustedEnd < shape[axis],
              'Index $end of $index on axis $axis is out of range');
          newShape.add((adjustedEnd - adjustedStart) ~/ step);
          newStrides.add(step * strides[axis]);
          newOffset += adjustedStart * strides[axis];
          axis++;
        case NewAxisIndex():
          // Adds a new one unit-length dimension.
          newShape.add(1);
          newStrides.add(strides.values.getRange(axis, dimensions).product());
      }
    }
    // Keep existing axis as-is.
    if (axis < dimensions) {
      newShape.addAll(shape.values.getRange(axis, dimensions));
      newStrides.addAll(strides.values.getRange(axis, dimensions));
    }
    // Return an update view onto the array.
    return Array(
      type: type,
      data: data,
      offset: newOffset,
      shape: Shape.fromIterable(newShape),
      strides: Strides.fromIterable(newStrides),
    );
  }

  /// Returns a view onto the data with the same
  Array<T> reshape(Shape shape) {
    if (this.shape.size != shape.size) {
      throw ArgumentError.value(
          shape, 'shape', 'Incompatible shape: ${this.shape}');
    }
    return Array<T>(
      type: type,
      data: data,
      offset: offset,
      shape: shape,
      strides: Strides.fromShape(shape),
    );
  }

  /// Returns a transposed view.
  Array<T> transpose({List<int>? axes}) {
    axes ??= List.generate(dimensions, (int index) => dimensions - index - 1,
        growable: false);
    return Array<T>(
      type: type,
      data: data,
      offset: offset,
      shape: Shape.fromIterable(axes.map((each) => shape[each])),
      strides: Strides.fromIterable(axes.map((each) => strides[each])),
    );
  }

  @override
  ObjectPrinter get toStringPrinter => super.toStringPrinter
    ..addValue(type, name: 'type')
    ..addValue(shape.values, name: 'shape')
    ..addValue(this, printer: ArrayPrinter<T>());
}
