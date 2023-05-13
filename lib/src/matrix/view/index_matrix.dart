import 'package:more/collection.dart' show IntegerRange;

import '../../../type.dart';
import '../../shared/storage.dart';
import '../matrix.dart';

/// Mutable indexed view of the rows and columns of a matrix.
class IndexMatrix<T> with Matrix<T> {
  IndexMatrix(this.matrix, Iterable<int> rowIndexes, Iterable<int> colIndexes)
      : rowIndexes = DataType.indexDataType.copyList(rowIndexes),
        colIndexes = DataType.indexDataType.copyList(colIndexes);

  final Matrix<T> matrix;
  final List<int> rowIndexes;
  final List<int> colIndexes;

  @override
  DataType<T> get dataType => matrix.dataType;

  @override
  int get rowCount => rowIndexes.length;

  @override
  int get colCount => colIndexes.length;

  @override
  Set<Storage> get storage => matrix.storage;

  @override
  T getUnchecked(int row, int col) =>
      matrix.getUnchecked(rowIndexes[row], colIndexes[col]);

  @override
  void setUnchecked(int row, int col, T value) =>
      matrix.setUnchecked(rowIndexes[row], colIndexes[col], value);
}

extension IndexMatrixExtension<T> on Matrix<T> {
  /// Returns a mutable view onto row indexes. Throws a [RangeError], if
  /// any of the [rowIndexes] are out of bounds.
  Matrix<T> rowIndex(Iterable<int> rowIndexes) =>
      index(rowIndexes, IntegerRange(0, colCount));

  /// Returns a mutable view onto row indexes. The behavior is undefined, if
  /// any of the [rowIndexes] are out of bounds.
  Matrix<T> rowIndexUnchecked(Iterable<int> rowIndexes) =>
      indexUnchecked(rowIndexes, IntegerRange(0, colCount));

  /// Returns a mutable view onto column indexes. Throws a [RangeError], if
  /// any of the [colIndexes] are out of bounds.
  Matrix<T> colIndex(Iterable<int> colIndexes) =>
      index(IntegerRange(0, rowCount), colIndexes);

  /// Returns a mutable view onto column indexes. The behavior is undefined, if
  /// any of the [colIndexes] are out of bounds.
  Matrix<T> colIndexUnchecked(Iterable<int> colIndexes) =>
      indexUnchecked(IntegerRange(0, rowCount), colIndexes);

  /// Returns a mutable view onto row and column indexes. Throws a
  /// [RangeError], if any of the indexes are out of bounds.
  Matrix<T> index(Iterable<int> rowIndexes, Iterable<int> colIndexes) {
    for (final index in rowIndexes) {
      RangeError.checkValueInInterval(index, 0, rowCount - 1, 'rowIndexes');
    }
    for (final index in colIndexes) {
      RangeError.checkValueInInterval(index, 0, colCount - 1, 'colIndexes');
    }
    return indexUnchecked(rowIndexes, colIndexes);
  }

  /// Returns a mutable view onto row and column indexes. The behavior is
  /// undefined if any of the indexes are out of bounds.
  Matrix<T> indexUnchecked(
          Iterable<int> rowIndexes, Iterable<int> colIndexes) =>
      switch (this) {
        IndexMatrix<T>(
          matrix: final matrix,
          rowIndexes: final thisRowIndexes,
          colIndexes: final thisColIndexes
        ) =>
          IndexMatrix<T>(
              matrix,
              rowIndexes.map((index) => thisRowIndexes[index]),
              colIndexes.map((index) => thisColIndexes[index])),
        _ => IndexMatrix<T>(this, rowIndexes, colIndexes),
      };
}
