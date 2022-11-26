import '../matrix.dart';

extension CompareMatrixExtension<T> on Matrix<T> {
  /// Compares this [Matrix] and with [other].
  bool compare(Matrix<T> other, {bool Function(T a, T b)? equals}) {
    if (equals == null && identical(this, other)) {
      return true;
    }
    if (rowCount != other.rowCount || colCount != other.colCount) {
      return false;
    }
    equals ??= dataType.equality.isEqual;
    for (var r = 0; r < rowCount; r++) {
      for (var c = 0; c < colCount; c++) {
        if (!equals(getUnchecked(r, c), other.getUnchecked(r, c))) {
          return false;
        }
      }
    }
    return true;
  }
}
