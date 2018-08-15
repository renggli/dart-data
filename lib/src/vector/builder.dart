library data.vector.builder;

import 'package:data/type.dart';

import 'impl/keyed_vector.dart';
import 'impl/list_vector.dart';
import 'impl/standard_vector.dart';
import 'vector.dart';

/// Builds a vector of a custom type.
class Builder<T> {
  /// Constructors a builder with the provided storage [format] and data [type].
  Builder(this.format, this.type);

  /// Returns the storage format of the builder.
  final Type format;

  /// Returns the data type of the builder.
  final DataType<T> type;

  /// Returns a builder for standard vectors.
  Builder<T> get standard => withFormat(StandardVector);

  /// Returns a builder for list vectors.
  Builder<T> get list => withFormat(ListVector);

  /// Returns a builder for keyed vectors.
  Builder<T> get keyed => withFormat(KeyedVector);

  /// Returns a builder with the provided storage [format].
  Builder<T> withFormat(Type format) =>
      this.format == format ? this : Builder<T>(format, type);

  /// Returns a builder with the provided data [type].
  Builder<S> withType<S>(DataType<S> type) =>
      this.type == type ? this : Builder<S>(format, type);

  /// Builds a new vector of the configured format.
  Vector<T> call(int count) {
    RangeError.checkNotNegative(count, 'count');
    switch (format) {
      case StandardVector:
        return StandardVector<T>(type, count);
      case ListVector:
        return ListVector<T>(type, count);
      case KeyedVector:
        return KeyedVector<T>(type, count);
    }
    throw ArgumentError.value(format, 'format');
  }

  /// Builds a vector with a constant [value].
  Vector<T> constant(int count, T value) {
    final result = this(count);
    for (var i = 0; i < count; i++) {
      result.setUnchecked(i, value);
    }
    return result;
  }

  /// Builds a vector from calling a [callback] on every value.
  Vector<T> generate(int count, T callback(int index)) {
    final result = this(count);
    for (var i = 0; i < count; i++) {
      result.setUnchecked(i, callback(i));
    }
    return result;
  }

  /// Builds a vector from another vector.
  Vector<T> from(Vector<T> source) {
    final result = this(source.count);
    for (var i = 0; i < source.count; i++) {
      result.setUnchecked(i, source.getUnchecked(i));
    }
    return result;
  }

  /// Builds a sub-vector from the range [start] to [end] (exclusive).
  Vector<T> fromRange(Vector<T> source, int start, int end) {
    RangeError.checkValidRange(start, end, source.count, 'start', 'end');
    final result = this(end - start);
    for (var i = start; i < end; i++) {
      result.setUnchecked(i - start, source.getUnchecked(i));
    }
    return result;
  }

  /// Builds a sub-vector from a list of column [indices].
  Vector<T> fromIndices(Vector<T> source, List<int> indices) {
    final result = this(indices.length);
    for (var i = 0; i < indices.length; i++) {
      RangeError.checkValueInInterval(i, 0, source.count, 'indices');
      result.setUnchecked(i, source.getUnchecked(indices[i]));
    }
    return result;
  }

  /// Builds a vector from a list of values.
  Vector<T> fromList(List<T> source) {
    if (source.isEmpty) {
      throw ArgumentError.value(source, 'source', 'Must be not empty');
    }
    final result = this(source.length);
    for (var i = 0; i < source.length; i++) {
      result.setUnchecked(i, source[i]);
    }
    return result;
  }
}
