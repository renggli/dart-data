/// Transparent acceleration via native BLAS/LAPACK, Apple vForce/vDSP, and
/// optimized pure Dart fallbacks.
///
/// Provides access to low-level hardware performance for compute-intensive
/// numerical operations. Automatically routes linear algebra, transforms, and
/// elementwise operations to native libraries via Dart FFI on desktop and server
/// platforms, and provides cache-tiled pure Dart fallbacks on platforms where
/// native FFI is unavailable (such as web environments).
///
/// Execution modes can be configured via [AccelerationMode]:
/// - [AccelerationMode.auto]: uses the fastest approach available (default).
/// - [AccelerationMode.accelerated]: forces native execution and throws
///   [AccelerationUnavailableError] if unavailable (no silent fallback).
/// - [AccelerationMode.dart]: forces pure Dart execution for benchmarking and
///   portability.
///
/// ## Core Components
///
/// - [Blas]: Basic Linear Algebra Subprograms covering vector-vector (Level 1),
///   matrix-vector (Level 2), and general matrix-matrix multiplication (Level 3).
/// - [Lapack]: Linear system solvers, matrix factorizations (Cholesky, LU, QR),
///   and eigenvalue/eigenvector decompositions.
/// - [Fft]: In-place 1D and 2D complex Fourier transforms on [Float64ComplexList],
///
/// - [Vforce]: Elementwise transcendental functions (sin, cos, exp, log, sqrt, pow),
///   vector reductions (sum, mean, variance), and 1D signal convolutions.
/// - [AccelerationManager]: Subsystem coordinator controlling [AccelerationMode]
///   and querying hardware acceleration availability flags.
/// - [Float64ComplexList]: Contiguous typed complex list backing zero-allocation
///   interleaved/split complex Fourier transforms.
/// - [AccelerationError]: Base class for exceptions thrown when accelerated
///   execution fails or is unavailable.
/// - [AccelerationUnavailableError]: Dedicated exception thrown when hardware
///   acceleration is requested in [AccelerationMode.accelerated] but is
///   unavailable.
/// - [AccelerationFailedError]: Dedicated exception thrown when native hardware
///   execution fails.
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
///   Blas.dgemm(
///     m: 2, n: 2, k: 2,
///     alpha: 1.0, a: a, lda: 2,
///     b: b, ldb: 2,
///     beta: 0.0, c: c, ldc: 2,
///   );
///   print(c);
/// }
/// ```
library;

import 'src/acceleration/acceleration_error.dart';
import 'src/acceleration/acceleration_manager.dart';
import 'src/acceleration/acceleration_mode.dart';
import 'src/acceleration/blas/blas.dart';
import 'src/acceleration/fft/fft.dart';
import 'src/acceleration/lapack/lapack.dart';
import 'src/acceleration/vforce/vforce.dart';
import 'src/type/types/complex.dart';

export 'src/acceleration/acceleration_error.dart';
export 'src/acceleration/acceleration_manager.dart';
export 'src/acceleration/acceleration_mode.dart';
export 'src/acceleration/blas/blas.dart';
export 'src/acceleration/fft/fft.dart';
export 'src/acceleration/lapack/lapack.dart';
export 'src/acceleration/vforce/vforce.dart';
export 'src/type/types/complex.dart' show Float64ComplexList;
