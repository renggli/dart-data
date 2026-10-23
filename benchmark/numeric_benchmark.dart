/// Comparative benchmarks for numeric and linear algebra routines.
///
/// Measures performance across two execution strategies:
/// - [AccelerationMode.dart]: forces pure Dart scalar / SIMD routines
/// - [AccelerationMode.accelerated]: forces native hardware acceleration
///   (BLAS / LAPACK / Apple vDSP & vForce via leaf direct-address `@ffi.Native`)
///
/// Run with:
/// ```sh
/// dart run benchmark/numeric_benchmark.dart [filter ...]
/// ```
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:data/acceleration.dart';
import 'package:data/linear.dart';
import 'package:data/numeric.dart';
import 'package:data/type.dart';

import 'runner.dart';

void main(List<String> arguments) {
  _suite.run(arguments, compareModes: true);
}

final _suite = BenchmarkSuite(
  name: 'Numeric Methods & Hardware Acceleration Benchmark',
  description: 'Evaluates BLAS Levels 1-3, LAPACK solvers, Apple vDSP FFTs, and vForce transcendentals.',
  specs: _buildSpecs(),
);

List<BenchmarkSpec> _buildSpecs() {
  final rng = math.Random(42);

  // Pre-allocated matrices and vectors for GEMM / GEMV / Level 1
  final m64A = Matrix<double>.generate(64, 64, (r, c) => rng.nextDouble());
  final m64B = Matrix<double>.generate(64, 64, (r, c) => rng.nextDouble());

  final m256A = Matrix<double>.generate(256, 256, (r, c) => rng.nextDouble());
  final m256B = Matrix<double>.generate(256, 256, (r, c) => rng.nextDouble());

  final m512A = Matrix<double>.generate(512, 512, (r, c) => rng.nextDouble());
  final m512B = Matrix<double>.generate(512, 512, (r, c) => rng.nextDouble());

  final m256FloatA = Matrix<double>.generate(
    256,
    256,
    (r, c) => rng.nextDouble(),
    type: DataType.float32,
  );
  final m256FloatB = Matrix<double>.generate(
    256,
    256,
    (r, c) => rng.nextDouble(),
    type: DataType.float32,
  );

  final m128A = Matrix<double>.generate(128, 128, (r, c) => rng.nextDouble());

  final m1024Mv = Matrix<double>.generate(
    1024,
    1024,
    (r, c) => rng.nextDouble(),
  );
  final v1024Mv = Vector<double>.generate(1024, (i) => rng.nextDouble());

  final m256Mv = Matrix<double>.generate(256, 256, (r, c) => rng.nextDouble());
  final v256Mv = Vector<double>.generate(256, (i) => rng.nextDouble());

  final v10kDot1 = Vector<double>.generate(10000, (i) => rng.nextDouble());
  final v10kDot2 = Vector<double>.generate(10000, (i) => rng.nextDouble());

  final v100kDot1 = Vector<double>.generate(100000, (i) => rng.nextDouble());
  final v100kDot2 = Vector<double>.generate(100000, (i) => rng.nextDouble());

  // Diagonally dominant linear system (well-conditioned for dgesv)
  final solve64Mat = Matrix<double>.generate(
    64,
    64,
    (r, c) => (r == c ? 100.0 : rng.nextDouble()),
  );
  final solve64Vec = Vector<double>.generate(64, (i) => rng.nextDouble());

  final solve128Mat = Matrix<double>.generate(
    128,
    128,
    (r, c) => (r == c ? 200.0 : rng.nextDouble()),
  );
  final solve128Vec = Vector<double>.generate(128, (i) => rng.nextDouble());

  // Overdetermined system for leastSquares (dgels)
  final lsMat = Matrix<double>.generate(200, 20, (r, c) => rng.nextDouble());
  final lsVec = Vector<double>.generate(200, (i) => rng.nextDouble());

  // Symmetric positive-definite matrix for dsyev
  final sym64 = Matrix<double>.generate(
    64,
    64,
    (r, c) => (r == c ? 50.0 + rng.nextDouble() : ((r + 1) * (c + 1)) * 0.01),
  );
  final sym128 = Matrix<double>.generate(
    128,
    128,
    (r, c) => (r == c ? 100.0 + rng.nextDouble() : ((r + 1) * (c + 1)) * 0.005),
  );

  // SVD test matrix
  final svd32 = Matrix<double>.generate(32, 32, (r, c) => rng.nextDouble());

  // FFT lists
  final fft1024 = DataType.complex.newList(1024);
  for (var i = 0; i < 1024; i++) {
    fft1024.data[2 * i] = math.sin(i * 0.05);
    fft1024.data[2 * i + 1] = math.cos(i * 0.05);
  }
  final fft16k = DataType.complex.newList(16384);
  for (var i = 0; i < 16384; i++) {
    fft16k.data[2 * i] = math.sin(i * 0.01);
    fft16k.data[2 * i + 1] = math.cos(i * 0.01);
  }
  final fft2_64 = DataType.complex.newList(64 * 64);
  for (var r = 0; r < 64; r++) {
    for (var c = 0; c < 64; c++) {
      final idx = 2 * (r * 64 + c);
      fft2_64.data[idx] = math.sin(r + c * 0.1);
      fft2_64.data[idx + 1] = math.cos(r - c * 0.1);
    }
  }
  final fft2_256 = DataType.complex.newList(256 * 256);
  for (var r = 0; r < 256; r++) {
    for (var c = 0; c < 256; c++) {
      final idx = 2 * (r * 256 + c);
      fft2_256.data[idx] = math.sin(r + c * 0.05);
      fft2_256.data[idx + 1] = math.cos(r - c * 0.05);
    }
  }

  // vForce / Transcendental arrays
  final vforceInput = Float64List.fromList(
    List<double>.generate(10000, (i) => 0.1 + (i % 100) * 0.05),
  );

  // Reductions array
  final redInput = Float64List.fromList(
    List<double>.generate(100000, (i) => rng.nextDouble()),
  );

  return [
    // -------------------------------------------------------------------------
    // BLAS Level 3: Matrix Multiplication
    // -------------------------------------------------------------------------
    BenchmarkSpec(
      name: 'dgemm 64x64',
      category: 'BLAS Level 3 (GEMM)',
      isNativeSupported: () => Blas.isAvailable,
      action: () => m64A * m64B,
      runs: 15,
      inner: 5,
    ),
    BenchmarkSpec(
      name: 'dgemm 256x256',
      category: 'BLAS Level 3 (GEMM)',
      isNativeSupported: () => Blas.isAvailable,
      action: () => m256A * m256B,
      runs: 11,
      inner: 1,
    ),
    BenchmarkSpec(
      name: 'dgemm 512x512',
      category: 'BLAS Level 3 (GEMM)',
      isNativeSupported: () => Blas.isAvailable,
      action: () => m512A * m512B,
      runs: 7,
      inner: 1,
    ),
    BenchmarkSpec(
      name: 'sgemm 256x256 (float32)',
      category: 'BLAS Level 3 (GEMM)',
      isNativeSupported: () => Blas.isAvailable,
      action: () => m256FloatA * m256FloatB,
      runs: 11,
      inner: 1,
    ),
    BenchmarkSpec(
      name: 'dsyrk 128x128',
      category: 'BLAS Level 3 (GEMM)',
      isNativeSupported: () => Blas.isAvailable,
      action: () => m128A.transposed * m128A,
      runs: 15,
      inner: 2,
    ),

    // -------------------------------------------------------------------------
    // BLAS Level 2: Matrix-Vector Multiplication
    // -------------------------------------------------------------------------
    BenchmarkSpec(
      name: 'dgemv 256x256',
      category: 'BLAS Level 2 (GEMV)',
      isNativeSupported: () => Blas.isAvailable,
      action: () => m256Mv.apply(v256Mv),
      runs: 15,
      inner: 10,
    ),
    BenchmarkSpec(
      name: 'dgemv 1024x1024',
      category: 'BLAS Level 2 (GEMV)',
      isNativeSupported: () => Blas.isAvailable,
      action: () => m1024Mv.apply(v1024Mv),
      runs: 15,
      inner: 2,
    ),

    // -------------------------------------------------------------------------
    // BLAS Level 1: Vector-Vector Operations
    // -------------------------------------------------------------------------
    BenchmarkSpec(
      name: 'ddot 10,000',
      category: 'BLAS Level 1',
      isNativeSupported: () => Blas.isAvailable,
      action: () => v10kDot1.dot(v10kDot2),
      runs: 15,
      inner: 50,
    ),
    BenchmarkSpec(
      name: 'ddot 100,000',
      category: 'BLAS Level 1',
      isNativeSupported: () => Blas.isAvailable,
      action: () => v100kDot1.dot(v100kDot2),
      runs: 15,
      inner: 10,
    ),
    BenchmarkSpec(
      name: 'dnrm2 100,000',
      category: 'BLAS Level 1',
      isNativeSupported: () => Blas.isAvailable,
      action: v100kDot1.norm,
      runs: 15,
      inner: 5,
    ),

    // -------------------------------------------------------------------------
    // LAPACK: Direct Solvers & Decompositions
    // -------------------------------------------------------------------------
    BenchmarkSpec(
      name: 'solve 64x64 (dgesv)',
      category: 'LAPACK Solvers & Decompositions',
      isNativeSupported: () => Blas.isAvailable,
      action: () => solve64Mat.solve(solve64Vec),
      runs: 15,
      inner: 5,
    ),
    BenchmarkSpec(
      name: 'solve 128x128 (dgesv)',
      category: 'LAPACK Solvers & Decompositions',
      isNativeSupported: () => Blas.isAvailable,
      action: () => solve128Mat.solve(solve128Vec),
      runs: 15,
      inner: 2,
    ),
    BenchmarkSpec(
      name: 'leastSquares 200x20 (dgels)',
      category: 'LAPACK Solvers & Decompositions',
      isNativeSupported: () => Blas.isAvailable,
      action: () => leastSquares(lsMat, lsVec),
      runs: 15,
      inner: 5,
    ),
    BenchmarkSpec(
      name: 'eigenvalue 64x64 (dsyev)',
      category: 'LAPACK Solvers & Decompositions',
      isNativeSupported: () => Blas.isAvailable,
      action: () => sym64.eigenvalue,
      runs: 15,
      inner: 2,
    ),
    BenchmarkSpec(
      name: 'eigenvalue 128x128 (dsyev)',
      category: 'LAPACK Solvers & Decompositions',
      isNativeSupported: () => Blas.isAvailable,
      action: () => sym128.eigenvalue,
      runs: 11,
      inner: 1,
    ),
    BenchmarkSpec(
      name: 'svd 32x32 (dgesvd)',
      category: 'LAPACK Solvers & Decompositions',
      isNativeSupported: () => Blas.isAvailable,
      action: () => svd32.svd,
      runs: 15,
      inner: 2,
    ),

    // -------------------------------------------------------------------------
    // Apple vDSP: Fast Fourier Transforms
    // -------------------------------------------------------------------------
    BenchmarkSpec(
      name: 'fft 1D 1,024',
      category: 'Fast Fourier Transform',
      isNativeSupported: () => Fft.isAvailable,
      action: () => Fft.fft(buffer: fft1024),
      runs: 15,
      inner: 10,
    ),
    BenchmarkSpec(
      name: 'fft 1D 16,384',
      category: 'Fast Fourier Transform',
      isNativeSupported: () => Fft.isAvailable,
      action: () => Fft.fft(buffer: fft16k),
      runs: 15,
      inner: 2,
    ),
    BenchmarkSpec(
      name: 'fft 2D 64x64',
      category: 'Fast Fourier Transform',
      isNativeSupported: () => Fft.isAvailable,
      action: () => Fft.fft2(buffer: fft2_64, rows: 64, cols: 64),
      runs: 15,
      inner: 5,
    ),
    BenchmarkSpec(
      name: 'fft 2D 256x256',
      category: 'Fast Fourier Transform',
      isNativeSupported: () => Fft.isAvailable,
      action: () => Fft.fft2(buffer: fft2_256, rows: 256, cols: 256),
      runs: 11,
      inner: 1,
    ),

    // -------------------------------------------------------------------------
    // Apple vForce: Vector Transcendentals
    // -------------------------------------------------------------------------
    BenchmarkSpec(
      name: 'vForce sin 10,000',
      category: 'Vector Transcendentals (vForce)',
      isNativeSupported: () => Vforce.isAvailable,
      action: () => Vforce.vsin(input: vforceInput),
      runs: 15,
      inner: 20,
    ),
    BenchmarkSpec(
      name: 'vForce exp 10,000',
      category: 'Vector Transcendentals (vForce)',
      isNativeSupported: () => Vforce.isAvailable,
      action: () => Vforce.vexp(input: vforceInput),
      runs: 15,
      inner: 20,
    ),
    BenchmarkSpec(
      name: 'vForce log 10,000',
      category: 'Vector Transcendentals (vForce)',
      isNativeSupported: () => Vforce.isAvailable,
      action: () => Vforce.vlog(input: vforceInput),
      runs: 15,
      inner: 20,
    ),
    BenchmarkSpec(
      name: 'vForce sqrt 10,000',
      category: 'Vector Transcendentals (vForce)',
      isNativeSupported: () => Vforce.isAvailable,
      action: () => Vforce.vsqrt(input: vforceInput),
      runs: 15,
      inner: 20,
    ),

    // -------------------------------------------------------------------------
    // Apple vDSP: Vector Reductions
    // -------------------------------------------------------------------------
    BenchmarkSpec(
      name: 'vectorSum 100,000',
      category: 'Vector Reductions (vDSP)',
      isNativeSupported: () => Vforce.isAvailable,
      action: () => Vforce.sum(x: redInput),
      runs: 15,
      inner: 20,
    ),
    BenchmarkSpec(
      name: 'vectorMean 100,000',
      category: 'Vector Reductions (vDSP)',
      isNativeSupported: () => Vforce.isAvailable,
      action: () => Vforce.mean(x: redInput),
      runs: 15,
      inner: 20,
    ),
  ];
}
