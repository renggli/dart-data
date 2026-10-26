import '../../type/data_type.dart';
import '../matrix.dart';
import '../operator.dart';
import '../vector.dart';
import 'csc_matrix.dart';
import 'csr_matrix.dart';

/// Coordinate format (COO) sparse matrix.
///
/// Conceptually, a sparse matrix only stores non-zero entries by recording each
/// entry's row index, column index, and value. Mathematically, this stores the
/// multiset of non-zero entries $\{ (i_k, j_k, v_k) \}_{k=0}^{N-1}$ allowing
/// $O(1)$ dynamic appending.
///
/// ```dart
/// final coo = CooMatrix<double>(
///   rowCount: 3,
///   colCount: 3,
///   rowIndices: [0, 1, 2],
///   colIndices: [0, 1, 2],
///   values: [1.0, 2.0, 3.0],
///   type: DataType.float64,
/// );
/// ```
class CooMatrix<T> implements LinearOperator<T> {
  /// Creates a Coordinate format (COO) sparse matrix from explicit index and
  /// value buffers.
  new({
    required this.rowCount,
    required this.colCount,
    required this.rowIndices,
    required this.colIndices,
    required this.values,
    required this.type,
  }) {
    if (rowCount < 0 || colCount < 0) {
      throw ArgumentError(
        'Dimensions must be non-negative: ($rowCount x $colCount)',
      );
    }
    if (rowIndices.length != colIndices.length ||
        rowIndices.length != values.length) {
      throw ArgumentError(
        'rowIndices (${rowIndices.length}), colIndices (${colIndices.length}), and values (${values.length}) must have the same length.',
      );
    }
  }

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
        (switch (list) {
          [(_, _, final firstVal), ...] => DataType.fromInstance(firstVal),
          _ => DataType.fromType<T>(),
        });
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
    for (var row = 0; row < matrix.rowCount; row++) {
      for (var col = 0; col < matrix.colCount; col++) {
        final val = matrix.get(row, col);
        if (!type.equality.isEqual(val, zero)) {
          rowIndices.add(row);
          colIndices.add(col);
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

  /// Gets the element at ([row], [col]), returning additive identity if zero.
  T get(int row, int col) {
    if (row < 0 || row >= rowCount || col < 0 || col >= colCount) {
      throw RangeError(
        'Coordinates ($row, $col) out of bounds for matrix ($rowCount x $colCount)',
      );
    }
    final field = type.field;
    var sum = field.additiveIdentity;
    for (var k = 0; k < nnz; k++) {
      if (rowIndices[k] == row && colIndices[k] == col) {
        sum = field.add(sum, values[k]);
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
    for (var k = 0; k < nnz; k++) {
      final row = rowIndices[k];
      final col = colIndices[k];
      final val = values[k];
      res[row] = field.add(res[row], field.mul(val, x[col]));
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
    for (var k = 0; k < nnz; k++) {
      final row = rowIndices[k];
      final col = colIndices[k];
      final val = values[k];
      res[col] = field.add(res[col], field.mul(val, x[row]));
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
    for (var k = 0; k < nnz; k++) {
      final row = rowIndices[k];
      final col = colIndices[k];
      final val = values[k];
      res[col] = field.add(res[col], field.mul(field.conjugate(val), x[row]));
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

    final field = type.field;
    final rowPointers = List<int>.filled(rowCount + 1, 0);
    final coalescedCols = <int>[];
    final coalescedVals = <T>[];

    var k = 0;
    while (k < nnz) {
      final idx = order[k];
      final r = rowIndices[idx];
      final c = colIndices[idx];
      var sum = values[idx];
      k++;
      while (k < nnz) {
        final nextIdx = order[k];
        if (rowIndices[nextIdx] != r || colIndices[nextIdx] != c) break;
        sum = field.add(sum, values[nextIdx]);
        k++;
      }
      rowPointers[r + 1]++;
      coalescedCols.add(c);
      coalescedVals.add(sum);
    }
    for (var i = 0; i < rowCount; i++) {
      rowPointers[i + 1] += rowPointers[i];
    }

    final csrValues = type.newList(coalescedVals.length);
    for (var i = 0; i < coalescedVals.length; i++) {
      csrValues[i] = coalescedVals[i];
    }

    return CsrMatrix(
      rowCount: rowCount,
      colCount: colCount,
      rowPointers: rowPointers,
      colIndices: List<int>.of(coalescedCols, growable: false),
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

    final field = type.field;
    final colPointers = List<int>.filled(colCount + 1, 0);
    final coalescedRows = <int>[];
    final coalescedVals = <T>[];

    var k = 0;
    while (k < nnz) {
      final idx = order[k];
      final r = rowIndices[idx];
      final c = colIndices[idx];
      var sum = values[idx];
      k++;
      while (k < nnz) {
        final nextIdx = order[k];
        if (colIndices[nextIdx] != c || rowIndices[nextIdx] != r) break;
        sum = field.add(sum, values[nextIdx]);
        k++;
      }
      colPointers[c + 1]++;
      coalescedRows.add(r);
      coalescedVals.add(sum);
    }
    for (var j = 0; j < colCount; j++) {
      colPointers[j + 1] += colPointers[j];
    }

    final cscValues = type.newList(coalescedVals.length);
    for (var i = 0; i < coalescedVals.length; i++) {
      cscValues[i] = coalescedVals[i];
    }

    return CscMatrix(
      rowCount: rowCount,
      colCount: colCount,
      colPointers: colPointers,
      rowIndices: List<int>.of(coalescedRows, growable: false),
      values: cscValues,
      type: type,
    );
  }

  /// Converts this COO matrix to a dense [Matrix].
  Matrix<T> toDense() {
    final field = type.field;
    final res = Matrix<T>.filled(
      rowCount,
      colCount,
      field.additiveIdentity,
      type: type,
    );
    for (var k = 0; k < nnz; k++) {
      final r = rowIndices[k];
      final c = colIndices[k];
      res.set(r, c, field.add(res.get(r, c), values[k]));
    }
    return res;
  }
}
