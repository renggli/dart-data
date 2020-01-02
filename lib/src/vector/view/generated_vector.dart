library data.vector.view.generated;

import '../../../type.dart';
import '../mixins/unmodifiable_vector.dart';
import '../vector.dart';

/// Read-only vector generated from a callback.
class GeneratedVector<T> extends Vector<T> with UnmodifiableVectorMixin<T> {
  final T Function(int index) callback;

  GeneratedVector(this.dataType, this.count, this.callback);

  @override
  final DataType<T> dataType;

  @override
  final int count;

  @override
  Vector<T> copy() => this;

  @override
  T getUnchecked(int index) => callback(index);
}
