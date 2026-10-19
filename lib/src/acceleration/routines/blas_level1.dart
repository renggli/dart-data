import 'dart:math' as math;
import 'dart:typed_data';

import '../acceleration_error.dart';
import '../acceleration_manager.dart';
import '../acceleration_mode.dart';
import '../blas/cblas.dart';
import '../fallback/simd.dart';

/// BLAS Level 1 vector-vector routines.
abstract final class BlasLevel1 {
  /// Computes dot product of two Float64List vectors.
  static double? ddot({
    required int n,
    required Float64List x,
    int xOffset = 0,
    int incX = 1,
    required Float64List y,
    int yOffset = 0,
    int incY = 1,
    required BlasLibrary blas,
  }) {
    if (AccelerationManager.mode == AccelerationMode.accelerated) {
      if (!blas.isAvailable) {
        throw AccelerationError.unavailable('BLAS');
      }
      final res = blas.ddot(
        n: n,
        x: x,
        xOffset: xOffset,
        incX: incX,
        y: y,
        yOffset: yOffset,
        incY: incY,
      );
      if (res == null) {
        throw AccelerationError.failed('ddot');
      }
      return res;
    } else if (AccelerationManager.mode == AccelerationMode.auto &&
        blas.isAvailable) {
      final res = blas.ddot(
        n: n,
        x: x,
        xOffset: xOffset,
        incX: incX,
        y: y,
        yOffset: yOffset,
        incY: incY,
      );
      if (res != null) return res;
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

  /// Computes dot product of two Float32List vectors.
  static double? sdot({
    required int n,
    required Float32List x,
    int xOffset = 0,
    int incX = 1,
    required Float32List y,
    int yOffset = 0,
    int incY = 1,
    required BlasLibrary blas,
  }) {
    if (AccelerationManager.mode == AccelerationMode.accelerated) {
      if (!blas.isAvailable) {
        throw AccelerationError.unavailable('BLAS');
      }
      final res = blas.sdot(
        n: n,
        x: x,
        xOffset: xOffset,
        incX: incX,
        y: y,
        yOffset: yOffset,
        incY: incY,
      );
      if (res == null) {
        throw AccelerationError.failed('sdot');
      }
      return res;
    } else if (AccelerationManager.mode == AccelerationMode.auto &&
        blas.isAvailable) {
      final res = blas.sdot(
        n: n,
        x: x,
        xOffset: xOffset,
        incX: incX,
        y: y,
        yOffset: yOffset,
        incY: incY,
      );
      if (res != null) return res;
    }

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

  /// Computes Euclidean norm of a Float64List vector.
  static double? dnrm2({
    required int n,
    required Float64List x,
    int xOffset = 0,
    int incX = 1,
    required BlasLibrary blas,
  }) {
    if (AccelerationManager.mode == AccelerationMode.accelerated) {
      if (!blas.isAvailable) {
        throw AccelerationError.unavailable('BLAS');
      }
      final res = blas.dnrm2(n: n, x: x, xOffset: xOffset, incX: incX);
      if (res == null) {
        throw AccelerationError.failed('dnrm2');
      }
      return res;
    } else if (AccelerationManager.mode == AccelerationMode.auto &&
        blas.isAvailable) {
      final res = blas.dnrm2(n: n, x: x, xOffset: xOffset, incX: incX);
      if (res != null) return res;
    }

    var sumSq = 0.0;
    for (var i = 0, xi = xOffset; i < n; i++, xi += incX) {
      final val = x[xi];
      sumSq += val * val;
    }
    return math.sqrt(sumSq);
  }

  /// Computes Euclidean norm of a Float32List vector.
  static double? snrm2({
    required int n,
    required Float32List x,
    int xOffset = 0,
    int incX = 1,
    required BlasLibrary blas,
  }) {
    if (AccelerationManager.mode == AccelerationMode.accelerated) {
      if (!blas.isAvailable) {
        throw AccelerationError.unavailable('BLAS');
      }
      final res = blas.snrm2(n: n, x: x, xOffset: xOffset, incX: incX);
      if (res == null) {
        throw AccelerationError.failed('snrm2');
      }
      return res;
    } else if (AccelerationManager.mode == AccelerationMode.auto &&
        blas.isAvailable) {
      final res = blas.snrm2(n: n, x: x, xOffset: xOffset, incX: incX);
      if (res != null) return res;
    }

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

  /// Computes in-place scaled addition y = alpha * x + y for Float64List.
  static bool daxpy({
    required int n,
    required double alpha,
    required Float64List x,
    int xOffset = 0,
    int incX = 1,
    required Float64List y,
    int yOffset = 0,
    int incY = 1,
    required BlasLibrary blas,
  }) {
    if (AccelerationManager.mode == AccelerationMode.accelerated) {
      if (!blas.isAvailable) {
        throw AccelerationError.unavailable('BLAS');
      }
      final success = blas.daxpy(
        n: n,
        alpha: alpha,
        x: x,
        xOffset: xOffset,
        incX: incX,
        y: y,
        yOffset: yOffset,
        incY: incY,
      );
      if (!success) {
        throw AccelerationError.failed('daxpy');
      }
      return true;
    } else if (AccelerationManager.mode == AccelerationMode.auto &&
        blas.isAvailable) {
      final success = blas.daxpy(
        n: n,
        alpha: alpha,
        x: x,
        xOffset: xOffset,
        incX: incX,
        y: y,
        yOffset: yOffset,
        incY: incY,
      );
      if (success) return true;
    }

    for (
      var i = 0, xi = xOffset, yi = yOffset;
      i < n;
      i++, xi += incX, yi += incY
    ) {
      y[yi] += alpha * x[xi];
    }
    return true;
  }

  /// Computes in-place scaled addition y = alpha * x + y for Float32List.
  static bool saxpy({
    required int n,
    required double alpha,
    required Float32List x,
    int xOffset = 0,
    int incX = 1,
    required Float32List y,
    int yOffset = 0,
    int incY = 1,
    required BlasLibrary blas,
  }) {
    if (AccelerationManager.mode == AccelerationMode.accelerated) {
      if (!blas.isAvailable) {
        throw AccelerationError.unavailable('BLAS');
      }
      final success = blas.saxpy(
        n: n,
        alpha: alpha,
        x: x,
        xOffset: xOffset,
        incX: incX,
        y: y,
        yOffset: yOffset,
        incY: incY,
      );
      if (!success) {
        throw AccelerationError.failed('saxpy');
      }
      return true;
    } else if (AccelerationManager.mode == AccelerationMode.auto &&
        blas.isAvailable) {
      final success = blas.saxpy(
        n: n,
        alpha: alpha,
        x: x,
        xOffset: xOffset,
        incX: incX,
        y: y,
        yOffset: yOffset,
        incY: incY,
      );
      if (success) return true;
    }

    for (
      var i = 0, xi = xOffset, yi = yOffset;
      i < n;
      i++, xi += incX, yi += incY
    ) {
      y[yi] += alpha * x[xi];
    }
    return true;
  }

  /// In-place scaling x = alpha * x for Float64List.
  static bool dscal({
    required int n,
    required double alpha,
    required Float64List x,
    int xOffset = 0,
    int incX = 1,
    required BlasLibrary blas,
  }) {
    if (AccelerationManager.mode == AccelerationMode.accelerated) {
      if (!blas.isAvailable) {
        throw AccelerationError.unavailable('BLAS');
      }
      final success = blas.dscal(
        n: n,
        alpha: alpha,
        x: x,
        xOffset: xOffset,
        incX: incX,
      );
      if (!success) {
        throw AccelerationError.failed('dscal');
      }
      return true;
    } else if (AccelerationManager.mode == AccelerationMode.auto &&
        blas.isAvailable) {
      final success = blas.dscal(
        n: n,
        alpha: alpha,
        x: x,
        xOffset: xOffset,
        incX: incX,
      );
      if (success) return true;
    }

    for (var i = 0, xi = xOffset; i < n; i++, xi += incX) {
      x[xi] *= alpha;
    }
    return true;
  }

  /// In-place scaling x = alpha * x for Float32List.
  static bool sscal({
    required int n,
    required double alpha,
    required Float32List x,
    int xOffset = 0,
    int incX = 1,
    required BlasLibrary blas,
  }) {
    if (AccelerationManager.mode == AccelerationMode.accelerated) {
      if (!blas.isAvailable) {
        throw AccelerationError.unavailable('BLAS');
      }
      final success = blas.sscal(
        n: n,
        alpha: alpha,
        x: x,
        xOffset: xOffset,
        incX: incX,
      );
      if (!success) {
        throw AccelerationError.failed('sscal');
      }
      return true;
    } else if (AccelerationManager.mode == AccelerationMode.auto &&
        blas.isAvailable) {
      final success = blas.sscal(
        n: n,
        alpha: alpha,
        x: x,
        xOffset: xOffset,
        incX: incX,
      );
      if (success) return true;
    }

    for (var i = 0, xi = xOffset; i < n; i++, xi += incX) {
      x[xi] *= alpha;
    }
    return true;
  }
}
