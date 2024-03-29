import '../../../type.dart';
import '../../shared/storage.dart';
import '../mixin/unmodifiable_vector.dart';
import '../vector.dart';

/// Callback to generate a value in [GeneratedVector].
typedef VectorGeneratorCallback<T> = T Function(int index);

/// Read-only vector generated from a callback.
class GeneratedVector<T> with Vector<T>, UnmodifiableVectorMixin<T> {
  GeneratedVector(this.dataType, this.count, this.callback);

  final VectorGeneratorCallback<T> callback;

  @override
  final DataType<T> dataType;

  @override
  final int count;

  @override
  Set<Storage> get storage => {this};

  @override
  T getUnchecked(int index) => callback(index);
}
