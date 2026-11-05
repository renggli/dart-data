import '../../type/data_type.dart';
import '../matrix.dart';
import '../operator.dart';
import '../vector.dart';
import 'coo_matrix.dart';
import 'csr_matrix.dart';

/// Compressed Sparse Column (CSC) matrix.
///
/// Conceptually, CSC organizes non-zero sparse matrix entries column by column.
/// Mathematically, this represents a sparse matrix with compressed column
/// intervals $[\text{colPointers}_j, \text{colPointers}_{j+1})$ indexing row
/// numbers and values, providing optimal $O(\text{nnz})$ column slicing and
/// transposed SpMV performance.
///
/// ```dart
/// final csc = CscMatrix<double>(
///   rowCount: 2,
///   colCount: 2,
///   colPointers: [0, 1, 2],
///   rowIndices: [0, 1],
///   values: [1.0, 2.0],
///   type: DataType.float64,
/// );
/// ```
class CscMatrix<T> implements LinearOperator<T> {
  /// Creates a Compressed Sparse Column (CSC) matrix from column pointers, row
  /// indices, and values.
  new({
    required this.rowCount,
    required this.colCount,
    required this.colPointers,
    required this.rowIndices,
    required this.values,
    required this.type,
  }) {
    if (rowCount < 0 || colCount < 0) {
      throw ArgumentError(
        'Dimensions must be non-negative: ($rowCount x $colCount)',
      );
    }
    if (colPointers.length != colCount + 1) {
      throw ArgumentError(
        'colPointers length (${colPointers.length}) must be colCount + 1 (${colCount + 1}).',
      );
    }
    if (rowIndices.length != values.length) {
      throw ArgumentError(
        'rowIndices (${rowIndices.length}) and values (${values.length}) must have the same length.',
      );
    }
    if (colPointers.first != 0) {
      throw ArgumentError.value(
        colPointers.first,
        'colPointers[0]',
        'First col pointer must be 0.',
      );
    }
    if (colPointers.last != values.length) {
      throw ArgumentError.value(
        colPointers.last,
        'colPointers.last',
        'Last col pointer must equal values length (${values.length}).',
      );
    }
    for (var j = 0; j < colCount; j++) {
      final start = colPointers[j];
      final end = colPointers[j + 1];
      if (start > end) {
        throw ArgumentError(
          'colPointers must be non-decreasing: colPointers[$j] ($start) > colPointers[${j + 1}] ($end).',
        );
      }
      for (var p = start; p < end - 1; p++) {
        if (rowIndices[p] >= rowIndices[p + 1]) {
          throw ArgumentError(
            'rowIndices within column $j must be strictly increasing: '
            'rowIndices[$p] (${rowIndices[p]}) >= rowIndices[${p + 1}] (${rowIndices[p + 1]}).',
          );
        }
      }
    }
    for (var i = 0; i < rowIndices.length; i++) {
      final r = rowIndices[i];
      if (r < 0 || r >= rowCount) {
        throw RangeError.range(r, 0, rowCount - 1, 'rowIndices[$i]');
      }
    }
  }

  /// Constructs a CSC matrix from coordinate triplets.
  factory fromEntries(
    int rowCount,
    int colCount,
    Iterable<(int, int, T)> entries, {
    DataType<T>? type,
  }) => CooMatrix.fromEntries(rowCount, colCount, entries, type: type).toCsc();

  /// Constructs a CSC matrix from a dense [matrix].
  factory fromDense(Matrix<T> matrix) => CooMatrix.fromDense(matrix).toCsc();

  @override
  final int rowCount;

  @override
  final int colCount;

  @override
  final DataType<T> type;

  /// Index pointers into [rowIndices] and [values] for each column.
  final List<int> colPointers;

  /// Row index for each non-zero element.
  final List<int> rowIndices;

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
    final start = colPointers[col];
    final end = colPointers[col + 1];
    for (var ptr = start; ptr < end; ptr++) {
      if (rowIndices[ptr] == row) {
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
    for (var j = 0; j < colCount; j++) {
      final xj = x[j];
      final start = colPointers[j];
      final end = colPointers[j + 1];
      for (var ptr = start; ptr < end; ptr++) {
        final row = rowIndices[ptr];
        res[row] = field.add(res[row], field.mul(values[ptr], xj));
      }
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
    final xContig = x.tensor.isContiguous;
    final xData = x.tensor.data;
    final xOffset = x.tensor.offset;

    for (var j = 0; j < colCount; j++) {
      final start = colPointers[j];
      final end = colPointers[j + 1];
      var sum = field.additiveIdentity;
      if (xContig) {
        for (var ptr = start; ptr < end; ptr++) {
          sum = field.add(
            sum,
            field.mul(values[ptr], xData[xOffset + rowIndices[ptr]]),
          );
        }
      } else {
        for (var ptr = start; ptr < end; ptr++) {
          sum = field.add(sum, field.mul(values[ptr], x[rowIndices[ptr]]));
        }
      }
      res[j] = sum;
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
    final xContig = x.tensor.isContiguous;
    final xData = x.tensor.data;
    final xOffset = x.tensor.offset;

    for (var j = 0; j < colCount; j++) {
      final start = colPointers[j];
      final end = colPointers[j + 1];
      var sum = field.additiveIdentity;
      if (xContig) {
        for (var ptr = start; ptr < end; ptr++) {
          sum = field.add(
            sum,
            field.mul(
              field.conjugate(values[ptr]),
              xData[xOffset + rowIndices[ptr]],
            ),
          );
        }
      } else {
        for (var ptr = start; ptr < end; ptr++) {
          sum = field.add(
            sum,
            field.mul(field.conjugate(values[ptr]), x[rowIndices[ptr]]),
          );
        }
      }
      res[j] = sum;
    }
    return res;
  }

  @override
  LinearOperator<T> matmul(LinearOperator<T> other) => toCsr().matmul(other);

  /// Returns the transposed sparse matrix.
  CscMatrix<T> get transposed => toCoo().transposed.toCsc();

  /// Scales every element by [scalar].
  CscMatrix<T> scale(T scalar) {
    final field = type.field;
    final newValues = type.newList(values.length);
    for (var i = 0; i < values.length; i++) {
      newValues[i] = field.mul(values[i], scalar);
    }
    return CscMatrix(
      rowCount: rowCount,
      colCount: colCount,
      colPointers: List<int>.of(colPointers, growable: false),
      rowIndices: List<int>.of(rowIndices, growable: false),
      values: newValues,
      type: type,
    );
  }

  /// Adds [other] sparse matrix to this matrix.
  CscMatrix<T> operator +(CscMatrix<T> other) {
    if (rowCount != other.rowCount || colCount != other.colCount) {
      throw ArgumentError(
        'Matrix dimensions must agree: ($rowCount x $colCount) vs (${other.rowCount} x ${other.colCount})',
      );
    }
    final field = type.field;
    final equality = type.equality;
    final zero = field.additiveIdentity;
    final newColPointers = List<int>.filled(colCount + 1, 0);
    final newRows = <int>[];
    final newVals = <T>[];

    for (var c = 0; c < colCount; c++) {
      var p1 = colPointers[c];
      final end1 = colPointers[c + 1];
      var p2 = other.colPointers[c];
      final end2 = other.colPointers[c + 1];

      while (p1 < end1 && p2 < end2) {
        final r1 = rowIndices[p1];
        final r2 = other.rowIndices[p2];
        if (r1 < r2) {
          newRows.add(r1);
          newVals.add(values[p1]);
          p1++;
        } else if (r2 < r1) {
          newRows.add(r2);
          newVals.add(other.values[p2]);
          p2++;
        } else {
          final sum = field.add(values[p1], other.values[p2]);
          if (!equality.isEqual(sum, zero)) {
            newRows.add(r1);
            newVals.add(sum);
          }
          p1++;
          p2++;
        }
      }
      while (p1 < end1) {
        newRows.add(rowIndices[p1]);
        newVals.add(values[p1]);
        p1++;
      }
      while (p2 < end2) {
        newRows.add(other.rowIndices[p2]);
        newVals.add(other.values[p2]);
        p2++;
      }
      newColPointers[c + 1] = newRows.length;
    }

    final valList = type.newList(newVals.length);
    for (var i = 0; i < newVals.length; i++) {
      valList[i] = newVals[i];
    }

    return CscMatrix(
      rowCount: rowCount,
      colCount: colCount,
      colPointers: newColPointers,
      rowIndices: List<int>.of(newRows, growable: false),
      values: valList,
      type: type,
    );
  }

  /// Subtracts [other] sparse matrix from this matrix.
  CscMatrix<T> operator -(CscMatrix<T> other) {
    if (rowCount != other.rowCount || colCount != other.colCount) {
      throw ArgumentError(
        'Matrix dimensions must agree: ($rowCount x $colCount) vs (${other.rowCount} x ${other.colCount})',
      );
    }
    final field = type.field;
    final equality = type.equality;
    final zero = field.additiveIdentity;
    final newColPointers = List<int>.filled(colCount + 1, 0);
    final newRows = <int>[];
    final newVals = <T>[];

    for (var c = 0; c < colCount; c++) {
      var p1 = colPointers[c];
      final end1 = colPointers[c + 1];
      var p2 = other.colPointers[c];
      final end2 = other.colPointers[c + 1];

      while (p1 < end1 && p2 < end2) {
        final r1 = rowIndices[p1];
        final r2 = other.rowIndices[p2];
        if (r1 < r2) {
          newRows.add(r1);
          newVals.add(values[p1]);
          p1++;
        } else if (r2 < r1) {
          newRows.add(r2);
          newVals.add(field.neg(other.values[p2]));
          p2++;
        } else {
          final diff = field.sub(values[p1], other.values[p2]);
          if (!equality.isEqual(diff, zero)) {
            newRows.add(r1);
            newVals.add(diff);
          }
          p1++;
          p2++;
        }
      }
      while (p1 < end1) {
        newRows.add(rowIndices[p1]);
        newVals.add(values[p1]);
        p1++;
      }
      while (p2 < end2) {
        newRows.add(other.rowIndices[p2]);
        newVals.add(field.neg(other.values[p2]));
        p2++;
      }
      newColPointers[c + 1] = newRows.length;
    }

    final valList = type.newList(newVals.length);
    for (var i = 0; i < newVals.length; i++) {
      valList[i] = newVals[i];
    }

    return CscMatrix(
      rowCount: rowCount,
      colCount: colCount,
      colPointers: newColPointers,
      rowIndices: List<int>.of(newRows, growable: false),
      values: valList,
      type: type,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! CscMatrix ||
        rowCount != other.rowCount ||
        colCount != other.colCount) {
      return false;
    }
    if (nnz == other.nnz) {
      var exactMatch = true;
      for (var j = 0; j <= colCount; j++) {
        if (colPointers[j] != other.colPointers[j]) {
          exactMatch = false;
          break;
        }
      }
      if (exactMatch) {
        for (var i = 0; i < nnz; i++) {
          final otherVal = other.values[i];
          if (rowIndices[i] != other.rowIndices[i] ||
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
    for (var c = 0; c < colCount; c++) {
      var pA = colPointers[c];
      final endA = colPointers[c + 1];
      var pB = other.colPointers[c];
      final endB = other.colPointers[c + 1];

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

        final rowA = rowIndices[pA];
        final rowB = other.rowIndices[pB];
        if (rowA != rowB) return false;

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
    for (var c = 0; c < colCount; c++) {
      final start = colPointers[c];
      final end = colPointers[c + 1];
      for (var p = start; p < end; p++) {
        final val = values[p];
        if (!type.equality.isEqual(val, zero)) {
          hash = Object.hash(hash, rowIndices[p], c, type.equality.hash(val));
        }
      }
    }
    return hash;
  }

  @override
  String toString() => 'CscMatrix<$T>($rowCount x $colCount, nnz: $nnz)';

  /// Converts this CSC matrix to Coordinate (COO) format.
  CooMatrix<T> toCoo() {
    final rIdx = List<int>.filled(nnz, 0);
    final cIdx = List<int>.filled(nnz, 0);
    final vals = type.newList(nnz);

    var k = 0;
    for (var j = 0; j < colCount; j++) {
      final start = colPointers[j];
      final end = colPointers[j + 1];
      for (var ptr = start; ptr < end; ptr++) {
        rIdx[k] = rowIndices[ptr];
        cIdx[k] = j;
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

  /// Converts this CSC matrix to Compressed Sparse Row (CSR) format.
  CsrMatrix<T> toCsr() => toCoo().toCsr();

  /// Converts this CSC matrix to a dense [Matrix].
  Matrix<T> toDense() {
    final field = type.field;
    final res = Matrix<T>.filled(
      rowCount,
      colCount,
      field.additiveIdentity,
      type: type,
    );
    for (var j = 0; j < colCount; j++) {
      final start = colPointers[j];
      final end = colPointers[j + 1];
      for (var ptr = start; ptr < end; ptr++) {
        final r = rowIndices[ptr];
        res.set(r, j, field.add(res.get(r, j), values[ptr]));
      }
    }
    return res;
  }
}
