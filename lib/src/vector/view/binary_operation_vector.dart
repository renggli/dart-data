import 'package:more/functional.dart';

import '../../../type.dart';
import '../../shared/storage.dart';
import '../mixin/unmodifiable_vector.dart';
import '../vector.dart';

/// Read-only element-wise binary operation between two vectors.
class BinaryOperationVector<T> with Vector<T>, UnmodifiableVectorMixin<T> {
  BinaryOperationVector(this.dataType, this.first, this.second, this.operation)
      : assert(
            first.count == second.count,
            'Element count of first (${first.count}) and second '
            '(${second.count}) operand must match.');

  final Vector<T> first;
  final Vector<T> second;
  final Map2<T, T, T> operation;

  @override
  final DataType<T> dataType;

  @override
  int get count => first.count;

  @override
  Set<Storage> get storage => {...first.storage, ...second.storage};

  @override
  T getUnchecked(int index) =>
      operation(first.getUnchecked(index), second.getUnchecked(index));
}

extension BinaryOperationVectorExtension<T> on Vector<T> {
  /// Returns a view of an unary operation.
  Vector<T> binaryOperation(Vector<T> other, Map2<T, T, T> operation,
          {DataType<T>? dataType}) =>
      BinaryOperationVector<T>(
          dataType ?? this.dataType, this, other, operation);
}
