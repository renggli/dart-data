library data.vector.vector;

import 'package:data/type.dart';

import 'builder.dart';
import 'impl/standard_vector.dart';

/// Abstract vector type.
abstract class Vector<T> {
  /// Default builder for new vectors.
  static Builder<Object> get builder =>
      Builder<Object>(StandardVector, DataType.object);

  /// Unnamed default constructor.
  const Vector();

  /// The data type of this vector.
  DataType<T> get dataType;

  /// The number of elements in this vector.
  int get count;

  /// Returns a builder that is pre-configured to create matrices of the same
  /// storage format and data type as the receiver.
  Builder<T> get toBuilder => Builder<T>(runtimeType, dataType);

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

  /// Pretty prints the vector.
  @override
  String toString() {
    final buffer = StringBuffer(super.toString());
    buffer.write('[$count]:');
    for (var i = 0; i < count; i++) {
      buffer.write('  ${getUnchecked(i)}');
    }
    return buffer.toString();
  }
}
