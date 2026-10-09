import '../../type/data_type.dart';
import '../matrix.dart';
import '../operator.dart';
import '../vector.dart';
import 'coo_matrix.dart';
import 'csr_matrix.dart';

/// Compressed Sparse Column (CSC) matrix.
class CscMatrix<T> implements LinearOperator<T> {
  new({
    required this.rowCount,
    required this.colCount,
    required this.colPointers,
    required this.rowIndices,
    required this.values,
    required this.type,
  }) : assert(colPointers.length == colCount + 1),
       assert(rowIndices.length == values.length);

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

  /// Gets the element at [row, col], returning additive identity if zero.
  T get(int row, int col) {
    if (row < 0 || row >= rowCount || col < 0 || col >= colCount) {
      throw RangeError(
        'Coordinates ($row, $col) out of bounds for matrix ($rowCount x $colCount)',
      );
    }
    final start = colPointers[col];
    final end = colPointers[col + 1];
    for (var p = start; p < end; p++) {
      if (rowIndices[p] == row) return values[p];
      if (rowIndices[p] > row) break;
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
    final f = type.field;
    final res = Vector<T>.filled(rowCount, f.additiveIdentity, type: type);
    for (var j = 0; j < colCount; j++) {
      final xj = x[j];
      final start = colPointers[j];
      final end = colPointers[j + 1];
      for (var p = start; p < end; p++) {
        final r = rowIndices[p];
        res[r] = f.add(res[r], f.mul(values[p], xj));
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
    final f = type.field;
    final res = Vector<T>.filled(colCount, f.additiveIdentity, type: type);
    final xContig = x.tensor.isContiguous;
    final xData = x.tensor.data;
    final xOffset = x.tensor.offset;

    for (var j = 0; j < colCount; j++) {
      final start = colPointers[j];
      final end = colPointers[j + 1];
      var sum = f.additiveIdentity;
      if (xContig) {
        for (var p = start; p < end; p++) {
          sum = f.add(
            sum,
            f.mul(f.conjugate(values[p]), xData[xOffset + rowIndices[p]]),
          );
        }
      } else {
        for (var p = start; p < end; p++) {
          sum = f.add(sum, f.mul(f.conjugate(values[p]), x[rowIndices[p]]));
        }
      }
      res[j] = sum;
    }
    return res;
  }

  @override
  LinearOperator<T> matmul(LinearOperator<T> other) => toCsr().matmul(other);

  /// Converts this CSC matrix to Coordinate (COO) format.
  CooMatrix<T> toCoo() {
    final rIdx = List<int>.filled(nnz, 0);
    final cIdx = List<int>.filled(nnz, 0);
    final vals = type.newList(nnz);

    var k = 0;
    for (var j = 0; j < colCount; j++) {
      final start = colPointers[j];
      final end = colPointers[j + 1];
      for (var p = start; p < end; p++) {
        rIdx[k] = rowIndices[p];
        cIdx[k] = j;
        vals[k] = values[p];
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
    final res = Matrix<T>.filled(
      rowCount,
      colCount,
      type.field.additiveIdentity,
      type: type,
    );
    for (var j = 0; j < colCount; j++) {
      final start = colPointers[j];
      final end = colPointers[j + 1];
      for (var p = start; p < end; p++) {
        res.set(rowIndices[p], j, values[p]);
      }
    }
    return res;
  }
}
