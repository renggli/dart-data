# Benchmarks & CAS Diagnostic Suites

This directory contains command-line benchmark and diagnostic runners for evaluating the performance and mathematical completeness of `package:data`:

- **`bin/benchmark_runner.dart`** (suites in `bin/benchmark_suites/`): Measures execution speed and hardware acceleration speedups across numeric linear algebra, Fast Fourier Transforms, vector transcendentals, and symbolic computer algebra workloads, reporting median times and non-parametric 95% bootstrap confidence intervals.
- **`bin/cas_runner.dart`** (suites in `bin/cas_suites/`): Evaluates symbolic correctness across external Computer Algebra System corpora (Wester's 1999 CAS benchmark, Gruntz's 1996 limit thesis suite, SymPy algebra/series/summation/product/solver suites, and the external `sympy/integration-test-suites` integration and differentiation corpora).

---

## Performance Benchmarks (`bin/benchmark_runner.dart`)

Captured on macOS (Apple Silicon), Dart 3.14 VM (JIT via `dart run`).

### Running the Performance Benchmarks

```sh
# Run all benchmark suites (numeric and symbolic)
dart run bin/benchmark_runner.dart

# Run only a specific suite (-s / --suite)
dart run bin/benchmark_runner.dart -s numeric
dart run bin/benchmark_runner.dart -s symbolic

# Filter workloads by name or category pattern (-t / --test or positional args)
dart run bin/benchmark_runner.dart gemm
dart run bin/benchmark_runner.dart fft
dart run bin/benchmark_runner.dart katsura

# Print only the markdown summary tables (-q / --quiet)
dart run bin/benchmark_runner.dart -q
```

Every workload executes untimed warmup iterations first, followed by timed sample runs. Confidence intervals (95%) are computed non-parametrically using 1,000 bootstrap resamples of the sample median via `Bootstrap` in `package:data/stats.dart`.

### 1. Numeric Methods & Hardware Acceleration (`numeric`)

Evaluates every workload under two execution modes:

1. `AccelerationMode.dart` (forcing pure Dart scalar / SIMD execution).
2. `AccelerationMode.accelerated` (forcing native BLAS / LAPACK / Apple vDSP & vForce execution via leaf `@ffi.Native` direct-address bindings).

| Benchmark | Category | Pure Dart (µs) | Dart 95% CI | Native (µs) | Native 95% CI | Speedup |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| `dgemm 64x64` | BLAS Level 3 (GEMM) | 151 | [147, 159] | 25.4 | [10.6, 33.2] | **5.9×** |
| `dgemm 256x256` | BLAS Level 3 (GEMM) | 9,241 | [8,817, 9,321] | 128 | [126, 136] | **72.2×** |
| `dgemm 512x512` | BLAS Level 3 (GEMM) | 71,556 | [71,109, 72,744] | 445 | [437, 741] | **160.8×** |
| `sgemm 256x256 (float32)` | BLAS Level 3 (GEMM) | 9,855 | [9,778, 9,913] | 53.0 | [48.0, 57.0] | **185.9×** |
| `dsyrk 128x128` | BLAS Level 3 (GEMM) | 1,135 | [1,126, 1,193] | 21.5 | [21.0, 22.0] | **52.8×** |
| `dgemv 256x256` | BLAS Level 2 (GEMV) | 206 | [200, 212] | 3.70 | [3.70, 3.80] | **55.7×** |
| `dgemv 1024x1024` | BLAS Level 2 (GEMV) | 3,335 | [3,312, 3,384] | 38.5 | [36.5, 44.0] | **86.6×** |
| `ddot 10,000` | BLAS Level 1 | 7.52 | [7.36, 7.94] | 0.98 | [0.94, 1.12] | **7.7×** |
| `ddot 100,000` | BLAS Level 1 | 64.8 | [63.7, 66.3] | 2.90 | [2.80, 2.90] | **22.3×** |
| `dnrm2 100,000` | BLAS Level 1 | 314 | [302, 327] | 21.2 | [21.2, 21.2] | **14.8×** |
| `solve 64x64 (dgesv)` | LAPACK Solvers & Decompositions | 85.8 | [79.2, 89.2] | 36.4 | [35.4, 38.2] | **2.4×** |
| `solve 128x128 (dgesv)` | LAPACK Solvers & Decompositions | 506 | [500, 518] | 87.5 | [84.0, 91.0] | **5.8×** |
| `leastSquares 200x20 (dgels)` | LAPACK Solvers & Decompositions | 77.8 | [72.4, 95.0] | 54.2 | [50.4, 79.6] | **1.4×** |
| `eigenvalue 64x64 (dsyev)` | LAPACK Solvers & Decompositions | 560 | [551, 592] | 311 | [303, 351] | **1.8×** |
| `eigenvalue 128x128 (dsyev)` | LAPACK Solvers & Decompositions | 4,323 | [4,071, 4,452] | 1,533 | [1,495, 1,610] | **2.8×** |
| `svd 32x32 (dgesvd)` | LAPACK Solvers & Decompositions | 165 | [163, 173] | 162 | [150, 207] | **1.0×** |
| `fft 1D 1,024` | Fast Fourier Transform | 13.5 | [12.5, 14.2] | 2.30 | [2.20, 2.60] | **5.9×** |
| `fft 1D 16,384` | Fast Fourier Transform | 278 | [273, 296] | 185 | [180, 229] | **1.5×** |
| `fft 2D 64x64` | Fast Fourier Transform | 62.8 | [61.4, 64.4] | 23.4 | [20.8, 24.2] | **2.7×** |
| `fft 2D 256x256` | Fast Fourier Transform | 1,414 | [1,377, 1,468] | 454 | [448, 471] | **3.1×** |
| `vForce sin 10,000` | Vector Transcendentals (vForce) | 26.6 | [26.3, 27.1] | 9.70 | [9.60, 10.7] | **2.7×** |
| `vForce exp 10,000` | Vector Transcendentals (vForce) | 20.6 | [20.4, 21.4] | 11.4 | [11.4, 11.6] | **1.8×** |
| `vForce log 10,000` | Vector Transcendentals (vForce) | 23.7 | [23.3, 24.1] | 11.8 | [11.7, 12.3] | **2.0×** |
| `vForce sqrt 10,000` | Vector Transcendentals (vForce) | 6.10 | [6.05, 6.35] | 3.75 | [3.75, 3.80] | **1.6×** |
| `vectorSum 100,000` | Vector Reductions (vDSP) | 58.4 | [58.3, 58.9] | 7.90 | [7.85, 8.10] | **7.4×** |
| `vectorMean 100,000` | Vector Reductions (vDSP) | 58.5 | [58.1, 60.2] | 7.85 | [7.85, 7.90] | **7.5×** |

### 2. Symbolic Subsystem (`symbolic`)

Evaluates exact AST manipulation, canonical simplification, Taylor series expansion, symbolic differentiation/integration/limits, polynomial factorization, symbolic determinants, multivariate polynomial system solving (Gröbner basis via Buchberger with Sugar strategy and FGLM), parsing/formatting, and flat bytecode VM evaluation.

| Benchmark | Category | Median (µs) | 95% CI (µs) | Min–Max (µs) |
| --- | --- | ---: | ---: | ---: |
| `expand((x+y+z+1)^12)` | Algebraic Expansion | 1,218 | [806, 1,542] | 425–3,131 |
| `series(exp(sin(x)), x, 0, 20)` | Series & Calculus | 78.8 | [78.1, 80.9] | 74.9–147 |
| `det 6x6 symbolic` | Symbolic Linear Algebra | 13,224 | [10,993, 14,716] | 9,485–18,459 |
| `differentiate corpus (50)` | Series & Calculus | 227 | [216, 238] | 204–276 |
| `limit corpus (12)` | Series & Calculus | 1,239 | [1,141, 1,573] | 1,031–1,874 |
| `integrate corpus (45)` | Series & Calculus | 642 | [607, 758] | 556–1,254 |
| `simplify corpus (80)` | Simplification | 102 | [100, 110] | 94.9–170 |
| `parse + format (80)` | Parsing & Formatting | 344 | [332, 383] | 319–495 |
| `bytecode eval1D real (100k)` | Bytecode VM | 5,851 | [5,817, 5,897] | 5,672–6,089 |
| `bytecode eval1D complex (10k)` | Bytecode VM | 1,921 | [1,917, 1,938] | 1,874–2,009 |
| `bytecode evalVector (10k)` | Bytecode VM | 695 | [691, 705] | 687–745 |
| `factor(x^24 - 1)` | Polynomial Factorization | 18.9 | [17.8, 20.9] | 16.5–34.5 |
| `solvePolynomialSystem katsura-2` | Gröbner Basis Systems | 1,300 | [1,237, 1,555] | 1,117–2,806 |
| `solvePolynomialSystem katsura-3` | Gröbner Basis Systems | 2,784 | [2,371, 3,036] | 2,371–3,036 |

---

## CAS Diagnostic Benchmark Suites (`bin/cas_runner.dart`)

### Running the CAS Suites

```sh
# Run the built-in CAS benchmark suites
dart run bin/cas_runner.dart -s "wester|gruntz|algebra|series|solvers"

# Run external SymPy integration and differentiation corpora (clones on demand)
dart run bin/cas_runner.dart -s "_integrate"
dart run bin/cas_runner.dart -s "_differentiate"

# Filter individual cases and print quiet summary
dart run bin/cas_runner.dart -q -t "gruntz_8"
```

### Built-in CAS Suite Results

| Suite | Description | Cases | Passed | Pass Rate |
| --- | --- | ---: | ---: | ---: |
| `wester` | Michael Wester (1999) CAS Benchmark Suite | 107 | 107 | **100.0%** |
| `gruntz_limits` | Dominik Gruntz (1996) ETH Thesis & SymPy Limit Suite | 57 | 57 | **100.0%** |
| `algebra` | SymPy Simplify, Radsimp, Trigsimp & Polytools Suite | 55 | 55 | **100.0%** |
| `series_sums_products` | SymPy Power Series, Summations & Products Suite | 54 | 54 | **100.0%** |
| `solvers_linear` | SymPy Solvers, ODEs, Multivariable Calculus & Matrices Suite | 26 | 26 | **100.0%** |
| **Total** | **All Built-in CAS Suites** | **299** | **299** | **100.0%** |
