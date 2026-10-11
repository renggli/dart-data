# Implementation Roadmap & Task Specifications

This document defines the actionable engineering task list for `package:data`.

## Tasks

- [ ] Linear Algebra Ergonomics: Natural 2D Indexing, General Matrix Solver, Determinant & Inverse
- [ ] Sparse Polynomial Representation
- [ ] Apache Arrow C Data Interface & IPC Stream Export
- [ ] Apache Arrow UTF-8 String Offset Buffer (`ArrowStringSeries`)
- [ ] Sort-Merge Relational Join
- [ ] Streaming CSV & JSON Parsers
- [ ] Modularize Implementation Files (Single Responsibility, Low Coupling, High Cohesion)
- [ ] Parallel Unit Test Hierarchy & Comprehensive Coverage (Target Near 100%)
- [ ] Backend Acceleration Parity, Dedicated Modes (Auto, Accelerated, Dart) & Verification

---









### [ ] Linear Algebra Ergonomics: Natural 2D Indexing, General Matrix Solver, Determinant & Inverse

- **Problem / Goal**:
  - Matrix row indexing: In `v0.16.0`, `matrix[row]` returned a `Vector<T>` view of that row, enabling natural, universal 2D indexing syntax `matrix[r][c]`. In HEAD, `matrix[row]` is disallowed; indexing requires `matrix[(r, c)]` record syntax or `matrix.get(r, c)`.
  - Matrix `solve`: In `v0.16.0`, `matrix.solve(b)` was a general solver on `Matrix<num>`: if square, it solved via LU decomposition; if rectangular, it automatically solved the least-squares problem via QR decomposition; and it accepted both `Vector` and multi-column `Matrix` right-hand sides. In HEAD, `Matrix.solve(b)` is restricted to square matrices, only accepts `Vector<T>`, and throws `ArgumentError` if rectangular or given a matrix RHS.
  - Missing determinant and inverse: `v0.16.0` provided `matrix.det` and `matrix.inverse` directly on `Matrix<num>`. In HEAD, `matrix.inverse` was completely dropped, and `matrix.det` was hidden under `matrix.lu.det`.
- **The Win**:
  - Intuitive `matrix[row]` returning row `Vector<T>` view, enabling natural `matrix[r][c]` indexing.
  - Universal `Matrix.solve(rhs)` solving square, under-determined, and over-determined (least squares) systems, supporting both `Vector<T>` and `Matrix<T>` (multiple right-hand sides).
  - Convenient, direct access to `matrix.det` and `matrix.inverse` on `Matrix<T extends num>`.
- **Target Files**:
  - `lib/src/linear/matrix.dart`
  - `test/linear/matrix_test.dart`
- **Step-by-Step Implementation Details**:
  1. In `lib/src/linear/matrix.dart`, add `Vector<T> operator [](int row) => this.row(row);` while maintaining `T get(int row, int col)` and `void set(int row, int col, T value)`. Ensure `operator []=((int, int), T)` or setter methods continue to provide fast element mutation.
  2. Generalize `Matrix.solve`:
     - Overload or parameterize `solve(Object b)` to accept either `Vector<T>` or `Matrix<T>`.
     - When `rowCount == colCount`, route to LU solver (`dgesv` / pure-Dart LU).
     - When `rowCount != colCount`, route automatically to QR least-squares solver (`dgels` / pure-Dart QR), returning the minimum-norm least-squares solution.
  3. Reintroduce `T get det` / `double get det => lu.det;` directly on numeric matrices.
  4. Reintroduce `Matrix<double> get inverse` on square invertible matrices (via LU solve against identity).
  5. Add unit tests for `matrix[r][c]` read/write semantics, `det`, `inverse`, and square/rectangular multi-RHS solves.

---

### [ ] Sparse Polynomial Representation

- **Problem / Goal**:
  In `v0.16.0`, `Polynomial` supported sparse representations (`CompressedPolynomial`, `KeyedPolynomial`), which allowed polynomials with large sparse exponents (e.g. $x^{10000} - 1$) without allocating a 10,001-element dense array. In HEAD, `Polynomial` is backed strictly by dense `List<T> _coefficients`, making high-degree sparse polynomials memory-prohibitive.
- **The Win**:
  - Memory-efficient sparse polynomial algebra without allocating enormous contiguous coefficient lists.
- **Target Files**:
  - `lib/src/polynomial/impl/compressed_polynomial.dart` (new)
  - `lib/polynomial.dart`
  - `test/polynomial/compressed_polynomial_test.dart` (new)
- **Step-by-Step Implementation Details**:
  1. Implement `SparsePolynomial<T>` or `CompressedPolynomial<T>` in `lib/src/polynomial/` storing a map or sorted lists of non-zero `(degree, coefficient)` pairs.
  2. Ensure `Polynomial` operations (`+`, `-`, `*`, `evaluate`, `derivative`) support sparse representations seamlessly.
  3. Add unit tests for high-degree sparse polynomial operations ($x^{10000} - 1$), degree determination, multiplication, and evaluation.

---

### [ ] Apache Arrow C Data Interface & IPC Stream Export

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
  Operations accelerated by native FFI BLAS/LAPACK or SIMD (currently termed `hardware`) often silently fall back to pure Dart when acceleration is unavailable or fails, masking performance regressions or making it impossible to guarantee that hardware acceleration is actually running. Additionally, the term `hardware` is ambiguous and should be generalized to `Acceleration` / `Backend`. All backend variations (Hardware/Native FFI, SIMD, pure Dart) must be tested on identical inputs and verified to yield numerically identical outputs (within minor floating-point tolerances).
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

