import '../matrix.dart';

extension TestingExtension<T> on Matrix<T> {
  /// Tests if this [Matrix] is square.
  bool get isSquare => rowCount == columnCount;

  /// Tests if this [Matrix] is symmetric (equal to its transposed form).
  bool get isSymmetric {
    if (!isSquare) {
      return false;
    }
    final isEqual = dataType.equality.isEqual;
    for (var r = 1; r < rowCount; r++) {
      for (var c = 0; c < r; c++) {
        if (!isEqual(getUnchecked(r, c), getUnchecked(c, r))) {
          return false;
        }
      }
    }
    return true;
  }

  /// Tests if this [Matrix] is a diagonal matrix, with non-zero values only on
  /// the diagonal.
  bool get isDiagonal {
    final isEqual = dataType.equality.isEqual;
    final additiveIdentity = dataType.field.additiveIdentity;
    for (var r = 0; r < rowCount; r++) {
      for (var c = 0; c < columnCount; c++) {
        if (r != c && !isEqual(getUnchecked(r, c), additiveIdentity)) {
          return false;
        }
      }
    }
    return true;
  }

  /// Tests if this [Matrix] is a lower triangular matrix, with non-zero values
  /// only in the lower-triangle of the matrix.
  bool get isLowerTriangular {
    final isEqual = dataType.equality.isEqual;
    final additiveIdentity = dataType.field.additiveIdentity;
    for (var r = 0; r < rowCount; r++) {
      for (var c = r + 1; c < columnCount; c++) {
        if (!isEqual(getUnchecked(r, c), additiveIdentity)) {
          return false;
        }
      }
    }
    return true;
  }

  /// Tests if this [Matrix] is a upper triangular matrix, with non-zero values
  /// only in the upper-triangle of the matrix.
  bool get isUpperTriangular {
    final isEqual = dataType.equality.isEqual;
    final additiveIdentity = dataType.field.additiveIdentity;
    for (var r = 1; r < rowCount; r++) {
      for (var c = 0; c < columnCount && c < r; c++) {
        if (!isEqual(getUnchecked(r, c), additiveIdentity)) {
          return false;
        }
      }
    }
    return true;
  }
}
