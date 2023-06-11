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

  /// Computes the index for a list of indices into the underlying data.
  int getIndex(List<int> indices) {
    assert(
        dimensions == indices.length,
        'Indices out of range: '
        'expected $dimensions indices, but got ${indices.length}');
    var result = offset;
    for (var axis = 0; axis < indices.length; axis++) {
      final index = indices[axis];
      if (0 <= index) {
        assert(
            index < shape[axis],
            'Index $axis out of range: '
            'index must be less than ${shape[axis]}, but got $index');
        result += strides[axis] * index;
      } else {
        assert(
            -shape[axis] <= index,
            'Index $axis out of range: '
            'index must be larger or equal than ${-shape[axis]}, but got $index');
        result += strides[axis] * (shape[axis] + index);
      }
    }
    assert(
        0 <= result,
        'Internal error: '
        'result must not be negative, but got $result');
    assert(
        result < data.length,
        'Internal error: '
        'result must be less than ${data.length}, but got $result');
    return result;
  }

  Array<T> slice(Iterable<Index> indices) {
    var newOffset = offset;
    var axis = 0;
    final newShape = <int>[];
    final newStrides = <int>[];
    for (final index in indices) {
      assert(
          axis < dimensions,
          'Too many axes specified: '
          '$index on axis $axis, but expected at most $dimensions');
      switch (index) {
        case SkipIndex():
          newShape.add(1);
          newStrides.add(strides.values.getRange(axis, dimensions).product());
        case SingleIndex(index: final start):
          if (0 <= start) {
            assert(
                start < shape[axis],
                '$index on axis $axis out of range: '
                'index must be less than ${shape[axis]}, but got $start');
            newOffset += strides[axis] * start;
          } else {
            assert(
                -shape[axis] <= start,
                '$index on axis $axis out of range: '
                'index must be larger or equal than ${-shape[axis]}, but got $start');
            newOffset += strides[axis] * (shape[axis] + start);
          }
          axis++;
        case RangeIndex(start: final start, end: final end, step: final step):
          newShape.add((end - start) ~/ step);
          newStrides.add(step * strides[axis]);
          newOffset += start * strides[axis];
          axis++;
      }
    }
    if (axis < dimensions) {
      newShape.addAll(shape.values.getRange(axis, dimensions));
      newStrides.addAll(strides.values.getRange(axis, dimensions));
    }
    return Array(
      type: type,
      data: data,
      offset: newOffset,
      shape: Shape.fromIterable(newShape),
      strides: Strides.fromIterable(newStrides),
    );
  }

  T getValue(List<int> indices) => data[getIndex(indices)];

  void setValue(List<int> indices, T value) => data[getIndex(indices)] = value;

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
        strides: Strides.fromShape(shape));
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
