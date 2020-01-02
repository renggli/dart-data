library data.vector.view.generated;

import '../../../type.dart';
import '../../shared/storage.dart';
import '../mixins/unmodifiable_vector.dart';
import '../vector.dart';

/// Callback to generate a value in [GeneratedVector].
typedef VectorGeneratorCallback<T> = T Function(int index);

/// Read-only vector generated from a callback.
class GeneratedVector<T> with Vector<T>, UnmodifiableVectorMixin<T> {
  final VectorGeneratorCallback<T> callback;

  GeneratedVector(this.dataType, this.count, this.callback);

  @override
  final DataType<T> dataType;

  @override
  final int count;

  @override
  Set<Storage> get storage => {this};

  @override
  Vector<T> copy() => this;

  @override
  T getUnchecked(int index) => callback(index);
}
