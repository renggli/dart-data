import 'dart:collection' show ListMixin;

import 'package:more/printer.dart' show Printer;

import '../../type.dart' show DataType;
import '../shared/storage.dart';
import 'impl/keyed_vector.dart';
import 'impl/list_vector.dart';
import 'impl/standard_vector.dart';
import 'vector_format.dart';
import 'view/concat_vector.dart';
import 'view/constant_vector.dart';
import 'view/generated_vector.dart';

/// Abstract vector type.
abstract class Vector<T> implements Storage {
  /// Constructs a default vector of the desired [dataType], the provided
  /// element [count], and possibly a custom [format].
  factory Vector(DataType<T> dataType, int count, {VectorFormat? format}) {
    ArgumentError.checkNotNull(dataType, 'dataType');
    RangeError.checkNotNegative(count, 'count');
    switch (format ?? defaultVectorFormat) {
      case VectorFormat.standard:
        return StandardVector<T>(dataType, count);
      case VectorFormat.list:
        return ListVector<T>(dataType, count);
      case VectorFormat.keyed:
        return KeyedVector<T>(dataType, count);
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
        : ConcatVector<T>(dataType, vectors);
    return format == null ? result : result.toVector(format: format);
  }

  /// Constructs a vector with a constant [value]. If [format] is specified
  /// the resulting vector is mutable, otherwise this is a read-only view.
  factory Vector.constant(DataType<T> dataType, int count,
      {T? value, VectorFormat? format}) {
    final result =
        ConstantVector<T>(dataType, count, value ?? dataType.defaultValue);
    return format == null ? result : result.toVector(format: format);
  }

  /// Generates a vector from calling a [callback] on every value. If [format]
  /// is specified the resulting vector is mutable, otherwise this is a
  /// read-only view.
  factory Vector.generate(
      DataType<T> dataType, int count, VectorGeneratorCallback<T> callback,
      {VectorFormat? format}) {
    final result = GeneratedVector<T>(dataType, count, callback);
    return format == null ? result : result.toVector(format: format);
  }

  /// Constructs a vector from an list
  factory Vector.fromList(DataType<T> dataType, List<T> source,
      {VectorFormat? format}) {
    final result = Vector<T>(dataType, source.length, format: format);
    for (var i = 0; i < source.length; i++) {
      result.setUnchecked(i, dataType.cast(source[i]));
    }
    return result;
  }

  /// Returns the data type of this vector.
  DataType<T> get dataType;

  /// The dimensionality of this vector.
  int get count;

  /// Returns the shape of this vector.
  @override
  List<int> get shape => [count];

  /// Returns a copy of this vector.
  @override
  Vector<T> copy();

  /// Creates a new [Vector] containing the same elements as this one.
  Vector<T> toVector({VectorFormat? format}) {
    final result = Vector(dataType, count, format: format);
    for (var i = 0; i < count; i++) {
      result.setUnchecked(i, getUnchecked(i));
    }
    return result;
  }

  /// Returns the scalar at the provided [index].
  T operator [](int index) {
    RangeError.checkValidIndex(index, this, 'index', count);
    return getUnchecked(index);
  }

  /// Returns the scalar at the provided [index]. The behavior is undefined if
  /// [index] is outside of bounds.
  T getUnchecked(int index);

  /// Sets the scalar at the provided [index] to [value].
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
    Printer? valuePrinter,
    Printer? paddingPrinter,
    Printer? ellipsesPrinter,
    bool limit = true,
    int leadingItems = 3,
    int trailingItems = 3,
    String separator = ' ',
    String ellipses = '\u2026',
  }) {
    final buffer = StringBuffer();
    valuePrinter ??= dataType.printer;
    paddingPrinter ??= Printer.standard();
    ellipsesPrinter ??= Printer.standard();
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
  final Vector<T> vector;

  _VectorList(this.vector);

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
