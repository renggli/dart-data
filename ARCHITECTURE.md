# Subsystem Architecture & Technical Specifications

This document describes the achieved architecture across all subsystems of `package:data`, detailing architectural rationale, invariants, design constraints, and internal interactions.

## 1. Core Design Philosophy & Memory Model

### 1.1 Eager Evaluation Model

- **Reasoning**: The legacy architecture relied on more than 45 lazy view classes (e.g. `BinaryOperationMatrix`, `MatrixMatrixMultiplicationMatrix`, `TransposedMatrix`). While lazy views theoretically deferred evaluation, in practice they produced severe anti-patterns:
  - Deeply nested polymorphic call trees that destroyed CPU cache locality and defeated VM inline caching.
  - Silent repeated recomputations whenever elements were accessed multiple times.
  - Hidden memory retention chains preventing garbage collection of intermediate buffers.
- **Implementation & Constraints**:
  - All arithmetic operators (`+`, `-`, `*`, `/`, `matmul`) across `Tensor`, `Matrix`, and `Vector` are strictly eager.
  - When an arithmetic operation is invoked, computation executes immediately into a pre-allocated target buffer or a newly allocated contiguous buffer.
  - Structural view operations (`transpose`, `reshape`, `getRange`, `flip`) remain zero-copy by manipulating `Layout` strides and offsets, but they never wrap computation logic.

### 1.2 Memory Buffer Architecture & Aliasing Safety

- **Reasoning**: Scientific computations frequently execute operations where target buffers overlap with operand memory (e.g. `a = a + b` or in-place mutations). Without explicit aliasing guards, in-place evaluation silently corrupts unread input elements.
- **Implementation & Constraints**:
  - Direct `ByteBuffer` memory inspection utilities reside in `lib/src/type/buffers/memory.dart`.
  - `sharesMemory(List a, List b)` and `hasOverlap(TypedData a, TypedData b)` verify whether two storage arrays share underlying physical RAM via byte buffer pointer arithmetic and byte offset inspection.
  - In `Tensor.unaryOperation`, `binaryOperation`, `matmul`, and `reduction`, memory aliasing between inputs and output targets is detected prior to loop execution.
  - If hazardous overlap is detected (e.g., writing to a broadcast operand's buffer), intermediate calculations automatically route through a temporary copy buffer before writing to the target.

### 1.3 Unified Type System & Algebraic Fields

- **Reasoning**: Numeric and scientific operations require consistent algebraic structures (identities, field operations, numerical stability). Legacy mutable globals (`DataType.index`, `DataType.integer`, `DataType.float`) caused race conditions across isolates and tests. Concurrency isolates, ML pipelines, and graphics tasks need to configure floating-point precision (`float32` vs `float64`), integer precision (`int32` vs `int64`), and native off-heap storage frames without mutating global state.
- **Implementation & Constraints**:
  - Mutable globals are purged; default data types are isolate-safe and zone-scoped via `DefaultDataType`:
    - `DefaultDataType.index`: Static constant `DataType.uint32` for indexing collections, rows, and columns.
    - `DefaultDataType.integer`: Zone-scoped accessor defaulting to `DataType.int32` via `#data_default_integer`.
    - `DefaultDataType.float`: Zone-scoped accessor defaulting to `DataType.float64` via `#data_default_float`.
    - `DefaultDataType.isNative`: Zone-scoped accessor delegating to `NativeBuffer.isActive` via `#data_default_native`.
  - `DefaultDataType.withDefault<R>` provides the canonical, thread-safe way to configure execution contexts:
    - Supports standard positional trailing closures: `DefaultDataType.withDefault(computation, {integer, float, native})`.
    - Nested zone configurations preserve outer settings upon normal exit or exception unwinding.
    - Container constructors (`Tensor`, `Matrix`, `Vector`) and `DataType.newList` automatically respect `DefaultDataType.float`, `DefaultDataType.integer`, and `DefaultDataType.isNative` when no explicit type or native storage flag is specified.
  - `Field<T>` and `ExtendedField<T>` in `lib/src/type/models/field.dart` define strict algebraic contracts:
    - Standard operations: `additiveIdentity`, `multiplicativeIdentity`, `add`, `sub`, `mul`, `div`, `neg`, `inv`, `scale`.
    - Extended operations: `abs`, `norm`, `sqrt`, `exp`, `log`, `conjugate`.
  - Implemented across 18 specialized data types: floating-point (`Float32DataType`, `Float64DataType`), integers (`Int8DataType` through `Int64DataType`, unsigned variants), `BigIntDataType`, `ComplexDataType`, `FractionDataType`, `StringDataType`, `BooleanDataType`, and `ObjectDataType`.
  - Exact fractional scaling: `IntegerField.scale` uses `(a * f).round()`, and `BigIntField.scale` uses exact `Fraction.fromDouble` multiplication before truncation, eliminating rounding drift.

---

## 2. Tensor Subsystem (`package:data/tensor.dart`)

### 2.1 Unified N-D Strided `Layout`

- **Reasoning**: A single strided multidimensional representation unifies vectors, matrices, and N-dimensional tensors under identical memory indexing mathematics.
- **Implementation & Constraints**:
  - `Layout` (`lib/src/tensor/layout.dart`) models dimensions (`shape`), step sizes (`strides`), buffer displacement (`offset`), and whether storage is contiguous (`isContiguous`).
  - Zero-copy transformations produce new `Layout` instances referencing the same underlying `data` buffer:
    - `transpose(axes)`: Reorders shape and strides arrays.
    - `reshape(newShape)`: Recomputes contiguous strides if layout permits; otherwise triggers a contiguous buffer copy.
    - `getRange(start, end, {axis})`: Offsets the start pointer and truncates the dimension along `axis`.
    - `flip(axis)`: Negates the stride along `axis` and offsets the pointer to the end of the axis.

### 2.2 Contiguous Fast-Path Loops vs. Strided Iterators

- **Reasoning**: Generalized N-D multi-index translation (`toIndex(List<int> coords)`) requires loop overhead and coordinate allocation. Contiguous memory should run at raw array iteration speed.
- **Implementation & Constraints**:
  - All core operations (`unaryOperation`, `binaryOperation`) branch on `isContiguous`:
    - **Contiguous Path**: Directly loops over index range `0..length - 1` with a flat index counter, bypassing multi-index translation entirely. For `binaryOperation`, operands must share identical shapes, and if an explicit `target` is provided, it must also be contiguous and have matching dimension sizes.
    - **Strided / Non-Contiguous Path**: Uses `IndexIterator` to step through arbitrary non-contiguous and non-standard stride layouts.
  - **Target Shape Validation**: When a destination `target` is provided to `unaryOperation`, its shape must match `layout.shape` exactly; otherwise an `ArgumentError` is thrown, preventing memory overrun or corruption.

### 2.3 Broadcasting Semantics & Hazard Guards

- **Reasoning**: Multi-axis broadcasting enables element-wise operations between tensors of differing but compatible ranks/shapes (e.g. `[M, N] + [N]` or `[M, 1] * [1, N]`).
- **Implementation & Constraints**:
  - Shapes are aligned from trailing dimensions forward, inserting unit dimensions (`1`) for missing leading axes.
  - Dimensions match if they are equal or if either operand has size 1. Strides for broadcasted dimensions are set to 0.
  - Broadcaster guards detect when an in-place target matches an operand with stride 0 (broadcasted), forcing copy buffer allocation to prevent writing to memory shared across multiple coordinates.
  - **Broadcast Target Validation**: When an explicit `target` is provided to `binaryOperation`, its shape must exactly match the broadcasted output shape across all dimensions. If dimension lengths or ranks mismatch, an `ArgumentError` is thrown prior to evaluation, preventing truncated or corrupted writes.

### 2.4 Multi-Axis Reductions & Structural Manipulation

- **Reasoning**: Data science workflows require flexible axis aggregations and structural reshaping.
- **Implementation & Constraints**:
  - Reductions in `lib/src/tensor/operations/reduction.dart` (`sum`, `mean`, `min`, `max`, `std`, `var`, `argmin`, `argmax`) support arbitrary `axis` and `keepDims` options.
  - Axis reductions maintain accumulator buffers indexed by outer/inner layout strides.
  - Structural operations in `lib/src/tensor/operations/manipulation.dart`:
    - `concatenate` / `concatenateAll`: Joins tensors along an existing axis.
    - `stack` / `stackAll`: Inserts a new dimension and concatenates along it.
    - `tile`: Replicates tensor dimensions periodically.
    - `pad`: Pads boundaries with specified constant values or boundary reflections.

### 2.5 Batched Matrix Multiplication

- **Reasoning**: Deep learning, graphics, and multivariate Kalman filters require batched matrix multiplication over arbitrary leading batch axes: `(..., M, K) x (..., K, N) -> (..., M, N)`.
- **Implementation & Constraints**:
  - `matmul` (`lib/src/tensor/operations/matmul.dart`) validates that inner dimensions match ($K$).
  - Evaluates outer batch iterations over Cartesian product of leading batch dimensions, executing 2D slice multiplications across contiguous sub-matrices.

---

## 3. Linear Algebra & Sparse Subsystems (`package:data/linear.dart`)

### 3.1 Dense Matrix and Vector as Tensor Wrappers

- **Reasoning**: Rather than maintaining duplicate storage hierarchies, dense matrices and vectors are thin, zero-copy, rank-constrained wrappers around `Tensor<T>`.
- **Implementation & Constraints**:
  - `Matrix<T>` wraps a `Tensor<T>` where `rank == 2`. Dimensions are `rowCount = shape[0]` and `colCount = shape[1]`.
  - `Vector<T>` wraps a `Tensor<T>` where `rank == 1`. Dimension is `count = shape[0]`.
  - Operations like `matrix.transpose()`, `matrix.row(i)`, `matrix.col(j)`, and `matrix.diagonal()` return zero-copy views backed by the original tensor memory.
  - **Direct Fast-Path Indexing**:
    - `Tensor.get2D(r, c)`, `Tensor.set2D(r, c, v)`, `Tensor.get1D(idx)`, and `Tensor.set1D(idx, v)` provide `@pragma('vm:prefer-inline')` unchecked scalar access without heap `List<int>` coordinate allocations.
    - `Matrix<T>` provides `getUnchecked(row, col)` and `setUnchecked(row, col, value)` for performance-critical inner loops (factorizations, transformations), alongside bounds-checked `get(row, col)`, `set(row, col, value)`, and Dart 3 record indexing `operator []((int, int))` / `operator []=((int, int), value)`.
    - `Vector<T>` provides `getUnchecked(index)` and `setUnchecked(index, value)` alongside bounds-checked `operator [](index)` and `operator []=(index, value)`.
    - Direct linear buffer initialization in `Matrix.generate` and `Vector.generate` avoids coordinate list allocations.

### 3.2 The `LinearOperator<T>` Contract

- **Reasoning**: Iterative solvers (Conjugate Gradient, GMRES) only require matrix-vector products ($y = A x$ and $y = A^T x$), not direct entry access.
- **Implementation & Constraints**:
  - Defined in `lib/src/linear/operator.dart`:

    ```dart
    abstract interface class LinearOperator<T> {
      int get rowCount;
      int get colCount;
      DataType<T> get type;
      Vector<T> apply(Vector<T> x, {Vector<T>? target});
      Vector<T> applyTranspose(Vector<T> x, {Vector<T>? target});
      Matrix<T> matmul(Matrix<T> other, {Matrix<T>? target});
    }
    ```

  - Implemented by `Matrix<T>`, `CsrMatrix<T>`, `CscMatrix<T>`, and `CooMatrix<T>`.

### 3.3 Canonical Sparse Storage Formats

- **Reasoning**: Large-scale scientific and graph problems contain $>99\%$ zero entries. Dense storage wastes memory and induces $\mathcal{O}(N^2)$ operation costs.
- **Implementation & Constraints**:
  - **Compressed Sparse Row (`CsrMatrix`)**:
    - Stores non-zero elements in `values`, corresponding column indices in `colIndices`, and row start pointers in `rowPointers` of size $M + 1$.
    - Optimal for row slicing, matrix-vector multiplication $y = A x$, and standard linear system solves.
  - **Compressed Sparse Column (`CscMatrix`)**:
    - Stores column start pointers in `colPointers` of size $N + 1$.
    - Optimal for column slicing and computing transpose products $y = A^T x$.
  - **Coordinate List (`CooMatrix`)**:
    - Flat triplets `(row, col, value)`. Ideal for dynamic assembly and incremental sparse matrix construction before converting to CSR/CSC via `toCsr()` or `toCsc()`.

### 3.4 Matrix-Free Iterative Solvers

- **Reasoning**: Solving $A x = b$ for large sparse systems ($N > 100,000$) via dense LU factorization is computationally impossible ($\mathcal{O}(N^3)$ time, $\mathcal{O}(N^2)$ space).
- **Implementation & Constraints**:
  - `conjugateGradient`: Solves symmetric positive-definite systems using Krylov subspace projection with convergence tolerance and maximum iteration limits.
  - `gmres`: Generalized Minimal Residual method with restart parameter $m$ (GMRES(m)) and Arnoldi modified Gram-Schmidt orthogonalization for general non-symmetric square systems.
  - Solvers consume any `LinearOperator<T>`, executing without forming or modifying matrix entries.

### 3.5 Dense Matrix Decompositions

- **Reasoning**: Direct matrix factorizations provide exact solutions, determinants, inverses, and condition numbers for dense linear systems.
- **Implementation & Constraints**:
  - **LU Decomposition (`LU`)**: Doolittle algorithm with partial pivoting ($P A = L U$). Provides determinant computation and triangular back-substitution solves.
  - **QR Decomposition (`QR`)**: Householder reflector transformations yielding orthogonal $Q$ and upper-triangular $R$. Provides full-rank least-squares solves.
  - **Cholesky Factorization (`Cholesky`)**: $A = L L^T$ for symmetric positive-definite matrices, executing in $\frac{1}{3} N^3$ operations ($2\times$ faster than LU).
  - **Singular Value Decomposition (`SVD`)**: Golub-Reinsch bidiagonalization with implicit QR shifts computing $A = U \Sigma V^T$. Provides pseudo-inverses, rank estimation, and singular value inspection.
  - **Eigenvalue Decomposition (`Eigenvalue`)**: Reduction to Hessenberg form followed by Francis shifted double-step QR algorithm computing real and complex eigenvalues/eigenvectors.

### 3.6 Vector Operations & Norms

- **Reasoning**: Geometric and functional operations on vectors are foundational across optimization and analysis.
- **Implementation & Constraints**:
  - Generalized $L_p$ norm: `norm([p = 2.0])` supports $L_1$ (Manhattan), $L_2$ (Euclidean), and $L_\infty$ (Chebyshev maximum absolute).
  - Utility operations: `normalized()`, dot product `u.dot(v)`, outer product `u.outer(v)`, in-place scaling `scaleInPlace(factor)`, and scaled addition `addScaled(v, factor)`.

---

## 4. Tabular Data & DataFrame Engine (`package:data/dataframe.dart`)

### 4.1 Apache Arrow-Aligned Columnar Architecture

- **Reasoning**: Row-oriented tabular storage wastes memory on heterogeneous object headers and exhibits poor cache locality during analytical queries. Columnar storage groups identical types contiguously in memory, enabling vectorization and high-throughput analytical scans.
- **Implementation & Constraints**:
  - `DataFrame` represents a collection of named `Series<T>` instances of identical length.
  - Column access (`df['col']`, `df.column<T>('col')`) is $\mathcal{O}(1)$.
  - Slicing and filtering operate column-by-column across independent series.

### 4.2 Null Tracking via Validity Bitmasks

- **Reasoning**: Storing boxed `null` values inside primitive numeric arrays degrades memory density and prevents unboxed typed storage.
- **Implementation & Constraints**:
  - `ValidityMask` (`lib/src/dataframe/bitmask.dart`) uses 1 bit per row entry packed into `Uint8List` byte buffers, matching the Apache Arrow specification (bit = 1 indicates valid, bit = 0 indicates null).
  - Unboxed numeric series maintain contiguous `TypedData` lists (`Float64List`, `Int32List`) alongside a `ValidityMask`, ensuring data arrays remain primitive and unboxed.

### 4.3 Columnar Series Hierarchy & Zero-Allocation Operations

- **Reasoning**: Different data types require specialized memory structures. Numeric columns should achieve Arrow-grade performance without boxing primitives or thrashing garbage collection during query operations.
- **Implementation & Constraints**:
  - `TypedSeries<T>`: Backed by `TypedData` lists for high-performance numeric data.
    - Zero-allocation `filter`: Counts valid entries in `filterMask`, pre-allocates target typed array of exact length (`dataType.newList(count)`), copies unboxed elements directly, and maps the validity bitmask without boxing primitives.
    - Zero-allocation `slice`: Slices underlying typed array directly via `data.sublist(start, end)` and slices validity mask via `ValidityMask.slice(start, end)`.
    - Zero-overhead scalar access: `getNonNull(int index)` retrieves non-null values (throwing `StateError` on missing entries) without requiring `!` assertions from callers; `getUnchecked(int index)` provides inline raw array access when `hasNulls == false`.
  - `StringSeries`: Backed by string buffers for textual data.
  - `BoolSeries`: Packed boolean bit series.
  - `ObjectSeries`: General object reference series for complex domain models.

### 4.4 Relational Hash Joins & GroupBy Aggregations

- **Reasoning**: Fast relational transformations require collision-free, type-safe composite keys and optimized indexing structures without string allocation overhead.
- **Implementation & Constraints**:
  - Safe composite keys (`lib/src/dataframe/tuple_key.dart`):
    - `RowKeyExtractor` performs specialized zero-allocation record-based key extraction for 1 column (direct scalar `key`), 2 columns (record `(a, b)`), and 3 columns (record `(a, b, c)`).
    - Falls back to `TupleKey` with cached hash code and `DeepCollectionEquality` for 4 or more key columns.
    - Prevents delimiter injection attacks and eliminates null-string collisions (`null` vs `'null'`) and numeric type erasure (`1` vs `'1'`).
  - Hash join engine (`lib/src/dataframe/join.dart`):
    - Constructs `Map<Object?, List<int>>` hash index maps over right table join keys.
    - Probes index using left table keys to support `inner`, `left`, `right`, and `outer` joins. Null keys never match in joins.
  - `GroupBy` engine (`lib/src/dataframe/groupby.dart`):
    - Partitions row indices into buckets based on composite key objects (`Map<Object?, List<int>>`).
    - Aggregates groups across columns with `Agg.count`, `Agg.sum`, `Agg.mean`, `Agg.min`, `Agg.max`, `Agg.std`, `Agg.first`, and `Agg.last`.

### 4.5 Tabular Parsing (PetitParser), CSV/TSV Serialization & Container Conversions

- **Reasoning**: Seamless, robust data ingestion and transfer into computational models with customizable delimiter, quoting, and escaping rules.
- **Implementation & Constraints**:
  - `TabularDefinition` (`lib/src/dataframe/csv/parser.dart`): Customizable PEG grammar definition powered by `package:petitparser`. Private to `lib/src/dataframe/csv/`.
    - Typed combinators: Uses `[...].toChoiceParser()`, `.skip(before: quote.not())`, and `plusString()` for zero-allocation field character repetitions.
    - Full linter compliance: Grammar passes PetitParser's `linter(parser)` with zero structural defects, verifying absence of left-recursion, unbounded loops, or unreachable rules.
    - Preconfigured definitions for `TabularDefinition.csv()` (RFC 4180 with `""` quote escaping) and `TabularDefinition.tsv()` (tab delimiters supporting both RFC 4180 quotes and Unix backslash escapes `\t`, `\n`, `\r`, `\\`), with support for arbitrary user-defined delimiters and delimiters passed dynamically.
  - `CsvReader` (`lib/src/dataframe/csv/csv_reader.dart`):
    - Parses tabular records and lines via `TabularDefinition`, handling LF and CRLF newlines, multiline fields, and optional trailing line breaks without discarding valid empty rows or 1-column null data.
    - Automated columnar type inference (`int` -> `double` -> `bool` -> `String`) and null detection (`''`, `'null'`, `'NA'`).
    - Dedicated `CsvReader.parseTsv` helper configured with `TabularDefinition.tsv()`.
  - `CsvWriter` (`lib/src/dataframe/csv/csv_writer.dart`):
    - Serializes DataFrames to delimited text.
    - Proper delimiter-aware escaping: quotes and doubles quotes for fields containing the active `separator` (regardless of whether `,`, `\t`, `;`, `|`, etc.), `"` quotes, `\n`, or `\r`.
  - Container conversions (`df.toMatrix()` and `df.toTensor()`):
    - Bulk column copy fast-path: For non-null `TypedSeries<double>` columns, single columns are copied via `Float64List.setRange`, while multi-column selections use sequential flat buffer indexing without heap `List<int>` coordinate allocations.
    - Fallback paths preserve compatibility for mixed integer types, nullable columns, and general series.

---

## 5. Hardware Acceleration & FFI Subsystem (`lib/src/hardware/`)

### 5.1 Dynamic Library Discovery & Platform Detection

- **Reasoning**: High-performance linear algebra must transparently leverage hardware-tuned BLAS and LAPACK vendor libraries when available on the host OS.
- **Implementation & Constraints**:
  - `loadBlas()` in `lib/src/hardware/cblas_ffi.dart` dynamically queries system libraries:
    - macOS: Apple Accelerate framework (`Accelerate.framework/Accelerate`).
    - Linux: `libopenblas.so`, `libblas.so`, `liblapack.so`.
    - Windows: `openblas.dll`.
  - If native libraries are missing, the system gracefully falls back to pure-Dart algorithms without crashing.

### 5.2 BLAS Level 1, 2, 3 FFI Dispatch

- **Reasoning**: Hardware BLAS provides multi-threaded, SIMD-vectorized matrix arithmetic operating at tens of GFLOPS.
- **Implementation & Constraints**:
  - Bound via `dart:ffi`:
    - Level 1: `ddot`, `sdot` (dot products), `dnrm2`, `snrm2` (Euclidean norms), `daxpy`, `saxpy` ($y \leftarrow \alpha x + y$), `dscal`, `sscal` (scaling).
    - Level 2: `dgemv`, `sgemv` (matrix-vector multiplication).
    - Level 3: `dgemm`, `sgemm` (general matrix multiplication), `dsyrk`, `ssyrk`, `dsyr2`, `ssyr2` (symmetric rank-$k$ updates).
  - Zero-copy interop: Contiguous `Float64List` and `Float32List` buffers pass directly to native C pointers via `Pointer.fromAddress` or typed data addresses without intermediate heap copying.

### 5.3 LAPACK Solvers & Decompositions

- **Reasoning**: Production scientific systems rely on LAPACK for numerically stable factorizations.
- **Implementation & Constraints**:
  - Bound via `dart:ffi`:
    - `dgesv`: General linear system solver with partial pivoting. Transparently handles row-major to column-major layout transposition for multi-RHS matrices ($N \times \text{nrhs}$) and strided RHS matrices when interfacing with Fortran LAPACK routines (`dgetrf`/`dgetrs` or `dgesv_`), with a zero-copy fast path for contiguous single RHS ($nrhs = 1, ldb = 1$).
    - `dpotrf`: Cholesky factorization of symmetric positive-definite matrices.
    - `dgels`: Linear least-squares solver via QR or LQ factorization.
    - `dgeqrf`: Householder QR decomposition.
    - `dgesvd`: Singular value decomposition computing singular values and singular vectors.

### 5.4 Off-Heap Native Memory Lifecycle

- **Reasoning**: Allocating gigabyte-scale tensors in the Dart garbage-collected heap causes GC pauses and memory fragmentation. ML and GPU pipelines require transparent switching between managed typed lists and native memory frames.
- **Implementation & Constraints**:
  - `NativeBuffer` allocates native off-heap memory via `calloc` / `malloc`.
  - Container constructors (`Tensor.filled`, `Tensor.generate`, `Matrix.filled`, `Matrix.generate`, `Vector.filled`, etc.) allocate via `DataType.newList(length, native: native)`, seamlessly switching between standard heap-managed typed buffers and off-heap native memory frames via `DefaultDataType.withDefault(native: true)` or explicit `native: true/false` parameters.
  - Redundant factory constructors (`Tensor.native`, `Matrix.native`, `Vector.native`) and `allocateData` helper have been removed in favor of the canonical `newList` API and `native` arguments.
  - `DefaultDataType.isNative` dynamically respects zone-level `#data_default_native` overrides before falling back to `NativeBuffer.isActive`.
  - Memory cleanup is automatically coordinated via Dart's `NativeFinalizer`, ensuring that native pointers are freed when containers are garbage-collected without requiring manual `free()` calls.

### 5.5 Pure-Dart SIMD Acceleration Fallback

- **Reasoning**: Environments without FFI support (e.g. Flutter Web, Wasm) still benefit from CPU vector hardware.
- **Implementation & Constraints**:
  - `SimdEngine` (`lib/src/hardware/simd.dart`) leverages Dart's native `Float32x4List` and `Float32x4` types.
  - Evaluates 4-lane parallel floating-point arithmetic for element-wise vector/matrix addition, subtraction, multiplication, and dot products.

---

## 6. Numerical Analysis, ODEs & Optimization (`package:data/numeric.dart`)

### 6.1 Nonlinear Optimization Routines

- **Reasoning**: Finding minima of complex objective functions is ubiquitous in machine learning, engineering design, and parameter fitting.
- **Implementation & Constraints**:
  - `brentMinimize`: Univariate golden-section search combined with parabolic interpolation, achieving superlinear convergence without derivative requirements.
  - `nelderMead`: Multivariate derivative-free simplex method, resilient to non-smooth or noisy objective functions.
  - `bfgs`: Quasi-Newton Broyden-Fletcher-Goldfarb-Shanno method utilizing numerical gradients and Armijo line search to maintain a positive-definite Hessian approximation.
  - `lbfgs`: Limited-memory BFGS storing a rolling history of $m$ displacement vectors, enabling multivariate optimization over thousands of parameters with $\mathcal{O}(m N)$ memory.

### 6.2 Adaptive Ordinary Differential Equation (ODE) Solvers

- **Reasoning**: Physical dynamics, chemical kinetics, and orbital mechanics require stable, error-controlled numerical integration.
- **Implementation & Constraints**:
  - `rk4`: Classical 4th order Runge-Kutta solver with fixed step size.
  - `rk45`: Dormand-Prince 5(4) embedded adaptive Runge-Kutta solver. Computes 4th and 5th order step estimates with First-Same-As-Last (FSAL) efficiency, dynamically adjusting step size $h$ to maintain local truncation error within user tolerances (`atol`, `rtol`).

### 6.3 Numerical Multivariate Calculus

- **Reasoning**: Many optimization and sensitivity problems require derivatives of black-box functions.
- **Implementation & Constraints**:
  - `numericalDerivative` and `numericalSecondDerivative`: Central difference approximations with adaptive step size selection.
  - `numericalGradient`: Computes $\nabla f(x) \in \mathbb{R}^N$ for scalar multivariate functions.
  - `numericalJacobian`: Computes $J \in \mathbb{R}^{M \times N}$ for vector-valued multivariate functions $F: \mathbb{R}^N \to \mathbb{R}^{M}$.
  - `numericalHessian`: Computes symmetric second-order partial derivative matrix $H \in \mathbb{R}^{N \times N}$.

### 6.4 Non-Mutating Cooley-Tukey FFT Suite

- **Reasoning**: Spectral analysis and signal filtering require fast Fourier transformations that preserve original data structures.
- **Implementation & Constraints**:
  - Pure-Dart radix-2 Cooley-Tukey algorithm with bit-reversal sorting.
  - Operations in `lib/src/numeric/fft.dart`:
    - `fft` and `ifft`: 1D complex-to-complex forward and inverse transforms.
    - `rfft` and `irfft`: Real-valued 1D transforms exploiting Hermitian symmetry to compute $N/2 + 1$ unique complex frequencies.
    - `fft2` and `ifft2`: 2D transforms executing row-column separable passes over 2D matrices.
  - Immutability constraint: Input vectors/matrices are never modified in place; newly allocated containers are returned.

### 6.5 Stable Interpolation & Curve Fitting

- **Reasoning**: Continuous estimation from discrete empirical samples.
- **Implementation & Constraints**:
  - `CubicSpline`: $C^2$ continuous cubic spline interpolation supporting natural ($S''(x) = 0$) and clamped ($S'(x) = f'$) boundary conditions.
  - `PchipInterpolation`: Piecewise Cubic Hermite Interpolating Polynomial preserving monotonicity and preventing overshoot between data points.
  - `leastSquares`: General linear regression using LAPACK `dgels`, Householder QR, or SVD.
  - `polynomialRegression`: Vandermonde polynomial fitting using QR decomposition.
  - `levenbergMarquardt`: Damped Gauss-Newton nonlinear least-squares curve fitting.

### 6.6 Precision & Native Memory Scoping in Numerical Solvers

- **Reasoning**: Complex iterative numerical routines (e.g. nonlinear optimizers, ODE integrators, curve fitting, FFT) require seamless switching between double-precision scientific convergence and single-precision or native off-heap memory frames without invasive algorithm rewrites.
- **Implementation & Constraints**:
  - Routines allocate intermediate vectors and matrices via standard container constructors, dynamically inheriting the zone's active precision (`DefaultDataType.float`) and storage frame (`DefaultDataType.isNative`).
  - High-precision algorithms (e.g. adaptive Dormand-Prince `rk45` or BFGS quasi-Newton line searches) allow users to wrap execution inside `DefaultDataType.withDefault(float: DataType.float64)` or `DefaultDataType.withDefault(native: true)` to ensure convergence or offload large coordinate traces into native off-heap memory.

---

## 7. Statistics & Resampling (`package:data/stats.dart`)

### 7.1 Descriptive Statistics & Dimensionality Reduction

- **Reasoning**: Comprehensive summary profiles of empirical distributions.
- **Implementation & Constraints**:
  - Measures of location and dispersion: `quantile`, `median`, `iqr`, sample `skewness`, and excess `kurtosis`.
  - Association matrices: `covarianceMatrix`, `correlationMatrix` (Pearson linear correlation and Spearman rank-order correlation).
  - Principal Component Analysis (`pca`): Computes centered covariance matrices, orthogonal eigenvectors, eigenvalues, and explained variance ratios for dimensionality reduction.

### 7.2 Parametric Distributions & Maximum Likelihood Estimation (MLE)

- **Reasoning**: Closed-form probability modeling and parameter inference from data.
- **Implementation & Constraints**:
  - 12 probability distributions implemented with probability density/mass functions (`pdf`/`pmf`), cumulative distribution functions (`cdf`), quantile functions (`inverseCdf`), and random sampling (`sample`):
    - Continuous: `NormalDistribution`, `StudentTDistribution`, `FDistribution`, `BetaDistribution`, `GammaDistribution`, `ExponentialDistribution`, `ChiSquaredDistribution`, `UniformDistribution`.
    - Discrete: `BernoulliDistribution`, `BinomialDistribution`, `PoissonDistribution`, `DiscreteUniformDistribution`.
  - All distributions support analytical or numerical MLE fitting via `factory .fit(data)` constructors.

### 7.3 Hypothesis Testing Suite

- **Reasoning**: Rigorous statistical inference for experimental hypothesis testing.
- **Implementation & Constraints**:
  - `tTestOneSample`: Student's t-test comparing sample mean against hypothesized value.
  - `tTestTwoSample`: Two-sample t-test supporting Student's pooled variance and Welch's t-test for unequal variances.
  - `tTestPaired`: Paired-difference t-test.
  - `oneWayAnova`: One-way Analysis of Variance testing equality of three or more group means.
  - `chiSquaredTest` and `chiSquaredContingency`: Goodness-of-fit and contingency table test of independence.
  - `mannWhitneyUTest`: Non-parametric test for equality of two continuous distributions.

### 7.4 Non-Parametric & Parametric Bootstrap Resampling

- **Reasoning**: Estimating standard errors and confidence intervals without distribution assumptions.
- **Implementation & Constraints**:
  - `bootstrap`: Generates $B$ resampled datasets with replacement.
  - Confidence interval algorithms:
    - Percentile interval: Direct empirical quantiles of the bootstrap distribution.
    - BCa (Bias-Corrected and Accelerated) interval: Corrects for both median bias and skewness (acceleration parameter $a$ computed via jackknife influence values).

---

## 8. Polynomial Subsystem (`package:data/polynomial.dart`)

### 8.1 Immutable Value-Backed Representation

- **Reasoning**: The legacy polynomial implementation used mutable coefficient buffers and `copyInto` methods, leading to aliasing bugs and state pollution.
- **Implementation & Constraints**:
  - `Polynomial<T>` is strictly immutable, backed by an unmodifiable list of coefficients ordered from degree 0 to $N$.
  - All operations return newly allocated, canonicalized `Polynomial<T>` instances with trailing zero coefficients stripped.

### 8.2 Orthogonal Polynomial Families & Clenshaw Recurrence

- **Reasoning**: Orthogonal polynomials are essential for spectral methods, approximation theory, and numerical quadrature.
- **Implementation & Constraints**:
  - Static factory generators:
    - Chebyshev polynomials of the first kind ($T_n(x)$) and second kind ($U_n(x)$).
    - Legendre polynomials ($P_n(x)$).
    - Hermite polynomials (physicist $H_n(x)$ and probabilist $He_n(x)$).
  - Evaluated via `clenshawEvaluate` (`lib/src/polynomial/orthogonal.dart`), which evaluates three-term recurrence relations stably without expanding polynomial coefficients.

### 8.3 Formal Polynomial Arithmetic & Root Isolation

- **Reasoning**: Exact algebraic manipulation and root finding for arbitrary degrees.
- **Implementation & Constraints**:
  - Formal division with remainder (`divide`, `/`, `%`) and Euclidean Greatest Common Divisor (`gcd`).
  - Differentiation (`derivative()`) and anti-differentiation (`integrate()`).
  - Root isolation:
    - Degree 1: Analytical linear root.
    - Degree 2: Numerically stable quadratic formula with sign preservation to prevent catastrophic cancellation.
    - Degree $\ge 3$: Constructs Frobenius companion matrix of monic polynomial and solves for complex roots via `EigenvalueDecomposition`.

---

## 9. Symbolic Computation Engine (`package:data/symbolic.dart`)

### 9.1 Pure Functional Algebraic AST

- **Reasoning**: Mathematical expressions require an abstract syntax tree (AST) for analytical manipulation, simplification, and compilation.
- **Implementation & Constraints**:
  - Base class `Expr` (`lib/src/symbolic/ast.dart`) with immutable node subtypes:
    - Terminals: `Constant(num value)`, `Variable(String name)`.
    - Arithmetic: `Add`, `Sub`, `Mul`, `Div`, `Neg`, `Pow`.
    - Transcendental: `Sin`, `Cos`, `Exp`, `Ln`.
  - Overloads Dart arithmetic operators (`+`, `-`, `*`, `/`) so standard Dart code builds symbolic trees naturally.

### 9.2 Exact Automated Symbolic Differentiation

- **Reasoning**: Symbolic differentiation computes exact analytical derivatives without finite-difference approximation errors or step-size tuning.
- **Implementation & Constraints**:
  - Recursive `diff(String variable)` method implementing calculus differentiation rules:
    - Product rule: $(f \cdot g)' = f' g + f g'$.
    - Quotient rule: $(f / g)' = (f' g - f g') / g^2$.
    - Power rule: $(u^v)' = u^v \left(v' \ln u + v \frac{u'}{u}\right)$.
    - Chain rule across all transcendental nodes ($\sin, \cos, \exp, \ln$).

### 9.3 Canonical Simplification Engine

- **Reasoning**: Repeated differentiation and algebraic construction create bloated expression trees (e.g. $0 \cdot x + 1 \cdot f(x)$).
- **Implementation & Constraints**:
  - `simplify()` in `lib/src/symbolic/simplifier.dart` executes bottom-up recursive reductions:
    - Constant folding: Evaluates expressions composed solely of numeric constants.
    - Identity elimination: $x + 0 \to x$, $x \times 1 \to x$, $x \times 0 \to 0$, $x^1 \to x$, $x^0 \to 1$.
    - Structural grouping: Identical term aggregation and negation cancellations ($x - x \to 0$, $-(-x) \to x$).

### 9.4 Positional JIT & Tensor Kernel Compilation

- **Reasoning**: Interpreting AST trees by traversing nodes during iterative loops is orders of magnitude slower than compiled code.
- **Implementation & Constraints**:
  - `compile1D(varName)`: Produces a high-speed closure `double Function(double)`.
  - `compile(varOrder)`: Produces a multivariate closure `double Function(List<double>)`.
  - `compileTensorKernel(varOrder)`: Compiles an optimized tensor evaluation loop that reuses an internal argument buffer, evaluating symbolic expressions across entire tensors without heap allocations inside the loop.

### 9.5 Symbolic-to-Numeric Synergy

- **Reasoning**: Unifying analytical calculus with numeric optimization algorithms.
- **Implementation & Constraints**:
  - Numeric optimizers (`brentMinimize`, `nelderMead`, `bfgs`) accept `Expr` ASTs directly.
  - When an `Expr` is passed to `bfgs`, analytical gradients are computed automatically via `expr.diff()`, completely eliminating finite-difference approximation errors and accelerating convergence.
