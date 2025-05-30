import 'package:meta/meta.dart';
import 'package:more/collection.dart';
import 'package:more/printer.dart';

import '../../type.dart';
import 'layout.dart';
import 'printer.dart';

/// A multi-dimensional fixed-size container of items of a specific type.
@experimental
class Tensor<T> with ToStringPrinter {
  /// Constructs a [Tensor] filled with [value].
  ///
  /// By default a 0-dimensional tensor with the single value is returned. If a
  /// [shape] is provided all tensor entries are filled with that value.
  factory Tensor.filled(
    T value, {
    List<int>? shape,
    List<int>? strides,
    DataType<T>? type,
  }) {
    final type_ = type ?? DataType.fromInstance(value);
    final layout_ = Layout(shape: shape, strides: strides);
    final data_ = type_.newList(layout_.length, fillValue: value);
    return Tensor.internal(type: type_, layout: layout_, data: data_);
  }

  /// Constructs a [Tensor] filled with the results of [callback].
  factory Tensor.generate(
    T Function(List<int> key) callback, {
    required List<int> shape,
    List<int>? strides,
    DataType<T>? type,
  }) => Tensor.fromIterable(
    Layout(shape: shape).keys.map(callback),
    shape: shape,
    strides: strides,
    type: type ?? DataType.fromType<T>(),
  );

  /// Constructs an [Tensor] from an [iterable].
  ///
  /// By default a 1-dimensional tensor with the values from the iterable
  /// [iterable] is returned. If a [shape] is provided the data populates the
  /// tensor in the specified format in row-major.
  factory Tensor.fromIterable(
    Iterable<T> iterable, {
    List<int>? shape,
    List<int>? strides,
    DataType<T>? type,
  }) {
    final type_ = type ?? DataType.fromIterable(iterable);
    final data_ = type_.copyList(iterable);
    final layout_ = data_.isEmpty
        ? Layout.empty
        : Layout(shape: shape ?? [data_.length], strides: strides);
    return Tensor.internal(type: type_, layout: layout_, data: data_);
  }

  /// Constructs an [Tensor] from a nested [object].
  factory Tensor.fromObject(dynamic object, {DataType<T>? type}) {
    final array_ = object is Iterable
        ? object.deepFlatten<T>()
        : object is T
        ? <T>[object]
        : object == null
        ? <T>[]
        : throw ArgumentError.value(object, 'object');
    final type_ = type ?? DataType.fromIterable(array_);
    final layout_ = Layout.fromObject(object);
    final data_ = type_.copyList(array_);
    return Tensor.internal(type: type_, layout: layout_, data: data_);
  }

  /// Internal constructors of [Tensor] object.
  @internal
  Tensor.internal({
    required this.type,
    required this.layout,
    required this.data,
  });

  /// The type of this tensor.
  final DataType<T> type;

  /// The layout of the data in the underlying storage.
  final Layout layout;

  /// The underlying data storage.
  final List<T> data;

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
      Tensor<T>.internal(type: type, layout: layout[index], data: data);

  @override
  ObjectPrinter get toStringPrinter => super.toStringPrinter
    ..addValue(type, name: 'type')
    ..addValue(layout, name: 'layout')
    ..addValue(this, printer: TensorPrinter<T>());
}
