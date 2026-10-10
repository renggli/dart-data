import 'dart:math' as math;

import '../matrix.dart';

/// Extension methods for matrix norms, trace, and condition estimators.
extension MatrixNormExtension<T extends num> on Matrix<T> {
  /// Returns the Frobenius norm: $\|A\|_F = \sqrt{\sum_{i,j} |a_{ij}|^2}$.
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
  double get norm2 => svd.s.length > 0 ? svd.s[0] : 0.0;

  /// Returns the infinity norm: maximum absolute row sum $\max_i \sum_j |a_{ij}|$.
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

  /// Returns the trace of the matrix (sum of diagonal elements).
  double get trace {
    var sum = 0.0;
    final count = math.min(rowCount, colCount);
    for (var i = 0; i < count; i++) {
      sum += getUnchecked(i, i).toDouble();
    }
    return sum;
  }

  /// Returns the 2-norm condition number $\kappa(A) = \sigma_{\max} / \sigma_{\min}$.
  double get cond {
    final singularValues = svd.s;
    if (singularValues.length == 0) return 0.0;
    final minSingular = singularValues[singularValues.length - 1];
    return minSingular == 0.0
        ? double.infinity
        : singularValues[0] / minSingular;
  }

  /// Returns the effective numerical rank of the matrix.
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
