library matrix.decomposition.norm;

import 'dart:math' as math;

import '../../shared/math.dart';
import '../matrix.dart';
import 'singular_value.dart';

extension NormExtension<T extends num> on Matrix<T> {
  /// Returns the trace of this [Matrix].
  T get trace {
    var result = dataType.field.additiveIdentity;
    for (var i = 0; i < math.min(rowCount, columnCount); i++) {
      result += getUnchecked(i, i);
    }
    return result;
  }

  /// Returns the one norm, the maximum column sum of this [Matrix].
  T get norm1 {
    var result = dataType.field.additiveIdentity;
    for (var c = 0; c < columnCount; c++) {
      var sum = dataType.field.additiveIdentity;
      for (var r = 0; r < rowCount; r++) {
        sum += getUnchecked(r, c).abs();
      }
      result = math.max(result, sum);
    }
    return result;
  }

  /// Returns the two norm, the maximum singular value of this [Matrix].
  double get norm2 => singularValue.norm2;

  /// Returns the infinity norm, the maximum row sum of this [Matrix].
  T get normInfinity {
    var result = dataType.field.additiveIdentity;
    for (var r = 0; r < rowCount; r++) {
      var sum = dataType.field.additiveIdentity;
      for (var c = 0; c < columnCount; c++) {
        sum += getUnchecked(r, c).abs();
      }
      result = math.max(result, sum);
    }
    return result;
  }

  /// Returns the frobenius norm, the sum of squares of all elements of this
  /// [Matrix].
  double get normFrobenius {
    var result = 0.0;
    for (var c = 0; c < columnCount; c++) {
      for (var r = 0; r < rowCount; r++) {
        result = hypot(result, getUnchecked(r, c));
      }
    }
    return result;
  }
}
