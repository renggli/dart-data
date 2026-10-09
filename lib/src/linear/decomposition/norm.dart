import 'dart:math' as math;

import '../matrix.dart';

/// Extension methods for matrix norms, trace, and condition estimators.
extension MatrixNormExtension<T extends num> on Matrix<T> {
  /// Returns the Frobenius norm: $\|A\|_F = \sqrt{\sum_{i,j} |a_{ij}|^2}$.
  double get normFrobenius {
    var scale = 0.0;
    var sumsq = 1.0;
    for (var r = 0; r < rowCount; r++) {
      for (var c = 0; c < colCount; c++) {
        final val = get(r, c).toDouble();
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
    for (var c = 0; c < colCount; c++) {
      var sum = 0.0;
      for (var r = 0; r < rowCount; r++) {
        sum += get(r, c).abs().toDouble();
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
    for (var r = 0; r < rowCount; r++) {
      var sum = 0.0;
      for (var c = 0; c < colCount; c++) {
        sum += get(r, c).abs().toDouble();
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
      sum += get(i, i).toDouble();
    }
    return sum;
  }

  /// Returns the 2-norm condition number $\kappa(A) = \sigma_{\max} / \sigma_{\min}$.
  double get cond {
    final s = svd.s;
    if (s.length == 0) return 0.0;
    final minSingular = s[s.length - 1];
    return minSingular == 0.0 ? double.infinity : s[0] / minSingular;
  }

  /// Returns the effective numerical rank of the matrix.
  int get rank {
    final s = svd.s;
    if (s.length == 0) return 0;
    final eps = math.pow(2.0, -52).toDouble();
    final tol = math.max(rowCount, colCount) * s[0] * eps;
    var count = 0;
    for (var i = 0; i < s.length; i++) {
      if (s[i] > tol) count++;
    }
    return count;
  }
}
