import '../../../type.dart';
import '../../shared/storage.dart';
import '../mixin/unmodifiable_vector.dart';
import '../vector.dart';

/// Read-only vector with a constant value.
class ConstantVector<T> with Vector<T>, UnmodifiableVectorMixin<T> {
  final T value;

  ConstantVector(this.dataType, this.count, this.value);

  @override
  final DataType<T> dataType;

  @override
  final int count;

  @override
  Set<Storage> get storage => {this};

  @override
  Vector<T> copy() => this;

  @override
  T getUnchecked(int index) => value;
}
