import '../../type.dart';
import 'vector.dart';

/// Abstract interface representing a linear mapping between finite-dimensional vector spaces.
abstract interface class LinearOperator<T> {
  /// The number of rows (dimension of the codomain).
  int get rowCount;

  /// The number of columns (dimension of the domain).
  int get colCount;

  /// The data type of the operator elements.
  DataType<T> get type;

  /// Computes the action of this operator on vector [x]: y = A * x.
  Vector<T> apply(Vector<T> x);

  /// Computes the action of the transpose operator on vector [x]: y = A^T * x.
  Vector<T> applyTranspose(Vector<T> x);

  /// Computes the operator composition: (A * other).
  LinearOperator<T> matmul(LinearOperator<T> other);
}
