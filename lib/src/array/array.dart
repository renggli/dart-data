import 'package:more/collection.dart';
import 'package:more/printer.dart';

import '../../type.dart';
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

  /// The absolute offset into the underlying array.
  final int offset;

  /// The length of each dimension in the array.
  final Shape shape;

  /// The number of indices to jump to reach the next value in the dimension.
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
    for (var i = 0; i < indices.length; i++) {
      final index = indices[i];
      if (0 <= index) {
        assert(
            index < shape[i],
            'Index $i out of range: '
            'index must be less than ${shape[i]}, but got $index');
        result += strides[i] * index;
      } else {
        assert(
            -shape[i] <= index,
            'Index $i out of range: '
            'index must be larger or equal than ${-shape[i]}, but got $index');
        result += strides[i] * (shape[i] + index);
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

  T getValue(List<int> indices) => data[getIndex(indices)];

  void setValue(List<int> indices, T value) => data[getIndex(indices)] = value;

  /// Returns a view onto the data with the same
  Array<T> reshape(Shape shape) {
    assert(this.shape.size != shape.size,
        'Cannot change the shape from ${this.shape} to $shape');
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
    ..addValue(data, name: 'data')
    ..addValue(offset, name: 'offset')
    ..addValue(shape, name: 'shape')
    ..addValue(strides, name: 'strides');
}
