library data.matrix.decompositions;

import 'decomposition/cholesky.dart';
import 'decomposition/eigen.dart';
import 'decomposition/lu.dart';
import 'decomposition/qr.dart';
import 'decomposition/singular_value.dart';
import 'matrix.dart';

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
    solve(a.transpose, b.transpose);

/// Returns the inverse if [a] is square, pseudo-inverse otherwise.
Matrix<double> inverse(Matrix<num> a) =>
    solve(a, Matrix.builder.diagonal.identity(a.rowCount, 1.0));

/// Returns the determinant.
double det(Matrix<num> source) => lu(source).det;

/// Returns the rank, the effective numerical rank.
int rank(Matrix<num> source) => singularValue(source).rank;

/// Returns the condition, the ratio of largest to smallest singular value.
double cond(Matrix<num> source) => singularValue(source).cond;
