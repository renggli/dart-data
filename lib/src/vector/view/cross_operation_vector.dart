import '../../../type.dart';
import '../../shared/storage.dart';
import '../mixin/unmodifiable_vector.dart';
import '../vector.dart';

/// Read-only cross product between two vectors.
class CrossOperationVector<T> with Vector<T>, UnmodifiableVectorMixin<T> {
  CrossOperationVector(this.dataType, this.a, this.b)
      : assert(a.count == 3, 'Vector must have 3 elements, but got ${a.count}'),
        assert(b.count == 3, 'Vector must have 3 elements, but got ${b.count}'),
        sub = dataType.field.sub,
        mul = dataType.field.mul;

  final T Function(T a, T b) sub;
  final T Function(T a, T b) mul;

  final Vector<T> a;
  final Vector<T> b;

  @override
  final DataType<T> dataType;

  @override
  int get count => 3;

  @override
  Set<Storage> get storage => {...a.storage, ...b.storage};

  @override
  T getUnchecked(int index) {
    switch (index) {
      case 0:
        return sub(mul(a.getUnchecked(1), b.getUnchecked(2)),
            mul(a.getUnchecked(2), b.getUnchecked(1)));
      case 1:
        return sub(mul(a.getUnchecked(2), b.getUnchecked(0)),
            mul(a.getUnchecked(0), b.getUnchecked(2)));
      case 2:
        return sub(mul(a.getUnchecked(0), b.getUnchecked(1)),
            mul(a.getUnchecked(1), b.getUnchecked(0)));
    }
    throw UnimplementedError();
  }
}
