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
| `dgemm 64x64` | BLAS Level 3 (GEMM) | 151 | [149, 154] | 11.0 | [10.4, 15.4] | **13.7×** |
| `dgemm 256x256` | BLAS Level 3 (GEMM) | 8,600 | [8,529, 8,945] | 125 | [123, 127] | **68.8×** |
| `dgemm 512x512` | BLAS Level 3 (GEMM) | 71,038 | [70,760, 71,544] | 647 | [475, 800] | **109.8×** |
| `sgemm 256x256 (float32)` | BLAS Level 3 (GEMM) | 9,915 | [9,831, 10,127] | 114 | [63.0, 172] | **87.0×** |
| `dsyrk 128x128` | BLAS Level 3 (GEMM) | 1,133 | [1,104, 1,213] | 21.0 | [21.0, 21.5] | **54.0×** |
| `dgemv 256x256` | BLAS Level 2 (GEMV) | 207 | [204, 219] | 3.90 | [3.80, 4.30] | **53.0×** |
| `dgemv 1024x1024` | BLAS Level 2 (GEMV) | 3,273 | [3,251, 3,300] | 34.0 | [34.0, 34.0] | **96.3×** |
| `ddot 10,000` | BLAS Level 1 | 6.80 | [6.72, 7.32] | 0.94 | [0.94, 0.96] | **7.2×** |
| `ddot 100,000` | BLAS Level 1 | 64.1 | [63.0, 65.3] | 2.90 | [2.90, 2.90] | **22.1×** |
| `dnrm2 100,000` | BLAS Level 1 | 151 | [144, 158] | 21.2 | [21.2, 21.2] | **7.1×** |
| `solve 64x64 (dgesv)` | LAPACK Solvers & Decompositions | 76.0 | [75.6, 86.0] | 37.4 | [36.4, 39.6] | **2.0×** |
| `solve 128x128 (dgesv)` | LAPACK Solvers & Decompositions | 495 | [490, 507] | 82.0 | [81.5, 82.5] | **6.0×** |
| `leastSquares 200x20 (dgels)` | LAPACK Solvers & Decompositions | 88.4 | [79.2, 89.8] | 50.8 | [50.2, 61.0] | **1.7×** |
| `eigenvalue 64x64 (dsyev)` | LAPACK Solvers & Decompositions | 567 | [553, 590] | 299 | [298, 335] | **1.9×** |
| `eigenvalue 128x128 (dsyev)` | LAPACK Solvers & Decompositions | 4,314 | [4,175, 4,361] | 1,487 | [1,473, 1,574] | **2.9×** |
| `svd 32x32 (dgesvd)` | LAPACK Solvers & Decompositions | 172 | [171, 175] | 166 | [150, 205] | **1.0×** |
| `fft 1D 1,024` | Fast Fourier Transform | 11.7 | [10.5, 12.2] | 2.00 | [2.00, 2.10] | **5.8×** |
| `fft 1D 16,384` | Fast Fourier Transform | 231 | [230, 245] | 140 | [130, 211] | **1.7×** |
| `fft 2D 64x64` | Fast Fourier Transform | 63.0 | [62.4, 66.6] | 18.4 | [17.8, 18.6] | **3.4×** |
| `fft 2D 256x256` | Fast Fourier Transform | 1,465 | [1,385, 1,476] | 454 | [452, 471] | **3.2×** |
| `vForce sin 10,000` | Vector Transcendentals (vForce) | 25.1 | [24.1, 25.8] | 9.70 | [9.60, 10.2] | **2.6×** |
| `vForce exp 10,000` | Vector Transcendentals (vForce) | 20.5 | [20.3, 20.9] | 12.3 | [12.0, 13.7] | **1.7×** |
| `vForce log 10,000` | Vector Transcendentals (vForce) | 22.9 | [22.4, 24.1] | 12.3 | [12.3, 14.3] | **1.9×** |
| `vForce sqrt 10,000` | Vector Transcendentals (vForce) | 6.20 | [6.10, 6.35] | 4.35 | [4.20, 5.65] | **1.4×** |
| `vectorSum 100,000` | Vector Reductions (vDSP) | 59.2 | [58.2, 60.7] | 8.70 | [8.70, 8.95] | **6.8×** |
| `vectorMean 100,000` | Vector Reductions (vDSP) | 59.2 | [58.2, 61.7] | 8.70 | [8.65, 8.95] | **6.8×** |

### 2. Symbolic Subsystem (`symbolic`)

Evaluates exact AST manipulation, canonical simplification, Taylor series expansion, symbolic integration, polynomial factorization, symbolic determinants, and multivariate polynomial system solving (Gröbner basis via Buchberger with Sugar strategy and FGLM).

| Benchmark | Category | Median (µs) | 95% CI (µs) | Min–Max (µs) |
| --- | --- | ---: | ---: | ---: |
| `expand((x+y+z+1)^12)` | Algebraic Expansion | 2,491 | [2,381, 2,646] | 2,166–3,424 |
| `series(exp(sin(x)), x, 0, 20)` | Series & Calculus | 109 | [108, 110] | 103–141 |
| `det 6x6 symbolic` | Symbolic Linear Algebra | 28,812 | [28,604, 28,893] | 28,225–29,702 |
| `integrate corpus (45)` | Series & Calculus | 614 | [521, 723] | 476–1,218 |
| `simplify corpus (80)` | Simplification | 96.0 | [94.2, 101] | 87.3–185 |
| `factor(x^24 - 1)` | Polynomial Factorization | 19.5 | [18.7, 21.4] | 17.6–29.5 |
| `solvePolynomialSystem katsura-2` | Gröbner Basis Systems | 1,267 | [1,173, 1,334] | 959–2,079 |
| `solvePolynomialSystem katsura-3` | Gröbner Basis Systems | 5,598 | [4,271, 9,494] | 4,271–9,494 |

#### Historical Comparison (Pre- vs Post-Refactoring)

Comparison against the original baseline captured before the numeric-tower and N-ary AST refactoring:

| Benchmark | Baseline VM (µs) | Latest VM (µs) | 95% CI (µs) | VM Speedup |
| --- | ---: | ---: | ---: | ---: |
| `expand((x+y+z+1)^12)` | 6,679 | 2,491 | [2,381, 2,646] | **2.7×** |
| `series(exp(sin(x)), x, 0, 20)` | 74 | 109 | [108, 110] | **0.7×** |
| `det` 6×6 symbolic (`(r+1)^c + x^((r+c)%3)*y`) | 638,445 | 28,812 | [28,604, 28,893] | **22.2×** |
| `integrate` corpus (45 integrands) | 194 | 614 | [521, 723] | **0.3×** |
| `simplify` corpus (80 expressions) | 53 | 96.0 | [94.2, 101] | **0.6×** |
| `factor(x^24 - 1)` | 32 | 19.5 | [18.7, 21.4] | **1.6×** |
| `solvePolynomialSystem` Katsura-2 | 922 | 1,267 | [1,173, 1,334] | **0.7×** |
| `solvePolynomialSystem` Katsura-3 | 3,860,962 | 5,598 | [4,271, 9,494] | **689.7×** |

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
