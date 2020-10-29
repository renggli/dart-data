import 'dart:math' as math;

import '../../shared/math.dart';
import '../matrix.dart';
import 'singular_value.dart';

extension NormNumberExtension on Matrix<num> {
  /// Returns the two norm, the maximum singular value of this [Matrix].
  double get norm2 => singularValue.norm2;

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

extension NormDoubleExtension on Matrix<double> {
  /// Returns the trace of this [Matrix].
  double get trace {
    var result = 0.0;
    final count = math.min(rowCount, columnCount);
    for (var i = 0; i < count; i++) {
      result += getUnchecked(i, i);
    }
    return result;
  }

  /// Returns the one norm, the maximum column sum of this [Matrix].
  double get norm1 {
    var result = 0.0;
    for (var c = 0; c < columnCount; c++) {
      var sum = 0.0;
      for (var r = 0; r < rowCount; r++) {
        sum += getUnchecked(r, c).abs();
      }
      result = math.max(result, sum);
    }
    return result;
  }

  /// Returns the infinity norm, the maximum row sum of this [Matrix].
  double get normInfinity {
    var result = 0.0;
    for (var r = 0; r < rowCount; r++) {
      var sum = 0.0;
      for (var c = 0; c < columnCount; c++) {
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
    final count = math.min(rowCount, columnCount);
    for (var i = 0; i < count; i++) {
      result += getUnchecked(i, i);
    }
    return result;
  }

  /// Returns the one norm, the maximum column sum of this [Matrix].
  int get norm1 {
    var result = 0;
    for (var c = 0; c < columnCount; c++) {
      var sum = 0;
      for (var r = 0; r < rowCount; r++) {
        sum += getUnchecked(r, c).abs();
      }
      result = math.max(result, sum);
    }
    return result;
  }

  /// Returns the infinity norm, the maximum row sum of this [Matrix].
  int get normInfinity {
    var result = 0;
    for (var r = 0; r < rowCount; r++) {
      var sum = 0;
      for (var c = 0; c < columnCount; c++) {
        sum += getUnchecked(r, c).abs();
      }
      result = math.max(result, sum);
    }
    return result;
  }
}
