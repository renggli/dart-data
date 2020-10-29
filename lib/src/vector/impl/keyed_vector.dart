import '../../../type.dart';
import '../../shared/storage.dart';
import '../vector.dart';

/// Sparse keyed vector.
class KeyedVector<T> with Vector<T> {
  final Map<int, T> _values;

  KeyedVector(DataType<T> dataType, int count)
      : this._(dataType, count, <int, T>{});

  KeyedVector._(this.dataType, this.count, this._values);

  @override
  final DataType<T> dataType;

  @override
  final int count;

  @override
  Set<Storage> get storage => {this};

  @override
  Vector<T> copy() => KeyedVector._(dataType, count, Map.of(_values));

  @override
  T getUnchecked(int index) => _values[index] ?? dataType.defaultValue;

  @override
  void setUnchecked(int index, T value) {
    if (value == dataType.defaultValue) {
      _values.remove(index);
    } else {
      _values[index] = value;
    }
  }
}
