library matrix.decomposition.norm;

import 'dart:math' as math;

import '../../shared/math.dart';
import '../matrix.dart';
import 'singular_value.dart';

extension NormExtension<T extends num> on Matrix<T> {
  /// Returns the trace.
  T get trace {
    var result = dataType.field.additiveIdentity;
    for (var i = 0; i < math.min(rowCount, colCount); i++) {
      result += getUnchecked(i, i);
    }
    return result;
  }

  /// Returns the one norm, the maximum column sum.
  T get norm1 {
    var result = dataType.field.additiveIdentity;
    for (var c = 0; c < colCount; c++) {
      var sum = dataType.field.additiveIdentity;
      for (var r = 0; r < rowCount; r++) {
        sum += getUnchecked(r, c).abs();
      }
      result = math.max(result, sum);
    }
    return result;
  }

  /// Returns the two norm, the maximum singular value.
  double get norm2 => singularValue.norm2;

  /// Returns the infinity norm, the maximum row sum.
  T get normInfinity {
    var result = dataType.field.additiveIdentity;
    for (var r = 0; r < rowCount; r++) {
      var sum = dataType.field.additiveIdentity;
      for (var c = 0; c < colCount; c++) {
        sum += getUnchecked(r, c).abs();
      }
      result = math.max(result, sum);
    }
    return result;
  }

  /// Returns the frobenius norm, the sum of squares of all elements.
  double get normFrobenius {
    var result = 0.0;
    for (var c = 0; c < colCount; c++) {
      for (var r = 0; r < rowCount; r++) {
        result = hypot(result, getUnchecked(r, c));
      }
    }
    return result;
  }
}
