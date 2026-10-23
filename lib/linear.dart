/// Linear algebra system providing vectors, matrices, sparse formats, matrix
/// decompositions, and solvers.
///
/// Combines a natural, mathematical syntax for operations like addition (`+`),
/// subtraction (`-`), multiplication (`*`), and inversion with high-performance
/// underlying algorithms and transparent hardware acceleration.
///
/// ## Core Data Structures
///
/// - [Vector]: 1-dimensional mathematical vector supporting dot product, cross
///   product, $L_1$, $L_2$, and $L_\infty$ norms, and projections
///   ([VectorProjectionExtension]).
/// - [Matrix]: 2-dimensional matrix supporting matrix multiplication,
///   transposition, inversion, determinant, trace, and block slicing.
/// - [Float64Matrix] and [Float64Vector]: Zero-cost extension types providing
///   direct unboxed buffer access and optimized operations for double-precision
///   floats.
/// - Sparse matrices: [CsrMatrix] (Compressed Sparse Row), [CscMatrix]
///   (Compressed Sparse Column), and [CooMatrix] (Coordinate list) for large,
///   sparse linear systems.
/// - [LinearOperator]: Abstract linear map between vector spaces.
///
/// ## Matrix Factorizations & Decompositions
///
/// - [LUDecomposition] ($P A = L U$): Invert matrices, compute determinants,
///   and solve square systems.
/// - [QRDecomposition] ($A = Q R$): Orthogonal factorization for linear least
///   squares and orthonormalization.
/// - [CholeskyDecomposition] ($A = L L^T$): Efficient factorization for
///   symmetric positive-definite systems.
/// - [SingularValueDecomposition] ($A = U \Sigma V^T$): Low-rank
///   approximations, pseudo-inverses, and PCA.
/// - [EigenvalueDecomposition] ($A V = V \Lambda$): Eigenvalues and
///   eigenvectors of square matrices.
/// - Matrix norms: [MatrixNormExtension] computes induced $L_1$, $L_2$,
///   $L_\infty$, and Frobenius norms.
///
/// ## Solvers
///
/// - [solveIterative]: Iterative Krylov solver
///   ([IterativeMethod.conjugateGradient] for symmetric positive-definite,
///   [IterativeMethod.gmres] for general square systems).
/// - [solveTridiagonal]: Fast $\mathcal{O}(n)$ Thomas algorithm for tridiagonal
///   systems.
///
/// ## Example
///
/// ```dart
/// import 'package:data/linear.dart';
///
/// void main() {
///   // Create a 2x2 matrix
///   final a = Matrix<double>.fromRows([
///     [4.0, 1.0],
///     [1.0, 3.0],
///   ]);
///   final b = Vector<double>.fromList([1.0, 2.0]);
///
///   // Solve A * x = b
///   final x = a.cholesky.solveVector(b);
///   print('Solution: $x');
/// }
/// ```
library;

import 'src/linear/decomposition/cholesky.dart';
import 'src/linear/decomposition/eigenvalue.dart';
import 'src/linear/decomposition/lu.dart';
import 'src/linear/decomposition/norm.dart';
import 'src/linear/decomposition/qr.dart';
import 'src/linear/decomposition/svd.dart';
import 'src/linear/float64_matrix.dart';
import 'src/linear/float64_vector.dart';
import 'src/linear/matrix.dart';
import 'src/linear/operator.dart';
import 'src/linear/projection.dart';
import 'src/linear/solvers/iterative.dart';
import 'src/linear/solvers/tridiagonal.dart';
import 'src/linear/sparse/coo_matrix.dart';
import 'src/linear/sparse/csc_matrix.dart';
import 'src/linear/sparse/csr_matrix.dart';
import 'src/linear/vector.dart';

export 'src/linear/decomposition/cholesky.dart';
export 'src/linear/decomposition/eigenvalue.dart';
export 'src/linear/decomposition/lu.dart';
export 'src/linear/decomposition/norm.dart';
export 'src/linear/decomposition/qr.dart';
export 'src/linear/decomposition/svd.dart';
export 'src/linear/float64_matrix.dart';
export 'src/linear/float64_vector.dart';
export 'src/linear/matrix.dart';
export 'src/linear/operator.dart';
export 'src/linear/projection.dart';
export 'src/linear/solvers/iterative.dart';
export 'src/linear/solvers/tridiagonal.dart';
export 'src/linear/sparse/coo_matrix.dart';
export 'src/linear/sparse/csc_matrix.dart';
export 'src/linear/sparse/csr_matrix.dart';
export 'src/linear/vector.dart';
