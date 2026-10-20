import 'dart:math' as math;
import 'dart:typed_data';

import 'simd.dart';

/// Pure Dart reference implementations of BLAS Level 1 vector-vector routines.
abstract final class PureDartBlas1 {
  /// Computes dot product of two [Float64List] vectors.
  static double ddot({
    required int n,
    required Float64List x,
    int xOffset = 0,
    int incX = 1,
    required Float64List y,
    int yOffset = 0,
    int incY = 1,
  }) {
    var sum = 0.0;
    for (
      var i = 0, xi = xOffset, yi = yOffset;
      i < n;
      i++, xi += incX, yi += incY
    ) {
      sum += x[xi] * y[yi];
    }
    return sum;
  }

  /// Computes dot product of two [Float32List] vectors.
  static double sdot({
    required int n,
    required Float32List x,
    int xOffset = 0,
    int incX = 1,
    required Float32List y,
    int yOffset = 0,
    int incY = 1,
  }) {
    if (xOffset == 0 &&
        yOffset == 0 &&
        incX == 1 &&
        incY == 1 &&
        x.length == n &&
        y.length == n) {
      return SimdEngine.dotFloat32(x, y);
    }
    var sum = 0.0;
    for (
      var i = 0, xi = xOffset, yi = yOffset;
      i < n;
      i++, xi += incX, yi += incY
    ) {
      sum += x[xi] * y[yi];
    }
    return sum;
  }

  /// Computes Euclidean norm of a [Float64List] vector.
  static double dnrm2({
    required int n,
    required Float64List x,
    int xOffset = 0,
    int incX = 1,
  }) {
    var sumSq = 0.0;
    for (var i = 0, xi = xOffset; i < n; i++, xi += incX) {
      final val = x[xi];
      sumSq += val * val;
    }
    return math.sqrt(sumSq);
  }

  /// Computes Euclidean norm of a [Float32List] vector.
  static double snrm2({
    required int n,
    required Float32List x,
    int xOffset = 0,
    int incX = 1,
  }) {
    if (xOffset == 0 && incX == 1 && x.length == n) {
      return math.sqrt(SimdEngine.dotFloat32(x, x));
    }
    var sumSq = 0.0;
    for (var i = 0, xi = xOffset; i < n; i++, xi += incX) {
      final val = x[xi];
      sumSq += val * val;
    }
    return math.sqrt(sumSq);
  }

  /// Computes in-place scaled addition `y = alpha * x + y` for [Float64List].
  static bool daxpy({
    required int n,
    required double alpha,
    required Float64List x,
    int xOffset = 0,
    int incX = 1,
    required Float64List y,
    int yOffset = 0,
    int incY = 1,
  }) {
    for (
      var i = 0, xi = xOffset, yi = yOffset;
      i < n;
      i++, xi += incX, yi += incY
    ) {
      y[yi] += alpha * x[xi];
    }
    return true;
  }

  /// Computes in-place scaled addition `y = alpha * x + y` for [Float32List].
  static bool saxpy({
    required int n,
    required double alpha,
    required Float32List x,
    int xOffset = 0,
    int incX = 1,
    required Float32List y,
    int yOffset = 0,
    int incY = 1,
  }) {
    for (
      var i = 0, xi = xOffset, yi = yOffset;
      i < n;
      i++, xi += incX, yi += incY
    ) {
      y[yi] += alpha * x[xi];
    }
    return true;
  }

  /// In-place scaling `x = alpha * x` for [Float64List].
  static bool dscal({
    required int n,
    required double alpha,
    required Float64List x,
    int xOffset = 0,
    int incX = 1,
  }) {
    for (var i = 0, xi = xOffset; i < n; i++, xi += incX) {
      x[xi] *= alpha;
    }
    return true;
  }

  /// In-place scaling `x = alpha * x` for [Float32List].
  static bool sscal({
    required int n,
    required double alpha,
    required Float32List x,
    int xOffset = 0,
    int incX = 1,
  }) {
    for (var i = 0, xi = xOffset; i < n; i++, xi += incX) {
      x[xi] *= alpha;
    }
    return true;
  }
}
