import '../../../type.dart';
import '../../shared/storage.dart';
import '../vector.dart';

/// Mutable range of a vector.
class RangeVector<T> with Vector<T> {
  final Vector<T> vector;
  final int start;

  RangeVector(Vector<T> vector, int start, int end)
      : this._(vector, start, end - start);

  RangeVector._(this.vector, this.start, this.count);

  @override
  DataType<T> get dataType => vector.dataType;

  @override
  final int count;

  @override
  Set<Storage> get storage => vector.storage;

  @override
  Vector<T> copy() => RangeVector<T>._(vector.copy(), start, count);

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
  Vector<T> rangeUnchecked(int start, int end) =>
      start == 0 && end == count ? this : _rangeUnchecked(this, start, end);

  // TODO(renggli): https://github.com/dart-lang/sdk/issues/39959
  static Vector<T> _rangeUnchecked<T>(Vector<T> self, int start, int end) =>
      self is RangeVector<T>
          ? RangeVector<T>(self.vector, self.start + start, self.start + end)
          : RangeVector<T>(self, start, end);
}
