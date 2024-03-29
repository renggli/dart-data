import '../../../type.dart';
import '../../shared/storage.dart';
import '../mixin/unmodifiable_vector.dart';
import '../vector.dart';

/// Read-only vector with a constant value.
class ConstantVector<T> with Vector<T>, UnmodifiableVectorMixin<T> {
  ConstantVector(this.dataType, this.count, this.value);

  final T value;

  @override
  final DataType<T> dataType;

  @override
  final int count;

  @override
  Set<Storage> get storage => {this};

  @override
  T getUnchecked(int index) => value;
}
