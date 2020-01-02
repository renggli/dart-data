library data.vector.view.reversed;

import '../../../tensor.dart';
import '../../../type.dart';
import '../vector.dart';

/// Mutable reverse view of a vector.
class ReversedVector<T> extends Vector<T> {
  final Vector<T> vector;

  ReversedVector(this.vector);

  @override
  DataType<T> get dataType => vector.dataType;

  @override
  int get count => vector.count;

  @override
  Set<Tensor> get storage => vector.storage;

  @override
  Vector<T> copy() => ReversedVector<T>(vector.copy());

  @override
  T getUnchecked(int index) => vector.getUnchecked(vector.count - index - 1);

  @override
  void setUnchecked(int index, T value) =>
      vector.setUnchecked(vector.count - index - 1, value);
}

extension ReversedVectorExtension<T> on Vector<T> {
  /// Returns a reversed view of this [Vector].
  Vector<T> get reversed => _reversed(this);

  // TODO(renggli): workaround, https://github.com/dart-lang/sdk/issues/39959.
  Vector<T> _reversed<T>(Vector<T> self) =>
      self is ReversedVector<T> ? self.vector : ReversedVector<T>(self);
}
