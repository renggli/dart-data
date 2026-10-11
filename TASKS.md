# Implementation Roadmap & Task Specifications

This document defines the actionable engineering task list for `package:data`.

## Tasks

- [ ] High-Level Curve Fitting & Parametric Model Architecture Restoration
- [ ] Scientific Sampling Grids (`linearSpaced`, `logarithmicSpaced`, `geometricSpaced`)
- [ ] Linear Algebra Ergonomics: Natural 2D Indexing, General Matrix Solver, Determinant & Inverse
- [ ] Sparse Polynomial Representation
- [ ] Apache Arrow C Data Interface & IPC Stream Export
- [ ] Apache Arrow UTF-8 String Offset Buffer (`ArrowStringSeries`)
- [ ] Sort-Merge Relational Join
- [ ] Streaming CSV & JSON Parsers

---





### [ ] High-Level Curve Fitting & Parametric Model Architecture Restoration

- **Problem / Goal**:
  In `v0.16.0`, curve fitting was a cohesive, problem-oriented subsystem:
  - `CurveFit` abstract interface with `fit({required Vector<double> xs, required Vector<double> ys}) -> CurveFitResult`.
  - `CurveFitResult` returned both the optimal parameters and a ready-to-evaluate mathematical `function`.
  - `ParametrizedUnaryFunction` provided seamless binding over positional, named, list, map, and vector parameter models, along with parameter bounds (`minValue`, `maxValue`).
  In HEAD, non-linear fitting was reduced to raw `levenbergMarquardt`, which takes a residual vector function and raw parameter vector, returning only a `Vector<double>`. The user has to manually calculate residual vectors and reconstruct the fitted function.
- **The Win**:
  - Intuitive, high-level non-linear curve fitting: pass data vectors `xs` and `ys` and a model function $f(x; \theta)$, receiving back fitted parameters, covariance/uncertainty, $R^2$ goodness-of-fit, and a callable predictor function.
- **Target Files**:
  - `lib/src/numeric/curve_fit.dart`
  - `lib/numeric.dart`
  - `test/numeric/curve_fit_test.dart`
- **Step-by-Step Implementation Details**:
  1. Define `class CurveFitResult` containing `Vector<double> parameters`, `double Function(double) predict`, `double rSquared`, and residual metrics.
  2. Implement canonical `CurveFitResult curveFit({required Vector<num> xs, required Vector<num> ys, required double Function(double x, Vector<double> params) model, required Vector<double> initialParams, Vector<double>? lowerBounds, Vector<double>? upperBounds, double tolerance = 1e-7, int maxIterations = 100})`.
  3. Wire internal optimization to the existing Levenberg-Marquardt routine or bounded optimizer while encapsulating the residual vector assembly $(r_i = \text{model}(x_i, p) - y_i)$.
  4. Provide high-level wrappers for common models (exponential $a e^{b x}$, power $a x^b$, logarithmic $a + b \ln x$, gaussian $a e^{-\frac{(x - \mu)^2}{2\sigma^2}}$).
  5. Add tests fitting non-linear noisy datasets and verifying parameter convergence and $R^2$ accuracy.

---

### [ ] Scientific Sampling Grids (`linearSpaced`, `logarithmicSpaced`, `geometricSpaced`)

- **Problem / Goal**:
  `v0.16.0` provided standard scientific grid generator utilities:
  - `linearSpaced(start, stop, {count, includeEndpoint})` (equivalent to NumPy `linspace`)
  - `logarithmicSpaced(start, stop, {count, base, includeEndpoint})` (equivalent to NumPy `logspace`)
  - `geometricSpaced(start, stop, {count, includeEndpoint})` (equivalent to NumPy `geomspace`)
  These were purged in the greenfield rewrite, forcing users to write manual loops or indexing math whenever setting up evaluation grids, plotting coordinates, ODE time vectors, or interpolation domains.
- **The Win**:
  - Standard, zero-boilerplate creation of linearly, logarithmically, and geometrically spaced 1D `Vector<double>` coordinates.
- **Target Files**:
  - `lib/src/linear/vector.dart` (or `lib/src/numeric/sampling.dart`)
  - `lib/numeric.dart`
  - `lib/linear.dart`
  - `test/numeric/sampling_test.dart` (new)
- **Step-by-Step Implementation Details**:
  1. Implement `Vector<double> linearSpaced(double start, double stop, {int count = 50, bool endpoint = true, DataType<double>? type, bool? native})`.
  2. Implement `Vector<double> logarithmicSpaced(double start, double stop, {int count = 50, double base = 10.0, bool endpoint = true, DataType<double>? type, bool? native})`.
  3. Implement `Vector<double> geometricSpaced(double start, double stop, {int count = 50, bool endpoint = true, DataType<double>? type, bool? native})`.
  4. Also expose `Vector.linspace`, `Vector.logspace`, and `Vector.geomspace` factory constructors on `Vector` for discoverability.
  5. Add unit tests verifying start/stop boundary inclusion, spacing consistency, count accuracy, and logarithmic scaling.

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
