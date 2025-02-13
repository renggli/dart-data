import 'package:more/functional.dart';

import '../../../type.dart';
import '../../shared/storage.dart';
import '../matrix.dart';
import '../mixin/unmodifiable_matrix.dart';

/// Read-only element-wise binary operation between two matrices.
class BinaryOperationMatrix<T> with Matrix<T>, UnmodifiableMatrixMixin<T> {
  BinaryOperationMatrix(this.dataType, this.first, this.second, this.operation)
    : assert(
        first.rowCount == second.rowCount,
        'Row count of first (${first.rowCount}) and second '
        '(${second.rowCount}) operand must match.',
      ),
      assert(
        first.colCount == second.colCount,
        'Column count of first (${first.colCount}) and second '
        '(${second.colCount}) operand must match.',
      );

  final Matrix<T> first;
  final Matrix<T> second;
  final Map2<T, T, T> operation;

  @override
  final DataType<T> dataType;

  @override
  int get rowCount => first.rowCount;

  @override
  int get colCount => first.colCount;

  @override
  Set<Storage> get storage => {...first.storage, ...second.storage};

  @override
  T getUnchecked(int row, int col) =>
      operation(first.getUnchecked(row, col), second.getUnchecked(row, col));
}

extension BinaryOperationMatrixExtension<T> on Matrix<T> {
  /// Returns a view of an unary operation.
  Matrix<T> binaryOperation(
    Matrix<T> other,
    Map2<T, T, T> operation, {
    DataType<T>? dataType,
  }) => BinaryOperationMatrix<T>(
    dataType ?? this.dataType,
    this,
    other,
    operation,
  );
}
