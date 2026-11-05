import 'dart:math' as math;
import 'dart:typed_data';

import 'package:more/number.dart' show Complex;

import '../../acceleration/lapack/lapack.dart';
import '../../tensor/layout.dart';
import '../../tensor/tensor.dart';
import '../../type/data_type.dart';
import '../decomposition/lu.dart';
import '../decomposition/qr.dart';
import '../matrix.dart';

/// Solves the linear system $A X = B$ or linear least-squares problem
/// $A X \approx B$ for matrix right-hand side [b] using direct methods.
Matrix<T> solveDirect<T>(Matrix<T> a, Matrix<T> b) {
  if (b.rowCount != a.rowCount) {
    throw ArgumentError(
      'Dimension mismatch: Matrix ${a.rowCount} x ${a.colCount}, Matrix RHS ${b.rowCount} x ${b.colCount}',
    );
  }
  final rowCount = a.rowCount;
  final colCount = a.colCount;
  final nrhs = b.colCount;
  final type = a.type;

  if (rowCount == 0 || nrhs == 0) {
    return Matrix<T>.filled(
      colCount,
      nrhs,
      type.field.additiveIdentity,
      type: type,
    );
  }
  if (colCount == 0) {
    final zero = type.field.additiveIdentity;
    for (final val in b.values) {
      if (val != zero) {
        throw StateError('Linear system is inconsistent.');
      }
    }
    return Matrix<T>.filled(0, nrhs, zero, type: type);
  }
  if (rowCount == colCount) {
    if ((type as DataType) == DataType.float64) {
      final aData = _copyTensorToFloat64List(a.tensor, rowCount * colCount);
      final bData = _copyTensorToFloat64List(b.tensor, rowCount * nrhs);
      final success = Lapack.dgesv(
        n: rowCount,
        nrhs: nrhs,
        a: aData,
        lda: math.max(1, colCount),
        b: bData,
        ldb: math.max(1, nrhs),
      );
      if (success) {
        return Matrix<T>(
          Tensor.internal(
            type: type,
            layout: Layout(shape: [colCount, nrhs]),
            data: bData as List<T>,
          ),
        );
      }
    }
    return LUDecomposition<T>(a).solve(b);
  } else if ((type as DataType) == DataType.float64) {
    final aData = _copyTensorToFloat64List(a.tensor, rowCount * colCount);
    final maxMN = math.max(rowCount, colCount);
    final bData = _copyTensorToFloat64List(b.tensor, maxMN * nrhs);
    final success = Lapack.dgels(
      m: rowCount,
      n: colCount,
      nrhs: nrhs,
      a: aData,
      lda: math.max(1, colCount),
      b: bData,
      ldb: math.max(1, nrhs),
    );
    if (success) {
      final resultData = maxMN == colCount
          ? bData
          : bData.sublist(0, colCount * nrhs);
      return Matrix<T>(
        Tensor.internal(
          type: type,
          layout: Layout(shape: [colCount, nrhs]),
          data: resultData as List<T>,
        ),
      );
    }
    if (rowCount > colCount) {
      return QRDecomposition<T>(a).solve(b);
    }
    return solveUnderdeterminedMatrix(a, b);
  } else if (T == double || T == num || T == Complex) {
    if (rowCount > colCount) {
      return QRDecomposition<T>(a).solve(b);
    }
    return solveUnderdeterminedMatrix(a, b);
  } else {
    return solveRref(a, b);
  }
}

/// Solves an exact linear system using Gauss-Jordan elimination with Reduced
/// Row Echelon Form (RREF).
Matrix<T> solveRref<T>(Matrix<T> a, Matrix<T> b) {
  final field = a.type.field;
  final zero = field.additiveIdentity;
  final one = field.multiplicativeIdentity;
  final m = a.rowCount;
  final n = a.colCount;
  final k = b.colCount;
  final totalCols = n + k;
  final grid = [
    for (var r = 0; r < m; r++)
      [
        for (var c = 0; c < n; c++) a.getUnchecked(r, c),
        for (var c = 0; c < k; c++) b.getUnchecked(r, c),
      ],
  ];
  final pivotColumns = <int>[];
  var pivotRow = 0;

  for (var col = 0; col < totalCols && pivotRow < m; col++) {
    var found = -1;
    for (var r = pivotRow; r < m; r++) {
      if (field.add(grid[r][col], zero) != zero) {
        found = r;
        break;
      }
    }
    if (found == -1) continue;
    if (found != pivotRow) {
      final temp = grid[pivotRow];
      grid[pivotRow] = grid[found];
      grid[found] = temp;
    }
    pivotColumns.add(col);
    final pivot = grid[pivotRow][col];
    grid[pivotRow][col] = one;
    for (var c = col + 1; c < totalCols; c++) {
      grid[pivotRow][c] = field.div(grid[pivotRow][c], pivot);
    }
    for (var r = 0; r < m; r++) {
      if (r == pivotRow) continue;
      final factor = grid[r][col];
      if (field.add(factor, zero) == zero) {
        grid[r][col] = zero;
        continue;
      }
      grid[r][col] = zero;
      for (var c = col + 1; c < totalCols; c++) {
        grid[r][c] = field.sub(
          grid[r][c],
          field.mul(factor, grid[pivotRow][c]),
        );
      }
    }
    pivotRow++;
  }

  if (pivotColumns.any((p) => p >= n)) {
    throw StateError('Linear system is inconsistent.');
  }
  if (m >= n && pivotColumns.length < n) {
    throw StateError('Matrix is rank deficient.');
  }

  final result = Matrix<T>.filled(n, k, zero, type: a.type);
  for (var pIdx = 0; pIdx < pivotColumns.length; pIdx++) {
    final pCol = pivotColumns[pIdx];
    for (var c = 0; c < k; c++) {
      result.setUnchecked(pCol, c, grid[pIdx][n + c]);
    }
  }
  return result;
}

/// Solves an underdetermined linear system ($m < n$) using QR decomposition
/// of the conjugate transpose $A^* = Q R$.
Matrix<T> solveUnderdeterminedMatrix<T>(Matrix<T> a, Matrix<T> b) {
  final at = a.conjugateTranspose;
  final qr = QRDecomposition<T>(at);
  if (!qr.isFullRank) {
    throw StateError('Matrix is rank deficient.');
  }
  final field = a.type.field;
  final rMat = qr.r;
  final nx = b.colCount;
  final y = Matrix<T>.generate(
    a.rowCount,
    nx,
    (r, c) => field.additiveIdentity,
    type: a.type,
  );
  for (var j = 0; j < nx; j++) {
    for (var i = 0; i < a.rowCount; i++) {
      var sum = b.getUnchecked(i, j);
      for (var k = 0; k < i; k++) {
        sum = field.sub(
          sum,
          field.mul(
            field.conjugate(rMat.getUnchecked(k, i)),
            y.getUnchecked(k, j),
          ),
        );
      }
      y.setUnchecked(
        i,
        j,
        field.div(sum, field.conjugate(rMat.getUnchecked(i, i))),
      );
    }
  }
  final qMat = qr.q;
  return Matrix<T>.generate(a.colCount, nx, (i, j) {
    var sum = field.additiveIdentity;
    for (var k = 0; k < a.rowCount; k++) {
      sum = field.add(
        sum,
        field.mul(qMat.getUnchecked(i, k), y.getUnchecked(k, j)),
      );
    }
    return sum;
  }, type: a.type);
}

Float64List _copyTensorToFloat64List<E>(Tensor<E> t, int allocLength) {
  final out = Float64List(allocLength);
  if (t.layout.isContiguous && t.data is Float64List) {
    out.setRange(0, t.length, t.data as Float64List, t.layout.offset);
  } else {
    var i = 0;
    for (final v in t.values) {
      out[i++] = (v as num).toDouble();
    }
  }
  return out;
}
