library data.matrix.decompositions;

import 'dart:math' as math;

import '../shared/config.dart';
import '../shared/math.dart';
import 'decomposition/cholesky.dart';
import 'decomposition/eigen.dart';
import 'decomposition/lu.dart';
import 'decomposition/qr.dart';
import 'decomposition/singular_value.dart';
import 'matrix.dart';
import 'view/identity_matrix.dart';
import 'view/transposed_matrix.dart';

/// Returns the LU Decomposition.
LUDecomposition lu(Matrix<num> source) => LUDecomposition(source);

/// Returns the QR Decomposition.
QRDecomposition qr(Matrix<num> source) => QRDecomposition(source);

/// Returns the Cholesky Decomposition.
CholeskyDecomposition cholesky(Matrix<num> source) =>
    CholeskyDecomposition(source);

/// Returns the Singular Value Decomposition.
SingularValueDecomposition singularValue(Matrix<num> source) =>
    SingularValueDecomposition(source);

/// Returns the Eigenvalue Decomposition.
EigenvalueDecomposition eigenvalue(Matrix<num> source) =>
    EigenvalueDecomposition(source);

/// Returns the solution of [a] * x = [b].
Matrix<double> solve(Matrix<num> a, Matrix<num> b) =>
    a.rowCount == a.colCount ? lu(a).solve(b) : qr(a).solve(b);

/// Returns the solution of x * [a] = [b], which is also [a]' * x' = [b]'.
Matrix<double> solveTranspose(Matrix<num> a, Matrix<num> b) =>
    solve(a.transposed, b.transposed);

/// Returns the inverse if [source] is square, pseudo-inverse otherwise.
Matrix<double> inverse(Matrix<num> source) => solve(source,
    IdentityMatrix<double>(floatDataType, source.rowCount, source.rowCount, 1));

/// Returns the determinant.
double det(Matrix<num> source) => lu(source).det;

/// Returns the rank, the effective numerical rank.
int rank(Matrix<num> source) => singularValue(source).rank;

/// Returns the condition, the ratio of largest to smallest singular value.
double cond(Matrix<num> source) => singularValue(source).cond;

/// Returns the trace.
T trace<T extends num>(Matrix<T> source) {
  var result = source.dataType.nullValue;
  for (var i = 0; i < math.min(source.rowCount, source.colCount); i++) {
    result += source.getUnchecked(i, i);
  }
  return result;
}

/// Returns the one norm, the maximum column sum.
T norm1<T extends num>(Matrix<T> source) {
  var result = source.dataType.nullValue;
  for (var c = 0; c < source.colCount; c++) {
    var sum = source.dataType.nullValue;
    for (var r = 0; r < source.rowCount; r++) {
      sum += source.getUnchecked(r, c).abs();
    }
    result = math.max(result, sum);
  }
  return result;
}

/// Returns the two norm, the maximum singular value.
double norm2(Matrix<num> source) => singularValue(source).norm2;

/// Returns the infinity norm, the maximum row sum.
T normInfinity<T extends num>(Matrix<T> source) {
  var result = source.dataType.nullValue;
  for (var r = 0; r < source.rowCount; r++) {
    var sum = source.dataType.nullValue;
    for (var c = 0; c < source.colCount; c++) {
      sum += source.getUnchecked(r, c).abs();
    }
    result = math.max(result, sum);
  }
  return result;
}

/// Returns the frobenius norm, the sum of squares of all elements.
double normFrobenius(Matrix<num> source) {
  var result = 0.0;
  for (var c = 0; c < source.colCount; c++) {
    for (var r = 0; r < source.rowCount; r++) {
      result = hypot(result, source.getUnchecked(r, c));
    }
  }
  return result;
}
