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
/// multiset of non-zero entries `{(i_k, j_k, v_k)}` allowing `O(1)` dynamic
/// appending.
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
    for (var i = 0; i < rowIndices.length; i++) {
      final r = rowIndices[i];
      final c = colIndices[i];
      if (r < 0 || r >= rowCount) {
        throw RangeError.range(r, 0, rowCount - 1, 'rowIndices[$i]');
      }
      if (c < 0 || c >= colCount) {
        throw RangeError.range(c, 0, colCount - 1, 'colIndices[$i]');
      }
    }
  }

  /// Constructs a COO matrix from coordinate triplets.
  factory fromEntries(
    int rowCount,
    int colCount,
    Iterable<(int, int, T)> entries, {
    DataType<T>? type,
  }) {
    if (rowCount < 0 || colCount < 0) {
      throw ArgumentError(
        'Dimensions must be non-negative: ($rowCount x $colCount)',
      );
    }
    final list = entries.toList(growable: false);
    final effectiveType =
        type ??
        (list.isEmpty
            ? DataType.fromType<T>()
            : DataType.fromIterable([for (final (_, _, v) in list) v]));
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
        final val = matrix.getUnchecked(row, col);
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
      res.setUnchecked(
        row,
        field.add(
          res.getUnchecked(row),
          field.mul(values[k], x.getUnchecked(col)),
        ),
      );
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
      res.setUnchecked(
        col,
        field.add(
          res.getUnchecked(col),
          field.mul(values[k], x.getUnchecked(row)),
        ),
      );
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
      res.setUnchecked(
        col,
        field.add(
          res.getUnchecked(col),
          field.mul(field.conjugate(values[k]), x.getUnchecked(row)),
        ),
      );
    }
    return res;
  }

  /// Returns the transposed sparse matrix.
  CooMatrix<T> get transposed => CooMatrix(
    rowCount: colCount,
    colCount: rowCount,
    rowIndices: List<int>.of(colIndices, growable: false),
    colIndices: List<int>.of(rowIndices, growable: false),
    values: type.copyList(values),
    type: type,
  );

  /// Returns the conjugate transpose (Hermitian adjoint) sparse matrix.
  CooMatrix<T> get conjugateTranspose {
    final field = type.field;
    final conjValues = type.newList(values.length);
    for (var i = 0; i < values.length; i++) {
      conjValues[i] = field.conjugate(values[i]);
    }
    return CooMatrix(
      rowCount: colCount,
      colCount: rowCount,
      rowIndices: List<int>.of(colIndices, growable: false),
      colIndices: List<int>.of(rowIndices, growable: false),
      values: conjValues,
      type: type,
    );
  }

  /// Scales every element by [scalar].
  CooMatrix<T> scale(T scalar) {
    final field = type.field;
    final equality = type.equality;
    final zero = field.additiveIdentity;
    final newRowIndices = <int>[];
    final newColIndices = <int>[];
    final newValuesList = <T>[];
    for (var i = 0; i < values.length; i++) {
      final scaled = field.mul(values[i], scalar);
      if (!equality.isEqual(scaled, zero)) {
        newRowIndices.add(rowIndices[i]);
        newColIndices.add(colIndices[i]);
        newValuesList.add(scaled);
      }
    }
    final newValues = type.newList(newValuesList.length);
    for (var i = 0; i < newValuesList.length; i++) {
      newValues[i] = newValuesList[i];
    }
    return CooMatrix(
      rowCount: rowCount,
      colCount: colCount,
      rowIndices: List<int>.of(newRowIndices, growable: false),
      colIndices: List<int>.of(newColIndices, growable: false),
      values: newValues,
      type: type,
    );
  }

  /// Adds [other] sparse matrix to this matrix.
  CooMatrix<T> operator +(CooMatrix<T> other) =>
      _combine(other, subtract: false);

  /// Subtracts [other] sparse matrix from this matrix.
  CooMatrix<T> operator -(CooMatrix<T> other) =>
      _combine(other, subtract: true);

  /// Unary matrix negation.
  CooMatrix<T> operator -() {
    final field = type.field;
    final negatedValues = type.newList(values.length);
    for (var i = 0; i < values.length; i++) {
      negatedValues[i] = field.neg(values[i]);
    }
    return CooMatrix(
      rowCount: rowCount,
      colCount: colCount,
      rowIndices: List<int>.of(rowIndices, growable: false),
      colIndices: List<int>.of(colIndices, growable: false),
      values: negatedValues,
      type: type,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! CooMatrix ||
        rowCount != other.rowCount ||
        colCount != other.colCount) {
      return false;
    }
    return toCsr() == other.toCsr();
  }

  @override
  int get hashCode => toCsr().hashCode;

  @override
  String toString() => 'CooMatrix<$T>($rowCount x $colCount, nnz: $nnz)';

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
    final equality = type.equality;
    final zero = field.additiveIdentity;
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
      if (!equality.isEqual(sum, zero)) {
        rowPointers[r + 1]++;
        coalescedCols.add(c);
        coalescedVals.add(sum);
      }
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
    final equality = type.equality;
    final zero = field.additiveIdentity;
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
      if (!equality.isEqual(sum, zero)) {
        colPointers[c + 1]++;
        coalescedRows.add(r);
        coalescedVals.add(sum);
      }
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
      res.setUnchecked(r, c, field.add(res.getUnchecked(r, c), values[k]));
    }
    return res;
  }

  CooMatrix<T> _combine(CooMatrix<T> other, {required bool subtract}) {
    if (rowCount != other.rowCount || colCount != other.colCount) {
      throw ArgumentError(
        'Matrix dimensions must agree: ($rowCount x $colCount) vs (${other.rowCount} x ${other.colCount})',
      );
    }
    final combinedVals = type.newList(nnz + other.nnz);
    for (var i = 0; i < nnz; i++) {
      combinedVals[i] = values[i];
    }
    if (subtract) {
      final field = type.field;
      for (var i = 0; i < other.nnz; i++) {
        combinedVals[nnz + i] = field.neg(other.values[i]);
      }
    } else {
      for (var i = 0; i < other.nnz; i++) {
        combinedVals[nnz + i] = other.values[i];
      }
    }
    return CooMatrix(
      rowCount: rowCount,
      colCount: colCount,
      rowIndices: [...rowIndices, ...other.rowIndices],
      colIndices: [...colIndices, ...other.colIndices],
      values: combinedVals,
      type: type,
    );
  }
}
