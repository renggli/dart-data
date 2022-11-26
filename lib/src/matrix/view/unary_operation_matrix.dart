import 'package:more/functional.dart';

import '../../../type.dart';
import '../../shared/storage.dart';
import '../matrix.dart';
import '../mixin/unmodifiable_matrix.dart';

/// Read-only element-wise unary operation.
class UnaryOperationMatrix<T> with Matrix<T>, UnmodifiableMatrixMixin<T> {
  UnaryOperationMatrix(this.dataType, this.matrix, this.operation);

  final Matrix<T> matrix;
  final Map1<T, T> operation;

  @override
  final DataType<T> dataType;

  @override
  int get rowCount => matrix.rowCount;

  @override
  int get colCount => matrix.colCount;

  @override
  Set<Storage> get storage => matrix.storage;

  @override
  T getUnchecked(int row, int col) => operation(matrix.getUnchecked(row, col));
}

extension UnaryOperationMatrixExtension<T> on Matrix<T> {
  /// Returns a view of an unary operation.
  Matrix<T> unaryOperation(Map1<T, T> operation, {DataType<T>? dataType}) =>
      UnaryOperationMatrix<T>(dataType ?? this.dataType, this, operation);
}
