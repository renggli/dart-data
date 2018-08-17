library data.vector.vector;

import 'package:data/type.dart';

import 'builder.dart';
import 'impl/standard_vector.dart';
import 'view/sub_vector.dart';

/// Abstract vector type.
abstract class Vector<T> {
  /// Default builder for new vectors.
  static Builder<Object> get builder =>
      Builder<Object>(StandardVector, DataType.object);

  /// Unnamed default constructor.
  const Vector();

  /// The data type of this vector.
  DataType<T> get dataType;

  /// The dimensionality of this vector.
  int get count;

  /// Returns the value at the provided [index].
  T operator [](int index) {
    RangeError.checkValidIndex(index, this, 'index', count);
    return getUnchecked(index);
  }

  /// Returns the value at the provided [index]. The behavior is undefined if
  /// [index] is outside of bounds.
  T getUnchecked(int index);

  /// Sets the value at the provided [index] to [value].
  void operator []=(int index, T value) {
    RangeError.checkValidIndex(index, this, 'index', count);
    setUnchecked(index, value);
  }

  /// Sets the value at the provided [index] to [value]. The behavior is
  /// undefined if [index] is outside of bounds.
  void setUnchecked(int index, T value);

  /// Returns a mutable view onto a sub-vector. Throws a [RangeError], if
  /// the index is out of bounds.
  Vector<T> subVector(int start, int end) {
    RangeError.checkValidRange(start, end, count, 'start', 'end');
    if (start == 0 && end == count) {
      return this;
    } else {
      return subVectorUnchecked(start, end);
    }
  }

  /// Returns a mutable view onto a sub-matrix. The behavior is undefined, if
  /// the ranges is out of bounds.
  Vector<T> subVectorUnchecked(int start, int end) =>
      SubVector<T>(this, start, end);

  /// Pretty prints the vector.
  @override
  String toString() {
    final buffer = StringBuffer(runtimeType);
    buffer.write('[$count]: ');
    for (var i = 0; i < count; i++) {
      if (i > 0) {
        buffer.write(', ');
      }
      buffer.write(getUnchecked(i));
    }
    return buffer.toString();
  }
}
