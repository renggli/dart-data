/// Transparent acceleration via native BLAS/LAPACK, Dart SIMD vector operations,
/// and pure Dart fallbacks.
///
/// Provides access to low-level hardware performance for compute-intensive numerical
/// operations. Automatically routes matrix and vector operations to native BLAS/LAPACK
/// dynamic libraries via Dart FFI on desktop and server platforms, uses 128-bit SIMD
/// ([SimdEngine]) for vectorized arithmetic, and provides cache-tiled pure Dart fallbacks
/// on platforms where native FFI is unavailable (such as web environments).
///
/// Execution modes can be configured via [AccelerationMode]:
/// - [AccelerationMode.auto]: uses the fastest approach available (default).
/// - [AccelerationMode.accelerated]: forces native BLAS/LAPACK execution and throws
///   [StateError] if unavailable (no silent fallback).
/// - [AccelerationMode.dart]: forces pure Dart execution for benchmarking and portability.
///
/// ## Core Components
///
/// - [AccelerationManager]: Central coordinator for acceleration, providing Level 1
///   (dot product, norm, axpy), Level 2 (matrix-vector products), and Level 3 (general matrix
///   multiplication GEMM, symmetric rank-$k$ updates) routines, along with LAPACK solvers.
/// - [SimdEngine]: 128-bit vector arithmetic using `Float32x4` instructions for fast
///   element-wise addition, subtraction, multiplication, and dot products.
/// - [AccelerationMode]: Enum specifying execution strategy (`auto`, `accelerated`, `dart`).
///
/// ## Example
///
/// ```dart
/// import 'dart:typed_data';
/// import 'package:data/acceleration.dart';
///
/// void main() {
///   print('Native acceleration available: ${AccelerationManager.isAccelerated}');
///
///   final a = Float64List.fromList([1.0, 2.0, 3.0, 4.0]);
///   final b = Float64List.fromList([5.0, 6.0, 7.0, 8.0]);
///   final c = Float64List(4);
///
///   // Perform C = 1.0 * A * B + 0.0 * C
///   AccelerationManager.dgemm(
///     m: 2, n: 2, k: 2,
///     alpha: 1.0, a: a, lda: 2,
///     b: b, ldb: 2,
///     beta: 0.0, c: c, ldc: 2,
///   );
///   print(c);
/// }
/// ```
library;

import 'src/acceleration/acceleration_manager.dart';
import 'src/acceleration/acceleration_mode.dart';
import 'src/acceleration/fallback/simd.dart';

export 'src/acceleration/acceleration_manager.dart';
export 'src/acceleration/acceleration_mode.dart';
export 'src/acceleration/blas/cblas.dart';
export 'src/acceleration/fallback/simd.dart';
