library data.matrix.operator.iterator;

import '../matrix.dart';

extension IteratorExtension<T> on Matrix<T> {
  /// Returns an iterable over the values of this [Matrix] in row-by-row.
  Iterable<T> get rowMajor sync* {
    for (var r = 0; r < rowCount; r++) {
      for (var c = 0; c < colCount; c++) {
        yield getUnchecked(r, c);
      }
    }
  }

  /// Returns an iterable over the values of this [Matrix] in column-by-column.
  Iterable<T> get columnMajor sync* {
    for (var c = 0; c < colCount; c++) {
      for (var r = 0; r < rowCount; r++) {
        yield getUnchecked(r, c);
      }
    }
  }

  /// Returns an iterable that walks clockwise over the [Matrix] starting in the
  /// upper left corner.
  Iterable<T> get spiral sync* {
    var k = 0, l = 0;
    var m = rowCount, n = colCount;
    while (k < m && l < n) {
      // First row from the remaining rows:
      for (var i = l; i < n; i++) {
        yield getUnchecked(k, i);
      }
      k++;
      // Last column from the remaining columns:
      for (var i = k; i < m; i++) {
        yield getUnchecked(i, n - 1);
      }
      n--;
      // Last row from the remaining rows:
      if (k < m) {
        for (var i = n - 1; i >= l; i--) {
          yield getUnchecked(m - 1, i);
        }
        m--;
      }
      // First column from the remaining columns:
      if (l < n) {
        for (var i = m - 1; i >= k; i--) {
          yield getUnchecked(i, l);
        }
        l++;
      }
    }
  }
}
