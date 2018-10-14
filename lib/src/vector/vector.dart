library data.vector.vector;

import 'package:data/tensor.dart' show Tensor;
import 'package:data/type.dart' show DataType;
import 'package:more/printer.dart' show Printer;

import 'builder.dart';
import 'format.dart';
import 'view/index_vector.dart';
import 'view/mapped_vector.dart';
import 'view/range_vector.dart';
import 'view/unmodifiable_vector.dart';

/// Abstract vector type.
abstract class Vector<T> implements Tensor<T> {
  /// Default builder for new vectors.
  static Builder<Object> get builder =>
      Builder<Object>(Format.standard, DataType.object);

  /// Unnamed default constructor.
  const Vector();

  /// Returns the shape of this vector.
  @override
  List<int> get shape => [count];

  /// Returns a copy of this tensor.
  @override
  Vector<T> copy();

  /// The dimensionality of this vector.
  int get count;

  /// Returns the scalar at the provided [index].
  @override
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

  /// Returns a mutable view onto a vector range. Throws a [RangeError], if
  /// the index is out of bounds.
  Vector<T> range(int start, int end) {
    RangeError.checkValidRange(start, end, count, 'start', 'end');
    if (start == 0 && end == count) {
      return this;
    } else {
      return rangeUnchecked(start, end);
    }
  }

  /// Returns a mutable view onto a vector range. The behavior is undefined, if
  /// the range is out of bounds.
  Vector<T> rangeUnchecked(int start, int end) =>
      RangeVector<T>(this, start, end);

  /// Returns a mutable view onto indexes of a vector. Throws a [RangeError], if
  /// any of the indexes index is out of bounds.
  Vector<T> index(Iterable<int> indexes) {
    for (var index in indexes) {
      RangeError.checkValueInInterval(index, 0, count - 1, 'indexes');
    }
    return indexUnchecked(indexes);
  }

  /// Returns a mutable view onto a vector range. The behavior is undefined, if
  /// any of the indexes are out of bounds.
  Vector<T> indexUnchecked(Iterable<int> indexes) =>
      IndexVector<T>(this, indexes);

  /// Returns a lazy [Vector] with elements that are created by calling
  /// `callback` on each element of this `Vector`.
  Vector<S> map<S>(VectorTransformation<T, S> callback, DataType<S> dataType) =>
      MappedVector<T, S>(this, callback, dataType);

  /// Returns a unmodifiable view of the vector.
  Vector<T> get unmodifiable => UnmodifiableVector<T>(this);

  /// Returns a human readable representation of the vector.
  String format([Printer printer]) {
    final formatter = printer ?? dataType.printer;
    final buffer = StringBuffer();
    for (var i = 0; i < count; i++) {
      if (i > 0) {
        buffer.write(' ');
      }
      buffer.write(formatter(getUnchecked(i)));
    }
    return buffer.toString();
  }

  /// Returns a string representation of this vector.
  @override
  String toString() => '$runtimeType[$count]: ${format()}';
}
