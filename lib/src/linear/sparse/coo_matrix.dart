import '../../type/data_type.dart';
import '../matrix.dart';
import '../operator.dart';
import '../vector.dart';
import 'csc_matrix.dart';
import 'csr_matrix.dart';

/// Coordinate format (COO) sparse matrix.
class CooMatrix<T> implements LinearOperator<T> {
  new({
    required this.rowCount,
    required this.colCount,
    required this.rowIndices,
    required this.colIndices,
    required this.values,
    required this.type,
  }) : assert(
         rowIndices.length == colIndices.length &&
             rowIndices.length == values.length,
       );

  /// Constructs a COO matrix from coordinate triplets.
  factory fromEntries(
    int rowCount,
    int colCount,
    Iterable<(int, int, T)> entries, {
    DataType<T>? type,
  }) {
    final list = entries.toList(growable: false);
    final effectiveType =
        type ??
        (list.isNotEmpty
            ? DataType.fromInstance(list.first.$3)
            : DataType.float64 as DataType<T>);
    final rowIndices = <int>[];
    final colIndices = <int>[];
    final values = <T>[];
    for (final (r, c, v) in list) {
      if (r < 0 || r >= rowCount || c < 0 || c >= colCount) {
        throw RangeError(
          'Coordinates ($r, $c) out of bounds for matrix ($rowCount x $colCount)',
        );
      }
      rowIndices.add(r);
      colIndices.add(c);
      values.add(v);
    }
    return CooMatrix(
      rowCount: rowCount,
      colCount: colCount,
      rowIndices: rowIndices,
      colIndices: colIndices,
      values: values,
      type: effectiveType,
    );
  }

  /// Constructs a COO matrix from a dense [matrix].
  factory fromDense(Matrix<T> matrix) {
    final type = matrix.type;
    final zero = type.field.additiveIdentity;
    final rowIndices = <int>[];
    final colIndices = <int>[];
    final values = <T>[];
    for (var r = 0; r < matrix.rowCount; r++) {
      for (var c = 0; c < matrix.colCount; c++) {
        final val = matrix.get(r, c);
        if (!type.equality.isEqual(val, zero)) {
          rowIndices.add(r);
          colIndices.add(c);
          values.add(val);
        }
      }
    }
    return CooMatrix(
      rowCount: matrix.rowCount,
      colCount: matrix.colCount,
      rowIndices: rowIndices,
      colIndices: colIndices,
      values: values,
      type: type,
    );
  }

  @override
  final int rowCount;

  @override
  final int colCount;

  @override
  final DataType<T> type;

  /// Row coordinate list.
  final List<int> rowIndices;

  /// Column coordinate list.
  final List<int> colIndices;

  /// Non-zero entry values.
  final List<T> values;

  /// Number of stored non-zero entries.
  int get nnz => values.length;

  @override
  Vector<T> apply(Vector<T> x) {
    if (colCount != x.length) {
      throw ArgumentError(
        'Vector length (${x.length}) must match colCount ($colCount)',
      );
    }
    final f = type.field;
    final res = Vector<T>.filled(rowCount, f.additiveIdentity, type: type);
    for (var k = 0; k < nnz; k++) {
      final r = rowIndices[k];
      final c = colIndices[k];
      final v = values[k];
      res[r] = f.add(res[r], f.mul(v, x[c]));
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
    for (var k = 0; k < nnz; k++) {
      final r = rowIndices[k];
      final c = colIndices[k];
      final v = values[k];
      res[c] = f.add(res[c], f.mul(f.conjugate(v), x[r]));
    }
    return res;
  }

  @override
  LinearOperator<T> matmul(LinearOperator<T> other) => toCsr().matmul(other);

  /// Converts this COO matrix to Compressed Sparse Row (CSR) format.
  CsrMatrix<T> toCsr() {
    final order = List<int>.generate(nnz, (i) => i);
    order.sort((a, b) {
      final cmp = rowIndices[a].compareTo(rowIndices[b]);
      return cmp != 0 ? cmp : colIndices[a].compareTo(colIndices[b]);
    });

    final rowPointers = List<int>.filled(rowCount + 1, 0);
    final csrColIndices = List<int>.filled(nnz, 0);
    final csrValues = type.newList(nnz);

    for (var k = 0; k < nnz; k++) {
      final idx = order[k];
      rowPointers[rowIndices[idx] + 1]++;
      csrColIndices[k] = colIndices[idx];
      csrValues[k] = values[idx];
    }
    for (var i = 0; i < rowCount; i++) {
      rowPointers[i + 1] += rowPointers[i];
    }

    return CsrMatrix(
      rowCount: rowCount,
      colCount: colCount,
      rowPointers: rowPointers,
      colIndices: csrColIndices,
      values: csrValues,
      type: type,
    );
  }

  /// Converts this COO matrix to Compressed Sparse Column (CSC) format.
  CscMatrix<T> toCsc() {
    final order = List<int>.generate(nnz, (i) => i);
    order.sort((a, b) {
      final cmp = colIndices[a].compareTo(colIndices[b]);
      return cmp != 0 ? cmp : rowIndices[a].compareTo(rowIndices[b]);
    });

    final colPointers = List<int>.filled(colCount + 1, 0);
    final cscRowIndices = List<int>.filled(nnz, 0);
    final cscValues = type.newList(nnz);

    for (var k = 0; k < nnz; k++) {
      final idx = order[k];
      colPointers[colIndices[idx] + 1]++;
      cscRowIndices[k] = rowIndices[idx];
      cscValues[k] = values[idx];
    }
    for (var j = 0; j < colCount; j++) {
      colPointers[j + 1] += colPointers[j];
    }

    return CscMatrix(
      rowCount: rowCount,
      colCount: colCount,
      colPointers: colPointers,
      rowIndices: cscRowIndices,
      values: cscValues,
      type: type,
    );
  }

  /// Converts this COO matrix to a dense [Matrix].
  Matrix<T> toDense() {
    final res = Matrix<T>.filled(
      rowCount,
      colCount,
      type.field.additiveIdentity,
      type: type,
    );
    for (var k = 0; k < nnz; k++) {
      res.set(rowIndices[k], colIndices[k], values[k]);
    }
    return res;
  }
}
