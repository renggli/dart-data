import '../../../type.dart';
import '../../shared/storage.dart';
import '../vector.dart';

/// Standard vector.
class ListVector<T> with Vector<T> {
  new(DataType<T> dataType, int count)
    : this.fromList(dataType, dataType.newList(count));

  new fromList(this.dataType, this._values);

  final List<T> _values;

  @override
  final DataType<T> dataType;

  @override
  int get count => _values.length;

  @override
  Set<Storage> get storage => {this};

  @override
  T getUnchecked(int index) => _values[index];

  @override
  void setUnchecked(int index, T value) => _values[index] = value;
}
