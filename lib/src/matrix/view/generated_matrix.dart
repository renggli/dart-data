import '../../../type.dart';
import '../../shared/storage.dart';
import '../matrix.dart';
import '../mixin/unmodifiable_matrix.dart';

/// Callback to generate a value in [GeneratedMatrix].
typedef MatrixGeneratorCallback<T> = T Function(int row, int column);

/// Read-only generator matrix.
class GeneratedMatrix<T> with Matrix<T>, UnmodifiableMatrixMixin<T> {
  GeneratedMatrix(
      this.dataType, this.rowCount, this.columnCount, this.callback);

  final MatrixGeneratorCallback<T> callback;

  @override
  final DataType<T> dataType;

  @override
  final int rowCount;

  @override
  final int columnCount;

  @override
  Set<Storage> get storage => {this};

  @override
  T getUnchecked(int row, int col) => callback(row, col);
}
