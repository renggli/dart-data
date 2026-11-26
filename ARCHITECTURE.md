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
  - Direct `ByteBuffer` memory inspection utilities reside in `lib/src/type/utils/memory.dart`.
  - `sharesMemory(List a, List b)` and `hasOverlap(TypedData a, TypedData b)` verify whether two storage arrays share underlying physical RAM via byte buffer pointer arithmetic and byte offset inspection.
  - In `Tensor.unaryOperation`, `binaryOperation`, `matmul`, and `reduction`, memory aliasing between inputs and output targets is detected prior to loop execution.
  - If hazardous overlap is detected (e.g., writing to a broadcast operand's buffer), intermediate calculations automatically route through a temporary copy buffer before writing to the target.

### 1.3 Unified Type System & Algebraic Fields

- **Reasoning**: Numeric and scientific operations require consistent algebraic structures (identities, field operations, numerical stability). Immutable defaults eliminate race conditions:
  - `DataType.index`: Static constant `DataType.uint32` for indexing collections, rows, and columns.
  - `DataType.integer`: Static constant `DataType.int32` for integer arithmetic.
  - `DataType.float`: Static constant `DataType.float64` for floating point arithmetic.
- **Implementation & Constraints**:
  - Container constructors (`Tensor`, `Matrix`, `Vector`) and `DataType.newList` automatically respect `DataType.float` and `DataType.integer` when no explicit type is specified.
  - `Field<T>` and `ExtendedField<T>` in `lib/src/type/models/field.dart` define algebraic contracts:
    - `Field<T>` defines core algebraic and analytic operations: identities (`additiveIdentity`, `multiplicativeIdentity`), arithmetic (`add`, `sub`, `mul`, `div`, `neg`, `inv`, `scale`), discrete algebra (`mod`, `division`, `remainder`, `pow`, `modPow`, `modInverse`, `gcd`), analytic functions (`abs`, `norm`, `sqrt`, `exp`, `log`, `conjugate`), and limits (`nan`, `infinity`, `negativeInfinity`). Non-core/discrete operations provide default throwing implementations via `unsupportedOperation(...)`, while `conjugate` defaults to identity.
    - `ExtendedField<T>` extends `Field<T>` as the base class for fields with extended analytical domains.
  - Implemented across all built-in data types: floating-point (`Float32DataType`, `Float64DataType`), integers (`Int8DataType` through `Int64DataType`, unsigned variants), `BigIntDataType`, `ComplexDataType`, `FractionDataType`, `QuaternionDataType`, `NumericDataType`, `StringDataType`, `BooleanDataType`, `ObjectDataType`, `DynamicDataType`, and `NullableDataType`.
  - Exact fractional scaling: `IntegerField.scale` uses `(a * f).round()`, and `BigIntField.scale` uses exact `Fraction.fromDouble` multiplication before truncation, eliminating rounding drift.
  - Robustness & edge-case invariants: `Equality.isClose` rejects `NaN` or negative `epsilon`; `NullableEquality` propagates non-null `isEqual`/`isClose` (preserving IEEE-754 `NaN` inequality); `ComplexField` and `QuaternionField` use overflow- and underflow-safe scaling for `norm`, `inv`, and `div`; `Float64ComplexList.fromData` validates even buffer lengths at runtime; `ObjectDataType.cast` throws `ArgumentError` on invalid inputs.
  - **Dart 3 Class Modifiers & Subsystem Encapsulation**:
    - `DataType<T>` is an `abstract base class`, with category hierarchies `abstract base class TypedDataType<T, L>`, `IntegerDataType<L>`, and `FloatDataType<L>`. Subclasses must adhere to inheritance rules (`base` or `final`), preventing uncoordinated interface mocking across libraries while avoiding `sealed` file-confinement limits.
    - All built-in concrete data types (`Float64DataType`, `Int32DataType`, `BigIntDataType`, `ComplexDataType`, `FractionDataType`, `NumericDataType`, `BooleanDataType`, `StringDataType`, `ObjectDataType`, `NullableDataType`, etc.) are `final class`.
    - `Field<T>` and `ExtendedField<T>` are declared `abstract class`, providing default implementations for optional and discrete operations to eliminate boilerplate. Concrete field classes (`FloatField`, `IntegerField`, `BigIntField`, `ComplexField`, `FractionField`, `NumericField`, `ExprField`) extend `ExtendedField<T>` as `final class`, while `QuaternionField` extends `Field<Quaternion>` as `final class`.
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
    - On `Float64Vector`: algebraic inner product (`dot`) routes directly to BLAS `ddot`, and Euclidean norm (`norm([pNorm = 2])`) routes directly to BLAS `dnrm2` when $p = 2$.
    - Seamless subtyping: `Float64Tensor implements Tensor<double>`, `Float64Matrix implements Matrix<double>`, and `Float64Vector implements Vector<double>`, enabling them to pass transparently into any existing API accepting generic floating-point containers.

---

## 2. Tensor Subsystem (`package:data/tensor.dart`)

### 2.1 Unified N-D Strided `Layout`

- **Reasoning**: A single strided multidimensional representation unifies vectors, matrices, and N-dimensional tensors under identical memory indexing mathematics.
- **Implementation & Constraints**:
  - `Layout` (`lib/src/tensor/layout.dart`) models dimensions (`shape`), step sizes (`strides`), buffer displacement (`offset`), and whether storage is contiguous (`isContiguous`).
  - Zero-copy transformations produce new `Layout` instances referencing the same underlying `data` buffer:
    - `transpose(axes)` / `swapAxes(axis1, axis2)`: Reorder shape and strides arrays.
    - `squeeze([axis])` / `unsqueeze(axis)`: Remove or insert singleton axes of length `1`.
    - `reshape(newShape)`: Recomputes contiguous strides if layout permits; otherwise triggers a contiguous buffer copy.
    - `getRange({required int axis, int? start, int? end, int step = 1})`: Offsets the start pointer and truncates the dimension along `axis`.
    - `flip(axis)`: Negates the stride along `axis` and offsets the pointer to the end of the axis.
    - `isEmpty` / `isNotEmpty`: Reflect element count (`length == 0` / `length > 0`).

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
  - Reductions in `lib/src/tensor/operations/reduction.dart` (`sum`, `prod`, `mean`, `min`, `max`, `std`, `variance`, `argmin`, `argmax`, and boolean quantifiers `all`, `any`) support arbitrary `axis`, `keepDims`, and `target` options, with overflow-safe Welford mean and `ScaledNormAccumulator` standard deviation / `L_p` norm fallbacks.
  - Axis reductions maintain accumulator buffers and stride directly along fibers without per-element coordinate allocation.
  - Element-wise comparisons include `equalTo` and `notEqualTo`; boolean operations include `~`, `&`, `|`, and `^`.
  - Structural operations in `lib/src/tensor/operations/manipulation.dart`:
    - `concatenate` / `concatenateAll`: Joins tensors along an existing axis using contiguous block copies or zero-allocation strided odometers.
    - `stack` / `stackAll`: Inserts a new dimension and concatenates along it.
    - `tile`: Replicates tensor dimensions periodically.
    - `pad`: Pads boundaries with specified constant fill values.
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
  - `einsum` (`lib/src/tensor/operations/einsum.dart`): Evaluates Einstein summation convention matching NumPy notation (e.g. `'ij,jk->ik'`, `'ii->'`, `'ij,ij->ij'`, `'bij,bjk->bik'`, `'i,j,k->ijk'`). Validates alphabetic subscript labels, strips arbitrary whitespace, parses explicit (`->`) and implicit output conventions, routes 2-operand Hadamard products to aligned element-wise multiplication and 2-operand contractions to `matmul`, and executes universal multi-index odometer evaluation for general contractions, diagonals, traces, and batched equations.

---

## 3. Linear Algebra & Sparse Subsystems (`package:data/linear.dart`)

### 3.1 Dense Matrix and Vector as Tensor Wrappers

- **Reasoning**: Rather than maintaining duplicate storage hierarchies, dense matrices and vectors are thin, zero-copy, rank-constrained wrappers around `Tensor<T>`.
- **Implementation & Constraints**:
  - `Matrix<T>` wraps a `Tensor<T>` where `rank == 2`. Dimensions are `rowCount = shape[0]` and `colCount = shape[1]`.
  - `Vector<T>` wraps a `Tensor<T>` where `rank == 1`. Dimension is `length = shape[0]`.
  - Operations like `matrix.transposed`, `matrix.conjugateTranspose`, `matrix.row(i)`, `matrix.col(j)`, and `matrix.diagonal()` return views or conjugated adjoints backed by the underlying tensor elements (`Float64Matrix.conjugateTranspose` redeclares to `transposed`). Matrices expose `isEmpty`, `isNotEmpty`, `isSquare`, `isSymmetric`, `isHermitian`, `isDiagonal`, `isLowerTriangular`, and `isUpperTriangular`; vectors expose `isEmpty` and `isNotEmpty`.
  - **Trace & Diagonal Extraction**:
    - `matrix.diagonal()` returns a zero-copy 1D view of the main diagonal; `Matrix.identity` and `Matrix.diagonal` initialize diagonals in `O(N)` writes without per-element closures.
    - `matrix.trace` sums main diagonal elements `A_ii` for square matrices, returning `T` via `type.field.add` and throwing `ArgumentError` if non-square (`M != N`). The property is unified strictly on `Matrix<T>`, eliminating shadowing from `MatrixNormExtension`.
    - `matrix.conjugateTranspose` computes the Hermitian adjoint `A^* = conj(A)^T` mapping elements through `type.field.conjugate`.
  - **Direct Fast-Path Indexing**:
    - `Tensor.get2D(r, c)`, `Tensor.set2D(r, c, v)`, `Tensor.get1D(idx)`, and `Tensor.set1D(idx, v)` provide `@pragma('vm:prefer-inline')` unchecked scalar access without heap `List<int>` coordinate allocations.
    - `Matrix<T>` provides `getUnchecked(row, col)` and `setUnchecked(row, col, value)` for performance-critical inner loops (factorizations, transformations), alongside 2D indexing `matrix[r][c]`, bounds-checked `get(row, col)`, `set(row, col, value)`, and row assignment `operator []=(int, Vector<T>)`.
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
      Vector<T> apply(Vector<T> x);
      Vector<T> applyTranspose(Vector<T> x);
      Vector<T> applyConjugateTranspose(Vector<T> x);
      Matrix<T> matmul(Matrix<T> other);
    }
    ```

  - Implemented by `Matrix<T>`, `CsrMatrix<T>`, `CscMatrix<T>`, and `CooMatrix<T>`.

### 3.3 Canonical Sparse Storage Formats

- **Reasoning**: Large-scale scientific and graph problems contain $>99\%$ zero entries. Dense storage wastes memory and induces $\mathcal{O}(N^2)$ operation costs.
- **Implementation & Constraints**:
  - **Compressed Sparse Row (`CsrMatrix`)**:
    - Stores non-zero elements in `values`, corresponding column indices in `colIndices`, and row start pointers in `rowPointers` of size `M + 1`.
    - Optimal for row slicing, `O(log k)` binary-search element lookup (`get`), matrix-vector multiplication `y = A * x`, `O(nnz + m + n)` `transposed`, `conjugateTranspose`, and `toCsc()` conversion, and standard linear system solves.
  - **Compressed Sparse Column (`CscMatrix`)**:
    - Stores column start pointers in `colPointers` of size `N + 1`.
    - Optimal for column slicing, `O(log k)` binary-search element lookup (`get`), transposed products `y = A^T * x`, and `O(nnz + m + n)` `transposed`, `conjugateTranspose`, and `toCsr()` conversion.
  - **Coordinate List (`CooMatrix`)**:
    - Flat triplets `(row, col, value)` with `transposed` and `conjugateTranspose`. Ideal for dynamic assembly and incremental sparse matrix construction before converting to CSR/CSC via `toCsr()` or `toCsc()`.

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
    - `CholeskyMatrixExtension<T>` in `cholesky.dart` (`.cholesky`)
    - `LuMatrixExtension<T>` in `lu.dart` (`.lu`, `.det`, `.inverse`; `Matrix.inverse` delegates directly to `solve(identity)` for LAPACK `dgesv` acceleration)
    - `QrMatrixExtension<T>` in `qr.dart` (`.qr`)
    - `SvdMatrixExtension<T extends num>` in `svd.dart` (`.svd`)
    - `EigenvalueMatrixExtension<T extends num>` in `eigenvalue.dart` (`.eigenvalue`)
  - **Generic Decomposition Classes**: `LUDecomposition<T>`, `QRDecomposition<T>`, and `CholeskyDecomposition<T>` execute specialized primitive double fast-paths when `type == DataType.float64` and generic algebraic field operations via `type.field` for general scalar fields (including `Complex`).
  - **LU Decomposition (`LUDecomposition<T>`)**: Doolittle algorithm with partial row pivoting (`P * A = L * U`) based on modulus norm (`field.norm`). Provides determinant computation, `inverse`, and triangular back-substitution solves for both real and complex fields.
  - **QR Decomposition (`QRDecomposition<T>`)**: Complex Householder reflector transformations yielding unitary/orthogonal `Q` (`Q^* * Q = I`) and upper-triangular `R`. Uses phase factor `mu = x_k / |x_k|` to guarantee numerical stability and provides full-rank least-squares solves via canonical `solve(Matrix<T> b)` and `solveVector(Vector<T> b)`.
  - **Cholesky Factorization (`CholeskyDecomposition<T>`)**: `A = L * L^*` for symmetric/Hermitian positive-definite matrices, executing in roughly one-third `N^3` operations (twice as fast as LU). Enforces strictly positive real diagonal entries `L_ii > 0`, verifies Hermitian symmetry `A_kj = conj(A_jk)`, and provides `inverse` and `solve`/`solveVector`.
  - **Singular Value Decomposition (`SingularValueDecomposition`)**: Golub-Reinsch / LAPACK `dgesvd` computing `A = U * Sigma * V^T` (returning defensive copies from `u`, `vt`, `v` and identity factors on `m == 0` or `n == 0`). Provides pseudo-inverses, rank estimation, condition numbers, and singular value inspection.
  - **Eigenvalue Decomposition (`EigenvalueDecomposition`)**: Symmetric inputs route through `dsyev` (avoiding dense Hessenberg scratch allocations); general inputs reduce to Hessenberg form and apply Francis shifted double-step QR iteration. Exposes `isSymmetric`, defensive `v`, `d`, and real/imaginary/complex eigenvalues.
  - **Matrix Norms (`MatrixNormExtension`)**: Computes `normFrobenius`, `norm1`, `normInfinity`, and delegates `norm2`, `cond`, and `rank` to `SingularValueDecomposition`.

### 3.6 Vector Operations, Cumulative Scans & Geometric Decompositions

- **Reasoning**: Geometric and functional operations on vectors are foundational across numerical analysis, optimization, and signal processing.
- **Implementation & Constraints**:
  - Generalized `L_p` norm: `norm([p = 2.0])` supports `L_1` (Manhattan), `L_2` (Euclidean via BLAS / `ScaledNormAccumulator`), `L_inf` (Chebyshev maximum absolute), and max-abs scaled general `p >= 1`.
  - Cumulative prefix scans:
    - `cumsum({Vector<T>? target})`: Computes prefix sum in `O(N)` single pass using `field.add`. Fast paths iterate contiguous buffers directly; supports in-place accumulation (`target: this`) and safe defensive copying for overlapping slice aliases.
    - `cumprod({Vector<T>? target})`: Computes prefix product in `O(N)` single pass starting from `field.multiplicativeIdentity` using `field.mul`.
  - Orthogonal decomposition (`VectorProjectionExtension<T extends num>` in `lib/src/linear/projection.dart`):
    - `project(onto)`: Computes `(<u, v> / ||v||_2^2) * v` using max-abs scaling across subnormal and near-overflow magnitudes. Throws `ArgumentError` if lengths mismatch or if `onto` is empty, zero, or contains non-finite elements.
    - `reject(from)`: Computes `u - proj_v(u)` via in-place reusable buffer update with zero extraneous allocations.
  - Utility operations: `normalized()`, dot product `u.dot(v)`, outer product `u.outer(v)`, in-place scaling `scaleInPlace(factor)`, and scaled addition `addScaled(v, factor)`.

---

## 4. Tabular Data & DataFrame Engine (`package:data/dataframe.dart`)

### 4.1 Apache Arrow-Aligned Columnar Architecture

- **Reasoning**: Row-oriented tabular storage wastes memory on heterogeneous object headers and exhibits poor cache locality during analytical queries. Columnar storage groups identical types contiguously in memory, enabling vectorization and high-throughput analytical scans.
- **Implementation & Constraints**:
  - `DataFrame` represents a collection of named `Series<T>` instances of identical length exposed through an unmodifiable `columns` list.
  - Column access (`df['col']`, `df.typedColumn<T>('col')`, `df.containsColumn('col')`) is `O(1)`.
  - Slicing and filtering operate column-by-column across independent series.

### 4.2 Null Tracking via Validity Bitmasks

- **Reasoning**: Storing boxed `null` values inside primitive numeric arrays degrades memory density and prevents unboxed typed storage.
- **Implementation & Constraints**:
  - `ValidityMask` (`lib/src/dataframe/bitmask.dart`) uses 1 bit per row entry packed into `Uint8List` byte buffers, matching the Apache Arrow specification (bit = 1 indicates valid, bit = 0 indicates null), exposing an unmodifiable `bytes` view alongside `and`, `validCount`, `[]`, and structural equality/hashing.
  - Null counts are queried in `O(1)` time via an internal `_nullCount` counter updated incrementally on bit state transitions (`setNull`, `setValid`). Bulk byte constructors compute null counts using 32-bit parallel Hamming weight via `int.bitCount` (`package:more/math.dart`) across word chunks with unused tail bits masked out.
  - Unboxed numeric series maintain contiguous `TypedData` lists (`Float64List`, `Int32List`) alongside a `ValidityMask`, ensuring data arrays remain primitive and unboxed.

### 4.3 Columnar Series Hierarchy & Zero-Allocation Operations

- **Reasoning**: Different data types require specialized memory structures. Numeric columns should achieve Arrow-grade performance without boxing primitives or thrashing garbage collection during query operations.
- **Implementation & Constraints**:
  - `TypedSeries<T>`: Backed by `TypedData` lists for high-performance numeric data.
    - Zero-allocation `filter`: Counts valid entries in `filterMask`, pre-allocates target typed array of exact length (`dataType.newList(count)`), copies unboxed elements directly, and maps the validity bitmask without boxing primitives.
    - Zero-allocation `slice`: Slices underlying typed array directly via `data.sublist(start, end)` and slices validity mask via `ValidityMask.slice(start, end)`.
    - Zero-overhead scalar access: `getNonNull(int index)` retrieves non-null values (throwing `StateError` on missing entries) without requiring `!` assertions from callers; `getUnchecked(int index)` provides inline raw array access when `hasNulls == false`.
    - Shared overflow-safe reductions and `O(N)` expected-time selection (`lib/src/dataframe/numeric_stats.dart`) compute `mean`, `variance`, `std`, `median`, `quantile`, `GroupBy` statistics, and `DataFrame.describe()` without intermediate full sorting or finite-input overflow.
  - `ArrowStringSeries`: Backed by Arrow-compatible UTF-8 byte and offset buffers for textual data (with UTF-8 byte-order comparisons for `sort`, `min`, and `max`).
  - `BoolSeries`: Boolean series backed by a `List<bool>` data buffer with an optional `ValidityMask` for null tracking.
  - `ObjectSeries`: General object reference series for complex domain models.

### 4.4 Relational Hash Joins & GroupBy Aggregations

- **Reasoning**: Fast relational transformations require collision-free, type-safe composite keys and optimized indexing structures without string allocation overhead.
- **Implementation & Constraints**:
  - Safe composite keys (`lib/src/dataframe/tuple_key.dart`):
    - `RowKeyExtractor` performs specialized zero-allocation record-based key extraction for 1 column (direct scalar `key`), 2 columns (record `(a, b)`), and 3 columns (record `(a, b, c)`).
    - Falls back to `TupleKey` with cached hash code and `DeepCollectionEquality` for 4 or more key columns.
    - Prevents delimiter injection attacks and eliminates null-string collisions (`null` vs `'null'`) and numeric type erasure (`1` vs `'1'`).
  - Join engine (`lib/src/dataframe/join.dart`):
    - Supports hash join (`JoinMethod.hash`) and zero-copy pre-sorted sort-merge join (`JoinMethod.sortMerge`) across `inner`, `left`, `right`, and `outer` joins. Null and `NaN` keys never match in joins.
  - `GroupBy` engine (`lib/src/dataframe/groupby.dart`):
    - Partitions row indices into buckets based on composite key objects (`Map<Object?, List<int>>`).
    - Aggregates groups across columns with `Agg.count`, `Agg.sum`, `Agg.mean`, `Agg.min`, `Agg.max`, `Agg.std`, `Agg.variance`, `Agg.median`, `Agg.first`, and `Agg.last`, plus shorthand methods `mean()`, `sum()`, `min()`, `max()`, `std()`, `variance()`, `median()`, and `count()`.
    - Overflow-safe single-pass Welford accumulators (with two-pass scaled fallback on huge finite inputs) for sample variance (`Agg.variance`, with Bessel's correction `n - 1`, returning `null` when `n < 2`) and sample standard deviation (`Agg.std`).
    - In-place Dutch National Flag 3-way Quickselect for median (`Agg.median`) operating on a reused group scratch buffer without temporary heap allocations.

### 4.5 Tabular Parsing (PetitParser), CSV/TSV Serialization & Container Conversions

- **Reasoning**: Seamless, robust data ingestion and transfer into computational models with customizable delimiter, quoting, and escaping rules.
- **Implementation & Constraints**:
  - `TabularDefinition` (`lib/src/dataframe/csv/parser.dart`): Customizable PEG grammar definition powered by `package:petitparser`. Private to `lib/src/dataframe/csv/`.
    - Typed combinators: Uses `[...].toChoiceParser()`, `.skip(before: quote.not())`, and `plusString()` for zero-allocation field character repetitions.
    - Full linter compliance: Grammar passes PetitParser's `linter(parser)` with zero structural defects, verifying absence of left-recursion, unbounded loops, or unreachable rules.
    - Preconfigured definitions for `TabularDefinition.csv()` (RFC 4180 with `""` quote escaping) and `TabularDefinition.tsv()` (tab delimiters supporting both RFC 4180 quotes and Unix backslash escapes `\t`, `\n`, `\r`, `\\`), with support for arbitrary user-defined delimiters and delimiters passed dynamically.
  - `CsvReader` (`lib/src/dataframe/csv/csv_reader.dart`) & `DataFrame.fromTsv`:
    - Parses tabular records and lines via `TabularDefinition`, handling LF and CRLF newlines, multiline fields, and optional trailing line breaks without discarding valid empty rows or 1-column null data.
    - Automated columnar type inference (`int32` / `int64` -> `double` -> `bool` -> `String`) and null detection (`''`, `'null'`, `'NA'`).
    - Dedicated `CsvReader.parseTsv` and `DataFrame.fromTsv` helpers configured with `TabularDefinition.tsv()`.
  - `CsvWriter` (`lib/src/dataframe/csv/csv_writer.dart`):
    - Serializes DataFrames to delimited text.
    - Proper delimiter-aware escaping: quotes and doubles quotes for fields containing the active `separator` (regardless of whether `,`, `\t`, `;`, `|`, etc.), `"` quotes, `\n`, or `\r`.
  - Container conversions (`df.toMatrix()` and `df.toTensor()`):
    - Bulk column copy fast-path: For non-null `TypedSeries<double>` columns, single columns are copied via `Float64List.setRange`, while multi-column selections use sequential flat buffer indexing without heap `List<int>` coordinate allocations.
    - Fallback paths preserve compatibility for mixed integer types, nullable columns, and general series.

### 4.6 JSON Import & Export Serialization (`lib/src/dataframe/json/`)

- **Reasoning**: Web APIs, cloud data pipelines, and microservices exchange tabular data in standard JSON orientations. High-performance JSON interchange requires robust support for both array-of-objects, split columnar payloads, nested column-map orientations, and pure matrix values with clean null handling and type inference.
- **Implementation & Constraints**:
  - `JsonOrient` enumeration:
    - `records`: List of row objects `[{"col1": v1, "col2": v2}, ...]`.
    - `split`: Payload object `{"columns": ["col1", "col2"], "data": [[v1, v2], ...]}` separating schema from matrix data.
    - `columns`: Map of column arrays `{"col1": [v1, v2], ...}` or row-indexed maps `{"col1": {"0": v1, "1": v2}}` (supporting non-sequential indices and string index labels).
    - `array`: 2D array of rows `[[v1, v2], ...]`, defaulting column names to `col_0`, `col_1`, ... or custom names defined via `columnTypes`.
  - Auto-detection:
    - Automatically determines orientation when `orient` is omitted: root `List` of `Map` -> `records`, root `List` of `List` -> `array`, root `Map` with `'columns'` and 2D `'data'` -> `split`, other root `Map` -> `columns`.
  - Type-safe deserialization:
    - Automatic type inference (`Series.fromList`) with optional explicit `columnTypes: Map<String, DataType<dynamic>>` parameter. Non-null values are automatically coerced using `DataType.cast`.
    - Full null tracking preserved across all orientations with underlying `ValidityMask`.
  - Zero-overhead record extraction: `df.toRecords()` and `DataFrame.fromRecords` provide direct in-memory record conversions without JSON string encoding round-trips.

### 4.7 Apache Arrow IPC & C Data Interface Interoperability

- **Reasoning**: Interoperating zero-copy across analytic frameworks (DuckDB, Polars, PyArrow) and serialized Arrow streaming/file pipelines requires adherence to Arrow specifications and clean Dart typing without unconstrained `dynamic` APIs.
- **Implementation & Constraints**:
  - Apache Arrow C Data Interface: Standardized in-memory exchange via `DataFrame.exportTo({required outSchema, required outArray})`, `DataFrame.importFrom({required schema, required array})`, `Series.exportTo(...)`, and `Series.importFrom(...)`.
    - Pointers are typed as `Object` in cross-platform declarations and checked-cast to `ffi.Pointer<ArrowSchema>` / `ffi.Pointer<ArrowArray>` on Dart VM native platforms.
    - Low-level export/import functions are internal; `DataFrame` and `Series` methods form the single canonical entry point.
    - On Web/Wasm targets, invoking FFI Arrow C Data operations throws `UnsupportedError`.
  - Apache Arrow IPC: Binary streaming and file format serialization via `DataFrame.toArrowIpc()` and `DataFrame.fromArrowIpc()` with full validity bitmask alignment, null tracking, and multi-chunk concatenation.

---

## 5. Hardware Acceleration & FFI Subsystem (`lib/src/acceleration/`)

### 5.1 Architecture & Domain Decomposition

- **Reasoning**: Hardware-tuned linear algebra and numerical signal processing routines must provide high-throughput SIMD and multi-core vendor execution on desktop and server environments while maintaining 100% portable, numerically identical pure Dart fallbacks on platforms without FFI (e.g., Web, Wasm).
- **Sub-Package Layout**: The acceleration subsystem is decomposed into focused mathematical domains, each following a uniform structure (`<domain>.dart` containing the public dispatch interface, `<domain>_dart.dart` for pure Dart fallbacks, and conditional FFI bindings via `<domain>_native.dart` and `<domain>_stub.dart`):
  - `lib/src/acceleration/blas/`: Unified Basic Linear Algebra Subprograms (Levels 1, 2, and 3) in `Blas`.
  - `lib/src/acceleration/lapack/`: Linear system solvers and matrix decompositions in `Lapack`.
  - `lib/src/acceleration/fft/`: In-place 1D and 2D complex Fast Fourier Transforms on interleaved complex `Float64ComplexList` buffers in `Fft`.
  - `lib/src/acceleration/vforce/`: Vectorized transcendental functions, reductions, and 1D convolutions in `Vforce`.
  - `lib/src/acceleration/utils/`: Shared dynamic library resolution and platform symbol probing (`library_loader_ffi.dart`), dispatch helpers (`dispatcher.dart`), and Blue/LAPACK scaled norm accumulation (`norm_accumulator.dart`).
- **Acceleration Coordination**: `AccelerationManager` serves as an `abstract final` coordinator controlling execution `mode` (`AccelerationMode.auto`, `AccelerationMode.accelerated`, `AccelerationMode.dart`) and reporting active hardware acceleration status (`isAccelerated`). Errors use the sealed hierarchy `AccelerationError` (`AccelerationUnavailableError`, `AccelerationFailedError`). Each domain module exposes its own `isAvailable` boolean flag.

### 5.2 Dynamic Library Discovery & Platform Detection

- **Reasoning**: High-performance linear algebra transparently leverages hardware-tuned BLAS, LAPACK, FFTW3, and Apple Accelerate vendor libraries available on the host OS.
- **Implementation & Constraints**:
  - `platformBlasLibraries`, `platformVdspLibraries`, and `platformFftLibraries` in `lib/src/acceleration/utils/library_loader_ffi.dart` dynamically query system libraries using a shared `_openLibraries` loader with platform-accurate POSIX flags (`RTLD_LAZY | RTLD_GLOBAL`: `0x1 | 0x8` on Darwin, `0x1 | 0x100` on Linux/Android):
    - macOS/iOS: Apple Accelerate framework (`Accelerate.framework/Accelerate`), `libBLAS.dylib`, `liblapack.dylib`, `libfftw3.dylib`.
    - Linux/Android: `libopenblas.so.0`, `libopenblas.so`, `liblapacke.so.3`, `liblapacke.so`, `libblas.so.3`, `liblapack.so.3`, `libfftw3.so.3`, `libfftw3.so`.
    - Windows: `openblas.dll`, `libopenblas.dll`, `liblapacke.dll`, `lapack.dll`, `libfftw3-3.dll`, `fftw3.dll`.
  - `hasSymbol(symbol, libraries)` tests symbol export availability across loaded handles via `providesSymbol(symbol)`.
  - Platforms without FFI support conditionally compile against stubs (`*_stub.dart`) with zero runtime overhead or code bloat.

### 5.3 Unified BLAS Subsystem (`lib/src/acceleration/blas/`)

- **Reasoning**: Unifies vector-vector, matrix-vector, and matrix-matrix routines under a single, coherent `Blas` interface, replacing fragmented level-specific classes.
- **Routines**:
  - Level 1: `ddot`, `sdot` (dot products), `dnrm2`, `snrm2` (Euclidean norms via `ScaledNormAccumulator`), `daxpy`, `saxpy` ($y \leftarrow \alpha x + y$), `dscal`, `sscal` (vector scaling).
  - Level 2: `dgemv`, `sgemv` (matrix-vector multiplication), `dsyr2`, `ssyr2` (symmetric rank-2 update with automatic upper/lower triangle mirroring), `dtrmv`, `strmv` (in-place triangular matrix-vector multiplication), `dtrsv`, `strsv` (in-place triangular linear solves).
  - Level 3: `dgemm`, `sgemm` (general matrix multiplication), `dsyrk`, `ssyrk` (symmetric rank-$k$ update with automatic upper/lower triangle mirroring), `dsymm`, `ssymm` (symmetric matrix multiplication), `dtrmm`, `strmm` (in-place triangular matrix multiplication), `dtrsm`, `strsm` (in-place triangular matrix solves).
- **Pure Dart Fallback (`BlasDart`)**: Provides high-efficiency pure Dart implementations with cache-blocked tiled GEMM ($32 \times 32$ block tiles fitting within L1 data caches) and $4\times$ loop unrolling across all four transposition combinations (`cblasNoTrans`, `cblasTrans`, `cblasConjTrans`) and accumulation scalings ($\alpha$, $\beta$), zero-allocation dependency-ordered in-place triangular multiplies (`dtrmv`, `strmv`, `dtrmm`, `strmm`) and solves (`dtrsv`, `strsv`, `dtrsm`, `strsm`), and triangle-strict symmetric indexing in `dsymm`/`ssymm`.

### 5.4 LAPACK Solvers & Factorizations (`lib/src/acceleration/lapack/`)

- **Reasoning**: Production scientific systems rely on LAPACK for numerically stable factorizations and solves.
- **Routines**:
  - `dgesv`: General linear system solver $A X = B$ with partial pivoting. Multi-RHS matrices ($N \times \text{nrhs}$) and strided RHS matrices transparently gather to column-major layout for Fortran LAPACK routines (`dgesv_`) or compacted LAPACKE buffers and scatter back to row-major format, with a zero-copy fast path for contiguous single RHS ($nrhs = 1, ldb = 1$).
  - `dpotrf`: Cholesky factorization of symmetric positive-definite matrices, reading only the referenced triangle and validating finiteness before overwriting.
  - `dgels`: Linear least-squares solver $\min \|A X - B\|_2$ via QR (overdetermined) and LQ (underdetermined) factorizations using scale-invariant relative rank tolerances (`10 * max(m, n) * eps * maxDiag`).
  - `dsyev`, `ssyev`: Real symmetric eigenvalue solvers computing eigenvalues in ascending order and optional orthonormal eigenvectors (`jobz: 'V'` or `'N'`). Pure Dart fallbacks equilibrate by $\max|A|$ to prevent overflow/underflow, skip eigenvector updates when `jobz == 'N'`, and read only the referenced `uplo` triangle (matching Fortran paths).
  - `dgesvd`: Singular Value Decomposition $A = U \Sigma V^T$ without mutating input `A`, using Golub-Reinsch bidiagonalization equilibrated by $\max|A|$ with `ScaledNormAccumulator` column/row norms in pure Dart and native LAPACKE/Fortran bindings when available.

### 5.5 Fast Fourier Transform Subsystem (`lib/src/acceleration/fft/`)

- **Reasoning**: Frequency-domain analysis requires high-performance, in-place Fourier transforms that eliminate parallel list allocations and unnecessary conversions.
- **Implementation & Constraints**:
  - `Float64ComplexList`: Dedicated interleaved complex typed data list implementing `TypedDataList<Complex>` backed by a single contiguous interleaved `Float64List data` storage array `[re0, im0, re1, im1, ...]`.
  - In-Place Execution: `Fft.fft` and `Fft.fft2` operate directly in-place on `Float64ComplexList` buffers without copying or intermediate allocations, accepting a boolean `inverse` flag (no redundant wrapper functions like `ifft`/`ifft2`).
  - Cross-Platform Native Acceleration (`FftNative`): Binds directly to Apple Accelerate's interleaved double-precision DFT routines (`vDSP_DFT_Interleaved_CreateSetupD`, `vDSP_DFT_Interleaved_ExecuteD`) for supported sizes $f \cdot 2^p$ ($f \in \{1, 3, 5, 15\}$) plus four-step power-of-2 fallback on macOS/iOS, and directly to FFTW3 (`fftw_plan_dft_1d`, `fftw_plan_dft_2d`, `fftw_execute_dft`) for arbitrary 1D/2D sizes on Linux, Android, and Windows, delegating unsupported lengths to Bluestein's algorithm (`FftDart.bluestein`) and separable row/column passes (`FftDart.fft2Separable`).
  - Pure Dart Fallback (`FftDart`): Cooley-Tukey decimation-in-time radix-2 in-place 1D and separable 2D Fourier transforms using precomputed exact trigonometric twiddle tables without phase drift, Bluestein's chirp-Z algorithm for arbitrary sizes, and 32/64-bit safe `nextPowerOf2`.

### 5.6 Vectorized Functions & Signal Processing (`lib/src/acceleration/vforce/`)

- **Reasoning**: Bulk element-wise math and reductions benefit dramatically from vectorized hardware pipelines.
- **Routines**:
  - Element-wise Transcendental Math: `vsin`, `vcos`, `vexp`, `vlog`, `vsqrt`, `vpow` operating directly across input/output `Float64List` buffers, supporting zero-copy same-address in-place execution while automatically guarding shifted overlapping views via `hasOverlap` and `sameStartAddress`.
  - Vector Reductions: `sum`, `mean`, `variance` (sample and population) operating with native Apple vDSP vector reductions (`vDSP_sveD`, `vDSP_meanvD`, `vDSP_vsaddD`, `vDSP_svesqD`) and overflow-safe Welford/scaled fallbacks when all-finite sums overflow IEEE-754 bounds.
  - 1D Signal Processing: `convolve` (linear convolution) and `correlate` (cross-correlation) with exact range-based overlap guards.

### 5.7 Zero-Copy Direct Memory Address & Leaf Calls

- **Reasoning**: Passing memory directly between Dart and native code avoids expensive off-heap memory management and copies.
- **Implementation & Constraints**:
  - Direct Typed Data Addresses: Hardware acceleration routines bind to native symbols via `@ffi.Native(isLeaf: true)` external declarations.
  - Zero-Copy Addresses: Standard `Float64List` and `Float32List` buffers pass directly to native routines via `.address` (or `Float64List.sublistView(list, offset).address` for offset slices), with static per-isolate 1-element typed-data scratch buffers avoiding per-call FFI heap allocations in `VforceNative`.
  - Leaf Calls: Native functions are marked `isLeaf: true`, allowing the Dart runtime to pin typed data memory during the call without garbage collector interference.
  - Strict Parameter Contracts: Internal native and fallback methods enforce strictly named, non-null, `required` parameters with zero optionals, guaranteeing unambiguous call signatures.

---

## 6. Numerical Analysis, ODEs & Optimization (`package:data/numeric.dart`)

### 6.1 Nonlinear Optimization Routines

- **Reasoning**: Finding minima of complex objective functions is ubiquitous in machine learning, engineering design, and parameter fitting.
- **Implementation & Constraints**:
  - `minimize`: Unified entry point for univariate and multivariate optimization selecting algorithms via `OptimizationMethod` and returning an `OptimizationResult` (with value equality and `hashCode`):
    - `OptimizationMethod.brent`: Univariate golden-section search combined with parabolic interpolation, achieving superlinear convergence without derivative requirements.
    - `OptimizationMethod.nelderMead`: Multivariate derivative-free simplex method, resilient to non-smooth or noisy objective functions.
    - `OptimizationMethod.bfgs`: Quasi-Newton Broyden-Fletcher-Goldfarb-Shanno method utilizing numerical gradients and Armijo line search with $\mathcal{O}(N^2)$ rank-2 updates to maintain a positive-definite Hessian approximation.
    - `OptimizationMethod.lbfgs`: Limited-memory BFGS storing a rolling history of $m$ displacement vectors, enabling multivariate optimization over thousands of parameters with $\mathcal{O}(m N)$ memory.
  - Constrained optimization handling box bounds (`BoxBound`), general inequality constraints ($g_i(x) \le 0$), and equality constraints ($h_j(x) = 0$):
    - Box bounds $[l_i, u_i]$ utilize coordinate-wise smooth sigmoid variable transformations ($x_i = l_i + \frac{u_i - l_i}{1 + e^{-y_i}}$) with chain-rule gradient scaling ($\nabla_y F = \nabla_x L_A \odot \Phi'(y)$), strictly preventing out-of-bounds evaluations and domain violations.
    - General inequality and equality constraints are resolved via the Powell-Hestenes-Rockafellar Augmented Lagrangian Method (ALM) with adaptive penalty parameter scaling ($\mu$) and multiplier updates ($\lambda_j \leftarrow \max(0, \lambda_j + \mu g_j(x))$, $\nu_k \leftarrow \nu_k + \mu h_k(x)$).
    - Accepts objective closures `double Function(Vector<double>)` and constraint functions `List<double Function(Vector<double>)>` (which may be compiled from symbolic expressions via `expr.toVectorFunction()`), supporting both equality ($h(x) = 0$) and inequality ($g(x) \le 0$) constraints with automatic Lagrange multiplier updates.

### 6.2 Adaptive & Stiff Ordinary Differential Equation (ODE) Solvers

- **Reasoning**: Physical dynamics, chemical kinetics, and orbital mechanics require stable, error-controlled numerical integration across non-stiff and stiff systems.
- **Implementation & Constraints**:
  - `solveOde`: Unified ODE solver interface selecting methods via `OdeMethod`:
    - `OdeMethod.rk4`: Classical 4th order Runge-Kutta solver with fixed step size.
    - `OdeMethod.dormandPrince45`: Dormand-Prince 5(4) embedded adaptive Runge-Kutta solver. Computes 4th and 5th order step estimates with First-Same-As-Last (FSAL) efficiency, dynamically adjusting step size $h$ to maintain local truncation error within user tolerances (`atol`, `rtol`).
    - `OdeMethod.bdf2`: Two-step Backward Differentiation Formula implicit solver for stiff systems using Newton-Raphson iterations and finite-difference Jacobian estimation.
  - Supports dense continuous evaluation over optional `tEval` coordinate grids via $C^1$-continuous cubic Hermite interpolation.

### 6.3 Numerical Calculus

- **Reasoning**: Many optimization, physics, and sensitivity problems require derivatives of black-box functions.
- **Implementation & Constraints**:
  - `derivative`: Univariate differentiation supporting central and high-order finite-difference stencils (orders 1–6, up to 8 points) with adaptive step size selection.
  - `gradient`: Computes $\nabla f(x) \in \mathbb{R}^N$ for scalar multivariate functions via central differences.
  - `jacobian`: Computes $J \in \mathbb{R}^{M \times N}$ for vector-valued multivariate functions $F: \mathbb{R}^N \to \mathbb{R}^{M}$.
  - `hessian`: Computes symmetric second-order partial derivative matrix $H \in \mathbb{R}^{N \times N}$.

### 6.4 Fast Fourier Transform Suite & Signal Processing

- **Reasoning**: Spectral analysis and signal filtering require fast Fourier transformations and convolutions that efficiently scale to arbitrary signal sizes.
- **Implementation & Constraints**:
  - Operations in `lib/src/numeric/fft.dart`:
    - `fft`: 1D complex-to-complex in-place transform on `List<Complex> buffer` with optional `inverse: true`. Leverages radix-2 Cooley-Tukey for power-of-2 lengths and Bluestein's Chirp-Z transform algorithm for arbitrary non-power-of-2 lengths in $\mathcal{O}(N \log N)$ time.
    - `fft2`: 2D transforms executing row-column separable passes over 2D complex matrices with optional `inverse: true`.
    - `convolve`: 1D discrete signal convolution supporting `ConvolutionMode.full`, `ConvolutionMode.same`, and `ConvolutionMode.valid`.
    - `correlate`: 1D discrete cross-correlation supporting `ConvolutionMode.valid` (default), `ConvolutionMode.full`, and `ConvolutionMode.same`.

### 6.5 Stable Interpolation & Curve Fitting

- **Reasoning**: Continuous estimation from discrete empirical samples.
- **Implementation & Constraints**:
  - `CubicSpline`: $C^2$ continuous cubic spline interpolation supporting natural ($S''(x) = 0$) and clamped ($S'(x) = f'$) boundary conditions, with first (`derivative`) and second (`secondDerivative`) evaluation. Formulates spline second derivatives as a tridiagonal linear system solved in $\mathcal{O}(N)$ time via `solveTridiagonal`.
  - `PchipInterpolation`: Piecewise Cubic Hermite Interpolating Polynomial preserving monotonicity and preventing overshoot between data points, with exact piecewise first derivative evaluation (`derivative`).
  - `BilinearInterpolation`: 2D rectilinear grid interpolation using four-point convex weighting with partial gradient evaluation.
  - `BicubicInterpolation`: 2D surface interpolation over a rectilinear grid with $C^1$ continuity using 16-coefficient bicubic patches ($A = M F M^T$) with partial derivatives and continuous gradient extraction.
  - `leastSquares`: General linear regression using LAPACK `dgels` for full-rank systems and SVD fallback for rank-deficient systems.
  - `polynomialRegression`: Vandermonde polynomial fitting using QR decomposition with optional Tikhonov / Ridge L2 regularization (`lambda`) suppressing high-frequency Runge oscillations and conditioning rank-deficient systems.
  - `linearRegression` and `multipleLinearRegression`: Standard univariate and multivariate ordinary least-squares regression.
  - `curveFit` and `fitNonlinear`: Damped Gauss-Newton / Levenberg-Marquardt nonlinear least-squares curve fitting with optional parameter box bounds (`lowerBounds`, `upperBounds`), returning `CurveFitResult` (from `curveFit`) with parameter estimates, parameter covariance matrix ($(J^T J)^{-1} \cdot \text{RSE}^2$), and standard errors.

### 6.6 Precision in Numerical Solvers

- **Reasoning**: Complex iterative numerical routines (e.g. nonlinear optimizers, ODE integrators, curve fitting, FFT) require consistent precision profiles without invasive algorithm rewrites.
- **Implementation & Constraints**:
  - Routines allocate intermediate vectors and matrices via standard container constructors, using default double precision (`DataType.float` / `DataType.float64`).

### 6.7 Coordinate Grids & Adaptive Curve Sampling (`lib/src/numeric/sampling.dart`)

- **Reasoning**: Plotting and numerical discretization require both uniform/logarithmic coordinate grids and curvature-adaptive 1D function sampling that splits cleanly across vertical asymptotes, jump discontinuities, and out-of-domain intervals without drawing spurious vertical spikes.
- **Implementation & Constraints**:
  - Uniform and logarithmic grids: `linearSpaced`, `logarithmicSpaced`, and `geometricSpaced`.
  - `sampleCurve(f, a, b, {initialPoints = 65, maxPoints = 2048, tolerance = 1e-3})`: Evaluates `f` on a jittered initial grid, estimates a robust vertical scale, recursively bisects high-curvature and boundary intervals up to `maxPoints`, splits disjoint continuous `CurveSegment`s at vertical asymptotes (`1/x`, `tan(x)`) and step discontinuities (`floor(x)`, `sign(x)`), and computes a robust vertical range (`yMin`, `yMax`) clipped to the 2nd–98th percentile when discontinuities are present.

---

## 7. Statistics & Resampling (`package:data/stats.dart`)

### 7.1 Descriptive Statistics & Dimensionality Reduction

- **Reasoning**: Comprehensive summary profiles of empirical distributions.
- **Implementation & Constraints**:
  - Measures of location and dispersion: `mean`, `geometricMean`, `harmonicMean`, `quantile`, `quantiles`, `median`, `iqr`, `medianAbsoluteDeviation`, scale-normalized sample `skewness`, and excess `kurtosis`.
  - Weighted statistics: `weightedMean`, `weightedVariance` (supporting observation weights and Bessel reliability weight correction with max-weight normalization), and `weightedStandardDeviation`.
  - Moving window aggregations: Simple moving average (`movingAverage`) over rolling windows in $\mathcal{O}(N)$ amortized time with periodic/spike-triggered exact refresh to prevent drift and `NaN` poisoning, and exponential moving average (`exponentialMovingAverage`) with smoothing parameter $\alpha \in (0, 1]$.
  - Association matrices: `covarianceMatrix`, `correlationMatrix` (`pearsonCorrelationMatrix`, `spearmanCorrelationMatrix`, and `kendallCorrelationMatrix` / `kendallCorrelation` $\tau_b$ in $\mathcal{O}(n \log n)$).
  - Principal Component Analysis (`pca`): Computes SVD directly on centered/standardized matrices for small-to-medium sample sizes ($n \le 512$) and symmetric covariance eigendecomposition for tall matrices, enforcing deterministic component sign orientation and returning `PcaResult` with `singularValues`, `explainedVariance`, `explainedVarianceRatio`, and `cumulativeExplainedVarianceRatio`.

### 7.2 Parametric Distributions & Maximum Likelihood Estimation (MLE)

- **Reasoning**: Closed-form probability modeling and parameter inference from data across univariate and multivariate domains.
- **Implementation & Constraints**:
  - 24 univariate distributions (16 continuous, 8 discrete) with `probability`, `logProbability`, `cumulativeProbability`, `survival`, `inverseCumulativeProbability`, `inverseSurvival`, and random sampling (`sample`, `samples`):
    - Continuous: `NormalDistribution`, `StudentDistribution`, `FDistribution`, `BetaDistribution`, `GammaDistribution`, `InverseGammaDistribution`, `ExponentialDistribution`, `ChiSquaredDistribution`, `UniformDistribution`, `CauchyDistribution`, `LaplaceDistribution`, `LogisticDistribution`, `LogNormalDistribution`, `ParetoDistribution`, `WeibullDistribution`, `DegenerateDistribution`.
    - Discrete: `BernoulliDistribution`, `BinomialDistribution` (exact Bernoulli, geometric gap, and Hörmann BTRS sampling), `GeometricDistribution`, `HypergeometricDistribution`, `NegativeBinomialDistribution`, `PoissonDistribution` (exact Knuth and Hörmann PTRD sampling), `RademacherDistribution`, `UniformDiscreteDistribution`.
  - Multivariate distributions (`MultivariateDistribution<T extends num>`):
    - `MultivariateNormalDistribution`: Correlated Gaussian density over $\mathbb{R}^k$ parameterized by mean $\mu \in \mathbb{R}^k$ and covariance matrix $\Sigma \in \mathbb{R}^{k \times k}$. Defensively copies parameter containers for strict immutability, computes Cholesky factor $\Sigma = L L^T$, evaluates $\ln \text{PDF}$ via forward triangular solve ($L y = x - \mu \implies (x-\mu)^T \Sigma^{-1} (x-\mu) = \|y\|_2^2$), and generates correlated random samples $x = \mu + L z$ with paired standard normal draws.
    - `DirichletDistribution`: Continuous probability distribution over the open $(k-1)$-simplex parameterized by defensively copied concentration vector $\alpha \in \mathbb{R}^k$ ($\alpha_i > 0$). Evaluates log multivariate beta function via `gammaLn`, provides exact covariance matrix, and generates samples via normalized Gamma draws (with log-space fallback for small $\alpha$).
    - `MultinomialDistribution`: Discrete distribution over $k$ categories across $n$ trials parameterized by defensively copied probability vector $p \in [0, 1]^k$ ($\sum p_i = 1$). Evaluates log PMF via `factorialLn`, provides exact covariance matrix, and draws samples in $\mathcal{O}(k)$ via sequential conditional `BinomialDistribution` sampling.
  - All 24 univariate distributions support analytical or numerical fitting via single-pass `factory .fit(data)` constructors (`BernoulliDistribution`, `BetaDistribution`, `BinomialDistribution`, `CauchyDistribution`, `ChiSquaredDistribution`, `DegenerateDistribution`, `ExponentialDistribution`, `FDistribution`, `GammaDistribution`, `GeometricDistribution`, `HypergeometricDistribution`, `InverseGammaDistribution`, `LaplaceDistribution`, `LogisticDistribution`, `LogNormalDistribution`, `NegativeBinomialDistribution`, `NormalDistribution`, `ParetoDistribution`, `PoissonDistribution`, `RademacherDistribution`, `StudentDistribution`, `UniformDistribution`, `UniformDiscreteDistribution`, `WeibullDistribution`).

### 7.3 Hypothesis Testing Suite

- **Reasoning**: Rigorous statistical inference for experimental hypothesis testing, goodness-of-fit validation, and non-parametric paired testing.
- **Implementation & Constraints**:
  - `tTestOneSample`: Single-pass Welford Student's t-test comparing sample mean against hypothesized value.
  - `tTestTwoSample`: Two-sample t-test supporting Student's pooled variance and Welch's t-test for unequal variances with overflow-safe Satterthwaite degrees of freedom.
  - `tTestPaired`: Paired-difference t-test supporting hypothesized difference `mu0`.
  - `oneWayAnova`: One-way Analysis of Variance testing equality of two or more group means, reporting both numerator and denominator degrees of freedom.
  - `kruskalWallisTest`: Non-parametric k-sample rank test with tie correction against $\chi^2(k - 1)$.
  - `chiSquaredTest` and `chiSquaredContingency`: Goodness-of-fit and contingency table test of independence with optional Yates' continuity correction for $2 \times 2$ tables.
  - `fisherExactTest`: Exact test for independence in $2 \times 2$ `Matrix<int>` contingency tables based on `HypergeometricDistribution` without large-sample approximations.
  - `shapiroWilkTest`: Normality test based on Royston's AS R94 with translation-invariant symmetric pairing.
  - `mannWhitneyUTest`: Non-parametric test for equality of two independent continuous distributions with exact small-sample permutation DP and tie-corrected normal approximation.
  - `kolmogorovSmirnovTest`: One-sample Kolmogorov-Smirnov test for `ContinuousDistribution` supporting `twoSided`, `greater`, and `less` alternatives with exact small-sample ($n \le 100$) Smirnov / Marsaglia-Tsang-Wang probabilities and asymptotics.
  - `kolmogorovSmirnovTwoSample`: Two-sample Kolmogorov-Smirnov test supporting `twoSided`, `greater`, and `less` alternatives with exact untied lattice-path DP ($n_1 n_2 \le 10000$) and asymptotic probabilities.
  - `jarqueBeraTest`: Normality test matching scaled central-moment skewness $S$ and excess kurtosis $K - 3$, testing $JB = \frac{n}{6}(S^2 + \frac{(K-3)^2}{4}) \sim \chi^2(2)$.
  - `wilcoxonSignedRankTest`: Non-parametric paired signed-rank test (or one-sample median against 0) with exact subset-sum DP for small untied samples ($n \le 25$) and tie-corrected normal approximation.

### 7.4 Non-Parametric & Parametric Bootstrap Resampling

- **Reasoning**: Estimating standard errors and confidence intervals without distribution assumptions.
- **Implementation & Constraints**:
  - `@immutable` `Bootstrap`: Defensively copies input samples, generates $B$ non-parametric, custom-sampler (`Bootstrap.parametric`), or distribution-sampled (`Bootstrap.distribution<T>`) resamples.
  - `@immutable` `Jackknife`: Leave-one-out resampling computing unmodifiable `resamples`, `resampleEstimates`, `pseudoValues`, `influenceValues`, bias, standard error, and scale-normalized BCa `acceleration`.
  - Confidence interval algorithms on `Bootstrap`: `normalInterval`, `basicInterval`, `percentileInterval`, and `bcaInterval` (reusing `Jackknife.acceleration` and `NormalDistribution.standard()`).

---

## 8. Polynomial Subsystem (`package:data/polynomial.dart`)

### 8.1 Immutable Value-Backed Representation

- **Reasoning**: The legacy polynomial implementation used mutable coefficient buffers and `copyInto` methods, leading to aliasing bugs and state pollution.
- **Implementation & Constraints**:
  - `Polynomial<T>` is strictly immutable, backed either by an unmodifiable contiguous dense list (`DensePolynomial<T>`, degree `0..N`) or sorted sparse `(exponent, coefficient)` arrays (`CompressedPolynomial<T>`).
  - All operations return newly allocated, canonicalized `Polynomial<T>` instances with trailing zero coefficients stripped and IEEE-754 negative zeros (`-0.0`) normalized.
  - Binary algebraic operations (`+`, `-`, `*`, `compose`, `divide`, `gcd`) enforce identical coefficient `DataType<T>` instances.

### 8.2 Orthogonal Polynomial Families & Clenshaw Recurrence

- **Reasoning**: Orthogonal polynomials are essential for spectral methods, approximation theory, and numerical quadrature.
- **Implementation & Constraints**:
  - Static factory generators (`Polynomial.chebyshevT`, `Polynomial.chebyshevU`, `Polynomial.legendreP`, `Polynomial.hermiteH`, `Polynomial.hermiteHe`, `Polynomial.laguerreL`) compute recurrence coefficients directly in reusable `Float64List` buffers in `O(n^2)` time without intermediate polynomial allocations or FFT rounding noise.
  - Single-point `O(n)` recurrence evaluation across all six families is provided via `evaluateOrthogonal(degree, x, family: ..., alpha: ...)` (`lib/src/polynomial/orthogonal.dart`).
  - Linear combinations are evaluated in `O(n)` time and `O(1)` auxiliary space via Clenshaw recurrence (`evaluateOrthogonalSeries`). Generalized Laguerre functions validate finite `alpha`.

### 8.3 Formal Polynomial Arithmetic, Composition & Root Isolation

- **Reasoning**: Exact algebraic manipulation, composition, and root finding for arbitrary degrees.
- **Implementation & Constraints**:
  - `Polynomial.fromRoots` expands linear root factors in a single in-place `O(n^2)` pass.
  - Queries and algebraic utilities include `isZero`, `isConstant`, `monic()`, and binary exponentiation `pow(exponent)`.
  - Formal division with remainder (`divide`, `/`, `%`) tracks per-coefficient cancellation magnitudes for floating-point operands so untouched small terms survive while leading-term residuals and genuine cancellation noise are eliminated cleanly across both dense and `SplayTreeMap`-backed sparse implementations.
  - Euclidean `gcd` validates finite floating-point coefficients and normalizes monic results while preserving sparse representation.
  - Composition: `poly.compose(other)` evaluates `(P ∘ Q)(x) = P(Q(x))` algebraically using Horner's recurrence (dense) or incremental binary exponentiation (sparse).
  - Differentiation (`derivative({int order = 1})`) and anti-differentiation (`integrate()`).
  - Root isolation (`roots`):
    - Rejects non-finite and non-numeric coefficients with `ArgumentError`.
    - Deflates zero roots (`x^k` factors) analytically prior to solving the reduced polynomial.
    - Effective degrees `1` and `2` use overflow-safe component-rescaled real and complex closed-form formulas.
    - Effective degree >= 3 constructs the Frobenius companion matrix of the deflated monic polynomial and solves for complex roots via `EigenvalueDecomposition`.

### 8.4 Rational Functions (`RationalFunction<T>`)

- **Reasoning**: Many scientific modeling and transfer function problems involve ratios of polynomials `R(x) = P(x) / Q(x)`.
- **Implementation & Constraints**:
  - `RationalFunction<T>` in `lib/src/polynomial/rational.dart` encapsulates numerator and denominator polynomials.
  - Automatic and explicit GCD simplification via `simplify()` canonicalizes zero numerators (`0 / 1`), divides out `gcd(P, Q)`, and normalizes invertible denominators to monic form using direct scalar division while preserving `CompressedPolynomial` representations.
  - Properties and arithmetic include `isZero`, `isPolynomial`, `reciprocal()`, `pow(exponent)`, `+`, `-`, `*`, `/`, and unary negation `-`.
  - Evaluation (`evaluate`, `evaluateDouble`, `evaluateComplex`) handles pole zero-division with `UnsupportedError`.
  - Formal derivative (`derivative({int order = 1})`) computed iteratively using the quotient rule `(P' Q - P Q') / Q^2`.

---

## 9. Symbolic Computation Engine (`package:data/symbolic.dart`)

### 9.1 Modular Pure Functional Algebraic AST Hierarchy & Atomic Number Tower

- **Reasoning**: Mathematical expressions require a compact, uniform abstract syntax tree (AST) for analytical manipulation, canonical simplification, calculus transformations, and high-performance compilation. Unifying arithmetic into n-ary `Add`, `Mul`, and `Pow` nodes and representing numbers in a single atomic `Number` tower eliminates combinatorial pattern-matching explosion across algebra and calculus rules.
- **Implementation & Constraints**:
  - Base class `Expr` (`lib/src/symbolic/ast/expr.dart`) is an immutable `sealed class` defining foundational properties: `isSimplified`, `isReal`, `dependsOn`, `freeVariables`, `substitute`, generic child traversal (`mapChildren`, `anyNode`), and operator overloads (`+`, `-`, `*`, `/`, `-()`, `pow`).
  - Cached Structural Hashing: All composite AST nodes (`UnaryExpr`, `BinaryExpr`, `Add`, `Mul`, `Piecewise`, `Integral`, `Derivative`, `Limit`, with `LambertW` overriding `_computeHash()`) compute and cache their structural hash via `@override late final int hashCode` and short-circuit `hashCode == other.hashCode` in `operator ==`, preventing O(2^d) hash recomputation on shared DAG subtrees.
  - Zero-cost arbitrary-precision integers (`lib/src/symbolic/number/integer.dart` and `rational.dart`):
    - `Integer` is an `extension type const Integer._(Object _value)` wrapping a Dart `int` for values within +/-(2^53 - 1) (`maxSafeInteger` from `package:more/feature.dart`) and transparently promoting/demoting to `BigInt` on overflow, supporting `gcd`, `lcm`, `factorial`, `binomial`, and `isPrime` (delegating to `package:more/math.dart`).
  - Modularized across `lib/src/symbolic/ast/`:
    - `number.dart`: Atomic `Number` tower (`sealed class Number extends Expr`):
      - `RealNumeric` (`sealed class RealNumeric extends Number`): `RationalNumber` (`IntegerNumber` when `q = 1`, `FractionNumber` when `q > 1` with `gcd(|p|, q) = 1`, providing exact `gcd`, `lcm`, `isPrime`, and continued-fraction `RationalNumber.fromDouble` via `Fraction.fromDouble` from `package:more/number.dart`) and finite `RealNumber` (`-0.0` normalized to `0.0`; non-finite doubles mapped via `RealNumber.fromDouble` to `Constant.infinity`, `-Constant.infinity`, or `Constant.undefined`). `RealNumber` values represent IEEE-754 floating-point numbers: they are strictly numeric, never treated as symbols, and always simplify down to numeric results. Real numbers are never automatically inferred or guessed into rational numbers or exact constants (`sqrt(2)`, `sqrt(3)`, `pi`, `e`), and real-to-rational conversion is performed solely via explicit `.rationalize()`.
      - `ComplexNumber(RealNumeric real, RealNumeric imaginary)`: Atomic Gaussian/complex numeric node with `imaginary != 0`, auto-demoting to `real` via `ComplexNumber.of(real, imaginary)` when `imaginary.isZero`. Canonical imaginary unit is `ComplexNumber.i`.
    - `constant.dart`: Opaque leaf `Constant(name, value, {latex, mathMl})` (not a `Number`) with built-ins `pi`, `e`, `infinity`, and `undefined` (NaN). `Constant.value` is a `Complex` used only for numeric evaluation, `approximate()`, and sign queries; symbolic transformations never fold constants into floats unless `.approximate()` is called.
    - `variable.dart`: `Variable(name)` representing a named symbolic variable whose active `VariableDomain` (`unknown`, `complex`, `real`, `positive`, `integer`) is resolved via `Assumptions.domainOf(name)`, and `VariableFunction(name, arguments)` representing an unbound symbolic function application `f(x_1, ..., x_n)`.
    - `operator.dart`: Unified n-ary arithmetic operators (`Sub`, `Div`, `Neg`, and `Exp` are omitted):
      - `Add(List<Expr> terms, {bool isSimplified = false})`: Flat sum of terms. Subtraction `a - b` is `Add([a, -b])`.
      - `Mul(List<Expr> factors, {bool isSimplified = false})`: Flat product of factors. Unary negation `-x` is `Mul([-1, x])`, and division `a / b` is `Mul([a, Pow(b, -1)])` (or reduced `RationalNumber` when both operands are `RationalNumber`).
      - `Pow(Expr base, Expr exponent, {bool isSimplified = false})`: Exponentiation. Square roots `sqrt(x)` are `Pow(x, RationalNumber.half)`, reciprocals `1 / x` are `Pow(x, IntegerNumber.negativeOne)`, and natural exponentials `exp(x)` are `Pow(Constant.e, x)`.
    - `function.dart`, `special_function.dart`, `lambert_w.dart`: Elementary, transcendental, complex-part, combinatorial, rounding, and special function nodes (`Sin`, `Cos`, `Tan`, `Asin`, `Acos`, `Atan`, `Sinh`, `Cosh`, `Tanh`, `Asinh`, `Acosh`, `Atanh`, `Ln`, `Abs`, `Re`, `Im`, `Arg`, `Conjugate`, `Erf`, `Erfc`, `Erfi`, `FresnelS`, `FresnelC`, `ExpIntegralEi`, `LogIntegralLi`, `SinIntegralSi`, `CosIntegralCi`, `SinhIntegralShi`, `CoshIntegralChi`, `Gamma`, `UpperGamma`, `LowerGamma`, `Zeta`, `Digamma`, `Polygamma`, `Polylog`, `Beta`, `BesselJ`, `BesselY`, `BesselI`, `BesselK`, `EllipticK`, `EllipticE`, `EllipticF`, `EllipticEIncomplete`, `Factorial`, `Binomial`, `Floor`, `Ceil`, `Round`, `Sign`, `Mod`, `LambertW`).
    - `integral.dart`, `derivative.dart`, `limit.dart`, and `summation.dart`: Symbolic operator nodes `Integral(integrand, variable, {lower, upper})`, `Derivative(expr, variable, {order = 1})`, `Limit(expr, variable, point, {direction = LimitDirection.both})`, `Sum(expr, variable, lower, upper)`, and `Product(expr, variable, lower, upper)` representing unevaluated calculus and discrete operations. Definite `Integral` nodes evaluate numerically via 16-point Gauss-Legendre quadrature when `evaluate()` or `approximate()` is called, and definite `Integral`, `Limit`, `Sum`, and `Product` exclude their bound variable from `freeVariables`. Variable capture during substitution alpha-renames bound variables automatically.
    - `piecewise.dart` and `order_term.dart`: Conditional `Piecewise(List<PiecewiseBranch> branches, {Expr? otherwise})` expressions (`typedef PiecewiseBranch = ({RelationalExpr relation, Expr expr})`), relational predicates (`RelationalExpr`: `LessThan`, `LessEqual`, `GreaterThan`, `GreaterEqual`, `Equal`, `NotEqual`), and asymptotic `OrderTerm` (`O((x - a)^n)`).

### 9.2 First-Class Algebraic Field & Container Integration

- **Reasoning**: Mathematical CAS workflows require symbolic matrices, vectors, and polynomials. Decoupling from `numeric` does not imply isolation from algebraic containers.
- **Implementation & Constraints**:
  - `ExprDataType`, `ExprEquality`, and `ExprField` (`lib/src/symbolic/type/expr_data_type.dart`) implement `DataType<Expr>`, `Equality<Expr>`, and `ExtendedField<Expr>`.
  - Symbolic linear algebra & container extensions (`lib/src/symbolic/linear/`):
    - `BareissEngine` (`lib/src/symbolic/linear/bareiss.dart`): Fraction-free Gaussian elimination computing exact symbolic determinants (`determinant`), reduced row echelon form (`rowEchelon`, `rowEchelonWithPivots`), algebraic rank (`rank`), right nullspace bases (`nullSpace`), and exact linear system solves (`solve`) without intermediate expression swell, forwarding `Assumptions`.
    - `FaddeevLeVerrierEngine` (`lib/src/symbolic/linear/faddeev_leverrier.dart`): Characteristic polynomial `p(lambda) = det(lambda * I - A)` and symbolic matrix inverse `A^-1` via trace recurrence.
    - `SymbolicMatrixExtension` (`Matrix<Expr>`) and `SymbolicVectorExtension` (`Vector<Expr>`) in `lib/src/symbolic/linear/matrix.dart`: Symbolic linear algebra (`determinant`, `rowEchelon`, `rank`, `nullSpace`, `characteristicPolynomial({lambda = 'lambda', assumptions})`, `eigenvalues`, `eigenvectors` returning `List<SymbolicEigenpair>`, `inverse`, `power`), element-wise algebraic and calculus operations (`simplify`, `expand`, `factor`, `substitute`, `approximate`, `rationalize`, `derivative`, `integrate`), canonical string formatting (`format`), LaTeX (`toLatex`), and MathML (`toMathMl`), paired with `ExprSyntax.parseMatrix`/`tryParseMatrix` and `ExprSyntax.parseVector`/`tryParseVector`.
  - Multivariable calculus (`lib/src/symbolic/calculus/multivariable.dart`) returns first-class containers via extension methods only:
    - `expr.gradient(variables, {assumptions})` returns `Vector<Expr>`.
    - `expr.hessian(variables, {assumptions})` returns `Matrix<Expr>`.
    - `expr.laplacian(variables, {assumptions})` returns `Expr`.
    - `system.jacobian(variables, {assumptions})`, `system.divergence(variables, {assumptions})`, and `system.curl(variables, {assumptions})` on `Iterable<Expr>` / `Vector<Expr>` return `Matrix<Expr>`, `Expr`, and `Vector<Expr>`.

### 9.3 Exact Analytical Calculus, Series & Closed-Form Integration

- **Reasoning**: Exact symbolic calculus requires arbitrary-order differentiation, vector calculus, formal Laurent/power series expansions, asymptotic limits, and analytical anti-differentiation.
- **Implementation & Constraints**:
  - `DifferentiationExtension on Expr` (`lib/src/symbolic/calculus/differentiation.dart`):
    - `derivative(variable, {order = 1, assumptions = Assumptions.none})`: Computes exact analytical derivative via exhaustive pattern matching over AST node types with dependency short-circuiting (`!expr.dependsOn(variable)`), n-ary product/quotient, chain, generalized power, piecewise branch, Fundamental Theorem of Calculus / Leibniz integral rules (`d/dx integrate(f(t, x), t, a(x), b(x)) = f(b(x), x)*b'(x) - f(a(x), x)*a'(x) + integrate(df/dx, t, a(x), b(x))`), and unevaluated `Derivative` fallback for unbound `VariableFunction`, `Gamma`, `Beta`, `Factorial`, `Binomial`, `Arg`, and `Limit` expressions.
  - `IntegrationExtension on Expr` (`lib/src/symbolic/calculus/integration/`):
    - Modularized into `integration.dart` (core dispatcher, elementary single-node rules, and `IntegrationExtension`), `rational.dart` (polynomial division, `apart()` partial fractions, repeated quadratics, cubic/quartic/biquadratic denominators), `parts.dart` (LIATE and cyclic integration by parts), `trigonometric.dart` (trig/hyperbolic products, powers, and Weierstrass/rational substitutions), `radical.dart` (quadratic/affine/Chebyshev/fractional-linear radical reductions), `substitution.dart` (chain rule, u-substitution, and Gaussian antiderivatives), and `definite.dart` (definite and improper integration via FTC, limits, singularity partitioning, parity, and special integral families).
    - Computes closed-form symbolic antiderivatives, definite integrals `integrate(variable, {from, to, assumptions})` (including improper infinite bounds via `limit`, odd-function parity cancellation on symmetric intervals `[-a, a]`, and exact definite integral families for Gaussian/error functions, Dirichlet, Fresnel, Euler Gamma/Beta, Bose-Einstein/Fermi-Dirac, Wallis, and Euler logarithmic-sine/cosine integrals), and iterated multiple integrals `integrateMultiple(Iterable<IntegrationBound> bounds, {assumptions})` over constant or variable-dependent regions. Returns an unevaluated `Integral` AST node when no closed-form antiderivative or definite evaluation exists.
  - `SeriesExtension on Expr` (`lib/src/symbolic/calculus/series.dart`):
    - `toPowerSeries(variable, {point, order, assumptions})` and `series(variable, {point, order, includeOrder = true, assumptions})`: Single canonical formal truncated Laurent/Maclaurin series expansion (`PowerSeries`) accepting `Expr`, `int`, `BigInt`, or `double` expansion points and supporting Cauchy products, pole tracking (`valuation`), triangular series inversion, fractional powers, and ODE recurrence composition (`Pow(Constant.e, u)`, `Sin`, `Cos`, `Atan`, `Asinh`, `Atanh`, `Erf`, `Erfc`, `LambertW`). Passing `includeOrder: false` returns the truncated Taylor/Laurent polynomial without an `OrderTerm`.
  - `LimitExtension on Expr` (`lib/src/symbolic/calculus/limit.dart`):
    - `limit(variable, point, {direction = LimitDirection.both, assumptions = Assumptions.none})`: Evaluates finite (`Expr`, `int`, `BigInt`, `double`) and infinite (`Constant.infinity`, `-Constant.infinity`, `double.infinity`, `double.negativeInfinity`) limits via direct substitution, formal Laurent series pole/valuation analysis, algebraic rationalization, Gruntz most-rapidly-varying (MRV) asymptotic rewriting, Squeeze Theorem bounds for oscillating factors, and iterated L'Hopital's rule. Returns an unevaluated `Limit` AST node when a limit cannot be resolved analytically, while throwing `UnsupportedError` when a limit is proven not to exist (oscillation or mismatched one-sided limits).
  - `SummationExtension on Expr` (`lib/src/symbolic/calculus/summation.dart`):
    - `sum(variable, from, to, {assumptions})`, `indefiniteSum(variable, {assumptions})`, and `product(variable, from, to, {assumptions})`: Evaluates concrete finite sums/products and computes closed-form symbolic sums and products via Faulhaber / Bernoulli polynomial antidifferences (`sum k^p`), multi-factor geometric and Gosper polynomial-geometric recurrences (`sum P(k) * r^k`), Gosper factorial recurrences (`sum P(k) * k!`), binomial sums (`sum_{k=0..n} binomial(n, k) * x^k * y^(n - k)`), rational partial-fraction and shift-difference telescoping, infinite series limits and closed-form infinite families (Riemann `zeta(2m)`, odd zeta, Dirichlet `eta(2m)` and `beta(2m + 1)`, alternating harmonic, Mercator/polylogarithm `Li_1(r)` and `Li_2(1/2)`, Gregory-Leibniz arctan/atanh, and exponential/Stirling-Bell/trigonometric/hyperbolic factorial Taylor series with automatic index shifting), and factorial/Gamma/telescoping/infinite products (Wallis, Euler sine/cosine/sinh/cosh, Viete dyadic cosine).

### 9.4 Modular Algebraic Simplification, Approximation & Identity Engine

- **Reasoning**: Algebraic transformations produce unreduced expression trees requiring confluent reduction into minimal canonical normal forms without cyclic expansions, while preserving input term ordering until `.simplify()` is invoked.
- **Implementation & Constraints**:
  - `SimplifierExtension on Expr` (`lib/src/symbolic/algebra/simplify.dart`) executes bottom-up rewriting with `isSimplified` memoization and provides rectangular (`toRectangular({assumptions})`) and polar (`toPolar({assumptions})`) complex normal forms, decomposed into modular domain rules (`lib/src/symbolic/algebra/simplify/`):
    - `additive.dart` and `term_accumulator.dart` (`MonomialAccumulator`): Flattening, atomic `Number` folding, like-term collection, Pythagorean (`sin^2(u) + cos^2(u) -> 1`) and hyperbolic (`cosh^2(u) - sinh^2(u) -> 1`) contraction, logarithmic combination (`ln(a) + ln(b) -> ln(a * b)`), Landau `O(x^n)` dominance absorption, shared univariate polynomial degree/coefficient extraction (`polynomialDegree`, `extractPolynomialCoefficients`, `maxPolynomialDegree`, `buildPolynomialFromCoefficients`), and sorting in **increasing degree order** (`compareAdditiveTerms`: constants -> increasing degree `x, x^2, x^3` -> functions -> `OrderTerm` last).
    - `multiplicative.dart`: Atomic `Number` folding (`IntegerNumber`, `FractionNumber`, `RealNumber`, `ComplexNumber`), canonical structural factor ordering (`compareStructural`), base-exponent merging (`u^a * u^b -> u^(a + b)`), rational coefficient absorption into negative integer radicals (`2 * 2^(-1/2) -> sqrt(2)`), and polynomial fraction cancellation.
    - `power.dart`: Atomic numeric power evaluation (`powNumber`), exact prime-power radical extraction (`sqrt(12) -> 2 * sqrt(3)`, `2^(3/2) -> 2 * sqrt(2)`), domain-aware root reduction (`sqrt(x^2) -> x` when `VariableDomain.positive`, `|x|` otherwise), `exp(ln(u)) -> u`, and nested power folding.
    - `transcendental.dart` and `exact_constants.dart`: Elementary trigonometric, hyperbolic, exponential, logarithmic, and absolute value rules (`simplifySin`, `simplifyCos`, ..., `simplifyExp`, `simplifyLn`, `simplifyAbs`), exact special angles, and parity. `exact_constants.dart` matches special angles and radicals purely structurally on exact AST representations (`RationalNumber`, exact `Pow` radicals) without numerical evaluation or `RealNumber` guessing. All transcendental, trigonometric, and power operations applied to `RealNumber` inputs simplify directly to numeric `RealNumber` results.
    - `special.dart`, `complex.dart`, and `discrete.dart`: Special/combinatorial function identities (`LambertW`, `Erf`, `Erfc`, `Erfi`, `FresnelS`, `FresnelC`, `ExpIntegralEi`, `LogIntegralLi`, `SinIntegralSi`, `CosIntegralCi`, `SinhIntegralShi`, `CoshIntegralChi`, `Gamma`, `UpperGamma`, `LowerGamma`, `Zeta`, `Digamma`, `Polygamma`, `Polylog`, `Beta`, `BesselJ`, `BesselY`, `BesselI`, `BesselK`, `EllipticK`, `EllipticE`, `EllipticF`, `EllipticEIncomplete`, `Factorial`, `Binomial`), complex projections and normal forms (`simplifyRe`, `simplifyIm`, `simplifyArg`, `simplifyConjugate`, `toRectangularExpr`, `toPolarExpr`), and discrete/relational/piecewise/calculus AST node simplification (`Floor`, `Ceil`, `Round`, `Sign`, `Mod`, `RelationalExpr`, `Piecewise`, `Integral`, `Derivative`, `Limit`).
  - `ApproximationExtension on Expr` (`lib/src/symbolic/algebra/approximate.dart`):
    - `approximate({precision, assumptions})`: Evaluates exact `RationalNumber`s, `Constant`s (`pi`, `e`), definite `Integral`s, and closed subtrees into floating-point `RealNumber` / `ComplexNumber` values, leaving free symbolic variables intact.
    - `rationalize({maxDenominator, tolerance, assumptions})`: Recovers exact `RationalNumber` nodes from finite `RealNumber` leaves via continued-fraction convergents (`RationalNumber.fromDouble`).
  - Clear separation of concerns:
    - `simplify({assumptions})` focuses strictly on confluent reduction to normal form.
    - `expand({assumptions})` (`lib/src/symbolic/algebra/expand.dart`) distributes multiplications and integer powers of sums.
    - `factor({assumptions})` (`lib/src/symbolic/algebra/factor/`) decomposes composite `IntegerNumber` and `FractionNumber` values into prime-power products, extracts multivariate monomial GCDs, factors multivariate differences of squares (`A^2 - B^2`) and sums/differences of cubes (`A^3 +/- B^3`), and performs univariate square-free decomposition (`gcd(P, P')`) and rational/biquadratic factorization over `Q`.
  - `RationalFunctionExtension on Expr` (`lib/src/symbolic/algebra/rational.dart`):
    - Provides rational-function and polynomial manipulation: `numerator`, `denominator`, `together({assumptions})` (combining rational sums over a least common denominator), `cancel({assumptions})` (cancelling common polynomial and numeric factors), `collect(variable, {assumptions})` (grouping multivariate additive terms by powers of `variable`), `polynomialDivide(divisor, variable, {assumptions})` (exact univariate polynomial division returning `PolynomialDivisionResult`), and `apart(variable, {assumptions})` (partial fraction decomposition via polynomial factorization and `BareissEngine` undetermined coefficients).
  - `TrigRewriteExtension on Expr` (`lib/src/symbolic/algebra/trig.dart`):
    - Provides trigonometric and hyperbolic rewriting: `expandTrig({assumptions})` (angle-addition and De Moivre multiple-angle expansions), `simplifyTrig({assumptions})` (quotient normalization, Pythagorean reduction, product-to-sum, and double-angle contraction), and `rewrite(RewriteTarget, {assumptions})` (`RewriteTarget.exp`, `RewriteTarget.trig`, `RewriteTarget.sinCos`).

### 9.5 Unified Bytecode Compiler, Common Subexpression Elimination & Multi-Target Evaluator

- **Reasoning**: Inner simulation loops, numerical optimizers, ODE integrators, and direct expression evaluation require fast primitive execution without AST walking or redundant evaluation of shared subtrees.
- **Implementation & Constraints**:
  - `compileToBytecode` (`lib/src/symbolic/compiler/bytecode.dart`) and `BytecodeEvaluator` (`lib/src/symbolic/compiler/evaluator.dart`):
    - Compiles an `Expr` into a flat stack-and-register bytecode program (`List<Instruction>` with `Op` opcodes, conditional/unconditional jumps for `Piecewise`, and `Op.evalNode` fallback for definite `Integral` via 16-point Gauss-Legendre quadrature).
    - When `optimize: true` (the default for closure compilation), performs DAG reference-counting Common Subexpression Elimination (CSE), emitting `Op.storeReg` on the first evaluation of any composite subtree with reference count `> 1` and `Op.loadReg` on subsequent occurrences.
    - `BytecodeEvaluator` provides zero-allocation evaluation across all target types (`evaluate1D`, `evaluateList`, `evaluateVector`, `evaluateMap`, `evaluateTensor`, `evaluateComplex1D`, `evaluateComplexList`, `evaluateComplexMap`) using preallocated operand and register buffers, delegating hyperbolic and complex operations to `package:more`.
  - `CompilerExtension on Expr` (`lib/src/symbolic/compiler.dart`) exposes direct evaluation (`evaluate(context)` and `evaluateComplex(context)`) and compiled evaluation closures (`toBytecode`, `toFunction1D`, `toComplexFunction1D`, `toVectorFunction`, `compile`, `compileComplex`, and `compileTensorKernel`) backed by `BytecodeEvaluator`.

### 9.6 Symbolic Equation & System Solving

- **Reasoning**: Analytical resolution of algebraic equations, polynomial roots, differential equations, and simultaneous linear and nonlinear polynomial systems.
- **Implementation & Constraints**:
  - Univariate `Expr.solve(variable, {assumptions = Assumptions.none})` (`lib/src/symbolic/solver/`):
    - Linear equations (`a * x + b = 0`), rational equations (`P(x)/Q(x) = 0` with pole exclusion), and `Equal(lhs, rhs)` nodes.
    - Quadratic, cubic (Cardano), quartic (Ferrari), cyclotomic, and biquadratic polynomials with exact real and complex roots (`lib/src/symbolic/solver/polynomial.dart`).
    - Factored products (`f * g = 0 -> solve(f) union solve(g)`) and Rational Root Theorem + synthetic division.
    - Invertible transcendental and hyperbolic compositions (`lib/src/symbolic/solver/transcendental.dart`), including `u * exp(u) = c` and `u^u = c` via `LambertW`.
    - Domain filtering: Filters candidate roots according to `assumptions.domainOf(variable)` (`real` excludes non-real complex roots, `positive` retains strictly positive real roots, `integer` retains exact integer roots).
  - Simultaneous systems:
    - `Iterable<Expr>.solve(variables, {method = PolynomialSystemMethod.auto, assumptions = Assumptions.none})` (`lib/src/symbolic/solver/system.dart` and `polynomial_system.dart`): Single canonical entry point for simultaneous equation systems. Automatically clears rational denominators via `together()`, tracks denominator poles to exclude extraneous roots, and dispatches by structure: univariate equations via `solveEquation`, determined linear systems via exact symbolic Gaussian elimination (`solveSystemEquations`), 2-variable polynomial systems via Sylvester resultant elimination (`resultant.dart`), and general n-variable polynomial ideals via Buchberger Gröbner basis + FGLM lexicographic conversion (`buchberger.dart`, `fglm.dart`).
  - Ordinary differential equations (`lib/src/symbolic/solver/ode.dart`):
    - `Expr.solveOde({dependent, independent, constant = 'C1', at, initialValues = const [], assumptions = Assumptions.none})`: Solves first-order linear/separable ODEs and constant-coefficient linear ODEs up to order 6 expressed with first-class `Derivative` AST nodes and `Equal` relations, with optional initial value conditions at `at`.

### 9.7 Extensible Parser & Presentation-Aware Textualization (String, LaTeX, MathML)

- **Reasoning**: Standardized mathematical output across human consoles, academic LaTeX documents, and web applications, paired with a customizable parser and round-trip fidelity (`Expr.parse(e.toString()) == e`).
- **Implementation & Constraints**:
  - Presentation-aware rendering (`lib/src/symbolic/textualization/`):
    - Shared structural analysis helpers (`formatting.dart`) extract leading negatives (`stripLeadingNegative`), partition `Mul` factors into numerator and denominator lists (`partitionMulFraction`), detect positive powers of elementary functions (`matchFunctionPower`), and evaluate operator precedence parenthesization.
    - Even though the AST only has `Add`, `Mul`, and `Pow`, `string.dart` (`formatExpr`), `latex.dart` (`toLatex`), and `mathml.dart` (`toMathMl`) inspect term signs and factor exponents at render time to emit natural `a - b` (never `a + -b`), `-x` (never `-1 * x`), `<mo>&minus;</mo>` vs `<mo form="prefix">&minus;</mo>`, single combined fractions (`\frac{3 x}{4 y}`, `<mfrac>`), function power notation (`\sin^{2}(x)`, `<msup><mi>sin</mi><mn>2</mn></msup>`), radicals (`sqrt(x)`, `\sqrt{x}`, `<msqrt><mrow>...</mrow></msqrt>` / `<mroot><mrow>...</mrow><mn>n</mn></mroot>`), exponentials (`exp(x)`, `e^{x}`), and integrals (`\int`, `<mo>&#x222B;</mo>`).
  - `ExprSyntax` (`lib/src/symbolic/parser.dart`):
    - Direct declarative configuration via `ExprSyntax({constants, unaryFunctions, binaryFunctions, variadicFunctions})` (which merges custom bindings with standard mathematical constants and functions, including canonical parse-time rewrites for `sec`, `csc`, `cot`, `asec`/`arcsec`, `acsc`/`arccsc`, `acot`/`arccot`, `sech`, `csch`, `coth`, `asech`/`arcsech`, `acsch`/`arccsch`, `acoth`/`arccoth`, `log2`, and `log10`) and `ExprSyntax.empty({...})` (which starts with empty bindings), plus `ExprSyntax.standard`.
    - Strictly case-sensitive PetitParser `ExpressionBuilder<Expr>` grammar (`builder.loopback`, `resolve(builder.build()).end()`) where identifiers are any character sequence not starting with a digit and containing no whitespace or mathematical operator/delimiter symbols. Unbound 0-argument identifiers resolve to `Variable(name)`, and unbound function calls resolve to `VariableFunction(name, arguments)`.
    - Lower-level lexical token parsers `ExprSyntax.identifierTokenParser` and `ExprSyntax.numberTokenParser` are intentionally exposed as public static APIs to allow web applications (such as `web/calculator`) to syntax-highlight and tokenize input equations with identical lexical rules.

### 9.8 Domain Assumptions (`Assumptions`)

- **Reasoning**: Symbolic operations often depend on mathematical domain assumptions (`positive`, `real`, `integer`, `complex`) for variables without mutating AST nodes or relying on async zone state.
- **Implementation & Constraints**:
  - `Assumptions` (`lib/src/symbolic/assumptions.dart`) is an immutable `const` value class (`Assumptions({domains, defaultDomain, parent})`, with presets `Assumptions.none`, `Assumptions.real`, `Assumptions.positive`, `Assumptions.complex`, `domainOf(name)`, `assume(name, domain)`, and `copyWith(...)` hierarchical parent chaining) passed via optional named `{Assumptions assumptions = Assumptions.none}` parameters to symbolic transformation, calculus, and solver methods. When `assumptions` are provided, simplification (`sqrt(x^2) -> x`, `abs(x) -> x`, `sign(x) -> 1`, `arg(x) -> 0` for `positive`; `conj(x) -> x`, `re(x) -> x`, `im(x) -> 0` for `real`/`positive`/`integer`; `floor(n) -> n`, `ceil(n) -> n`, `round(n) -> n`, `sin(n * pi) -> 0`, `cos(2 * n * pi) -> 1`, `(-1)^(2 * n) -> 1` for `integer`) and equation solving (`solve`) respect the specified domain assumptions.

---

## 10. Special Functions Subsystem (`package:data/special.dart`)

### 10.1 High-Precision Transcendental Function Architecture

- **Reasoning**: Applied physics, engineering, and probability theory require numerically stable implementations of non-elementary transcendental functions across both real and complex domains that avoid underflow/overflow and preserve 15–16 digits (53-bit IEEE-754) of precision.
- **Implementation & Constraints**:
  - Pure Dart mathematical functions in `lib/src/special/`, exported directly via `lib/special.dart` (with internal helpers `expIntegralE1Complex`, `logAbsGammaWithSign`, and `utils.dart` kept package-internal).
  - Depends only on `dart:math` and `package:more/number.dart` (`Complex`); routines rely strictly on IEEE-754 floating-point operations with analytical reflection formulas, continued fractions, quadrature, and asymptotic expansions.

### 10.2 Gamma, Beta & Factorial Families (`lib/src/special/gamma.dart`, `beta.dart`, `digamma.dart`, `zeta.dart`, `factorial.dart`, `binomial.dart`, `permutation.dart`)

- **Gamma Functions**:
  - `gamma(x)` and `gammaComplex(z)`: Complete gamma function `Γ(x)` computed via exact lookup for integers `1..23`, 15-term Lanczos approximation (`g = 607 / 128`) yielding 15–16 digits of relative precision, and Euler's reflection formula `Γ(1 - z) * Γ(z) = π / sin(π * z)` with log-space overflow protection for `x < -100`.
  - `gammaLn(x)` and `gammaLnComplex(z)`: Logarithm of `Γ(z)`, using overflow-free `logSinPiComplex` in the left half-plane and preventing overflow up to `x ≈ 10^300`.
  - `gammaP(a, x)` and `gammaQ(a, x)`: Lower `P(a, x) = γ(a, x) / Γ(a)` and upper `Q(a, x) = Γ(a, x) / Γ(a)` regularized incomplete gamma functions. Evaluated via power series when `x < a + 1`, and Legendre's continued fraction via modified Lentz's method when `x >= a + 1`.
  - `lowerGamma(s, x)`, `lowerGammaComplex(s, z)`, `upperGamma(s, x)`, and `upperGammaComplex(s, z)`: Unregularized incomplete gamma functions with iterative negative-`s` recurrence.
  - `gammaPInv(a, p)` and `gammaQInv(a, q)`: Inverses of the regularized incomplete lower and upper gamma functions (shape `a` first, probability second), using Wilson-Hilferty / asymptotic initial approximations refined by bracketed Halley iterations with probability-scaled convergence tolerances.
- **Beta Functions**:
  - `beta(a, b)`, `betaComplex(a, b)`, `betaLn(a, b)`, and `betaLnComplex(a, b)`: Euler's beta function `B(a, b) = Γ(a) * Γ(b) / Γ(a + b)` and log-beta `ln B(a, b)`, guarding asymmetric overflow when `a + b > 150`.
  - `betaI(x, a, b)`: Regularized incomplete beta function `I_x(a, b) = B(x; a, b) / B(a, b)`, evaluated via continued fraction with symmetry transformation `I_x(a, b) = 1 - I_{1-x}(b, a)` when `x >= (a + 1) / (a + b + 2)`.
  - `betaIInv(p, a, b)`: Inverse incomplete beta function `x` such that `I_x(a, b) = p` using asymptotic approximations refined by bracketed Halley steps with relative tail tolerance.
- **Logarithmic Derivatives & Zeta Functions**:
  - `digamma(x)` and `digammaComplex(z)`: Logarithmic derivative `ψ(z) = Γ'(z) / Γ(z)`, evaluated via recurrence shifted to `|z| >= 10`, 14th-order Bernoulli asymptotic expansion, and overflow-free `cotPiComplex` reflection.
  - `polygamma(m, x)` and `polygammaComplex(m, z)`: Order-`m` logarithmic derivative `ψ^(m)(z)` with incremental 10-term Bernoulli asymptotic expansion and log-space factorial scaling for `m > 150`.
  - `zeta(s)` and `zetaComplex(s)`: Riemann zeta function `ζ(s)`, computed via Borwein's accelerated alternating series (`n = 21`) near the real axis, adaptive Euler–Maclaurin summation for larger `|Im(s)|`, and log-space Riemann reflection for `Re(s) < 0.5`.
  - `hurwitzZeta(s, a)` and `hurwitzZetaComplex(s, a)`: Hurwitz zeta function `ζ(s, a)` via exact Bernoulli polynomials `-B_{n+1}(a) / (n + 1)` at non-positive integers `s = -n` and shifted Euler–Maclaurin summation elsewhere.
- **Combinatorics**:
  - `factorial`, `factorialComplex`, `factorialLn`, `binomial`, `binomialComplex`, `binomialLn`, `permutation`, `permutationComplex`, and `permutationLn` with exact safe-integer / `BigInt` fast paths, generalized real/complex extensions, and cancellation-free small-`k` log-sums.

### 10.3 Gaussian Error & Fresnel Functions (`lib/src/special/erf.dart`, `fresnel.dart`)

- **Reasoning**: Fundamental to cumulative normal distributions, Brownian motion, diffusion equations, and wave diffraction.
- **Implementation & Constraints**:
  - `erf(x)` and `erfc(x)`: Error and complementary error functions `(2 / √π) ∫_0^x exp(-t^2) dt` and `1 - erf(x)`, computed via Cody's rational Chebyshev minimax approximations preserving subnormal tail precision down to `x ≈ 27.3`.
  - `erfComplex(z)` and `erfcComplex(z)`: Complex error and complementary error functions via Salzer's windowed series (A&S 7.1.29) and right-half-plane Lentz continued fractions.
  - `erfi(x)` and `erfiComplex(z)`: Imaginary error function `erfi(z) = -i * erf(i * z)` using power series for `|x| < 7` and split-exponential asymptotic expansion for `|x| >= 7`.
  - `erfInv(p)` and `erfcInv(p)`: Inverse error functions combining minimax/asymptotic tail initializations with Halley root refinement.
  - `fresnelS(x)`, `fresnelSComplex(z)`, `fresnelC(x)`, and `fresnelCComplex(z)`: Normalized Fresnel sine `S(z) = ∫_0^z sin(π/2 * t^2) dt` and cosine `C(z) = ∫_0^z cos(π/2 * t^2) dt` integrals via power series, Lentz continued fraction with modular phase reduction, and `erfComplex` continuation.

### 10.4 Cylindrical & Modified Bessel Functions (`lib/src/special/bessel.dart`)

- **Reasoning**: Solutions to Bessel's differential equation `x^2 y'' + x y' + (x^2 - ν^2) y = 0` in cylindrical wave propagation and heat conduction.
- **Implementation & Constraints**:
  - `besselJ(nu, x)` and `besselJComplex(nu, z)`: Bessel functions of the first kind of arbitrary real/complex order `ν`, achieving 15–16 digits via power series (`x <= 2`), unified Miller backward recurrence and directional recurrence (`2 < x <= max(25, ν^2)`), and Hankel's asymptotic expansion (`x > max(25, ν^2)`).
  - `besselY(nu, x)` and `besselYComplex(nu, z)`: Bessel functions of the second kind (Neumann functions), evaluated via Temme's small-`x` series (`x < 2`), Miller + Steed's CF2 Wronskian solver (`2 <= x <= max(25, ν^2)`), and Hankel asymptotics (`x > max(25, ν^2)`), eliminating near-integer `sin(πν)` cancellation.
  - `besselI(nu, x)` and `besselIComplex(nu, z)`: Modified Bessel functions of the first kind via positive-term power series, asymptotic expansion, and `I_{-ν} = I_ν + (2/π) sin(πν) K_ν` for negative non-integer orders.
  - `besselK(nu, x)` and `besselKComplex(nu, z)`: Modified Bessel functions of the second kind (Macdonald functions) via exponentially scaled trapezoidal quadrature for `|μ| <= 0.5` paired with unconditionally stable upward recurrence, small-`x` series, and asymptotic expansion.

### 10.5 Complete & Incomplete Elliptic Integrals (`lib/src/special/elliptic.dart`)

- **Reasoning**: Exact arc length of ellipses, planetary orbits, and pendulum periods.
- **Implementation & Constraints**:
  - `ellipticK(k)` and `ellipticKComplex(k)`: Complete Legendre elliptic integral of the first kind `K(k) = ∫_0^(π/2) dθ / √(1 - k^2 sin^2 θ)` in modulus `k` (`-1 <= k <= 1`), evaluated via the Arithmetic-Geometric Mean (AGM) for real `k` and Carlson's `R_F` for complex `k`.
  - `ellipticE(k, {phi})` and `ellipticEComplex(k, {phi})`: Complete (`phi` omitted) and incomplete (`phi` provided) Legendre elliptic integrals of the second kind in modulus `k`, evaluated via AGM or Carlson's `R_F` and `R_D` with quasi-periodicity reduction.
  - `ellipticF(phi, k)` and `ellipticFComplex(phi, k)`: Incomplete Legendre elliptic integral of the first kind `F(φ, k)` via Carlson's `R_F`.
  - `ellipticPi(n, k, {phi})` and `ellipticPiComplex(n, k, {phi})`: Complete and incomplete Legendre elliptic integrals of the third kind `Π(n, k)` and `Π(n, φ, k)` via Carlson's `R_F` and `R_J`.

### 10.6 Generalized Hypergeometric Series (`lib/src/special/hypergeometric.dart`)

- **Reasoning**: Unifying framework subsuming exponential, trigonometric, Bessel, and orthogonal polynomial series.
- **Implementation & Constraints**:
  - `hypergeometric1F1(a, b, z)` and `hypergeometric1F1Complex(a, b, z)`: Kummer confluent hypergeometric function `1F1(a; b; z)` with terminating polynomial detection, Kummer's first transformation, and log-gamma asymptotic expansion for large negative `z`.
  - `hypergeometric2F1(a, b, c, z)` and `hypergeometric2F1Complex(a, b, c, z)`: Gauss hypergeometric function `2F1(a, b; c; z)`, utilizing parameter symmetry, Pfaff/Euler linear transformations, and logarithmic `1 - z` series for integer `c - a - b` near `z = 1`.
  - `hypergeometricPFQ(a, b, z)` and `hypergeometricPFQComplex(a, b, z)`: Generalized hypergeometric series `pFq(a; b; z)` with pole precedence checking and closed-form delegation for `0F0`, `1F0`, `1F1`, and `2F1`.

### 10.7 Lambert W Function (`lib/src/special/lambert_w.dart`)

- **Reasoning**: Solutions to transcendental equations of the form `W(z) exp(W(z)) = z`, appearing in tree enumeration, diode physics, enzyme kinetics, and delay differential equations.
- **Implementation & Constraints**:
  - `lambertW(z, {branch = 0})` and `lambertWComplex(z, {branch = 0})`: Principal (`branch: 0`, `z >= -1/e`) and secondary (`branch: -1`, `-1/e <= z <= 0` with `W_{-1}(0) = -∞`) branches initialized via branch-point Taylor series, Padé, or asymptotic logarithmic expansions and refined by standard or log-space Halley iterations.

### 10.8 Exponential, Trigonometric, Hyperbolic Integrals & Polylogarithm (`lib/src/special/exp_integral.dart`, `trig_integral.dart`, `polylog.dart`)

- **Reasoning**: Non-elementary antiderivatives of rational-exponential, rational-trigonometric, and rational-hyperbolic kernels, plus polylogarithms appearing in Bose-Einstein/Fermi-Dirac statistics and dilogarithm identities.
- **Implementation & Constraints**:
  - `expIntegral(x)`, `expIntegralComplex(z)`, `expIntegralE(n, x)`, `expIntegralEComplex(n, z)`, `logIntegral(x)`, and `logIntegralComplex(z)`: Exponential, generalized exponential `E_n`, and logarithmic integrals evaluated via power series, modified Lentz continued fractions, upward recurrence, and split-exponential asymptotics.
  - `sinIntegral(x)`, `sinIntegralComplex(z)`, `cosIntegral(x)`, `cosIntegralComplex(z)`, `sinhIntegral(x)`, `sinhIntegralComplex(z)`, `coshIntegral(x)`, and `coshIntegralComplex(z)`: Sine, cosine, hyperbolic sine, and hyperbolic cosine integrals with branch-consistent continuation across negative real and imaginary axes.
  - `polylog(s, z)` and `polylogComplex(s, z)`: Polylogarithm `Li_s(z)` with exact Eulerian rational forms for negative integer orders, Landen/duplication acceleration near `z = -1`, singular logarithmic expansion near `z = 1`, and inversion for `|z| > 1`.
