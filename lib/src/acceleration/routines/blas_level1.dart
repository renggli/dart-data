import 'dart:typed_data';

import '../blas/cblas.dart';
import '../fallback/pure_dart_blas1.dart';
import 'dispatcher.dart';

/// BLAS Level 1 vector-vector routines.
abstract final class BlasLevel1 {
  /// Computes dot product of two [Float64List] vectors.
  static double? ddot({
    required int n,
    required Float64List x,
    int xOffset = 0,
    int incX = 1,
    required Float64List y,
    int yOffset = 0,
    int incY = 1,
    required BlasLibrary blas,
  }) => executeAccelerated(
    feature: 'BLAS',
    operation: 'ddot',
    isAvailable: blas.isAvailable,
    accelerate: () => blas.ddot(
      n: n,
      x: x,
      xOffset: xOffset,
      incX: incX,
      y: y,
      yOffset: yOffset,
      incY: incY,
    ),
    fallback: () => PureDartBlas1.ddot(
      n: n,
      x: x,
      xOffset: xOffset,
      incX: incX,
      y: y,
      yOffset: yOffset,
      incY: incY,
    ),
  );

  /// Computes dot product of two [Float32List] vectors.
  static double? sdot({
    required int n,
    required Float32List x,
    int xOffset = 0,
    int incX = 1,
    required Float32List y,
    int yOffset = 0,
    int incY = 1,
    required BlasLibrary blas,
  }) => executeAccelerated(
    feature: 'BLAS',
    operation: 'sdot',
    isAvailable: blas.isAvailable,
    accelerate: () => blas.sdot(
      n: n,
      x: x,
      xOffset: xOffset,
      incX: incX,
      y: y,
      yOffset: yOffset,
      incY: incY,
    ),
    fallback: () => PureDartBlas1.sdot(
      n: n,
      x: x,
      xOffset: xOffset,
      incX: incX,
      y: y,
      yOffset: yOffset,
      incY: incY,
    ),
  );

  /// Computes Euclidean norm of a [Float64List] vector.
  static double? dnrm2({
    required int n,
    required Float64List x,
    int xOffset = 0,
    int incX = 1,
    required BlasLibrary blas,
  }) => executeAccelerated(
    feature: 'BLAS',
    operation: 'dnrm2',
    isAvailable: blas.isAvailable,
    accelerate: () => blas.dnrm2(n: n, x: x, xOffset: xOffset, incX: incX),
    fallback: () =>
        PureDartBlas1.dnrm2(n: n, x: x, xOffset: xOffset, incX: incX),
  );

  /// Computes Euclidean norm of a [Float32List] vector.
  static double? snrm2({
    required int n,
    required Float32List x,
    int xOffset = 0,
    int incX = 1,
    required BlasLibrary blas,
  }) => executeAccelerated(
    feature: 'BLAS',
    operation: 'snrm2',
    isAvailable: blas.isAvailable,
    accelerate: () => blas.snrm2(n: n, x: x, xOffset: xOffset, incX: incX),
    fallback: () =>
        PureDartBlas1.snrm2(n: n, x: x, xOffset: xOffset, incX: incX),
  );

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
    required BlasLibrary blas,
  }) => executeAcceleratedOperation(
    feature: 'BLAS',
    operation: 'daxpy',
    isAvailable: blas.isAvailable,
    accelerate: () => blas.daxpy(
      n: n,
      alpha: alpha,
      x: x,
      xOffset: xOffset,
      incX: incX,
      y: y,
      yOffset: yOffset,
      incY: incY,
    ),
    fallback: () => PureDartBlas1.daxpy(
      n: n,
      alpha: alpha,
      x: x,
      xOffset: xOffset,
      incX: incX,
      y: y,
      yOffset: yOffset,
      incY: incY,
    ),
  );

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
    required BlasLibrary blas,
  }) => executeAcceleratedOperation(
    feature: 'BLAS',
    operation: 'saxpy',
    isAvailable: blas.isAvailable,
    accelerate: () => blas.saxpy(
      n: n,
      alpha: alpha,
      x: x,
      xOffset: xOffset,
      incX: incX,
      y: y,
      yOffset: yOffset,
      incY: incY,
    ),
    fallback: () => PureDartBlas1.saxpy(
      n: n,
      alpha: alpha,
      x: x,
      xOffset: xOffset,
      incX: incX,
      y: y,
      yOffset: yOffset,
      incY: incY,
    ),
  );

  /// In-place scaling `x = alpha * x` for [Float64List].
  static bool dscal({
    required int n,
    required double alpha,
    required Float64List x,
    int xOffset = 0,
    int incX = 1,
    required BlasLibrary blas,
  }) => executeAcceleratedOperation(
    feature: 'BLAS',
    operation: 'dscal',
    isAvailable: blas.isAvailable,
    accelerate: () =>
        blas.dscal(n: n, alpha: alpha, x: x, xOffset: xOffset, incX: incX),
    fallback: () => PureDartBlas1.dscal(
      n: n,
      alpha: alpha,
      x: x,
      xOffset: xOffset,
      incX: incX,
    ),
  );

  /// In-place scaling `x = alpha * x` for [Float32List].
  static bool sscal({
    required int n,
    required double alpha,
    required Float32List x,
    int xOffset = 0,
    int incX = 1,
    required BlasLibrary blas,
  }) => executeAcceleratedOperation(
    feature: 'BLAS',
    operation: 'sscal',
    isAvailable: blas.isAvailable,
    accelerate: () =>
        blas.sscal(n: n, alpha: alpha, x: x, xOffset: xOffset, incX: incX),
    fallback: () => PureDartBlas1.sscal(
      n: n,
      alpha: alpha,
      x: x,
      xOffset: xOffset,
      incX: incX,
    ),
  );
}
