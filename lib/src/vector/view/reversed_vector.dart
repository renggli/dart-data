import '../../../type.dart';
import '../../shared/storage.dart';
import '../vector.dart';

/// Mutable reverse view of a vector.
class ReversedVector<T> with Vector<T> {
  ReversedVector(this.vector);

  final Vector<T> vector;

  @override
  DataType<T> get dataType => vector.dataType;

  @override
  int get count => vector.count;

  @override
  Set<Storage> get storage => vector.storage;

  @override
  T getUnchecked(int index) => vector.getUnchecked(vector.count - index - 1);

  @override
  void setUnchecked(int index, T value) =>
      vector.setUnchecked(vector.count - index - 1, value);
}

extension ReversedVectorExtension<T> on Vector<T> {
  /// Returns a reversed view of this [Vector].
  Vector<T> get reversed => _reversed(this);

  // TODO(renggli): https://github.com/dart-lang/sdk/issues/39959
  static Vector<T> _reversed<T>(Vector<T> self) =>
      self is ReversedVector<T> ? self.vector : ReversedVector<T>(self);
}
