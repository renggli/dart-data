import 'dart:math' as math;

import '../../shared/math.dart';
import '../matrix.dart';
import 'singular_value.dart';

extension NormNumberExtension on Matrix<num> {
  /// Returns the two norm: The maximum singular value of this [Matrix].
  double get norm2 => singularValue.norm2;

  /// Returns the Frobenius norm: The square root of the sum of squares of all
  /// elements of this [Matrix].
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

extension NormDoubleExtension on Matrix<double> {
  /// Returns the trace of this [Matrix].
  double get trace {
    var result = 0.0;
    final count = math.min(rowCount, colCount);
    for (var i = 0; i < count; i++) {
      result += getUnchecked(i, i);
    }
    return result;
  }

  /// Returns the one norm: The maximum column sum of this [Matrix].
  double get norm1 {
    var result = 0.0;
    for (var c = 0; c < colCount; c++) {
      var sum = 0.0;
      for (var r = 0; r < rowCount; r++) {
        sum += getUnchecked(r, c).abs();
      }
      result = math.max(result, sum);
    }
    return result;
  }

  /// Returns the infinity norm: The maximum row sum of this [Matrix].
  double get normInfinity {
    var result = 0.0;
    for (var r = 0; r < rowCount; r++) {
      var sum = 0.0;
      for (var c = 0; c < colCount; c++) {
        sum += getUnchecked(r, c).abs();
      }
      result = math.max(result, sum);
    }
    return result;
  }
}

extension NormIntegerExtension on Matrix<int> {
  /// Returns the trace of this [Matrix].
  int get trace {
    var result = 0;
    final count = math.min(rowCount, colCount);
    for (var i = 0; i < count; i++) {
      result += getUnchecked(i, i);
    }
    return result;
  }

  /// Returns the one norm: The maximum column sum of this [Matrix].
  int get norm1 {
    var result = 0;
    for (var c = 0; c < colCount; c++) {
      var sum = 0;
      for (var r = 0; r < rowCount; r++) {
        sum += getUnchecked(r, c).abs();
      }
      result = math.max(result, sum);
    }
    return result;
  }

  /// Returns the infinity norm: The maximum row sum of this [Matrix].
  int get normInfinity {
    var result = 0;
    for (var r = 0; r < rowCount; r++) {
      var sum = 0;
      for (var c = 0; c < colCount; c++) {
        sum += getUnchecked(r, c).abs();
      }
      result = math.max(result, sum);
    }
    return result;
  }
}
