# Implementation Roadmap & Task Specifications

This document defines the actionable engineering task list for `package:data`.

## Tasks

- [x] Apache Arrow C Data Interface & IPC Stream Export
- [x] Apache Arrow UTF-8 String Offset Buffer (`ArrowStringSeries`)
- [ ] Sort-Merge Relational Join
- [ ] Streaming CSV & JSON Parsers
- [ ] Modularize Implementation Files (Single Responsibility, Low Coupling, High Cohesion)
- [ ] Parallel Unit Test Hierarchy & Comprehensive Coverage (Target Near 100%)
- [ ] Backend Acceleration Parity, Dedicated Modes (Auto, Accelerated, Dart) & Verification
- [ ] Hardware Acceleration for FFT, Signal Processing & Vectorized Operations
- [ ] Consistent 80-Character Comment Formatting & Doc Reflow

---

### [x] Apache Arrow C Data Interface & IPC Stream Export

- **Problem / Goal**:
  Sharing DataFrames with external engines in Python (Polars, pandas, PyArrow) or DuckDB requires slow serialization to disk CSV or JSON files.
- **The Win**:
  - Zero-copy in-memory exchange via standard ABI `ArrowSchema` and `ArrowArray` FFI structs.
- **Target Files**:
  - `lib/src/dataframe/arrow_c_data.dart` (new)
  - `lib/src/dataframe/arrow_ipc.dart` (new)
  - `lib/dataframe.dart`
  - `test/dataframe/arrow_c_data_test.dart` (new)
- **Step-by-Step Implementation Details**:
  1. In `lib/src/dataframe/arrow_c_data.dart`, define `dart:ffi` Struct representations for `ArrowSchema` and `ArrowArray`.
  2. Implement `exportToArrowC(Pointer<ArrowArray> outArray, Pointer<ArrowSchema> outSchema)`:
     - Map `TypedSeries` memory buffers directly to pointers in `buffers` array.
     - Pass `validityMask.buffer` as buffer 0 and data memory as buffer 1.
     - Wire `release` callback to maintain Dart object references until freed by native consumer.
  3. Add tests verifying C struct layout compliance and pointer exports.

---

### [ ] Apache Arrow UTF-8 String Offset Buffer (`ArrowStringSeries`)

- **Problem / Goal**:
  `StringSeries` stores individual Dart `String` instances on the garbage-collected heap, consuming large amounts of memory and preventing zero-copy Arrow serialization.
- **The Win**:
  - Apache Arrow-compliant flat `Uint8List` byte buffer with `Uint32List` offsets, eliminating individual heap string objects.
- **Target Files**:
  - `lib/src/dataframe/arrow_string_series.dart` (new)
  - `lib/src/dataframe/series.dart`
  - `test/dataframe/series_test.dart`
- **Step-by-Step Implementation Details**:
  1. Create `lib/src/dataframe/arrow_string_series.dart`:
     Implement `ArrowStringSeries` backed by `Uint8List _bytes`, `Uint32List _offsets`, and `ValidityMask _validityMask`.
  2. Provide `getBytes(int index)` returning `Uint8List.sublistView` for zero-copy string inspection.
  3. Update `CsvReader` and `DataFrame` string column construction to build `ArrowStringSeries`.
  4. Add unit tests checking null handling, UTF-8 decoding, and string slicing.

---

### [ ] Sort-Merge Relational Join

- **Problem / Goal**:
  DataFrame joins strictly use hash tables, requiring $\mathcal{O}(M)$ auxiliary memory and dynamic hashing.
- **The Win**:
  - $\mathcal{O}(M + N)$ execution time and $\mathcal{O}(1)$ auxiliary memory join for pre-sorted key columns.
- **Target Files**:
  - `lib/src/dataframe/join.dart`
  - `test/dataframe/join_test.dart`
- **Step-by-Step Implementation Details**:
  1. In `lib/src/dataframe/join.dart`, implement `sortMergeJoin`:
     - Validate or sort key columns.
     - Traverse both DataFrames with dual cursor pointers, emitting matching pairs and handling duplicate key runs.
  2. Add unit tests for inner, left, right, and outer sort-merge joins with duplicate keys.

---

### [ ] Streaming CSV & JSON Parsers

- **Problem / Goal**:
  `CsvReader` and JSON parsers buffer entire multi-gigabyte files into memory strings before parsing.
- **The Win**:
  - Constant memory streaming DataFrame ingestion from `Stream<List<int>>` and `Stream<String>`.
- **Target Files**:
  - `lib/src/dataframe/csv.dart`
  - `lib/src/dataframe/json.dart`
  - `test/dataframe/csv_stream_test.dart` (new)
- **Step-by-Step Implementation Details**:
  1. Implement chunked state-machine RFC 4180 streaming transformer for `Stream<List<int>>`.
  2. Stream parsed rows into chunked Series buffers, concatenating into `DataFrame` blocks.
  3. Add tests verifying parsing of large streamed chunks without buffering the full dataset in RAM.

---

### [ ] Modularize Implementation Files (Single Responsibility, Low Coupling, High Cohesion)

- **Problem / Goal**:
  Several implementation files in `lib/src/` have grown very large and handle multiple distinct concerns (core data structures, hardware FFI routing, formatting, decompositions, and algorithms). This violates the Single Responsibility Principle and complicates navigation, code reviews, and tree-shaking.
- **The Win**:
  - Keep each implementation file focused on doing one thing only.
  - Split large files into focused subdirectories with private implementation helpers (`_...` files or internal classes).
  - High cohesion: components that belong together stay together; low coupling: independent concerns are decoupled into cleanly structured modules.
- **Target Files**:
  - Subsystems with oversized files (e.g. `lib/src/hardware/`, `lib/src/linear/`, `lib/src/tensor/`, `lib/src/dataframe/`, `lib/src/numeric/`).
- **Step-by-Step Implementation Details**:
  1. Audit file sizes and responsibilities across `lib/src/` to identify monolithic implementations exceeding single-responsibility bounds.
  2. Extract distinct sub-algorithms (e.g. decompositions, internal matrix solvers, iterative Krylov steps, CSV chunk parsers, FFI bindings) into dedicated subdirectories with private/internal helpers.
  3. Ensure public API export boundaries remain pristine and canonical, with zero breaking changes to public consumers.

---

### [ ] Parallel Unit Test Hierarchy & Comprehensive Coverage (Target Near 100%)

- **Problem / Goal**:
  Unit test coverage across some subsystems is incomplete or concentrated in large monolithic test files rather than mirroring the modular structure of the implementation.
- **The Win**:
  - Exact 1:1 parallel file and directory hierarchy between `lib/src/` and `test/`.
  - Small, modular unit test files mirroring each corresponding implementation file.
  - Near 100% test coverage across lines, branches, and condition paths in all subsystems.
- **Target Files**:
  - `test/` hierarchy mirroring all modules in `lib/src/`.
- **Step-by-Step Implementation Details**:
  1. Restructure and break up large test files to mirror the implementation hierarchy exactly (e.g. `lib/src/foo/bar.dart` -> `test/foo/bar_test.dart`).
  2. Write granular tests asserting behavior, boundary conditions, edge cases, and error states using `package:checks`.
  3. Measure coverage using `dart pub global run coverage:format_coverage` or `test_coverage` to systematically verify near 100% test coverage.

---

### [ ] Backend Acceleration Parity, Dedicated Modes (Auto, Accelerated, Dart) & Verification

- **Problem / Goal**:
  Operations accelerated by native FFI BLAS/LAPACK or SIMD (currently termed `hardware`) often silently fall back to pure Dart when acceleration is unavailable or fails, masking performance regressions or making it impossible to guarantee that hardware acceleration is actually running. Additionally, the term `hardware` is ambiguous and should be generalized to `Acceleration` / `Backend`. All backend variations (Hardware/Native FFI, SIMD, pure Dart) must be tested on identical inputs and verified to yield numerically identical outputs (accepting minor floating-point tolerances).
- **The Win**:
  - Dedicated configuration enum (`AccelerationMode` or `BackendMode`):
    - `auto`: uses the fastest available approach (default).
    - `hardware` / `accelerated`: forces native hardware/BLAS execution and explicitly throws if unavailable or failed (no silent fallback).
    - `dart`: forces pure Dart execution for benchmarking, debugging, and portability testing.
  - Refined terminology migrating from `hardware` to `acceleration` or `backend` across public and internal APIs.
  - Comprehensive parity test suite verifying identical outputs across all backends for the same inputs/setups.
- **Target Files**:
  - `lib/src/hardware/` -> refactor/modernize to `acceleration` / `backend`.
  - `lib/hardware.dart` (or `lib/acceleration.dart`).
  - `test/acceleration/` / `test/hardware/` parity test suites.
- **Step-by-Step Implementation Details**:
  1. Define `enum AccelerationMode { auto, hardware, dart }` (or `BackendMode`).
  2. Implement backend dispatch mechanics ensuring `hardware` fails fast with an explicit error rather than silently falling back to Dart.
  3. Modernize terminology from `hardware` to `acceleration` across APIs.
  4. Write parameterized parity test suites running identical test vectors across all backends, checking for mathematical equivalence within standard numerical tolerances.

---

### [ ] Hardware Acceleration for FFT, Signal Processing & Vectorized Operations

- **Problem / Goal**:
  Fourier transform routines (`fft`, `ifft`, `rfft`, `irfft`, `fft2`, `ifft2` in `lib/src/numeric/fft.dart`) and related computational routines across `package:data` (1D/2D convolutions, high-degree polynomial multiplications, descriptive vector statistics in `lib/src/stats/descriptive.dart`, elementwise transcendental math in tensors/vectors, and multidimensional tensor reductions) are implemented exclusively in pure Dart scalar code using heap-allocated objects (`List<Complex>`, `List<num>`). For large 1D vectors ($N \ge 1024$), 2D image matrices ($M \times N \ge 256 \times 256$), and high-degree polynomial multiplications, pure Dart execution creates substantial memory churn and CPU overhead compared to native hardware-accelerated vector DSP libraries. While matrix linear algebra operations already leverage native hardware acceleration via BLAS/LAPACK FFI and SIMD (`HardwareManager`), FFT, signal processing, and other numerical vector operations lack hardware-accelerated execution paths.
- **The Win**:
  - Investigate and integrate platform-native hardware acceleration matching the architecture of matrix acceleration (`loadBlas()` in `cblas_ffi.dart`):
    - **macOS / iOS (Apple Accelerate Framework)**:
      - FFT & Signal Processing: Leverage `vDSP` routines (`vDSP_create_fftsetupD`, `vDSP_destroy_fftsetupD`, `vDSP_fft_zripD`, `vDSP_fft2d_zripD`, `vDSP_convD`) from the already loaded `/System/Library/Frameworks/Accelerate.framework/Accelerate`.
      - Elementwise Transcendental Functions: Leverage `vForce` routines (`vvsin`, `vvcos`, `vvexp`, `vvlog`, `vvsqrt`, `vvpow`) for vectorized operations on `Float64List` / `Float32List`.
      - Vector Reductions & Summary Statistics: Leverage `vDSP` primitives (`vDSP_sveD`, `vDSP_meanvD`, `vDSP_measqvD`, `vDSP_normalizeD`) to accelerate descriptive statistics (`mean`, `variance`, `standardDeviation`, `norm`) in `stats/descriptive.dart`.
    - **Linux / Windows (FFTW3 / PocketFFT / BLAS Level 1)**:
      - FFT: Investigate FFI dynamic loading for FFTW3 (`libfftw3.so.3` / `fftw3.dll`), embedded lightweight C PocketFFT via Native Assets, or optimized pure Dart SIMD butterfly passes using `Float64x2List` / `Float32x4List`.
      - Reductions & Vector Math: Wire BLAS Level 1 routines already bound in `cblas_ffi.dart` (`dasum`, `dnrm2`, `ddot`, `daxpy`, `dscal`) to vector and tensor reduction operations.
  - Transparent routing through `HardwareManager` (or `AccelerationManager`) respecting `AccelerationMode` (`auto`, `hardware`, `dart`) with minimum problem size gating ($N \ge 64$) to amortize FFI marshalling overhead.
  - High-performance memory representations: Efficient conversion between Dart's interleaved `Complex(a, b)` instances and native split-complex structures (`DSPDoubleSplitComplex`) or interleaved `fftw_complex`.
  - Acceleration for related and dependent domains: 1D/2D convolution and cross-correlation (`convolve`, `correlate`), spectral filtering, $\mathcal{O}(N \log N)$ FFT-based polynomial multiplication (`Polynomial * Polynomial`), and tensor contractions/einsum.
- **Target Files**:
  - `lib/src/hardware/cfft.dart` (new) or `lib/src/hardware/vdsp_ffi.dart` / `fftw_ffi.dart`
  - `lib/src/hardware/vforce_ffi.dart` (new)
  - `lib/src/hardware/hardware.dart`
  - `lib/src/numeric/fft.dart`
  - `lib/src/polynomial/polynomial.dart`
  - `lib/src/stats/descriptive.dart`
  - `lib/src/tensor/operations/reduction.dart`
  - `test/numeric/fft_test.dart`
  - `test/hardware/fft_hardware_test.dart` (new)
  - `test/hardware/vforce_hardware_test.dart` (new)
- **Step-by-Step Implementation Details**:
  1. Investigate and benchmark candidate acceleration backends (Apple Accelerate `vDSP` and `vForce` on macOS/iOS, FFTW3/PocketFFT and BLAS Level 1 on Linux/Windows, and pure Dart SIMD butterfly passes).
  2. Implement native FFI bindings and unified function signatures for 1D and 2D real and complex FFT transforms, including conversion between interleaved and split-complex formats.
  3. Implement native FFI bindings for elementwise transcendental functions (`vForce`) and vector reduction primitives (`vDSP` / BLAS Level 1).
  4. Integrate FFT and vectorized math dispatch into `HardwareManager` with minimum size gating ($N \ge 64$) and graceful fallback handling.
  5. Accelerate dependent routines: FFT-based discrete convolution, high-degree polynomial multiplication, tensor reductions, and descriptive statistics.
  6. Add parity unit tests comparing native accelerated numerical results against pure Dart references across real, complex, 1D, and 2D test vectors within floating-point tolerance $\epsilon$.

---

### [ ] Consistent 80-Character Comment Formatting & Doc Reflow

- **Problem / Goal**:
  Dart standard style guidelines (Effective Dart: Documentation and Formatting) prescribe wrapping documentation comments (`///`) and code comments consistently at 80 characters. While `dart format` formats Dart statements, it deliberately does not rewrap existing doc comments or inline comments. As a result, comments across `lib/`, `test/`, and `example/` have accumulated inconsistent line lengths, with many lines exceeding 100–140 characters and others containing awkward manual breaks, impairing readability in standard 80-column editor splits, sidebars, and diffs.
- **The Win**:
  - Uniform, readable documentation across the entire codebase adhering strictly to the canonical 80-column line limit.
  - Improved developer experience when viewing code in split editors, terminal pagers, and code review interfaces.
  - Safe formatting complying with `AGENTS.md` documentation guidelines:
    - Preserves all Markdown code blocks (```dart ... ```) and indented code fences.
    - Preserves bracketed identifier links (`[ClassName]`, `[methodName]`) without breaking symbol references.
    - Strictly escapes brackets in mathematical LaTeX expressions (`$\[a, b\]$`, `$\mathcal{O}(N \log N)$`) or encloses them in backticks to prevent Dart analyzer `comment_references` warnings.
    - Reflows prose naturally while respecting markdown lists, bullet points, headers, and paragraph separation with blank `///` lines.
- **Target Files**:
  - All public API export libraries (`lib/*.dart`).
  - Implementation modules in `lib/src/**`.
  - Unit tests in `test/**` and documentation examples in `example/**`.
- **Step-by-Step Implementation Details**:
  1. Audit existing doc comments (`///`), multi-line comments (`/* ... */`), and single-line comments (`//`) for lines exceeding 80 characters.
  2. Implement or apply an AST-/regex-aware reflow script to rewrap prose at or under 80 characters while preserving:
     - Markdown code fences (```dart ... ```) and indented code blocks.
     - Bracketed doc references (`[ClassName]`, `[methodName]`).
     - Mathematical LaTeX formulas with properly escaped brackets (`$\[a, b\]$`).
     - Markdown lists, bullet points, headers, and blank doc lines (`///`).
  3. Systematically apply 80-character reflow across `lib/`, `test/`, and `example/`.
  4. Run `dart analyze` to verify zero `comment_references` or documentation warnings, and run `dart test` to ensure no functional regressions.
