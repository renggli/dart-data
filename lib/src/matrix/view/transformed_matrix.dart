import '../../../type.dart';
import '../../shared/storage.dart';
import '../matrix.dart';

/// Mutable two-way transformed matrix.
class TransformedMatrix<S, T> with Matrix<T> {
  TransformedMatrix(this.matrix, this.read, this.write, this.dataType);

  final Matrix<S> matrix;
  final T Function(int row, int col, S value) read;
  final S Function(int row, int col, T value) write;

  @override
  final DataType<T> dataType;

  @override
  int get rowCount => matrix.rowCount;

  @override
  int get colCount => matrix.colCount;

  @override
  Set<Storage> get storage => matrix.storage;

  @override
  T getUnchecked(int row, int col) =>
      read(row, col, matrix.getUnchecked(row, col));

  @override
  void setUnchecked(int row, int col, T value) =>
      matrix.setUnchecked(row, col, write(row, col, value));
}

extension TransformedMatrixExtension<T> on Matrix<T> {
  /// Returns a read-only view on this [Matrix] with all its elements lazily
  /// converted by calling the provided transformation [callback].
  Matrix<S> map<S>(
    S Function(int row, int col, T value) callback, [
    DataType<S>? dataType,
  ]) => transform<S>(callback, dataType: dataType);

  /// Returns a view on this [Matrix] with all its elements lazily converted
  /// by calling the provided [read] transformation. An optionally provided
  /// [write] transformation enables writing to the returned matrix.
  Matrix<S> transform<S>(
    S Function(int row, int col, T value) read, {
    T Function(int row, int col, S value)? write,
    DataType<S>? dataType,
  }) => TransformedMatrix<T, S>(
    this,
    read,
    write ?? (r, c, v) => throw UnsupportedError('Matrix is not mutable.'),
    dataType ?? DataType.fromType<S>(),
  );
}
