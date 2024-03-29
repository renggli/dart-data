import '../../../type.dart';
import '../../shared/storage.dart';
import '../vector.dart';

/// Sparse keyed vector.
class KeyedVector<T> with Vector<T> {
  KeyedVector(this.dataType, this.count);

  final Map<int, T> _values = <int, T>{};

  @override
  final DataType<T> dataType;

  @override
  final int count;

  @override
  Set<Storage> get storage => {this};

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

  @override
  void forEach(void Function(int index, T value) callback) =>
      _values.forEach(callback);
}
