import 'dart:math' as math;

import '../matrix.dart';
import 'svd.dart';

/// Extension methods for matrix norms, condition estimators, and numerical rank.
extension MatrixNormExtension<T extends num> on Matrix<T> {
  /// Returns the Frobenius norm: $\|A\|_F = \sqrt{\sum_{i,j} |a_{ij}|^2}$.
  ///
  /// Conceptually, this calculates the overall magnitude or Euclidean size
  /// of the matrix by summing the squares of all entries and taking
  /// the square root.
  /// Formally, it computes the Frobenius (Hilbert-Schmidt) norm
  /// $\|A\|_F = \sqrt{\operatorname{Tr}(A^T A)} = \sqrt{\sum_{i=1}^{\min(m, n)} \sigma_i^2}$,
  /// implemented via scaled summation to prevent intermediate underflow and overflow.
  ///
  /// ```dart
  /// final m = Matrix<double>.fromRows([
  ///   [3.0, 0.0],
  ///   [0.0, 4.0],
  /// ]);
  /// print(m.normFrobenius); // 5.0
  /// ```
  double get normFrobenius {
    var scale = 0.0;
    var sumsq = 1.0;
    for (var row = 0; row < rowCount; row++) {
      for (var col = 0; col < colCount; col++) {
        final val = getUnchecked(row, col).toDouble();
        if (val != 0.0) {
          final absVal = val.abs();
          if (scale < absVal) {
            sumsq = 1.0 + sumsq * (scale / absVal) * (scale / absVal);
            scale = absVal;
          } else {
            sumsq += (absVal / scale) * (absVal / scale);
          }
        }
      }
    }
    return scale * math.sqrt(sumsq);
  }

  /// Returns the 1-norm: maximum absolute column sum $\max_j \sum_i |a_{ij}|$.
  ///
  /// Conceptually, this adds up the absolute values in each column
  /// and returns the maximum column sum.
  /// Formally, it computes the induced operator 1-norm
  /// $\|A\|_1 = \max_{\|\mathbf{x}\|_1 = 1} \|A \mathbf{x}\|_1 = \max_{1 \le j \le n} \sum_{i=1}^m |a_{ij}|$.
  ///
  /// ```dart
  /// final m = Matrix<double>.fromRows([
  ///   [1.0, 2.0],
  ///   [3.0, 4.0],
  /// ]);
  /// print(m.norm1); // max(1+3, 2+4) = 6.0
  /// ```
  double get norm1 {
    var result = 0.0;
    for (var col = 0; col < colCount; col++) {
      var sum = 0.0;
      for (var row = 0; row < rowCount; row++) {
        sum += getUnchecked(row, col).abs().toDouble();
      }
      result = math.max(result, sum);
    }
    return result;
  }

  /// Returns the 2-norm: largest singular value $\sigma_{\max}(A)$.
  ///
  /// Conceptually, this measures the maximum factor by which the matrix
  /// can stretch the length of any vector.
  /// Formally, it computes the induced spectral 2-norm
  /// $\|A\|_2 = \max_{\|\mathbf{x}\|_2 = 1} \|A \mathbf{x}\|_2 = \sigma_1(A)$.
  ///
  /// ```dart
  /// final m = Matrix<double>.fromRows([
  ///   [2.0, 0.0],
  ///   [0.0, 5.0],
  /// ]);
  /// print(m.norm2); // 5.0
  /// ```
  double get norm2 => svd.s.length > 0 ? svd.s[0] : 0.0;

  /// Returns the infinity norm: maximum absolute row sum $\max_i \sum_j |a_{ij}|$.
  ///
  /// Conceptually, this adds up the absolute values along each row
  /// and returns the maximum row sum.
  /// Formally, it computes the induced operator infinity norm
  /// $\|A\|_\infty = \max_{\|\mathbf{x}\|_\infty = 1} \|A \mathbf{x}\|_\infty = \max_{1 \le i \le m} \sum_{j=1}^n |a_{ij}|$.
  ///
  /// ```dart
  /// final m = Matrix<double>.fromRows([
  ///   [1.0, 2.0],
  ///   [3.0, 4.0],
  /// ]);
  /// print(m.normInfinity); // max(1+2, 3+4) = 7.0
  /// ```
  double get normInfinity {
    var result = 0.0;
    for (var row = 0; row < rowCount; row++) {
      var sum = 0.0;
      for (var col = 0; col < colCount; col++) {
        sum += getUnchecked(row, col).abs().toDouble();
      }
      result = math.max(result, sum);
    }
    return result;
  }

  /// Returns the 2-norm condition number $\kappa(A) = \sigma_{\max} / \sigma_{\min}$.
  ///
  /// Conceptually, the condition number indicates how sensitive or numerically unstable
  /// solving $A x = b$ will be. A condition number near 1 indicates a well-conditioned matrix;
  /// a very large condition number means rounding errors or slight perturbations will degrade the solution.
  /// Formally, it computes $\kappa_2(A) = \|A\|_2 \|A^{-1}\|_2 = \frac{\sigma_{\max}}{\sigma_{\min}}$,
  /// which bounds relative solution error $\frac{\|\delta \mathbf{x}\|}{\|\mathbf{x}\|} \le \kappa(A) \frac{\|\delta \mathbf{b}\|}{\|\mathbf{b}\|}$.
  ///
  /// ```dart
  /// final id = Matrix<double>.identity(2);
  /// print(id.cond); // 1.0
  /// ```
  double get cond {
    final singularValues = svd.s;
    if (singularValues.length == 0) return 0.0;
    final minSingular = singularValues[singularValues.length - 1];
    return minSingular == 0.0
        ? double.infinity
        : singularValues[0] / minSingular;
  }

  /// Returns the effective numerical rank of the matrix.
  ///
  /// Conceptually, rank is the number of linearly independent rows or columns
  /// in the matrix that provide unique, non-redundant information.
  /// Formally, it computes $\operatorname{rank}(A) = \#\{\sigma_i > \max(m, n) \cdot \sigma_1 \cdot \epsilon_{\text{mach}}\}$,
  /// identifying the dimension of the column space robustly in floating-point arithmetic.
  ///
  /// ```dart
  /// final m = Matrix<double>.fromRows([
  ///   [1.0, 2.0],
  ///   [2.0, 4.0],
  /// ]);
  /// print(m.rank); // 1
  /// ```
  int get rank {
    final singularValues = svd.s;
    if (singularValues.length == 0) return 0;
    final eps = math.pow(2.0, -52).toDouble();
    final tol = math.max(rowCount, colCount) * singularValues[0] * eps;
    var count = 0;
    for (var i = 0; i < singularValues.length; i++) {
      if (singularValues[i] > tol) count++;
    }
    return count;
  }
}
