import 'package:more/functional.dart';

import '../../../type.dart';
import '../../shared/storage.dart';
import '../mixin/unmodifiable_vector.dart';
import '../vector.dart';

/// Read-only element-wise unary operation.
class UnaryOperationVector<T> with Vector<T>, UnmodifiableVectorMixin<T> {
  UnaryOperationVector(this.dataType, this.vector, this.operation);

  final Vector<T> vector;
  final Map1<T, T> operation;

  @override
  final DataType<T> dataType;

  @override
  int get count => vector.count;

  @override
  Set<Storage> get storage => vector.storage;

  @override
  T getUnchecked(int index) => operation(vector.getUnchecked(index));
}

extension UnaryOperationVectorExtension<T> on Vector<T> {
  /// Returns a view of an unary operation.
  Vector<T> unaryOperation(Map1<T, T> operation, {DataType<T>? dataType}) =>
      UnaryOperationVector<T>(dataType ?? this.dataType, this, operation);
}
