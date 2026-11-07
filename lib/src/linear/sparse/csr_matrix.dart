import '../../type/data_type.dart';
import '../matrix.dart';
import '../operator.dart';
import '../vector.dart';
import 'coo_matrix.dart';
import 'csc_matrix.dart';

/// Compressed Sparse Row (CSR) matrix.
///
/// Conceptually, CSR organizes non-zero sparse matrix entries row by row so
/// that matrix-vector multiplication is fast and memory-efficient.
/// Mathematically, this represents a sparse matrix with compressed row
/// intervals $[\text{rowPointers}_i, \text{rowPointers}_{i+1})$ indexing column
/// numbers and values, providing optimal $O(\text{nnz})$ row slicing and SpMV
/// performance.
///
/// ```dart
/// final csr = CsrMatrix<double>(
///   rowCount: 2,
///   colCount: 2,
///   rowPointers: [0, 1, 2],
///   colIndices: [0, 1],
///   values: [1.0, 2.0],
///   type: DataType.float64,
/// );
/// ```
class CsrMatrix<T> implements LinearOperator<T> {
  /// Creates a Compressed Sparse Row (CSR) matrix from row pointers, column
  /// indices, and values.
  new({
    required this.rowCount,
    required this.colCount,
    required this.rowPointers,
    required this.colIndices,
    required this.values,
    required this.type,
  }) {
    if (rowCount < 0 || colCount < 0) {
      throw ArgumentError(
        'Dimensions must be non-negative: ($rowCount x $colCount)',
      );
    }
    if (rowPointers.length != rowCount + 1) {
      throw ArgumentError(
        'rowPointers length (${rowPointers.length}) must be rowCount + 1 (${rowCount + 1}).',
      );
    }
    if (colIndices.length != values.length) {
      throw ArgumentError(
        'colIndices (${colIndices.length}) and values (${values.length}) must have the same length.',
      );
    }
    if (rowPointers.first != 0) {
      throw ArgumentError.value(
        rowPointers.first,
        'rowPointers[0]',
        'First row pointer must be 0.',
      );
    }
    if (rowPointers.last != values.length) {
      throw ArgumentError.value(
        rowPointers.last,
        'rowPointers.last',
        'Last row pointer must equal values length (${values.length}).',
      );
    }
    for (var i = 0; i < rowCount; i++) {
      final start = rowPointers[i];
      final end = rowPointers[i + 1];
      if (start > end) {
        throw ArgumentError(
          'rowPointers must be non-decreasing: rowPointers[$i] ($start) > rowPointers[${i + 1}] ($end).',
        );
      }
      for (var p = start; p < end - 1; p++) {
        if (colIndices[p] >= colIndices[p + 1]) {
          throw ArgumentError(
            'colIndices within row $i must be strictly increasing: '
            'colIndices[$p] (${colIndices[p]}) >= colIndices[${p + 1}] (${colIndices[p + 1]}).',
          );
        }
      }
    }
    for (var i = 0; i < colIndices.length; i++) {
      final c = colIndices[i];
      if (c < 0 || c >= colCount) {
        throw RangeError.range(c, 0, colCount - 1, 'colIndices[$i]');
      }
    }
  }

  /// Constructs a CSR matrix from coordinate triplets.
  factory fromEntries(
    int rowCount,
    int colCount,
    Iterable<(int, int, T)> entries, {
    DataType<T>? type,
  }) => CooMatrix.fromEntries(rowCount, colCount, entries, type: type).toCsr();

  /// Constructs a CSR matrix from a dense [matrix].
  factory fromDense(Matrix<T> matrix) => CooMatrix.fromDense(matrix).toCsr();

  @override
  final int rowCount;

  @override
  final int colCount;

  @override
  final DataType<T> type;

  /// Index pointers into [colIndices] and [values] for each row.
  final List<int> rowPointers;

  /// Column index for each non-zero element.
  final List<int> colIndices;

  /// Non-zero entry values.
  final List<T> values;

  /// Number of stored non-zero elements.
  int get nnz => values.length;

  /// Gets the element at ([row], [col]), returning additive identity if zero.
  T get(int row, int col) {
    if (row < 0 || row >= rowCount || col < 0 || col >= colCount) {
      throw RangeError(
        'Coordinates ($row, $col) out of bounds for matrix ($rowCount x $colCount)',
      );
    }
    final field = type.field;
    var sum = field.additiveIdentity;
    final start = rowPointers[row];
    final end = rowPointers[row + 1];
    for (var ptr = start; ptr < end; ptr++) {
      if (colIndices[ptr] == col) {
        sum = field.add(sum, values[ptr]);
      }
    }
    return sum;
  }

  @override
  Vector<T> apply(Vector<T> x) {
    if (colCount != x.length) {
      throw ArgumentError(
        'Vector length (${x.length}) must match colCount ($colCount)',
      );
    }
    final field = type.field;
    final res = Vector<T>.filled(rowCount, field.additiveIdentity, type: type);
    final xContig = x.tensor.isContiguous;
    final xData = x.tensor.data;
    final xOffset = x.tensor.offset;

    for (var i = 0; i < rowCount; i++) {
      final start = rowPointers[i];
      final end = rowPointers[i + 1];
      var sum = field.additiveIdentity;
      if (xContig) {
        for (var ptr = start; ptr < end; ptr++) {
          sum = field.add(
            sum,
            field.mul(values[ptr], xData[xOffset + colIndices[ptr]]),
          );
        }
      } else {
        for (var ptr = start; ptr < end; ptr++) {
          sum = field.add(sum, field.mul(values[ptr], x[colIndices[ptr]]));
        }
      }
      res[i] = sum;
    }
    return res;
  }

  @override
  Vector<T> applyTranspose(Vector<T> x) {
    if (rowCount != x.length) {
      throw ArgumentError(
        'Vector length (${x.length}) must match rowCount ($rowCount)',
      );
    }
    final field = type.field;
    final res = Vector<T>.filled(colCount, field.additiveIdentity, type: type);
    for (var i = 0; i < rowCount; i++) {
      final xi = x[i];
      final start = rowPointers[i];
      final end = rowPointers[i + 1];
      for (var ptr = start; ptr < end; ptr++) {
        final col = colIndices[ptr];
        res[col] = field.add(res[col], field.mul(values[ptr], xi));
      }
    }
    return res;
  }

  @override
  Vector<T> applyConjugateTranspose(Vector<T> x) {
    if (rowCount != x.length) {
      throw ArgumentError(
        'Vector length (${x.length}) must match rowCount ($rowCount)',
      );
    }
    final field = type.field;
    final res = Vector<T>.filled(colCount, field.additiveIdentity, type: type);
    for (var i = 0; i < rowCount; i++) {
      final xi = x[i];
      final start = rowPointers[i];
      final end = rowPointers[i + 1];
      for (var ptr = start; ptr < end; ptr++) {
        final col = colIndices[ptr];
        res[col] = field.add(
          res[col],
          field.mul(field.conjugate(values[ptr]), xi),
        );
      }
    }
    return res;
  }

  @override
  LinearOperator<T> matmul(LinearOperator<T> other) {
    if (colCount != other.rowCount) {
      throw ArgumentError(
        'Dimension mismatch: CsrMatrix ($rowCount x $colCount) * Operator (${other.rowCount} x ${other.colCount})',
      );
    }
    if (other is CsrMatrix<T>) {
      return _matmulSparse(other);
    } else if (other is CooMatrix<T>) {
      return _matmulSparse(other.toCsr());
    } else if (other is CscMatrix<T>) {
      return _matmulSparse(other.toCsr());
    } else if (other is Matrix<T>) {
      return _matmulDense(other);
    } else {
      return _matmulOperator(other);
    }
  }

  /// Returns the transposed sparse matrix.
  CsrMatrix<T> get transposed => toCoo().transposed.toCsr();

  /// Scales every element by [scalar].
  CsrMatrix<T> scale(T scalar) {
    final field = type.field;
    final equality = type.equality;
    final zero = field.additiveIdentity;
    if (equality.isEqual(scalar, zero)) {
      return CsrMatrix(
        rowCount: rowCount,
        colCount: colCount,
        rowPointers: List<int>.filled(rowCount + 1, 0),
        colIndices: const [],
        values: type.newList(0),
        type: type,
      );
    }
    final newRowPointers = List<int>.filled(rowCount + 1, 0);
    final newColIndices = <int>[];
    final newValuesList = <T>[];
    for (var r = 0; r < rowCount; r++) {
      newRowPointers[r] = newValuesList.length;
      final start = rowPointers[r];
      final end = rowPointers[r + 1];
      for (var i = start; i < end; i++) {
        final scaled = field.mul(values[i], scalar);
        if (!equality.isEqual(scaled, zero)) {
          newColIndices.add(colIndices[i]);
          newValuesList.add(scaled);
        }
      }
    }
    newRowPointers[rowCount] = newValuesList.length;
    final newValues = type.newList(newValuesList.length);
    for (var i = 0; i < newValuesList.length; i++) {
      newValues[i] = newValuesList[i];
    }
    return CsrMatrix(
      rowCount: rowCount,
      colCount: colCount,
      rowPointers: newRowPointers,
      colIndices: newColIndices,
      values: newValues,
      type: type,
    );
  }

  /// Adds [other] sparse matrix to this matrix.
  CsrMatrix<T> operator +(CsrMatrix<T> other) {
    if (rowCount != other.rowCount || colCount != other.colCount) {
      throw ArgumentError(
        'Matrix dimensions must agree: ($rowCount x $colCount) vs (${other.rowCount} x ${other.colCount})',
      );
    }
    final field = type.field;
    final equality = type.equality;
    final zero = field.additiveIdentity;
    final newRowPointers = List<int>.filled(rowCount + 1, 0);
    final newCols = <int>[];
    final newVals = <T>[];

    for (var r = 0; r < rowCount; r++) {
      var p1 = rowPointers[r];
      final end1 = rowPointers[r + 1];
      var p2 = other.rowPointers[r];
      final end2 = other.rowPointers[r + 1];

      while (p1 < end1 && p2 < end2) {
        final c1 = colIndices[p1];
        final c2 = other.colIndices[p2];
        if (c1 < c2) {
          newCols.add(c1);
          newVals.add(values[p1]);
          p1++;
        } else if (c2 < c1) {
          newCols.add(c2);
          newVals.add(other.values[p2]);
          p2++;
        } else {
          final sum = field.add(values[p1], other.values[p2]);
          if (!equality.isEqual(sum, zero)) {
            newCols.add(c1);
            newVals.add(sum);
          }
          p1++;
          p2++;
        }
      }
      while (p1 < end1) {
        newCols.add(colIndices[p1]);
        newVals.add(values[p1]);
        p1++;
      }
      while (p2 < end2) {
        newCols.add(other.colIndices[p2]);
        newVals.add(other.values[p2]);
        p2++;
      }
      newRowPointers[r + 1] = newCols.length;
    }

    final valList = type.newList(newVals.length);
    for (var i = 0; i < newVals.length; i++) {
      valList[i] = newVals[i];
    }

    return CsrMatrix(
      rowCount: rowCount,
      colCount: colCount,
      rowPointers: newRowPointers,
      colIndices: List<int>.of(newCols, growable: false),
      values: valList,
      type: type,
    );
  }

  /// Subtracts [other] sparse matrix from this matrix.
  CsrMatrix<T> operator -(CsrMatrix<T> other) {
    if (rowCount != other.rowCount || colCount != other.colCount) {
      throw ArgumentError(
        'Matrix dimensions must agree: ($rowCount x $colCount) vs (${other.rowCount} x ${other.colCount})',
      );
    }
    final field = type.field;
    final equality = type.equality;
    final zero = field.additiveIdentity;
    final newRowPointers = List<int>.filled(rowCount + 1, 0);
    final newCols = <int>[];
    final newVals = <T>[];

    for (var r = 0; r < rowCount; r++) {
      var p1 = rowPointers[r];
      final end1 = rowPointers[r + 1];
      var p2 = other.rowPointers[r];
      final end2 = other.rowPointers[r + 1];

      while (p1 < end1 && p2 < end2) {
        final c1 = colIndices[p1];
        final c2 = other.colIndices[p2];
        if (c1 < c2) {
          newCols.add(c1);
          newVals.add(values[p1]);
          p1++;
        } else if (c2 < c1) {
          newCols.add(c2);
          newVals.add(field.neg(other.values[p2]));
          p2++;
        } else {
          final diff = field.sub(values[p1], other.values[p2]);
          if (!equality.isEqual(diff, zero)) {
            newCols.add(c1);
            newVals.add(diff);
          }
          p1++;
          p2++;
        }
      }
      while (p1 < end1) {
        newCols.add(colIndices[p1]);
        newVals.add(values[p1]);
        p1++;
      }
      while (p2 < end2) {
        newCols.add(other.colIndices[p2]);
        newVals.add(field.neg(other.values[p2]));
        p2++;
      }
      newRowPointers[r + 1] = newCols.length;
    }

    final valList = type.newList(newVals.length);
    for (var i = 0; i < newVals.length; i++) {
      valList[i] = newVals[i];
    }

    return CsrMatrix(
      rowCount: rowCount,
      colCount: colCount,
      rowPointers: newRowPointers,
      colIndices: List<int>.of(newCols, growable: false),
      values: valList,
      type: type,
    );
  }

  /// Unary matrix negation.
  CsrMatrix<T> operator -() {
    final field = type.field;
    final negatedValues = type.newList(values.length);
    for (var i = 0; i < values.length; i++) {
      negatedValues[i] = field.neg(values[i]);
    }
    return CsrMatrix(
      rowCount: rowCount,
      colCount: colCount,
      rowPointers: List<int>.of(rowPointers, growable: false),
      colIndices: List<int>.of(colIndices, growable: false),
      values: negatedValues,
      type: type,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! CsrMatrix ||
        rowCount != other.rowCount ||
        colCount != other.colCount) {
      return false;
    }
    if (nnz == other.nnz) {
      var exactMatch = true;
      for (var i = 0; i <= rowCount; i++) {
        if (rowPointers[i] != other.rowPointers[i]) {
          exactMatch = false;
          break;
        }
      }
      if (exactMatch) {
        for (var i = 0; i < nnz; i++) {
          final otherVal = other.values[i];
          if (colIndices[i] != other.colIndices[i] ||
              otherVal is! T ||
              !type.equality.isEqual(values[i], otherVal)) {
            exactMatch = false;
            break;
          }
        }
        if (exactMatch) return true;
      }
    }

    final zero = type.field.additiveIdentity;
    for (var r = 0; r < rowCount; r++) {
      var pA = rowPointers[r];
      final endA = rowPointers[r + 1];
      var pB = other.rowPointers[r];
      final endB = other.rowPointers[r + 1];

      while (pA < endA || pB < endB) {
        while (pA < endA && type.equality.isEqual(values[pA], zero)) {
          pA++;
        }
        while (pB < endB &&
            (other.values[pB] is! T ||
                type.equality.isEqual(other.values[pB] as T, zero))) {
          pB++;
        }
        if (pA >= endA && pB >= endB) break;
        if (pA >= endA || pB >= endB) return false;

        final colA = colIndices[pA];
        final colB = other.colIndices[pB];
        if (colA != colB) return false;

        final valB = other.values[pB];
        if (valB is! T || !type.equality.isEqual(values[pA], valB)) {
          return false;
        }
        pA++;
        pB++;
      }
    }
    return true;
  }

  @override
  int get hashCode {
    final zero = type.field.additiveIdentity;
    var hash = Object.hash(rowCount, colCount);
    for (var r = 0; r < rowCount; r++) {
      final start = rowPointers[r];
      final end = rowPointers[r + 1];
      for (var p = start; p < end; p++) {
        final val = values[p];
        if (!type.equality.isEqual(val, zero)) {
          hash = Object.hash(hash, r, colIndices[p], type.equality.hash(val));
        }
      }
    }
    return hash;
  }

  @override
  String toString() => 'CsrMatrix<$T>($rowCount x $colCount, nnz: $nnz)';

  /// Converts this CSR matrix to Coordinate (COO) format.
  CooMatrix<T> toCoo() {
    final rIdx = List<int>.filled(nnz, 0);
    final cIdx = List<int>.filled(nnz, 0);
    final vals = type.newList(nnz);

    var k = 0;
    for (var i = 0; i < rowCount; i++) {
      final start = rowPointers[i];
      final end = rowPointers[i + 1];
      for (var ptr = start; ptr < end; ptr++) {
        rIdx[k] = i;
        cIdx[k] = colIndices[ptr];
        vals[k] = values[ptr];
        k++;
      }
    }

    return CooMatrix(
      rowCount: rowCount,
      colCount: colCount,
      rowIndices: rIdx,
      colIndices: cIdx,
      values: vals,
      type: type,
    );
  }

  /// Converts this CSR matrix to Compressed Sparse Column (CSC) format.
  CscMatrix<T> toCsc() => toCoo().toCsc();

  /// Converts this CSR matrix to a dense [Matrix].
  Matrix<T> toDense() {
    final field = type.field;
    final res = Matrix<T>.filled(
      rowCount,
      colCount,
      field.additiveIdentity,
      type: type,
    );
    for (var i = 0; i < rowCount; i++) {
      final start = rowPointers[i];
      final end = rowPointers[i + 1];
      for (var ptr = start; ptr < end; ptr++) {
        final c = colIndices[ptr];
        res.set(i, c, field.add(res.get(i, c), values[ptr]));
      }
    }
    return res;
  }

  CsrMatrix<T> _matmulSparse(CsrMatrix<T> other) {
    final field = type.field;
    final m = rowCount;
    final n = other.colCount;

    final cRowPointers = List<int>.filled(m + 1, 0);
    final cColIndices = <int>[];
    final cValuesList = <T>[];

    final marker = List<int>.filled(n, -1);
    final x = type.newList(n, fillValue: field.additiveIdentity);
    final rowCols = <int>[];

    for (var i = 0; i < m; i++) {
      final aStart = rowPointers[i];
      final aEnd = rowPointers[i + 1];

      for (var aPtr = aStart; aPtr < aEnd; aPtr++) {
        final aVal = values[aPtr];
        final k = colIndices[aPtr];

        final bStart = other.rowPointers[k];
        final bEnd = other.rowPointers[k + 1];

        for (var bPtr = bStart; bPtr < bEnd; bPtr++) {
          final col = other.colIndices[bPtr];
          final bVal = other.values[bPtr];
          final prod = field.mul(aVal, bVal);

          if (marker[col] != i) {
            marker[col] = i;
            x[col] = prod;
            rowCols.add(col);
          } else {
            x[col] = field.add(x[col], prod);
          }
        }
      }

      if (rowCols.isNotEmpty) {
        rowCols.sort();
        for (var cIdx = 0; cIdx < rowCols.length; cIdx++) {
          final c = rowCols[cIdx];
          final val = x[c];
          if (!type.equality.isEqual(val, field.additiveIdentity)) {
            cColIndices.add(c);
            cValuesList.add(val);
          }
        }
        rowCols.clear();
      }
      cRowPointers[i + 1] = cColIndices.length;
    }

    final cValues = type.newList(cValuesList.length);
    for (var i = 0; i < cValuesList.length; i++) {
      cValues[i] = cValuesList[i];
    }

    return CsrMatrix<T>(
      rowCount: m,
      colCount: n,
      rowPointers: cRowPointers,
      colIndices: cColIndices,
      values: cValues,
      type: type,
    );
  }

  Matrix<T> _matmulDense(Matrix<T> other) {
    final field = type.field;
    final m = rowCount;
    final n = other.colCount;

    final res = Matrix<T>.filled(m, n, field.additiveIdentity, type: type);

    for (var i = 0; i < m; i++) {
      final start = rowPointers[i];
      final end = rowPointers[i + 1];
      for (var ptr = start; ptr < end; ptr++) {
        final aVal = values[ptr];
        final k = colIndices[ptr];

        for (var j = 0; j < n; j++) {
          final prod = field.mul(aVal, other.getUnchecked(k, j));
          res.setUnchecked(i, j, field.add(res.getUnchecked(i, j), prod));
        }
      }
    }
    return res;
  }

  Matrix<T> _matmulOperator(LinearOperator<T> other) {
    final field = type.field;
    final m = rowCount;
    final n = other.colCount;

    final res = Matrix<T>.filled(m, n, field.additiveIdentity, type: type);
    final eJ = Vector<T>.filled(n, field.additiveIdentity, type: type);
    for (var j = 0; j < n; j++) {
      if (j > 0) eJ[j - 1] = field.additiveIdentity;
      eJ[j] = field.multiplicativeIdentity;
      final otherCol = other.apply(eJ);
      final thisCol = apply(otherCol);
      for (var i = 0; i < m; i++) {
        res.setUnchecked(i, j, thisCol[i]);
      }
    }
    return res;
  }
}
