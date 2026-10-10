import '../../../type.dart';
import '../matrix.dart';
import '../operator.dart';
import '../vector.dart';
import 'coo_matrix.dart';
import 'csc_matrix.dart';

/// Compressed Sparse Row (CSR) matrix.
class CsrMatrix<T> implements LinearOperator<T> {
  new({
    required this.rowCount,
    required this.colCount,
    required this.rowPointers,
    required this.colIndices,
    required this.values,
    required this.type,
  }) : assert(rowPointers.length == rowCount + 1),
       assert(colIndices.length == values.length);

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

  /// Gets the element at [row, col], returning additive identity if zero.
  T get(int row, int col) {
    if (row < 0 || row >= rowCount || col < 0 || col >= colCount) {
      throw RangeError(
        'Coordinates ($row, $col) out of bounds for matrix ($rowCount x $colCount)',
      );
    }
    final start = rowPointers[row];
    final end = rowPointers[row + 1];
    for (var ptr = start; ptr < end; ptr++) {
      if (colIndices[ptr] == col) return values[ptr];
      if (colIndices[ptr] > col) break;
    }
    return type.field.additiveIdentity;
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
    final field = type.field;
    final res = Matrix<T>.filled(
      rowCount,
      other.colCount,
      field.additiveIdentity,
      type: type,
    );
    final eJ = Vector<T>.filled(
      other.colCount,
      field.additiveIdentity,
      type: type,
    );
    for (var j = 0; j < other.colCount; j++) {
      if (j > 0) eJ[j - 1] = field.additiveIdentity;
      eJ[j] = field.multiplicativeIdentity;
      final otherCol = other.apply(eJ);
      final thisCol = apply(otherCol);
      for (var i = 0; i < rowCount; i++) {
        res.set(i, j, thisCol[i]);
      }
    }
    return res;
  }

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
    final res = Matrix<T>.filled(
      rowCount,
      colCount,
      type.field.additiveIdentity,
      type: type,
    );
    for (var i = 0; i < rowCount; i++) {
      final start = rowPointers[i];
      final end = rowPointers[i + 1];
      for (var ptr = start; ptr < end; ptr++) {
        res.set(i, colIndices[ptr], values[ptr]);
      }
    }
    return res;
  }
}
