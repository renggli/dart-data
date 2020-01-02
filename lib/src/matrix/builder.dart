library data.matrix.builder;

//
///// Builds a matrix of a custom type.
//class Builder<T> {
//
//  /// Builds a matrix by concatenating a list of [matrices] horizontally.
//  Matrix<T> concatHorizontal(Iterable<Matrix<T>> matrices,
//      {bool lazy = false}) {
//    final result = ConcatHorizontalMatrix<T>(type, matrices);
//    return lazy ? result : fromMatrix(result);
//  }
//
//  /// Builds a matrix by concatenating a list of [matrices] vertically.
//  Matrix<T> concatVertical(Iterable<Matrix<T>> matrices, {bool lazy = false}) {
//    final result = ConcatVerticalMatrix<T>(type, matrices);
//    return lazy ? result : fromMatrix(result);
//  }
//
//  /// Builds a matrix from a row vector.
//  Matrix<T> fromRow(Vector<T> source, {bool lazy = false}) =>
//      lazy ? source.rowMatrix : fromMatrix(source.rowMatrix);
//
//  /// Builds a matrix from a column vector.
//  Matrix<T> fromColumn(Vector<T> source, {bool lazy = false}) =>
//      lazy ? source.columnMatrix : fromMatrix(source.columnMatrix);
//
//  /// Builds a matrix from a diagonal vector.
//  Matrix<T> fromDiagonal(Vector<T> source, {bool lazy = false}) =>
//      lazy ? source.diagonalMatrix : fromMatrix(source.diagonalMatrix);
//
//
//
//  /// Builds a matrix from a list of row vectors.
//  Matrix<T> fromRowVectors(List<Vector<T>> source) {
//    final result = this(source.length, source.isEmpty ? 0 : source[0].count);
//    for (var r = 0; r < result.rowCount; r++) {
//      final sourceRow = source[r];
//      if (sourceRow.count != result.colCount) {
//        throw ArgumentError.value(
//            source, 'source', 'All row vectors must be equally sized.');
//      }
//      for (var c = 0; c < result.colCount; c++) {
//        result.setUnchecked(r, c, sourceRow[c]);
//      }
//    }
//    return result;
//  }
//
//
//
//  /// Builds a matrix from a list of column vectors.
//  Matrix<T> fromColumnVectors(List<Vector<T>> source) {
//    final result = this(source.isEmpty ? 0 : source[0].count, source.length);
//    for (var c = 0; c < result.colCount; c++) {
//      final sourceCol = source[c];
//      if (sourceCol.count != result.rowCount) {
//        throw ArgumentError.value(
//            source, 'source', 'All column vectors must be equally sized.');
//      }
//      for (var r = 0; r < result.rowCount; r++) {
//        result.setUnchecked(r, c, sourceCol[r]);
//      }
//    }
//    return result;
//  }
//
//}
