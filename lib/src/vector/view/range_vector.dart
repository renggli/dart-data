import '../../../type.dart';
import '../../shared/storage.dart';
import '../vector.dart';

/// Mutable range of a vector.
class RangeVector<T> with Vector<T> {
  RangeVector(this.vector, this.start, this.end) : count = end - start;

  final Vector<T> vector;
  final int start;
  final int end;

  @override
  DataType<T> get dataType => vector.dataType;

  @override
  final int count;

  @override
  Set<Storage> get storage => vector.storage;

  @override
  T getUnchecked(int index) => vector.getUnchecked(start + index);

  @override
  void setUnchecked(int index, T value) =>
      vector.setUnchecked(start + index, value);
}

extension RangeVectorExtension<T> on Vector<T> {
  /// Returns a mutable view onto a [Vector] range. Throws a [RangeError], if
  /// the index is out of bounds.
  Vector<T> range(int start, [int? end]) {
    end = RangeError.checkValidRange(start, end, count, 'start', 'end');
    return rangeUnchecked(start, end);
  }

  /// Returns a mutable view onto a [Vector] range. The behavior is undefined,
  /// if the range is out of bounds.
  Vector<T> rangeUnchecked(int start, int end) {
    if (start == 0 && end == count) return this;
    return switch (this) {
      RangeVector<T>(vector: final thisVector, start: final thisStart) =>
        RangeVector<T>(thisVector, thisStart + start, thisStart + end),
      _ => RangeVector<T>(this, start, end),
    };
  }
}
