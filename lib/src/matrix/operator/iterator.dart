import '../matrix.dart';
import '../types.dart';

extension IteratorMatrixExtension<T> on Matrix<T> {
  /// Returns an iterable over the values of this [Matrix] in row-by-row.
  Iterable<RowColumnValue<T>> get rowMajor sync* {
    for (var r = 0; r < rowCount; r++) {
      for (var c = 0; c < colCount; c++) {
        yield (row: r, col: c, value: getUnchecked(r, c));
      }
    }
  }

  /// Returns an iterable over the values of this [Matrix] in column-by-column.
  Iterable<RowColumnValue<T>> get columnMajor sync* {
    for (var c = 0; c < colCount; c++) {
      for (var r = 0; r < rowCount; r++) {
        yield (row: r, col: c, value: getUnchecked(r, c));
      }
    }
  }

  /// Returns an iterable that walks clockwise over the [Matrix] starting in the
  /// upper left corner.
  Iterable<RowColumnValue<T>> get spiral sync* {
    var k = 0, l = 0;
    var m = rowCount, n = colCount;
    while (k < m && l < n) {
      // First row from the remaining rows:
      for (var i = l; i < n; i++) {
        yield (row: k, col: i, value: getUnchecked(k, i));
      }
      k++;
      // Last column from the remaining columns:
      for (var i = k; i < m; i++) {
        yield (row: i, col: n - 1, value: getUnchecked(i, n - 1));
      }
      n--;
      // Last row from the remaining rows:
      if (k < m) {
        for (var i = n - 1; i >= l; i--) {
          yield (row: m - 1, col: i, value: getUnchecked(m - 1, i));
        }
        m--;
      }
      // First column from the remaining columns:
      if (l < n) {
        for (var i = m - 1; i >= k; i--) {
          yield (row: i, col: l, value: getUnchecked(i, l));
        }
        l++;
      }
    }
  }

  /// Returns an iterable that walks zig-sag over the [Matrix] starting in the
  /// upper left corner.
  Iterable<RowColumnValue<T>> get zigZag sync* {
    for (var i = 0; i < colCount + rowCount - 1; i++) {
      if (i.isOdd) {
        // Walk down and left.
        for (
          var r = i < colCount ? 0 : i - colCount + 1,
              c = i < colCount ? i : colCount - 1;
          r < rowCount && c >= 0;
          r++, c--
        ) {
          yield (row: r, col: c, value: getUnchecked(r, c));
        }
      } else {
        // Walk up and right.
        for (
          var r = i < rowCount ? i : rowCount - 1,
              c = i < rowCount ? 0 : i - rowCount + 1;
          r >= 0 && c < colCount;
          r--, c++
        ) {
          yield (row: r, col: c, value: getUnchecked(r, c));
        }
      }
    }
  }
}
