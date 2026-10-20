# Numeric Acceleration Benchmark Baseline

Captured on macOS (Apple Silicon), Dart 3.13 VM (JIT via `dart run`).

## Running the Benchmark

```sh
# Run all numeric benchmarks
dart run benchmark/numeric_benchmark.dart

# Filter by category or name substring
dart run benchmark/numeric_benchmark.dart gemm
dart run benchmark/numeric_benchmark.dart fft
dart run benchmark/numeric_benchmark.dart solve
```

Every benchmark executes untimed warmup iterations first, then evaluates timed runs under:
1. `AccelerationMode.dart` (forcing pure Dart scalar / SIMD execution).
2. `AccelerationMode.accelerated` (forcing native BLAS / LAPACK / Apple vDSP & vForce execution via leaf `@ffi.Native` direct-address bindings).

Confidence intervals (95%) are computed non-parametrically using 1,000 bootstrap resamples on the measured per-run samples via `Bootstrap` in `package:data/stats.dart`.

## Benchmark Results

| Benchmark | Category | Pure Dart (µs) | Dart 95% CI | Native (µs) | Native 95% CI | Speedup |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| `dgemm 64x64` | BLAS Level 3 (GEMM) | 155 | [153, 160] | 8.80 | [8.80, 9.00] | **17.6×** |
| `dgemm 256x256` | BLAS Level 3 (GEMM) | 9,279 | [9,148, 9,433] | 135 | [128, 144] | **68.7×** |
| `dgemm 512x512` | BLAS Level 3 (GEMM) | 74,378 | [73,935, 74,702] | 492 | [457, 497] | **151.2×** |
| `sgemm 256x256 (float32)` | BLAS Level 3 (GEMM) | 10,521 | [10,331, 10,639] | 54.0 | [49.0, 55.0] | **194.8×** |
| `dsyrk 128x128` | BLAS Level 3 (GEMM) | 1,189 | [1,155, 1,332] | 22.5 | [22.0, 23.5] | **52.8×** |
| `dgemv 256x256` | BLAS Level 2 (GEMV) | 179 | [172, 182] | 3.50 | [3.50, 4.10] | **51.1×** |
| `dgemv 1024x1024` | BLAS Level 2 (GEMV) | 2,769 | [2,720, 2,806] | 36.0 | [35.5, 36.5] | **76.9×** |
| `ddot 10,000` | BLAS Level 1 | 9.64 | [9.56, 10.2] | 0.78 | [0.78, 0.80] | **12.4×** |
| `ddot 100,000` | BLAS Level 1 | 96.1 | [95.5, 97.4] | 2.70 | [2.70, 2.70] | **35.6×** |
| `dnrm2 100,000` | BLAS Level 1 | 69.4 | [68.8, 72.0] | 20.6 | [20.4, 21.0] | **3.4×** |
| `solve 64x64 (dgesv)` | LAPACK Solvers & Decompositions | 75.6 | [74.8, 78.2] | 41.4 | [40.0, 43.6] | **1.8×** |
| `solve 128x128 (dgesv)` | LAPACK Solvers & Decompositions | 545 | [536, 612] | 118 | [118, 123] | **4.6×** |
| `leastSquares 200x20 (dgels)` | LAPACK Solvers & Decompositions | 192 | [190, 197] | 47.2 | [46.8, 48.2] | **4.1×** |
| `eigenvalue 64x64 (dsyev)` | LAPACK Solvers & Decompositions | 2,120 | [2,084, 2,148] | 290 | [287, 304] | **7.3×** |
| `eigenvalue 128x128 (dsyev)` | LAPACK Solvers & Decompositions | 16,579 | [16,535, 16,725] | 1,578 | [1,570, 1,623] | **10.5×** |
| `svd 32x32 (dgesvd)` | LAPACK Solvers & Decompositions | 512 | [493, 713] | 504 | [499, 526] | **1.0×** |
| `fft 1D 1,024` | Fast Fourier Transform (vDSP) | 132 | [126, 137] | 13.9 | [13.7, 16.3] | **9.5×** |
| `fft 1D 16,384` | Fast Fourier Transform (vDSP) | 3,560 | [3,496, 3,860] | 221 | [220, 226] | **16.1×** |
| `fft 2D 64x64` | Fast Fourier Transform (vDSP) | 701 | [689, 717] | 66.8 | [66.2, 68.2] | **10.5×** |
| `fft 2D 256x256` | Fast Fourier Transform (vDSP) | 25,079 | [19,751, 26,197] | 3,177 | [3,127, 4,972] | **7.9×** |
| `vForce sin 10,000` | Vector Transcendentals (vForce) | 24.6 | [24.4, 36.5] | 9.55 | [9.45, 10.0] | **2.6×** |
| `vForce exp 10,000` | Vector Transcendentals (vForce) | 19.6 | [19.6, 19.9] | 12.7 | [12.2, 12.9] | **1.6×** |
| `vForce log 10,000` | Vector Transcendentals (vForce) | 23.8 | [22.7, 24.5] | 12.0 | [11.8, 12.9] | **2.0×** |
| `vForce sqrt 10,000` | Vector Transcendentals (vForce) | 5.85 | [5.55, 5.85] | 4.30 | [4.20, 5.20] | **1.4×** |
| `vectorSum 100,000` | Vector Reductions (vDSP) | 58.0 | [57.8, 58.9] | 8.45 | [8.40, 8.80] | **6.9×** |
| `vectorMean 100,000` | Vector Reductions (vDSP) | 59.8 | [58.6, 61.7] | 8.45 | [8.40, 8.45] | **7.1×** |
