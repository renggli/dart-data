import 'package:meta/meta.dart';
import 'package:more/collection.dart';
import 'package:more/printer.dart';

import '../../type.dart';
import 'printer.dart';
import 'utils/layout.dart';

/// A multi-dimensional fixed-size container of items of a specific type.
@experimental
class Tensor<T> with ToStringPrinter {
  /// Constructs a [Tensor] of [value].
  ///
  /// By default a 0-dimensional tensor with the single value is returned. If a
  /// `shape` is provided all tensor entries are filled with that value.
  factory Tensor.filled(T value,
      {List<int>? shape, List<int>? strides, DataType<T>? type}) {
    final type_ = type ?? DataType.fromInstance(value);
    final layout_ = Layout(shape: shape, strides: strides);
    final data_ = type_.newList(layout_.length, fillValue: value);
    return Tensor.internal(type: type_, data: data_, layout: layout_);
  }

  /// Constructs an [Tensor] from an `iterable`.
  ///
  /// By default a 1-dimensional tensor with the values from the iterable
  /// `iterable` is returned. If a `shape` is provided the data populates the
  /// tensor in the specified format in row-major.
  factory Tensor.fromIterable(Iterable<T> iterable,
      {List<int>? shape, List<int>? strides, DataType<T>? type}) {
    final type_ = type ?? DataType.fromIterable(iterable);
    final data_ = type_.copyList(iterable);
    final layout_ = data_.isEmpty
        ? Layout.empty
        : Layout(shape: shape ?? [data_.length], strides: strides);
    return Tensor.internal(type: type_, data: data_, layout: layout_);
  }

  /// Constructs an [Tensor] from a nested `object`.
  factory Tensor.fromObject(dynamic object, {DataType<T>? type}) {
    final array_ = object is Iterable
        ? object.deepFlatten<T>()
        : object is T
            ? <T>[object]
            : object == null
                ? <T>[]
                : throw ArgumentError.value(object, 'object');
    final type_ = type ?? DataType.fromIterable(array_);
    final data_ = type_.copyList(array_);
    final layout_ = Layout.fromObject(object);
    return Tensor.internal(type: type_, data: data_, layout: layout_);
  }

  /// Internal constructors of [Tensor] object.
  @internal
  Tensor.internal({
    required this.type,
    required this.data,
    required this.layout,
  });

  /// The type of this tensor.
  final DataType<T> type;

  /// The underlying data storage.
  final List<T> data;

  /// The layout of the data in the underlying storage.
  final Layout layout;

  /// The number of dimensions.
  int get rank => layout.rank;

  /// The number of elements.
  int get length => layout.length;

  /// An iterator over the values of the tensor.
  Iterable<T> get values => layout.indices.map((index) => data[index]);

  /// Returns the value at the given key (index-list).
  T getValue(List<int> key) => data[layout.toIndex(key)];

  /// Sets the value at the given key (index-list).
  void setValue(List<int> key, T value) => data[layout.toIndex(key)] = value;

  /// Returns a view with the first axis resolved to [index].
  Tensor<T> operator [](int index) =>
      Tensor<T>.internal(type: type, data: data, layout: layout[index]);

  /// Returns a view with the given [axis] resolved to [index].
  Tensor<T> elementAt(int index, {int axis = 0}) => Tensor<T>.internal(
      type: type, data: data, layout: layout.elementAt(index, axis: axis));

  /// Returns a view with the given [axis] sliced to the range between [start]
  /// and [end] (exclusive).
  Tensor<T> getRange(int start, int? end, {int step = 1, int axis = 0}) =>
      Tensor<T>.internal(
          type: type,
          data: data,
          layout: layout.getRange(start, end, step: step, axis: axis));

  /// Returns a contiguous flat array.
  Tensor<T> ravel() => reshape([layout.length]);

  /// Returns a reshaped view, in some cases the data is copied.
  Tensor<T> reshape(List<int> shape) {
    final (layout_, data_) = layout.isContiguous
        ? (Layout(shape: shape, offset: layout.offset), data)
        : (Layout(shape: shape), type.copyList(values));
    if (layout.length != layout_.length) {
      throw ArgumentError.value(shape, 'shape', 'Incompatible with $layout');
    }
    return Tensor<T>.internal(type: type, data: data_, layout: layout_);
  }

  /// Return the tensor collapsed into one dimension.
  Tensor<T> flatten() => reshape([length]);

  /// Returns a transposed view.
  Tensor<T> transpose({List<int>? axes}) => Tensor<T>.internal(
      type: type, data: data, layout: layout.transpose(axes: axes));

  @override
  ObjectPrinter get toStringPrinter => super.toStringPrinter
    ..addValue(type, name: 'type')
    ..addValue(layout, name: 'layout')
    ..addValue(this, printer: TensorPrinter<T>());
}
