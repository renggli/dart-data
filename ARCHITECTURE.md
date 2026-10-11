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
  - **Dart 3 Class Modifiers & Subsystem Encapsulation**:
    - `DataType<T>` is an `abstract base class`, with category hierarchies `abstract base class TypedDataType<T, L>`, `IntegerDataType<L>`, and `FloatDataType<L>`. Subclasses must adhere to inheritance rules (`base` or `final`), preventing uncoordinated interface mocking across libraries while avoiding `sealed` file-confinement limits.
    - All built-in concrete data types (`Float64DataType`, `Int32DataType`, `BigIntDataType`, `ComplexDataType`, `FractionDataType`, `NumericDataType`, `BooleanDataType`, `StringDataType`, `ObjectDataType`, `NullableDataType`, etc.) are `final class`.
    - `Field<T>` and `ExtendedField<T>` are declared `abstract interface class`, enforcing pure algebraic contracts that require explicit `implements` for all field implementations across library files. Concrete field classes (`FloatField`, `IntegerField`, `BigIntField`, `ComplexField`, `FractionField`, `NumericField`) implement `ExtendedField<T>` as `final class`, while `QuaternionField` implements `Field<Quaternion>` as `final class`.
    - `Equality<T>` is `abstract interface class Equality<T>`, with canonical `base class NaturalEquality<T> implements Equality<T>`, and all specialized equality classes declared `final class`.

### 1.4 Zero-Cost Extension Types (`Float64Tensor`, `Float64Matrix`, `Float64Vector`)

- **Reasoning**: Generic `Tensor<double>`, `Matrix<double>`, and `Vector<double>` incur polymorphic method dispatch and generic type parameter overhead, preventing direct non-virtual access to typed array buffers without downcasting.
- **Implementation & Constraints**:
  - `Float64Tensor` in `lib/src/tensor/float64_tensor.dart` (exported in `lib/tensor.dart`), and `Float64Matrix` & `Float64Vector` in `lib/src/linear/float64_matrix.dart` & `lib/src/linear/float64_vector.dart` (exported in `lib/linear.dart`):
    - Defined as Dart 3.3+ extension types wrapping `Tensor<double>`, `Matrix<double>`, and `Vector<double>` with zero runtime heap allocation overhead.
    - Expose `asTypedList` property providing direct, unboxed access to the underlying `Float64List` storage buffer.
    - Fast contiguous element access: inlined indexers bypass generic checks and bounds-checking cascades.
    - Implement inlined arithmetic operators (`+`, `-`, `*`, `/`, `-()`, `scale`) that bypass generic field abstraction and execute contiguous vector loops directly on `Float64List` buffers.
    - On `Float64Matrix`: matrix multiplication (`*`) routes directly to native BLAS `dgemm` when operands are contiguous, while vector multiplication (`apply`) routes directly to BLAS `dgemv`.
    - On `Float64Vector`: algebraic inner product (`dot`) routes directly to BLAS `ddot`, and Euclidean norm (`norm2`) routes directly to BLAS `dnrm2`.
    - Seamless subtyping: `Float64Tensor implements Tensor<double>`, `Float64Matrix implements Matrix<double>`, and `Float64Vector implements Vector<double>`, enabling them to pass transparently into any existing API accepting generic floating-point containers.

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
    - `split`: Divides a tensor along a specified axis into equal chunks as zero-copy views; validates positive chunk count and exact divisibility.
    - `splitWithSizes`: Partitions a tensor along a specified axis into chunks matching given partition sizes as zero-copy views; validates non-negative sizes and exact size sum matching.
  - Multi-axis strided slicing in `lib/src/tensor/layout.dart` and `lib/src/tensor/tensor.dart`:
    - `Slice(start, end, step)`: Specifies range and stride per axis, with `Slice.all` selecting all elements.
    - `Layout.slice(slices)` and `Tensor.slice(slices)`: Constructs zero-copy strided views recalculating `offset`, `shape`, `strides`, `length`, and `isContiguous`.
    - Conforms to Python/NumPy slicing rules: supports positive and negative steps (reversals), open-ended bounds (`null`), negative indices wrapping relative to dimension length, and boundary clamping for out-of-bounds indices. Missing trailing slices default to `Slice.all`.

### 2.5 Batched Matrix Multiplication

- **Reasoning**: Deep learning, graphics, and multivariate Kalman filters require batched matrix multiplication over arbitrary leading batch axes: `(..., M, K) x (..., K, N) -> (..., M, N)`.
- **Implementation & Constraints**:
  - `matmul` (`lib/src/tensor/operations/matmul.dart`) validates that inner dimensions match ($K$).
  - Evaluates outer batch iterations over Cartesian product of leading batch dimensions, executing 2D slice multiplications across contiguous sub-matrices.

### 2.6 Generalized Tensor Contraction & Einstein Summation (`tensordot`, `einsum`)

- **Reasoning**: Scientific computing, quantum mechanics, and deep learning architectures require multi-axis tensor contractions and declarative index reductions.
- **Implementation & Constraints**:
  - `tensordot` (`lib/src/tensor/operations/contraction.dart`): Contracts arbitrary subsets of axes between two tensors. Permutes free and contracted axes to form contiguous 2D block shapes, dispatches to accelerated 2D `matmul` (mapping to BLAS GEMM when float32/float64), and reshapes to output dimensions.
  - `innerProduct` and `outerProduct`: Specialized contractions representing full multi-axis inner products (yielding rank-0 scalar tensors) and zero-contraction outer products.
  - `einsum` (`lib/src/tensor/operations/einsum.dart`): Evaluates Einstein summation convention matching NumPy notation (e.g. `'ij,jk->ik'`, `'ii->'`, `'bij,bjk->bik'`, `'i,j,k->ijk'`). Automatically parses explicit (`->`) and implicit output conventions, routes 2-operand contractions to optimized `tensordot` when applicable, and executes universal multi-index odometer evaluation for general contractions, diagonals, traces, and batched equations.

---

## 3. Linear Algebra & Sparse Subsystems (`package:data/linear.dart`)

### 3.1 Dense Matrix and Vector as Tensor Wrappers

- **Reasoning**: Rather than maintaining duplicate storage hierarchies, dense matrices and vectors are thin, zero-copy, rank-constrained wrappers around `Tensor<T>`.
- **Implementation & Constraints**:
  - `Matrix<T>` wraps a `Tensor<T>` where `rank == 2`. Dimensions are `rowCount = shape[0]` and `colCount = shape[1]`.
  - `Vector<T>` wraps a `Tensor<T>` where `rank == 1`. Dimension is `count = shape[0]`.
  - Operations like `matrix.transpose()`, `matrix.conjugateTranspose`, `matrix.row(i)`, `matrix.col(j)`, and `matrix.diagonal()` return views or conjugated adjoints backed by the underlying tensor elements.
  - **Trace & Diagonal Extraction**:
    - `matrix.diagonal()` returns a zero-copy 1D view of the main diagonal.
    - `matrix.trace` sums main diagonal elements $A_{ii}$ for square matrices, returning `T` via `type.field.add` and throwing `ArgumentError` if non-square ($M \ne N$). The property is unified strictly on `Matrix<T>`, eliminating shadowing from `MatrixNormExtension`.
    - `matrix.conjugateTranspose` computes the Hermitian adjoint $A^* = (\bar{A})^T$ mapping elements through `type.field.conjugate`.
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

### 3.4 Tridiagonal & Matrix-Free Iterative Solvers

- **Reasoning**: Solving $A x = b$ for large sparse or structured banded systems ($N > 100,000$) via dense LU factorization is computationally impossible ($\mathcal{O}(N^3)$ time, $\mathcal{O}(N^2)$ space).
- **Implementation & Constraints**:
  - `solveTridiagonal`: Solves tridiagonal systems $A x = d$ in $\mathcal{O}(N)$ time and $\mathcal{O}(1)$ auxiliary space beyond a single modified superdiagonal array using the Thomas algorithm. Contains contiguous buffer fast paths and handles singular zero-pivot validation.
  - `conjugateGradient`: Solves symmetric positive-definite systems using Krylov subspace projection with convergence tolerance and maximum iteration limits.
  - `gmres`: Generalized Minimal Residual method with restart parameter $m$ (GMRES(m)) and Arnoldi modified Gram-Schmidt orthogonalization for general non-symmetric square systems.
  - Iterative solvers consume any `LinearOperator<T>`, executing without forming or modifying matrix entries.

### 3.5 Dense Matrix Decompositions (Modular Decomposition Extensions)

- **Reasoning**: Direct matrix factorizations provide exact solutions, determinants, inverses, and condition numbers for dense linear systems. Defining decompositions via modular typed extensions at the top of each algorithm file guarantees compile-time type safety while eliminating unsafe runtime downcasts and keeping `matrix.dart` decoupled from specific decomposition algorithms.
- **Implementation & Constraints**:
  - **Modular Type-Safe Extensions**: Factorization entry points are declared at the top of their dedicated decomposition files in `lib/src/linear/decomposition/` and exported via `package:data/linear.dart`:
    - `CholeskyMatrixExtension<T extends num>`, `CholeskyComplexMatrixExtension` in `cholesky.dart` (`.cholesky`)
    - `LuMatrixExtension<T extends num>`, `LuComplexMatrixExtension` in `lu.dart` (`.lu`)
    - `QrMatrixExtension<T extends num>`, `QrComplexMatrixExtension` in `qr.dart` (`.qr`)
    - `SvdMatrixExtension<T extends num>` in `svd.dart` (`.svd`)
    - `EigenvalueMatrixExtension<T extends num>` in `eigenvalue.dart` (`.eigenvalue`)
  - **Generic Decomposition Classes**: `LUDecomposition<T>`, `QRDecomposition<T>`, and `CholeskyDecomposition<T>` execute specialized primitive double fast-paths when `type == DataType.float64` and generic algebraic field operations via `type.field` for general scalar fields (including `Complex`).
  - **LU Decomposition (`LUDecomposition<T>`)**: Doolittle algorithm with partial row pivoting ($P A = L U$) based on modulus norm (`field.norm`). Provides determinant computation and triangular back-substitution solves for both real and complex fields.
  - **QR Decomposition (`QRDecomposition<T>`)**: Complex Householder reflector transformations yielding unitary/orthogonal $Q$ ($Q^* Q = I$) and upper-triangular $R$. Uses phase factor $\mu = x_k / |x_k|$ to guarantee numerical stability and provides full-rank least-squares solves via canonical `solve(Matrix<T> b)` and `solveVector(Vector<T> b)`.
  - **Cholesky Factorization (`CholeskyDecomposition<T>`)**: $A = L L^*$ for symmetric/Hermitian positive-definite matrices, executing in $\frac{1}{3} N^3$ operations ($2\times$ faster than LU). Enforces strictly positive real diagonal entries $L_{ii} > 0$ and verifies Hermitian symmetry $A_{kj} = \overline{A_{jk}}$.
  - **Singular Value Decomposition (`SingularValueDecomposition`)**: Golub-Reinsch bidiagonalization with implicit QR shifts computing $A = U \Sigma V^T$. Provides pseudo-inverses, rank estimation, and singular value inspection.
  - **Eigenvalue Decomposition (`EigenvalueDecomposition`)**: Reduction to Hessenberg form followed by Francis shifted double-step QR algorithm computing real and complex eigenvalues/eigenvectors.


### 3.6 Vector Operations, Cumulative Scans & Geometric Decompositions

- **Reasoning**: Geometric and functional operations on vectors are foundational across numerical analysis, optimization, and signal processing.
- **Implementation & Constraints**:
  - Generalized $L_p$ norm: `norm([p = 2.0])` supports $L_1$ (Manhattan), $L_2$ (Euclidean), and $L_\infty$ (Chebyshev maximum absolute).
  - Cumulative prefix scans:
    - `cumsum({Vector<T>? target})`: Computes prefix sum in $\mathcal{O}(N)$ single pass using `field.add`. Fast paths iterate contiguous buffers directly; supports in-place accumulation (`target: this`) and safe defensive copying for overlapping slice aliases.
    - `cumprod({Vector<T>? target})`: Computes prefix product in $\mathcal{O}(N)$ single pass starting from `field.multiplicativeIdentity` using `field.mul`.
  - Orthogonal decomposition (`VectorProjectionExtension<T extends num>` in `lib/src/linear/projection.dart`):
    - `project(onto)`: Computes $\operatorname{proj}_{\mathbf{v}}(\mathbf{u}) = \frac{\langle \mathbf{u}, \mathbf{v} \rangle}{\|\mathbf{v}\|_2^2} \mathbf{v}$. Throws `ArgumentError` if lengths mismatch or if $\|\mathbf{v}\|_2^2 < 1\text{e-}15$.
    - `reject(from)`: Computes $\operatorname{oproj}_{\mathbf{v}}(\mathbf{u}) = \mathbf{u} - \operatorname{proj}_{\mathbf{v}}(\mathbf{u})$ via in-place reusable buffer update with zero extraneous allocations.
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
  - Null counts are queried in $\mathcal{O}(1)$ time via an internal `_nullCount` counter updated incrementally on bit state transitions (`setNull`, `setValid`). Bulk byte constructors compute null counts using 32-bit parallel Hamming weight via `int.bitCount` (`package:more/math.dart`) across word chunks with unused tail bits masked out.
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
    - Aggregates groups across columns with `Agg.count`, `Agg.sum`, `Agg.mean`, `Agg.min`, `Agg.max`, `Agg.std`, `Agg.var_`, `Agg.median`, `Agg.first`, and `Agg.last`.
    - Numerically stable single-pass Welford accumulators for sample variance (`Agg.var_`, with Bessel's correction $n - 1$, returning `null` when $n < 2$) and sample standard deviation (`Agg.std`).
    - In-place Dutch National Flag 3-way Quickselect for median (`Agg.median`) operating on a reused group scratch buffer without temporary heap allocations.

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

### 4.6 JSON Import & Export Serialization (`lib/src/dataframe/json.dart`)

- **Reasoning**: Web APIs, cloud data pipelines, and microservices exchange tabular data in standard JSON orientations. High-performance JSON interchange requires robust support for both array-of-objects, split columnar payloads, nested column-map orientations, and pure matrix values with clean null handling and type inference.
- **Implementation & Constraints**:
  - `JsonOrient` enumeration:
    - `records`: List of row objects `[{"col1": v1, "col2": v2}, ...]`.
    - `split`: Payload object `{"columns": ["col1", "col2"], "data": [[v1, v2], ...]}` separating schema from matrix data.
    - `columns`: Map of column arrays `{"col1": [v1, v2], ...}` or row-indexed maps `{"col1": {"0": v1, "1": v2}}` (supporting non-sequential indices and string index labels).
    - `values_`: 2D array of rows `[[v1, v2], ...]`, defaulting column names to `col_0`, `col_1`, ... or custom names defined via `columnTypes`.
  - Auto-detection:
    - Automatically determines orientation when `orient` is omitted: root `List` of `Map` -> `records`, root `List` of `List` -> `values_`, root `Map` with `'columns'` and 2D `'data'` -> `split`, other root `Map` -> `columns`.
  - Type-safe deserialization:
    - Automatic type inference (`Series.fromList`) with optional explicit `columnTypes: Map<String, DataType<dynamic>>` parameter. Non-null values are automatically coerced using `DataType.cast`.
    - Full null tracking preserved across all orientations with underlying `ValidityMask`.
  - Zero-overhead record extraction: `df.toRecords()` and `DataFrame.fromRecords` provide direct in-memory record conversions without JSON string encoding round-trips.

---

## 5. Hardware Acceleration & FFI Subsystem (`lib/src/acceleration/`)

### 5.1 Dynamic Library Discovery & Platform Detection

- **Reasoning**: High-performance linear algebra must transparently leverage hardware-tuned BLAS and LAPACK vendor libraries when available on the host OS.
- **Implementation & Constraints**:
  - `loadBlas()` in `lib/src/acceleration/blas/cblas_ffi.dart` dynamically queries system libraries:
    - macOS: Apple Accelerate framework (`Accelerate.framework/Accelerate`).
    - Linux: `libopenblas.so`, `libblas.so`, `liblapack.so`.
    - Windows: `openblas.dll`.
  - If native libraries are missing, the system gracefully falls back to pure-Dart algorithms without crashing.

### 5.2 BLAS Level 1, 2, 3 FFI Dispatch

- **Reasoning**: Hardware BLAS provides multi-threaded, SIMD-vectorized matrix arithmetic operating at tens of GFLOPS.
- **Implementation & Constraints**:
  - Bound via `dart:ffi`:
    - Level 1: `ddot`, `sdot` (dot products), `dnrm2`, `snrm2` (Euclidean norms), `daxpy`, `saxpy` ($y \leftarrow \alpha x + y$), `dscal`, `sscal` (scaling).
    - Level 2: `dgemv`, `sgemv` (matrix-vector multiplication), `dtrmv`, `strmv` (triangular matrix-vector multiplication).
    - Level 3: `dgemm`, `sgemm` (general matrix multiplication), `dsymm`, `ssymm` (symmetric matrix multiplication), `dtrmm`, `strmm` (triangular matrix multiplication), `dsyrk`, `ssyrk`, `dsyr2`, `ssyr2` (symmetric rank-$k$ and rank-2 updates).
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
    - `dsyev`, `ssyev`: LAPACK symmetric eigenvalue solvers computing real eigenvalues in ascending order and corresponding orthonormal eigenvectors. Transparently dispatched by `EigenvalueDecomposition` when matrices are symmetric with `DataType.float64` under active hardware acceleration, seamlessly falling back to pure Dart Householder tridiagonal reduction (`_tred2`) and implicit QL iteration (`_tql2`) when acceleration is disabled or for non-float64 types.

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
  - `SimdEngine` (`lib/src/acceleration/fallback/simd.dart`) leverages Dart's native `Float32x4List` and `Float32x4` types.
  - Evaluates 4-lane parallel floating-point arithmetic for element-wise vector/matrix addition, subtraction, multiplication, and dot products.

### 5.6 Pure-Dart Cache-Blocked GEMM (`lib/src/acceleration/fallback/pure_dart_gemm.dart`)

- **Reasoning**: For small matrices ($N < 64$), FFI leaf-call overhead exceeds kernel execution time. On non-FFI environments (Flutter Web, Wasm) or when native BLAS is disabled, naive 3-loop GEMM causes severe CPU cache thrashing due to non-sequential memory strides.
- **Implementation & Constraints**:
  - `cacheBlockedGemmFloat64` and `cacheBlockedGemmFloat32` implement cache-tiled matrix multiplication with $32 \times 32$ block tiles ($32 \times 32 \times 8\text{ bytes} = 8\text{ KB}$, fitting within L1 data caches) and $4\times$ loop unrolling.
  - Transparent dispatch: `AccelerationManager.dgemm` and `sgemm` automatically route small matrices ($m < 64 \land n < 64 \land k < 64$) or non-FFI executions directly to the cache-blocked algorithms, bypassing FFI overhead while sustaining optimal memory hierarchy locality and sequential register streaming.
  - Supports all transposition combinations: `cblasNoTrans`, `cblasTrans`, with arbitrary $\alpha$ and $\beta$ accumulation scaling.

---

## 6. Numerical Analysis, ODEs & Optimization (`package:data/numeric.dart`)

### 6.1 Nonlinear Optimization Routines

- **Reasoning**: Finding minima of complex objective functions is ubiquitous in machine learning, engineering design, and parameter fitting.
- **Implementation & Constraints**:
  - `brentMinimize`: Univariate golden-section search combined with parabolic interpolation, achieving superlinear convergence without derivative requirements.
  - `nelderMead`: Multivariate derivative-free simplex method, resilient to non-smooth or noisy objective functions.
  - `bfgs`: Quasi-Newton Broyden-Fletcher-Goldfarb-Shanno method utilizing numerical gradients and Armijo line search to maintain a positive-definite Hessian approximation.
  - `lbfgs`: Limited-memory BFGS storing a rolling history of $m$ displacement vectors, enabling multivariate optimization over thousands of parameters with $\mathcal{O}(m N)$ memory.
  - `minimizeConstrained`: Constrained optimization handling box bounds (`BoxBound`), general inequality constraints ($g_i(x) \le 0$), and equality constraints ($h_j(x) = 0$):
    - Box bounds $[l_i, u_i]$ utilize coordinate-wise smooth sigmoid variable transformations ($x_i = l_i + \frac{u_i - l_i}{1 + e^{-y_i}}$) with chain-rule gradient scaling ($\nabla_y F = \nabla_x L_A \odot \Phi'(y)$), strictly preventing out-of-bounds evaluations and domain violations.
    - General inequality and equality constraints are resolved via the Powell-Hestenes-Rockafellar Augmented Lagrangian Method (ALM) with adaptive penalty parameter scaling ($\mu$) and multiplier updates ($\lambda_j \leftarrow \max(0, \lambda_j + \mu g_j(x))$, $\nu_k \leftarrow \nu_k + \mu h_k(x)$).
    - Transparently accepts numerical closures (`double Function(Vector<double>)` or `double Function(double)` for 1D) or symbolic [Expr] expressions with automatic analytical gradient generation.

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
  - `CubicSpline`: $C^2$ continuous cubic spline interpolation supporting natural ($S''(x) = 0$) and clamped ($S'(x) = f'$) boundary conditions. Formulates spline second derivatives as a tridiagonal linear system solved in $\mathcal{O}(N)$ time via `solveTridiagonal`.
  - `PchipInterpolation`: Piecewise Cubic Hermite Interpolating Polynomial preserving monotonicity and preventing overshoot between data points.
  - `BilinearInterpolation`: 2D rectilinear grid interpolation using four-point convex weighting with partial gradient evaluation.
  - `BicubicInterpolation`: 2D surface interpolation over a rectilinear grid with $C^1$ continuity using 16-coefficient bicubic patches ($A = M F M^T$) with partial derivatives and continuous gradient extraction.
  - `leastSquares`: General linear regression using LAPACK `dgels`, Householder QR, or SVD.
  - `polynomialRegression`: Vandermonde polynomial fitting using QR decomposition with optional Tikhonov / Ridge L2 regularization (`lambda`) suppressing high-frequency Runge oscillations and conditioning rank-deficient systems.
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
  - Weighted statistics: `weightedMean` and `weightedVariance` supporting observation weights and Bessel reliability weight correction ($s_w^2 = \frac{\sum w_i}{(\sum w_i)^2 - \sum w_i^2} \sum w_i (x_i - \bar{x}_w)^2$).
  - Moving window aggregations: Simple moving average (`movingAverage`) over rolling windows in $\mathcal{O}(N)$ time with $\mathcal{O}(1)$ updates per step, and exponential moving average (`exponentialMovingAverage`) with smoothing parameter $\alpha \in (0, 1]$.
  - Association matrices: `covarianceMatrix`, `correlationMatrix` (Pearson linear correlation and Spearman rank-order correlation).
  - Principal Component Analysis (`pca`): Computes centered covariance matrices, orthogonal eigenvectors, eigenvalues, and explained variance ratios for dimensionality reduction.

### 7.2 Parametric Distributions & Maximum Likelihood Estimation (MLE)

- **Reasoning**: Closed-form probability modeling and parameter inference from data across univariate and multivariate domains.
- **Implementation & Constraints**:
  - Univariate distributions (12 implemented with `pdf`/`pmf`, `cdf`, quantile/`inverseCdf`, and random sampling):
    - Continuous: `NormalDistribution`, `StudentTDistribution`, `FDistribution`, `BetaDistribution`, `GammaDistribution`, `ExponentialDistribution`, `ChiSquaredDistribution`, `UniformDistribution`.
    - Discrete: `BernoulliDistribution`, `BinomialDistribution`, `PoissonDistribution`, `DiscreteUniformDistribution`.
  - Multivariate distributions (`MultivariateDistribution<T extends num>`):
    - `MultivariateNormalDistribution`: Correlated Gaussian density over $\mathbb{R}^k$ parameterized by mean $\mu \in \mathbb{R}^k$ and covariance matrix $\Sigma \in \mathbb{R}^{k \times k}$. Computes Cholesky factor $\Sigma = L L^T$, evaluates $\ln \text{PDF}$ via forward triangular solve ($L y = x - \mu \implies (x-\mu)^T \Sigma^{-1} (x-\mu) = \|y\|_2^2$), and generates correlated random samples $x = \mu + L z$ with standard normal $z \sim \mathcal{N}(0, I_k)$.
    - `DirichletDistribution`: Continuous probability distribution over the open $(k-1)$-simplex parameterized by concentration vector $\alpha \in \mathbb{R}^k$ ($\alpha_i > 0$). Evaluates log multivariate beta function via `gammaLn`, provides exact covariance matrix, and generates samples via normalized independent Gamma draws $Y_i \sim \text{Gamma}(\alpha_i, 1.0)$.
    - `MultinomialDistribution`: Discrete distribution over $k$ categories across $n$ trials parameterized by probability vector $p \in [0, 1]^k$ ($\sum p_i = 1$). Evaluates log PMF via log-factorials (`factorialLn`), provides exact covariance matrix, and draws samples via categorical accumulation.
  - Univariate distributions support analytical or numerical MLE fitting via `factory .fit(data)` constructors.

### 7.3 Hypothesis Testing Suite

- **Reasoning**: Rigorous statistical inference for experimental hypothesis testing, goodness-of-fit validation, and non-parametric paired testing.
- **Implementation & Constraints**:
  - `tTestOneSample`: Student's t-test comparing sample mean against hypothesized value.
  - `tTestTwoSample`: Two-sample t-test supporting Student's pooled variance and Welch's t-test for unequal variances.
  - `tTestPaired`: Paired-difference t-test.
  - `oneWayAnova`: One-way Analysis of Variance testing equality of three or more group means.
  - `chiSquaredTest` and `chiSquaredContingency`: Goodness-of-fit and contingency table test of independence.
  - `mannWhitneyUTest`: Non-parametric test for equality of two continuous distributions.
  - `kolmogorovSmirnovTest`: One-sample Kolmogorov-Smirnov test evaluating maximum supremum distance $D = \max(D^+, D^-)$ between empirical CDF and continuous theoretical distribution with asymptotic Stephens approximation for $p$-values.
  - `kolmogorovSmirnov2Sample`: Two-sample Kolmogorov-Smirnov test assessing whether two independent empirical samples originate from the same continuous distribution using effective sample size $n_e = \frac{n_1 n_2}{n_1 + n_2}$.
  - `jarqueBeraTest`: Normality test matching sample skewness $S$ and kurtosis $K$ against normal expectations ($S = 0, K = 3$), testing asymptotic statistic $JB = \frac{n}{6}(S^2 + \frac{(K-3)^2}{4}) \sim \chi^2(2)$.
  - `wilcoxonSignedRankTest`: Non-parametric paired signed-rank test (or one-sample median against 0) with rank-sum calculation, tie-corrected variance, and continuity-corrected normal approximation.

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
    - Generalized Laguerre polynomials ($L_n^{(\alpha)}(x)$ via `Polynomial.laguerreL` / `laguerreL` in `lib/src/polynomial/orthogonal.dart`) computed via 3-term recurrence: $L_{k+1}^{(\alpha)}(x) = \frac{1}{k+1} ((2k + 1 + \alpha - x) L_k^{(\alpha)}(x) - (k + \alpha) L_{k-1}^{(\alpha)}(x))$. Direct point evaluation available via `laguerreEvaluate(n, x, {alpha})`.
  - Evaluated via `clenshawEvaluate` (`lib/src/polynomial/orthogonal.dart`), which evaluates three-term recurrence relations stably without expanding polynomial coefficients.

### 8.3 Formal Polynomial Arithmetic, Composition & Root Isolation

- **Reasoning**: Exact algebraic manipulation, composition, and root finding for arbitrary degrees.
- **Implementation & Constraints**:
  - Formal division with remainder (`divide`, `/`, `%`) and Euclidean Greatest Common Divisor (`gcd`).
  - Composition: `poly.compose(other)` evaluates $(P \circ Q)(x) = P(Q(x))$ algebraically using Horner's recurrence.
  - Differentiation (`derivative()`) and anti-differentiation (`integrate()`).
  - Root isolation:
    - Degree 1: Analytical linear root.
    - Degree 2: Numerically stable quadratic formula with sign preservation to prevent catastrophic cancellation.
    - Degree $\ge 3$: Constructs Frobenius companion matrix of monic polynomial and solves for complex roots via `EigenvalueDecomposition`.

### 8.4 Rational Functions (`RationalFunction<T>`)

- **Reasoning**: Many scientific modeling and transfer function problems involve ratios of polynomials $R(x) = \frac{P(x)}{Q(x)}$.
- **Implementation & Constraints**:
  - `RationalFunction<T>` in `lib/src/polynomial/rational.dart` encapsulates numerator and denominator polynomials.
  - Automatic and explicit GCD simplification via `simplify()` dividing out $\gcd(P, Q)$ and normalizing the denominator to monic form.
  - Arithmetic overloads (`+`, `-`, `*`, `/`, `unary-`) with automatic cross-multiplication and canonical simplification.
  - Exact evaluation (`evaluate`, `evaluateDouble`) with pole zero-division error handling.
  - Formal derivative (`derivative()`) computed using the quotient rule: $\left(\frac{P}{Q}\right)' = \frac{P' Q - P Q'}{Q^2}$.

---

## 9. Symbolic Computation Engine (`package:data/symbolic.dart`)

### 9.1 Pure Functional Algebraic AST

- **Reasoning**: Mathematical expressions require an abstract syntax tree (AST) for analytical manipulation, simplification, and compilation.
- **Implementation & Constraints**:
  - Base class `Expr` (`lib/src/symbolic/ast.dart`) with immutable node subtypes:
    - Terminals: `Constant(double value, [String? name])` (with named constants `Constant.pi`, `Constant.e` and top-level `pi`, `e`), `Variable(String name)`.
    - Arithmetic: `Add`, `Sub`, `Mul`, `Div`, `Neg`, `Pow`.
    - Transcendental: `Sin`, `Cos`, `Exp`, `Ln`.
  - Overloads Dart arithmetic operators (`+`, `-`, `*`, `/`) so standard Dart code builds symbolic trees naturally.

### 9.2 Exact Automated Symbolic Differentiation

- **Reasoning**: Symbolic differentiation computes exact analytical derivatives without finite-difference approximation errors or step-size tuning.
- **Implementation & Constraints**:
  - `DifferentiationExtension on Expr` in `lib/src/symbolic/calculus/differentiation.dart` provides `expr.diff(variable)`:
    - Implemented as an exhaustive `switch (expr)` pattern match over `sealed class Expr`.
    - Product rule: $(f \cdot g)' = f' g + f g'$.
    - Quotient rule: $(f / g)' = (f' g - f g') / g^2$.
    - Power rule: Generalized 2-tuple record pattern `(base.dependsOn(x), exponent.dependsOn(x))` handling scalar constant, power rule $u^n$, exponential $c^u$, and general $(u^v)' = u^v (v' \ln u + v \frac{u'}{u})$.
    - Chain rule across all transcendental nodes ($\sin, \cos, \exp, \ln$).

### 9.3 Canonical Simplification Engine

- **Reasoning**: Repeated differentiation and algebraic construction create bloated expression trees (e.g. $0 \cdot x + 1 \cdot f(x)$).
- **Implementation & Constraints**:
  - `SimplifierExtension on Expr` in `lib/src/symbolic/simplifier.dart` provides `expr.simplify()`, executing bottom-up recursive reductions via exhaustive pattern matching:
    - Constant folding: Evaluates expressions composed solely of numeric constants.
    - Identity elimination: $x + 0 \to x$, $x \times 1 \to x$, $x \times 0 \to 0$, $x^1 \to x$, $x^0 \to 1$.
    - Structural grouping: Identical term aggregation and negation cancellations ($x - x \to 0$, $-(-x) \to x$).

### 9.4 Positional JIT & Tensor Kernel Compilation

- **Reasoning**: Interpreting AST trees by traversing nodes during iterative loops is orders of magnitude slower than compiled code.
- **Implementation & Constraints**:
  - `CompilerExtension on Expr` in `lib/src/symbolic/compiler.dart` provides:
    - `compile1D(varName)`: Produces a high-speed closure `double Function(double)`.
    - `compile(varOrder)`: Produces a multivariate closure `double Function(List<double>)`.
    - `compileTensorKernel(varOrder)`: Compiles the simplified AST into a linear instruction sequence (flattened post-order RPN bytecode evaluator) over a single pre-allocated `Float64List` stack. Bypasses recursive closure call overhead and intermediate argument buffers, executing flat-loop vectorized evaluations directly from input buffers to output buffer.

### 9.5 Symbolic-to-Numeric Synergy

- **Reasoning**: Unifying analytical calculus with numeric optimization algorithms.
- **Implementation & Constraints**:
  - Numeric optimizers (`brentMinimize`, `nelderMead`, `bfgs`) accept `Expr` ASTs directly.
  - When an `Expr` is passed to `bfgs`, analytical gradients are computed automatically via `expr.diff()`, completely eliminating finite-difference approximation errors and accelerating convergence.

### 9.6 Exact Analytical Symbolic Integration & Adaptive Quadrature Fallback

- **Reasoning**: Exact symbolic anti-differentiation is essential for closed-form calculus, indefinite integration, and high-precision definite integration. When an elementary anti-derivative does not exist or evaluation is non-finite, bridging to high-precision numerical quadrature guarantees universal solvability.
- **Implementation & Constraints**:
  - Modular calculus extensions exported directly via `package:data/symbolic.dart`:
    - `IntegrationExtension on Expr` in `lib/src/symbolic/calculus/integration.dart` provides `integrate(variable, {from, to})`.
    - `MultivariableExtension on Expr` in `lib/src/symbolic/calculus/multivariable.dart` provides `gradient(variables)` and `hessian(variables)`.
    - `MultivariableIterableExtension on Iterable<Expr>` in `lib/src/symbolic/calculus/multivariable.dart` provides `jacobian(variables)`.
    - `TaylorExtension on Expr` in `lib/src/symbolic/calculus/taylor.dart` provides `taylorSeries(variable, {around, order})`.
    - `DifferentiationExtension on Expr` in `lib/src/symbolic/calculus/differentiation.dart` provides `diff(variable)`.
    - `LinearFormExtension on Expr` in `lib/src/symbolic/calculus/linear_form.dart` provides `matchLinear(variable)`, `matchScalarMultiple(target, variable)`, and `scale(factor)`.
    - **Analytical Anti-Differentiation Rules**:
      - *Constants & Independent*: $\int c\,dx = c x$ ($\int 0\,dx = 0$), $\int y\,dx = y x$ for $y \ne x$.
      - *Linear combinations*: $\int (a f(x) + b g(x))\,dx = a \int f\,dx + b \int g\,dx$, $\int (-f)\,dx = -\int f\,dx$, $\int (f / c)\,dx = \frac{1}{c} \int f\,dx$.
      - *Power rule*: $\int (ax + b)^n\,dx = \frac{(ax + b)^{n+1}}{a (n+1)}$ for $n \ne -1$; $\int (ax + b)^{-1}\,dx = \frac{\ln(ax + b)}{a}$; $\int \frac{c}{ax + b}\,dx = \frac{c \ln(ax + b)}{a}$; $\int \frac{c}{(ax + b)^n}\,dx = \int c (ax + b)^{-n}\,dx$.
      - *Exponentials*: $\int e^{ax + b}\,dx = \frac{e^{ax + b}}{a}$; $\int c^{ax + b}\,dx = \frac{c^{ax + b}}{a \ln c}$ ($c$ independent of $variable$, $c > 0, c \ne 1$ if numeric).
      - *Trigonometrics*: $\int \sin(ax + b)\,dx = -\frac{\cos(ax + b)}{a}$; $\int \cos(ax + b)\,dx = \frac{\sin(ax + b)}{a}$.
      - *Logarithms*: $\int \ln(ax + b)\,dx = \frac{(ax + b) \ln(ax + b) - (ax + b)}{a}$.
      - *Products, Quotients & Substitutions*: Chain-rule substitution ($\int u'(x) f(u(x))\,dx = F(u(x))$, including rational power denominators $\frac{u'(x)}{u(x)^n}$ and general scalar matching via `matchScalarMultiple`), integration by parts for linear polynomial $\times$ integrable term ($P(x) e^{cx+d}$, $P(x) c^{ax+b}$, $P(x) \cos(cx+d)$, $P(x) \sin(cx+d)$, $P(x) \ln(cx+d)$), distributive expansion across additions/subtractions ($(f_1 + f_2) g \to f_1 g + f_2 g$), and identity multiplication ($u \cdot u \to u^2$).
  - **Definite Integration & Numerical Quadrature Fallback**:
    - Definite integration validates that both bounds are supplied; if $from == to$, returns `Constant(0.0)`. Supports reversed integration bounds ($from > to$).
    - Evaluates analytical anti-derivative $F(b) - F(a)$. If free variables remain, returns the simplified symbolic expression; if scalar, returns `Constant(val)`.
    - If no closed-form anti-derivative exists (throws `UnsupportedError`) or evaluation is non-finite, automatically falls back to Adaptive Gauss-Kronrod quadrature (`gaussKronrod`) from `lib/src/numeric/integration.dart`.
    - For indefinite integrals, unsupported forms throw `UnsupportedError`.

### 9.7 LaTeX Serialization & Taylor Series Polynomial Bridge

- **Reasoning**: Bridging symbolic mathematics to publication-grade document generation and high-performance polynomial algebra.
- **Implementation & Constraints**:
  - `LatexExtension on Expr` in `lib/src/symbolic/latex.dart` provides `toLatex()`, rendering publication-grade LaTeX math syntax via pattern matching:
    - Fractions formatted with `\frac{left}{right}` without extraneous outer parentheses on numerator or denominator.
    - Multiplication formatted with `\cdot` with precedence parentheses wrapping additive operands.
    - Exponentiation formatted with `{base}^{exp}` with automatic base wrapping for compound bases.
    - Transcendentals formatted using LaTeX math operators (`\sin(...)`, `\cos(...)`, `e^{...}`, `\ln(...)`).
  - `Polynomial.fromExpr(expr, variable, {around = 0.0, order = 4, type})` in `lib/src/polynomial/polynomial.dart`:
    - Constructs an exact `Polynomial<T>` by evaluating Taylor series coefficients $c_k = \frac{f^{(k)}(x_0)}{k!}$.
    - For expansions around $x_0 = 0.0$, initializes coefficients directly into an array in $\mathcal{O}(order)$ without polynomial power multiplications.
    - For expansions around $x_0 \ne 0.0$, accumulates polynomial powers of $(x - x_0)$ using Horner and polynomial product operations.

### 9.8 Symbolic Equation & Linear System Solving (`solve`, `solveSystem`)

- **Reasoning**: Exact analytical resolution of algebraic equations and simultaneous linear systems directly from symbolic AST expressions.
- **Implementation & Constraints**:
  - `SolverExtension on Expr` in `lib/src/symbolic/solver.dart` provides `expr.solve(variable)`:
    - Linear equations: Identifies affine forms $a x + b = 0$ via `matchLinear`, returning exact root $x = -b / a$.
    - Quadratic equations: Identifies degree-2 forms $a x^2 + b x + c = 0$ via second derivative curvature analysis ($a = f''/2$, $b = f'(0)$, $c = f(0)$) and solves via discriminant formula $x = \frac{-b \pm \sqrt{b^2 - 4ac}}{2a}$ with real-root discrimination.
    - Factored equations: Recursively partitions product nodes $f(x) \cdot g(x) = 0$ into component roots $\text{solve}(f) \cup \text{solve}(g)$.
    - Transcendental isolation: Inverts elementary transcendental equations $f(u(x)) = c$ across $\exp, \ln, \text{pow}$, isolating inner arguments and recursively solving inverted forms.
  - `SystemSolverExtension on Iterable<Expr>` in `lib/src/symbolic/solver.dart` provides `equations.solveSystem(variables)`:
    - Solves square $N \times N$ linear systems $f_i(x_1, \dots, x_n) = 0$.
    - Computes exact Jacobian matrix entries $A_{i, j} = \frac{\partial f_i}{\partial x_j}$ and constant vector $b_i = -f_i(\vec{0})$.
    - Solves via symbolic Gaussian elimination with partial pivoting and back-substitution, returning `Map<String, Expr>` or `null` for singular systems.

### 9.9 Symbolic Mathematical Constants & PetitParser Grammar Parsing

- **Reasoning**: Symbolic math requires first-class mathematical constants ($\pi, e$) and text parsing capabilities to construct AST expressions ergonomically from mathematical strings, papers, and interactive user inputs.
- **Implementation & Constraints**:
  - `Constant` in `lib/src/symbolic/ast.dart` supports named constants `Constant.pi` ($\pi \approx 3.141592653589793$) and `Constant.e` ($e \approx 2.718281828459045$), also exported as top-level `pi` and `e`.
  - LaTeX serialization formats `Constant.pi` as `\pi` and `Constant.e` as `e`.
  - Simplifier recognizes mathematical identities involving constants ($\sin(\pi) \to 0$, $\cos(\pi) \to -1$, $\ln(e) \to 1$, $e^x \to \exp(x)$, $\exp(1) \to e$), while strictly preserving named constant identity across algebraic reductions ($\pi \cdot 1 \to \pi$, $\pi + 0 \to \pi$, $\pi - 0 \to \pi$, $e^1 \to e$, $\pi - \pi \to 0$, $\pi / \pi \to 1$) without premature floating-point folding.
  - `ExpressionParser` (`lib/src/symbolic/parser.dart`) powered by `package:petitparser`:
    - `buildExpressionParser()` creates a customizable `Parser<Expr>` using `ExpressionBuilder<Expr>` with exact operator precedence and associativity.
    - `Expr.parse(String input)` and `Expr.tryParse(String input)` provide high-level parsing with strict syntax validation, throwing `FormatException` on parse errors.
    - Supported syntax:
      - Numbers: Integers, decimals, and scientific notation (`42`, `3.14`, `1e-5`, `.5`).
      - Named constants: `pi`, `PI`, `\pi`, `π`, `e`, `\e`, `ℯ`. Word boundary lookahead ensures no false matches against identifiers (`pixel`, `eigen`, `eta`).
      - Variables: Alphanumeric and underscore identifiers (`x`, `y1`, `var_2`), LaTeX commands (`\theta`, `\alpha`), and direct Unicode Greek letters (`θ`, `α`, `β`).
      - Functions: `sin`, `cos`, `exp`, `ln`, `log`, `sqrt` with parentheses `(...)`, brackets `[...]`, or curly braces `{...}`, case-insensitively and with optional LaTeX backslash (`\sin(...)`).
      - LaTeX constructs: `\frac{num}{den}`, `\dfrac{num}{den}`, `\cdot`, `\times`, `\div`.
      - Operators: Prefix `+`, `-`; right-associative exponentiation `^`, `**`; left-associative `*`, `/`; left-associative `+`, `-`.
      - Delimiters: Parentheses `(...)`, brackets `[...]`, braces `{...}`.
    - Verified defect-free with PetitParser grammar reflection linter (`linter(expressionParser).isEmpty`).
