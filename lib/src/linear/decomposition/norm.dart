import 'dart:math' as math;

import '../../acceleration/utils/norm_accumulator.dart';
import '../matrix.dart';
import 'svd.dart';

/// Extension methods for matrix norms, condition estimators, and numerical
/// rank.
extension MatrixNormExtension<T extends num> on Matrix<T> {
  /// Returns the Frobenius norm: `sqrt(sum(|a_ij|^2))`.
  ///
  /// Uses scaled summation to prevent intermediate underflow and overflow.
  ///
  /// ```dart
  /// final m = Matrix<double>.fromRows([
  ///   [3.0, 0.0],
  ///   [0.0, 4.0],
  /// ]);
  /// print(m.normFrobenius); // 5.0
  /// ```
  double get normFrobenius {
    final acc = ScaledNormAccumulator();
    for (var row = 0; row < rowCount; row++) {
      for (var col = 0; col < colCount; col++) {
        acc.add(getUnchecked(row, col).toDouble());
      }
    }
    return acc.norm;
  }

  /// Returns the 1-norm: maximum absolute column sum `max_j sum_i |a_ij|`.
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
      if (sum.isNaN) return double.nan;
      result = math.max(result, sum);
    }
    return result;
  }

  /// Returns the 2-norm: largest singular value `sigma_max(A)`.
  ///
  /// ```dart
  /// final m = Matrix<double>.fromRows([
  ///   [2.0, 0.0],
  ///   [0.0, 5.0],
  /// ]);
  /// print(m.norm2); // 5.0
  /// ```
  double get norm2 => rowCount == 0 || colCount == 0
      ? 0.0
      : SingularValueDecomposition(this, computeVectors: false).norm2;

  /// Returns the infinity norm: maximum absolute row sum `max_i sum_j |a_ij|`.
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
      if (sum.isNaN) return double.nan;
      result = math.max(result, sum);
    }
    return result;
  }

  /// Returns the 2-norm condition number `sigma_max / sigma_min`.
  ///
  /// ```dart
  /// final id = Matrix<double>.identity(2);
  /// print(id.cond); // 1.0
  /// ```
  double get cond => rowCount == 0 || colCount == 0
      ? 0.0
      : SingularValueDecomposition(this, computeVectors: false).cond;

  /// Returns the effective numerical rank of the matrix via SVD singular-value
  /// thresholding.
  ///
  /// ```dart
  /// final m = Matrix<double>.fromRows([
  ///   [1.0, 2.0],
  ///   [2.0, 4.0],
  /// ]);
  /// print(m.rank); // 1
  /// ```
  int get rank => rowCount == 0 || colCount == 0
      ? 0
      : SingularValueDecomposition(this, computeVectors: false).rank;
}
