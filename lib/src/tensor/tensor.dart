import 'dart:typed_data';

import 'package:meta/meta.dart';
import 'package:more/collection.dart';
import 'package:more/printer.dart';

import '../../stats.dart';
import '../../type.dart';
import 'index.dart';
import 'printer.dart';
import 'utils/shape.dart' as shape_utils;
import 'utils/stride.dart' as stride_utils;

/// A multi-dimensional fixed-size container of items of a specific type.
class Tensor<T> with ToStringPrinter {
  /// Constructs a [Tensor] of [value].
  ///
  /// By default a 0-dimensional tensor with the single value is returned. If a
  /// `shape` is provided all tensor entries are filled with that value.
  factory Tensor.filled(T value,
      {List<int>? shape, List<int>? strides, DataType<T>? type}) {
    final newType = type ?? DataType.fromInstance(value);
    final newShape = shape_utils.fromIterable(shape ?? const <int>[]);
    final newStrides = strides ?? stride_utils.fromShape(newShape);
    final newData = newType.newList(newShape.product(), fillValue: value);
    return Tensor.internal(
      type: newType,
      data: newData,
      shape: newShape,
      stride: newStrides,
    );
  }

  /// Constructs an [Tensor] from an `iterable`.
  ///
  /// By default a 1-dimensional tensor with the values from the iterable
  /// `iterable` is returned. If a `shape` is provided the data populates the
  /// tensor in the specified format in row-major.
  factory Tensor.fromIterable(Iterable<T> iterable,
      {List<int>? shape, List<int>? strides, DataType<T>? type}) {
    assert(iterable.isNotEmpty, '`iterable` should not be empty');
    final newType = type ?? DataType.fromIterable(iterable);
    final newData = newType.copyList(iterable);
    final newShape = shape_utils.fromIterable(shape ?? [newData.length]);
    final newStrides = strides ?? stride_utils.fromShape(newShape);
    return Tensor.internal(
      type: newType,
      data: newData,
      shape: newShape,
      stride: newStrides,
    );
  }

  /// Constructs an [Tensor] from a nested `object`.
  factory Tensor.fromObject(Iterable<dynamic> object, {DataType<T>? type}) {
    final newType = type ?? DataType.fromIterable(object.deepFlatten());
    final newData = newType.copyList(object.deepFlatten());
    final newShape = shape_utils.fromObject(object);
    final newStrides = stride_utils.fromShape(newShape);
    return Tensor.internal(
      type: newType,
      data: newData,
      shape: newShape,
      stride: newStrides,
    );
  }

  /// Internal constructors of [Tensor] object.
  @internal
  Tensor.internal({
    required this.type,
    required this.data,
    this.offset = 0,
    required this.shape,
    required this.stride,
  })  : assert(shape is TypedData, '`shape` should be TypedData'),
        assert(shape.every((s) => s > 0), '`shape` should be positive'),
        assert(stride is TypedData, '`stride` should be TypedData'),
        assert(stride.every((s) => s != 0), '`stride` should be non-null'),
        assert(shape.length == stride.length, '`shape` and `stride` length'),
        assert(offset + shape.product() <= data.length, '`data` is too short');

  /// The type of this tensor.
  final DataType<T> type;

  /// The underlying data storage.
  final List<T> data;

  /// The absolute offset into the underlying data.
  final int offset;

  /// The length of each dimension in the underlying data.
  final List<int> shape;

  /// The number of indices to jump to the next value in each dimension of the
  /// underlying data.
  final List<int> stride;

  /// The number of dimensions.
  int get dimensions => shape.length;

  /// Tests if the data is stored contiguous.
  bool get isContiguous =>
      stride_utils.isContiguous(shape: shape, stride: stride);

  /// The value at the given `indices`.
  T getValue(Iterable<int> indices) => data[getOffset(indices)];

  /// Sets the value at the given `indices`.
  void setValue(Iterable<int> indices, T value) =>
      data[getOffset(indices)] = value;

  /// Compute the offset of the given `indices` in the underlying tensor.
  int getOffset(Iterable<int> indices) {
    assert(indices.length == dimensions,
        'Expected $dimensions indices, but got ${indices.length}');
    var axis = 0;
    var result = offset;
    for (final index in indices) {
      final adjustedIndex = index < 0 ? shape[axis] + index : index;
      assert(0 <= adjustedIndex && adjustedIndex < shape[axis],
          'Index $index on axis $axis is out of range');
      result += stride[axis] * adjustedIndex;
      axis++;
    }
    return result;
  }

  /// Returns a view with the first axis resolved to `index`.
  Tensor<T> operator [](Index index) => slice([index]);

  /// Returns a view with the `indices` resolved.
  Tensor<T> slice(Iterable<Index> indices) {
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
          newOffset += stride[axis] * adjustedStart;
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
          newStrides.add(step * stride[axis]);
          newOffset += adjustedStart * stride[axis];
          axis++;
        case NewAxisIndex():
          // Adds a new one unit-length dimension.
          newShape.add(1);
          newStrides.add(stride.getRange(axis, dimensions).product());
      }
    }
    // Keep existing axis as-is.
    if (axis < dimensions) {
      newShape.addAll(shape.getRange(axis, dimensions));
      newStrides.addAll(stride.getRange(axis, dimensions));
    }
    // Return an update view onto the tensor.
    return Tensor.internal(
      type: type,
      data: data,
      offset: newOffset,
      shape: shape_utils.fromIterable(newShape),
      stride: stride_utils.fromIterable(newStrides),
    );
  }

  /// Returns a view onto the data with the same
  Tensor<T> reshape(List<int> shape) {
    assert(this.shape.product() == shape.product(),
        'New shape $shape is not compatible with ${this.shape}');
    return Tensor<T>.internal(
      type: type,
      data: data,
      offset: offset,
      shape: stride_utils.fromIterable(shape),
      stride: stride_utils.fromShape(shape),
    );
  }

  /// Returns a transposed view.
  Tensor<T> transpose({List<int>? axes}) {
    axes ??= IntegerRange(dimensions).reversed;
    return Tensor<T>.internal(
      type: type,
      data: data,
      offset: offset,
      shape: shape_utils.fromIterable(axes.map((each) => shape[each])),
      stride: stride_utils.fromIterable(axes.map((each) => stride[each])),
    );
  }

  @override
  ObjectPrinter get toStringPrinter => super.toStringPrinter
    ..addValue(type, name: 'type')
    ..addValue(shape, name: 'shape')
    ..addValue(stride, name: 'strides')
    ..addValue(offset, name: 'offset')
    ..addValue(this, printer: TensorPrinter<T>());
}
