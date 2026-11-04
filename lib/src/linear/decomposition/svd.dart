import 'dart:math' as math;
import 'dart:typed_data';

import '../../acceleration/lapack/lapack.dart';
import '../../tensor/layout.dart';
import '../../tensor/tensor.dart';
import '../../type/data_type.dart';
import '../matrix.dart';
import '../vector.dart';

/// Extension methods providing Singular Value Decomposition (SVD) on numeric
/// matrices.
extension SvdMatrixExtension<T extends num> on Matrix<T> {
  /// Computes the Singular Value Decomposition (SVD) of this matrix.
  SingularValueDecomposition get svd =>
      SingularValueDecomposition(_toDoubleMatrix());

  Matrix<double> _toDoubleMatrix() => this is Matrix<double>
      ? this as Matrix<double>
      : Matrix<double>.generate(
          rowCount,
          colCount,
          (r, c) => getUnchecked(r, c).toDouble(),
          type: DataType.float64,
        );
}

/// Singular Value Decomposition (SVD) of an $m \times n$ matrix $A$.
///
/// Conceptually, SVD breaks any matrix down into three intuitive geometric
/// steps: an initial rotation ($V^T$), scaling along coordinate axes
/// ($\Sigma$), and a second rotation ($U$). More formally, it computes
/// $A = U \Sigma V^T$ where $U \in \mathbb{R}^{m \times m}$ and
/// $V \in \mathbb{R}^{n \times n}$ are orthogonal matrices and $\Sigma$
/// contains singular values $\sigma_1 \ge \sigma_2 \ge \dots \ge 0$ in
/// non-increasing order.
///
/// ```dart
/// final a = Matrix<double>.fromRows([
///   [3.0, 0.0],
///   [0.0, 4.0],
/// ]);
/// final svd = a.svd;
/// print(svd.s); // [4.0, 3.0]
/// ```
class SingularValueDecomposition {
  /// Computes the SVD of [matrix].
  factory(Matrix<num> matrix, {bool computeVectors = true}) {
    final rowsA = matrix.rowCount;
    final colsA = matrix.colCount;
    final nm = math.min(rowsA, colsA);

    if (rowsA == 0 || colsA == 0) {
      return SingularValueDecomposition._(
        Vector<double>(
          Tensor.internal(
            type: DataType.float64,
            layout: Layout(shape: [0]),
            data: Float64List(0),
          ),
        ),
        computeVectors
            ? Matrix<double>(
                Tensor.internal(
                  type: DataType.float64,
                  layout: Layout(shape: [rowsA, rowsA]),
                  data: Float64List(0),
                ),
              )
            : null,
        computeVectors
            ? Matrix<double>(
                Tensor.internal(
                  type: DataType.float64,
                  layout: Layout(shape: [colsA, colsA]),
                  data: Float64List(0),
                ),
              )
            : null,
        computeVectors,
        rowsA,
        colsA,
      );
    }

    var allFinite = true;
    final aVals = Float64List(rowsA * colsA);
    var idx = 0;
    for (var r = 0; r < rowsA; r++) {
      for (var c = 0; c < colsA; c++) {
        final val = matrix.getUnchecked(r, c).toDouble();
        if (!val.isFinite) allFinite = false;
        aVals[idx++] = val;
      }
    }

    final sVals = Float64List(nm);
    final uVals = computeVectors ? Float64List(rowsA * rowsA) : null;
    final vtVals = computeVectors ? Float64List(colsA * colsA) : null;

    if (!allFinite) {
      sVals.fillRange(0, nm, double.nan);
      uVals?.fillRange(0, rowsA * rowsA, double.nan);
      vtVals?.fillRange(0, colsA * colsA, double.nan);
    } else {
      final ok = Lapack.dgesvd(
        jobu: computeVectors ? 'A' : 'N',
        jobvt: computeVectors ? 'A' : 'N',
        m: rowsA,
        n: colsA,
        a: aVals,
        lda: colsA,
        s: sVals,
        u: uVals,
        ldu: rowsA,
        vt: vtVals,
        ldvt: colsA,
      );
      if (!ok) {
        sVals.fillRange(0, nm, double.nan);
        uVals?.fillRange(0, rowsA * rowsA, double.nan);
        vtVals?.fillRange(0, colsA * colsA, double.nan);
      }
    }

    final sVector = Vector<double>(
      Tensor.internal(
        type: DataType.float64,
        layout: Layout(shape: [nm]),
        data: sVals,
      ),
    );
    final uMatrix = computeVectors
        ? Matrix<double>(
            Tensor.internal(
              type: DataType.float64,
              layout: Layout(shape: [rowsA, rowsA]),
              data: uVals!,
            ),
          )
        : null;
    final vtMatrix = computeVectors
        ? Matrix<double>(
            Tensor.internal(
              type: DataType.float64,
              layout: Layout(shape: [colsA, colsA]),
              data: vtVals!,
            ),
          )
        : null;

    return SingularValueDecomposition._(
      sVector,
      uMatrix,
      vtMatrix,
      computeVectors,
      rowsA,
      colsA,
    );
  }

  const new _(
    this.s,
    this._u,
    this._vt,
    this.vectorsComputed,
    this._rowCount,
    this._colCount,
  );

  /// The singular values in descending order.
  final Vector<double> s;

  final Matrix<double>? _u;
  final Matrix<double>? _vt;

  /// Whether singular vectors were computed.
  final bool vectorsComputed;

  final int _rowCount;
  final int _colCount;

  /// The left singular vectors as an $m \times m$ orthogonal matrix.
  Matrix<double> get u =>
      _u ?? (throw StateError('Singular vectors were not computed.'));

  /// The transpose of right singular vectors as an $n \times n$ orthogonal
  /// matrix.
  Matrix<double> get vt =>
      _vt ?? (throw StateError('Singular vectors were not computed.'));

  /// The right singular vectors as an $n \times n$ orthogonal matrix.
  Matrix<double> get v => vt.transposed;

  /// Returns the diagonal matrix of singular values of size $m \times n$.
  Matrix<double> get sigma => Matrix<double>.generate(
    _rowCount,
    _colCount,
    (row, col) => row == col && row < s.length ? s[row] : 0.0,
    type: DataType.float64,
  );

  /// The effective numerical rank of the matrix.
  int get rank {
    if (s.length == 0) return 0;
    final maxDim = math.max(_rowCount, _colCount);
    final maxS = s[0].abs();
    final tol = maxDim * maxS * 2.220446049250313e-16;
    var count = 0;
    for (var i = 0; i < s.length; i++) {
      if (s[i].abs() > tol) count++;
    }
    return count;
  }

  /// The 2-norm (largest singular value).
  double get norm2 => s.length > 0 ? s[0].abs() : 0.0;

  /// Condition number $\sigma_{\max} / \sigma_{\min}$.
  double get cond {
    if (s.length == 0) return 0.0;
    final maxDim = math.max(_rowCount, _colCount);
    final tol = maxDim * s[0].abs() * 2.220446049250313e-16;
    final minS = s[s.length - 1].abs();
    return minS <= tol ? double.infinity : s[0].abs() / minS;
  }

  /// Solves the linear system $A x \approx b$ using minimum norm least squares.
  Vector<double> solveVector(Vector<num> b, {double? tolerance}) {
    if (!vectorsComputed) {
      throw StateError('Singular vectors were not computed.');
    }
    if (u.rowCount != b.length) {
      throw ArgumentError(
        'Vector length (${b.length}) must match rowCount (${u.rowCount}).',
      );
    }
    final cols = vt.colCount;
    final mn = math.min(u.rowCount, cols);
    final tmp = Float64List(cols);
    final maxDim = math.max(u.rowCount, cols);
    final maxS = s.length > 0 ? s[0].abs() : 0.0;
    final tol = tolerance ?? maxDim * maxS * 2.220446049250313e-16;

    for (var j = 0; j < cols; j++) {
      var val = 0.0;
      if (j < mn) {
        for (var i = 0; i < u.rowCount; i++) {
          val += u.getUnchecked(i, j) * b.getUnchecked(i).toDouble();
        }
        val = s[j].abs() > tol ? val / s[j] : 0.0;
      }
      tmp[j] = val;
    }

    final result = Float64List(cols);
    for (var j = 0; j < cols; j++) {
      var val = 0.0;
      for (var i = 0; i < cols; i++) {
        val += vt.getUnchecked(i, j) * tmp[i];
      }
      result[j] = val;
    }

    return Vector<double>(
      Tensor.internal(
        type: DataType.float64,
        layout: Layout(shape: [cols]),
        data: result,
      ),
    );
  }

  /// Solves the linear system $A X \approx B$ using minimum norm least squares.
  Matrix<double> solve(Matrix<num> b, {double? tolerance}) {
    if (!vectorsComputed) {
      throw StateError('Singular vectors were not computed.');
    }
    if (u.rowCount != b.rowCount) {
      throw ArgumentError(
        'Matrix row count (${b.rowCount}) must match rowCount (${u.rowCount}).',
      );
    }
    final cols = vt.colCount;
    final nrhs = b.colCount;
    final mn = math.min(u.rowCount, cols);
    final maxDim = math.max(u.rowCount, cols);
    final maxS = s.length > 0 ? s[0].abs() : 0.0;
    final tol = tolerance ?? maxDim * maxS * 2.220446049250313e-16;

    final result = Matrix<double>.filled(
      cols,
      nrhs,
      0.0,
      type: DataType.float64,
    );
    final tmp = Float64List(cols);

    for (var col = 0; col < nrhs; col++) {
      for (var j = 0; j < cols; j++) {
        var val = 0.0;
        if (j < mn) {
          for (var i = 0; i < u.rowCount; i++) {
            val += u.getUnchecked(i, j) * b.getUnchecked(i, col).toDouble();
          }
          val = s[j].abs() > tol ? val / s[j] : 0.0;
        }
        tmp[j] = val;
      }

      for (var j = 0; j < cols; j++) {
        var val = 0.0;
        for (var i = 0; i < cols; i++) {
          val += vt.getUnchecked(i, j) * tmp[i];
        }
        result.setUnchecked(j, col, val);
      }
    }

    return result;
  }
}
