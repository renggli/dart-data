import 'dart:collection' show ListMixin;

import 'package:meta/meta.dart';
import 'package:more/printer.dart' show Printer, StandardPrinter;

import '../../type.dart' show DataType;
import '../shared/storage.dart';
import '../tensor/tensor.dart';
import 'impl/compressed_vector.dart';
import 'impl/keyed_vector.dart';
import 'impl/list_vector.dart';
import 'impl/tensor_vector.dart';
import 'vector_format.dart';
import 'view/concat_vector.dart';
import 'view/constant_vector.dart';
import 'view/generated_vector.dart';

/// Abstract vector type.
abstract mixin class Vector<T> implements Storage {
  /// Constructs a default vector of the desired [dataType], the provided
  /// element [count], and possibly a custom [format].
  factory Vector(DataType<T> dataType, int count, {VectorFormat? format}) {
    RangeError.checkNotNegative(count, 'count');
    switch (format ?? VectorFormat.standard) {
      case VectorFormat.list:
        return ListVector<T>(dataType, count);
      case VectorFormat.compressed:
        return CompressedVector<T>(dataType, count);
      case VectorFormat.keyed:
        return KeyedVector<T>(dataType, count);
      case VectorFormat.tensor:
        return TensorVector<T>(dataType, count);
    }
  }

  /// Returns the concatenation of [vectors].
  factory Vector.concat(DataType<T> dataType, Iterable<Vector<T>> vectors,
      {VectorFormat? format}) {
    if (vectors.isEmpty) {
      throw ArgumentError.value(
          vectors, 'vectors', 'Expected at least 1 vector.');
    }
    final result = vectors.length == 1
        ? vectors.first
        : ConcatVector<T>(dataType, vectors.toList(growable: false));
    return format == null ? result : result.toVector(format: format);
  }

  /// Constructs a vector with a constant [value].
  ///
  /// If [format] is specified the resulting vector is mutable, otherwise this
  /// is a read-only view.
  factory Vector.constant(DataType<T> dataType, int count,
      {T? value, VectorFormat? format}) {
    final result =
        ConstantVector<T>(dataType, count, value ?? dataType.defaultValue);
    return format == null ? result : result.toVector(format: format);
  }

  /// Generates a vector from calling a [callback] on every value.
  ///
  /// If [format] is specified the resulting vector is mutable, otherwise this
  /// is a read-only view.
  factory Vector.generate(
      DataType<T> dataType, int count, VectorGeneratorCallback<T> callback,
      {VectorFormat? format}) {
    final result = GeneratedVector<T>(dataType, count, callback);
    return format == null ? result : result.toVector(format: format);
  }

  /// Constructs a vector from an [iterable]. To enable efficient access
  /// the data is always copied.
  factory Vector.fromIterable(DataType<T> dataType, Iterable<T> source,
      {VectorFormat? format}) {
    final length = source.length;
    final iterator = source.iterator;
    final result = Vector<T>(dataType, length, format: format);
    for (var i = 0; i < length && iterator.moveNext(); i++) {
      result.setUnchecked(i, dataType.cast(iterator.current));
    }
    return result;
  }

  /// Constructs a vector from a source list.
  ///
  /// If [format] is specified, [source] is copied into a mutable vector of the
  /// selected format; otherwise a view onto the possibly mutable [source] is
  /// provided.
  factory Vector.fromList(DataType<T> dataType, List<T> source,
      {VectorFormat? format}) {
    final result = ListVector.fromList(dataType, source);
    return format == null ? result : result.toVector(format: format);
  }

  /// Constructs a vector from a [Tensor].
  ///
  /// If [format] is specified, [source] is copied into a mutable vector of the
  /// selected format; otherwise a view onto the possibly mutable [source] is
  /// provided.
  factory Vector.fromTensor(Tensor<T> source, {VectorFormat? format}) {
    final result = TensorVector<T>.fromTensor(source);
    return format == null ? result : result.toVector(format: format);
  }

  /// Returns the data type of this vector.
  DataType<T> get dataType;

  /// The dimensionality of this vector.
  int get count;

  /// Returns the shape of this vector.
  @override
  List<int> get shape => [count];

  /// Returns the target vector with all elements of this vector copied into it.
  Vector<T> copyInto(Vector<T> target) {
    assert(
        count == target.count,
        'Count of this vector ($count) and the target vector '
        '(${target.count}) must match.');
    if (this != target) {
      for (var i = 0; i < count; i++) {
        target.setUnchecked(i, getUnchecked(i));
      }
    }
    return target;
  }

  /// Creates a new [Vector] containing the same elements as this one.
  Vector<T> toVector({VectorFormat? format}) =>
      copyInto(Vector(dataType, count, format: format));

  /// Returns the scalar at the provided [index].
  @nonVirtual
  T operator [](int index) {
    RangeError.checkValidIndex(index, this, 'index', count);
    return getUnchecked(index);
  }

  /// Returns the scalar at the provided [index]. The behavior is undefined if
  /// [index] is outside of bounds.
  T getUnchecked(int index);

  /// Sets the scalar at the provided [index] to [value].
  @nonVirtual
  void operator []=(int index, T value) {
    RangeError.checkValidIndex(index, this, 'index', count);
    setUnchecked(index, value);
  }

  /// Sets the scalar at the provided [index] to [value]. The behavior is
  /// undefined if [index] is outside of bounds.
  void setUnchecked(int index, T value);

  /// Returns a list iterable over the vector.
  List<T> get iterable => _VectorList<T>(this);

  /// Tests if [index] is within the bounds of this vector.
  @nonVirtual
  bool isWithinBounds(int index) => 0 <= index && index < count;

  /// Iterates over each value in the vector. Skips over default values, which
  /// can be done very efficiently on sparse vectors.
  void forEach(void Function(int index, T value) callback) {
    for (var index = 0; index < count; index++) {
      final value = getUnchecked(index);
      if (value != dataType.defaultValue) {
        callback(index, value);
      }
    }
  }

  /// Returns a human readable representation of the vector.
  String format({
    Printer<T>? valuePrinter,
    Printer<String>? paddingPrinter,
    Printer<String>? ellipsesPrinter,
    bool limit = true,
    int leadingItems = 3,
    int trailingItems = 3,
    String separator = ' ',
    String ellipses = '\u2026',
  }) {
    final buffer = StringBuffer();
    valuePrinter ??= dataType.printer;
    paddingPrinter ??= const StandardPrinter<String>();
    ellipsesPrinter ??= const StandardPrinter<String>();
    for (var i = 0; i < count; i++) {
      if (i > 0) {
        buffer.write(separator);
      }
      if (limit && leadingItems <= i && i < count - trailingItems) {
        buffer.write(paddingPrinter(ellipsesPrinter(ellipses)));
        i = count - trailingItems - 1;
      } else {
        buffer.write(paddingPrinter(valuePrinter(getUnchecked(i))));
      }
    }
    return buffer.toString();
  }

  /// Returns the string representation of this polynomial.
  @override
  String toString() => '$runtimeType('
      'dataType: ${dataType.name}, '
      'count: $count):\n'
      '${format()}';
}

class _VectorList<T> extends ListMixin<T> {
  _VectorList(this.vector);

  final Vector<T> vector;

  @override
  int get length => vector.count;

  @override
  set length(int newLength) =>
      throw UnsupportedError('Unable to change length of vector.');

  @override
  T operator [](int index) => vector[index];

  @override
  void operator []=(int index, T value) => vector[index] = value;
}
