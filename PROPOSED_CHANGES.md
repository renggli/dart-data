# Architecture Review & Feature Proposals for `package:data`

## Executive Summary

`package:data` is an extensive, high-performance mathematics and data structure library for Dart, providing data structures and algorithms across matrices, vectors, tensors, polynomials, numerical analysis, special functions, and probability distributions.

This document presents a comprehensive review of the codebase covering:
1. **Architectural Improvements & Inconsistencies**: Structural design limitations, evaluation models (lazy vs. eager), the `Storage` aliasing defect, mutable global state, and type system design.
2. **Subsystem-by-Subsystem Deficiencies & Bugs**: Concrete defects and limitations in `tensor`, `matrix`, `vector`, `numeric`, `stats`, and `polynomial`.
3. **Missing Features & Algorithmic Roadmap**: Essential scientific computing capabilities (optimization, ODE solvers, cubic splines, hypothesis testing, complex linear algebra, axis reductions).
4. **Modern Dart 3+ Evolution**: Leveraging extension types, SIMD vectorization, and class modifiers.

---

## 1. Core Architectural Issues & Proposals

### 1.1 Architectural Fragmentation: `Tensor` vs. `Matrix` vs. `Vector`

#### Current State
The library currently maintains three parallel tensor-like data models:
- **`Tensor<T>`** ([lib/src/tensor/tensor.dart](file:///Users/renggli/Programming/Dart/Data/lib/src/tensor/tensor.dart)): An N-dimensional dense array backed by a flat buffer and a unified `Layout` (shape, strides, offset). All layout operations (slice, transpose, flip, reshape, expand, collapse) are zero-copy views. However, mathematical operators (`+`, `-`, `*`) are **eager**, returning newly allocated `Tensor` instances.
- **`Matrix<T>`** ([lib/src/matrix/matrix.dart](file:///Users/renggli/Programming/Dart/Data/lib/src/matrix/matrix.dart)): A 2D data structure featuring 10 storage implementations (RowMajor, ColumnMajor, CSR, CSC, COO, Keyed, Diagonal, NestedRow, NestedColumn, TensorMatrix) and over 20 specialized lazy view classes ([lib/src/matrix/view/](file:///Users/renggli/Programming/Dart/Data/lib/src/matrix/view/)). Mathematical operators (`+`, `-`, `*`) return **lazy views** ([`BinaryOperationMatrix`](file:///Users/renggli/Programming/Dart/Data/lib/src/matrix/view/binary_operation_matrix.dart), [`MatrixMatrixMultiplicationMatrix`](file:///Users/renggli/Programming/Dart/Data/lib/src/matrix/view/matrix_matrix_multiplication_matrix.dart)).
- **`Vector<T>`** ([lib/src/vector/vector.dart](file:///Users/renggli/Programming/Dart/Data/lib/src/vector/vector.dart)): A 1D data structure mirroring Matrix's lazy view architecture.

#### Problems & Inconsistencies
1. **Conflicting Operator Semantics**:
   - In `Matrix`, `a * b` performs **linear-algebra matrix multiplication** (`mulMatrix` in [lib/src/matrix/operator/mul.dart:10-14](file:///Users/renggli/Programming/Dart/Data/lib/src/matrix/operator/mul.dart#L10-L14)).
   - In `Tensor`, `a * b` performs **element-wise multiplication** ([lib/src/tensor/operations/operation.dart:108](file:///Users/renggli/Programming/Dart/Data/lib/src/tensor/operations/operation.dart#L108)).
   - In `Vector`, `a * b` performs **element-wise multiplication** ([lib/src/vector/operator/mul.dart:7-9](file:///Users/renggli/Programming/Dart/Data/lib/src/vector/operator/mul.dart#L7-L9)).
   - In `Matrix`, element-wise multiplication (Hadamard product) does not have a dedicated method or operator.
   - In `Tensor`, matrix multiplication (`matmul`) does not exist.
2. **Hidden Algorithmic Complexity in Lazy Matrix Views**:
   - `MatrixMatrixMultiplicationMatrix.getUnchecked(row, col)` ([lib/src/matrix/view/matrix_matrix_multiplication_matrix.dart:31-41](file:///Users/renggli/Programming/Dart/Data/lib/src/matrix/view/matrix_matrix_multiplication_matrix.dart#L31-L41)) computes an inner dot product on the fly on **every single element read**.
   - If an algorithm accesses elements multiple times without calling `.toMatrix()`, the operation explodes into quadratic or cubic redundant work. Chaining `(A * B) * C` recomputes the entire inner matrix multiplication for every single element accessed.
3. **Class Explosion vs. Unified Layout**:
   - `Matrix` implements 25 view classes to handle transposition, horizontal/vertical flipping, diagonal extraction, rotation, indexing, slicing, etc.
   - In contrast, `Tensor` handles all of these using a single, elegant `Layout` class by updating `shape`, `strides`, and `offset`.

#### Proposed Architecture
- **Unify Dense 1D/2D Containers on Tensor Layout**: Refactor dense `Matrix` and `Vector` implementations to be thin typed wrappers or extension types over 2D and 1D `Tensor` layouts, eliminating redundant view classes.
- **Preserve Specialized Sparse Matrices**: Retain CSR, CSC, COO, and Keyed formats for sparse linear algebra, where stride-based indexing does not apply.
- **Clarify Operator Semantics**:
  - Distinguish element-wise multiplication (`hadamard(other)` or `elementMultiply(other)`) from matrix multiplication (`mulMatrix(other)` or `matmul(other)`).
  - Add `matmul` to `Tensor` for 2D and batched N-D matrix multiplication.
- **Predictable Evaluation Strategy**: Document and standardize evaluation rules. Lazy views are beneficial for pure indexing/transformations (transposition, slicing), but arithmetic products should either be eagerly evaluated or provide distinct types (e.g. `LazyMatrix` vs `Matrix`).

---

### 1.2 Storage Aliasing Defect & Unused `Storage` Abstraction

#### Current State
- The `Storage` interface ([lib/src/shared/storage.dart](file:///Users/renggli/Programming/Dart/Data/lib/src/shared/storage.dart)) specifies:
  ```dart
  abstract class Storage {
    List<int> get shape;
    Set<Storage> get storage;
  }
  ```
- Every single view and container in `matrix`, `vector`, and `polynomial` implements `Set<Storage> get storage => ...`.
- However, across the entire library, **`storage` is never once inspected, queried, or checked** in any algorithm or assignment.
- Meanwhile, `Tensor` does not even implement `Storage`.

#### The Aliasing Bug
In `Matrix.copyInto` ([lib/src/matrix/matrix.dart:511-530](file:///Users/renggli/Programming/Dart/Data/lib/src/matrix/matrix.dart#L511-L530)):
```dart
Matrix<T> copyInto(Matrix<T> target) {
  assert(rowCount == target.rowCount, ...);
  assert(colCount == target.colCount, ...);
  if (this != target) {
    for (var r = 0; r < rowCount; r++) {
      for (var c = 0; c < colCount; c++) {
        target.setUnchecked(r, c, getUnchecked(r, c));
      }
    }
  }
  return target;
}
```
If a user calls:
```dart
matrix.transposed.copyInto(matrix);
```
Since `matrix.transposed != matrix`, the loop executes. When `r=0, c=1`, `target[0, 1]` is overwritten with `matrix[1, 0]`. When the loop later reaches `r=1, c=0`, it reads `matrix[0, 1]`—which has already been overwritten—resulting in silent data corruption!

#### Proposed Solution
1. **Connect `storage` to Aliasing Detection**:
   In `copyInto` and in-place mutating operations, check if `storage.intersection(target.storage).isNotEmpty`. If an alias exists, copy through a temporary buffer.
2. **Unify `Tensor` into `Storage`**: Have `Tensor` implement `Storage` (or replace `Storage` with a unified memory buffer representation).

---

### 1.3 Mutable Global State in `DataType`

#### Current State
In [lib/src/type/type.dart:62-100](file:///Users/renggli/Programming/Dart/Data/lib/src/type/type.dart#L62-L100):
```dart
/// Configurable default data type to index collections, rows, columns, etc.
static IntegerDataType index = uint32;

/// Configurable default data type for integer arithmetic.
static IntegerDataType integer = int32;

/// Configurable default data type for floating point arithmetic.
static FloatDataType float = float64;
```

#### Problem
These are mutable global variables (`static ... = ...;`). If any library or third-party package reassigns `DataType.float = DataType.float32;`, it globally alters the behavior of all downstream matrix, vector, and tensor computations in the same isolate, introducing race conditions, broken immutability, and flaky unit tests.

#### Proposed Solution
- Change them to `static const` defaults (e.g. `static const IntegerDataType defaultIndex = uint32;`, `static const FloatDataType defaultFloat = float64;`).
- If configurability is required, provide explicit configurations passed via constructors or scoped through `Zone` variables (`runZoned`).

---

### 1.4 Algebraic Type Hierarchy & Numeric Deficiencies

#### 1. Incomplete `Field<T>` Interface
In [lib/src/type/models/field.dart](file:///Users/renggli/Programming/Dart/Data/lib/src/type/models/field.dart), `Field<T>` provides basic ring/field operations (`add`, `sub`, `mul`, `div`), but lacks:
- Absolute value / norm: `abs(T a) -> T` or `norm(T a) -> double`
- Square root: `sqrt(T a) -> T`
- Transcendental functions: `exp`, `log`, `sin`, `cos`, `pow`

Because `Field<T>` lacks these, decompositions and algorithms (such as SVD, QR, Eigenvalues, norms, and regression) cannot be implemented generically on `DataType<T>`. Consequently, all decompositions are restricted to `Matrix<num>` and cast internally to `DataType.float` (`double`), leaving `Complex`, `Fraction`, and `BigInt` unsupported.

#### 2. Flawed `IntegerField.scale` Implementation
In [lib/src/type/impl/integer.dart:292](file:///Users/renggli/Programming/Dart/Data/lib/src/type/impl/integer.dart#L292):
```dart
@override
int scale(int a, num f) => a * f.round();
```
`f` is rounded **before** multiplying with `a`.
- Example: `DataType.int32.field.scale(10, 0.4)` evaluates to `10 * 0 = 0`.
- Example: `DataType.int32.field.scale(10, 0.6)` evaluates to `10 * 1 = 10`.
- Expected behavior: `(a * f).round()`. Scaling 10 by 0.4 should yield 4, not 0.

#### 3. Missing Type Promotion in Operations
Binary operations in `Tensor` and `Matrix` require operands to share the exact same type:
```dart
Tensor<T> operator +(Tensor<T> other)
```
Users cannot add a `Tensor<int>` to a `Tensor<double>` without manually allocating and casting. Introducing type promotion rules (e.g. `int` + `double` $\to$ `double`) would align the library with NumPy and standard mathematical libraries.

---

### 1.5 Modern Dart 3+ Language Features

- **Extension Types (`extension type`)**: Dart 3.3+ introduces zero-cost extension types. Lightweight views over typed lists (e.g. `Float64Vector` wrapping `Float64List`) can eliminate heap wrapper overhead entirely.
- **SIMD Vectorization**: Dart supports `Float32x4List` and `Int32x4List` in `dart:typed_data`. Dense vector and tensor element-wise arithmetic on `float32` and `int32` can achieve 4x throughput improvements on compatible CPUs.
- **Class Modifiers**:
  - `Storage` should be declared `base class` or `interface class` to restrict arbitrary subtyping.
  - `DataType` and `Distribution` hierarchies should use `sealed` classes where possible to allow exhaustive pattern matching.

---

## 2. Subsystem-by-Subsystem Review & Defects

### 2.1 Tensor Subsystem (`lib/src/tensor/`)

#### 1. Shape Checking Bug in `binaryOperation` with `target` and Broadcasting
In [lib/src/tensor/operations/operation.dart:82-84](file:///Users/renggli/Programming/Dart/Data/lib/src/tensor/operations/operation.dart#L82-L84):
```dart
    final (thisLayout, otherLayout) = layout.broadcast(other.layout);
    ...
    if (target == null) {
      ...
    } else {
      // Perform the operation into another one (possibly in-place).
      LayoutError.checkEqualShape(layout, target.layout, 'target');
```
When broadcasting is required (e.g. operand `a` of shape `[1, 3]` and operand `b` of shape `[3, 3]`), the resulting broadcast shape is `[3, 3]`.
If the user provides a `target` tensor of shape `[3, 3]`, line 83 checks `layout` (`[1, 3]`) against `target.layout` (`[3, 3]`) and throws a `LayoutError`!
If the user mistakenly passes `target` of shape `[1, 3]`, line 83 passes, but iteration loops 9 times while `target` only has 3 elements, causing an `IndexOutOfRange` or truncation.
**Fix**: Must check `LayoutError.checkEqualShape(thisLayout, target.layout, 'target');`.

#### 2. Missing Axis Reductions
In NumPy, `sum(axis: ...)`, `mean(axis: ...)`, `min`, `max`, `std`, `var`, `argmin`, `argmax`, `all`, `any` are fundamental. `package:data` has no axis reduction operations for `Tensor`.

#### 3. Missing Tensor Manipulation
- `concatenate(Iterable<Tensor<T>>, {int axis = 0})`
- `stack(Iterable<Tensor<T>>, {int axis = 0})`
- `split(int parts, {int axis = 0})`
- `tile(List<int> reps)` and `pad(...)`

#### 4. Missing Linear Algebra on Tensors
- `matmul(Tensor<T> other)`: Batched 2D matrix multiplication for tensors of rank $\ge 2$.
- `tensordot`, `einsum`, `inner`, `outer`.

#### 5. Lack of Fast Paths for Contiguous Data
Currently, all tensor element operations iterate through multi-dimensional `IndexIterator` mixed-radix coordinate calculations. For contiguous tensors, replacing iterators with direct loops over flat arrays (`for (var i = 0; i < length; i++) target[i] = op(source[i]);`) yields dramatic speedups.

---

### 2.2 Matrix Subsystem (`lib/src/matrix/`)

#### 1. Code Duplication in Norms & Trace
In [lib/src/matrix/decomposition/norm.dart](file:///Users/renggli/Programming/Dart/Data/lib/src/matrix/decomposition/norm.dart), `NormDoubleExtension` (lines 24-60) and `NormIntegerExtension` (lines 62-98) contain identical duplicate implementations of `trace`, `norm1`, and `normInfinity`.
Furthermore, `trace` is not available on `Matrix<num>` or `Matrix<Complex>`.

#### 2. Lack of Complex Matrix Linear Algebra
None of the matrix decompositions ([`Cholesky`](file:///Users/renggli/Programming/Dart/Data/lib/src/matrix/decomposition/cholesky.dart), [`Eigenvalue`](file:///Users/renggli/Programming/Dart/Data/lib/src/matrix/decomposition/eigenvalue.dart), [`LU`](file:///Users/renggli/Programming/Dart/Data/lib/src/matrix/decomposition/lu.dart), [`QR`](file:///Users/renggli/Programming/Dart/Data/lib/src/matrix/decomposition/qr.dart), [`SingularValue`](file:///Users/renggli/Programming/Dart/Data/lib/src/matrix/decomposition/singular_value.dart)) support `Complex` numbers, despite `DataType.complex` existing in the library. Complex eigenvalues, conjugate transposition (Hermitian transpose $A^*$), and unitary matrix decompositions are essential for physics, signal processing, and control theory.

#### 3. Lack of Sparse Solvers & Algorithms
`Matrix` provides CSR, CSC, COO, and Keyed sparse matrix formats, but:
- There are no sparse linear solvers (e.g. Conjugate Gradient, GMRES, BiCGSTAB).
- Calling `.inverse` or `.solve` converts sparse matrices to dense representations, defeating their memory efficiency.
- Banded and tridiagonal matrix solvers (e.g. Thomas algorithm $O(n)$) are missing.

---

### 2.3 Vector Subsystem (`lib/src/vector/`)

#### Missing Features
- **Vector Norms**: Currently only basic dot/distance exists; missing generalized $L_p$ norm, $L_1$ (Manhattan), $L_2$ (Euclidean), and $L_\infty$ (Chebyshev).
- **Normalization**: In-place and view methods to produce unit vectors (`vector.normalized()`).
- **Outer Product**: `u.outer(v) -> Matrix<T>`.
- **Cumulative Operations**: `cumsum()`, `cumprod()`.
- **Projection & Rejection**: Projecting a vector onto another.

---

### 2.4 Numeric Subsystem (`lib/src/numeric/`)

#### 1. Optimization / Minimization (Completely Missing)
- Currently, `numeric/` only contains univariate root-finding (`solve.dart` using Brent's method) and least-squares curve fitting.
- Missing:
  - 1D scalar minimization (Golden section search, Brent's minimization method).
  - Multi-dimensional unconstrained optimization (Nelder-Mead simplex, BFGS, L-BFGS, Gradient Descent).
  - Constrained optimization (box bounds, equality/inequality constraints).

#### 2. Ordinary Differential Equation (ODE) Solvers (Completely Missing)
Scientific computing frequently requires integrating ODEs:
- Initial value problem (IVP) solvers: Runge-Kutta 4th order (RK4) and adaptive step size Dormand-Prince (RK45) / Cash-Karp.

#### 3. Multivariate Numerical Calculus (Missing)
- [lib/src/numeric/derivative.dart](file:///Users/renggli/Programming/Dart/Data/lib/src/numeric/derivative.dart) only supports univariate scalar functions `double Function(double)`.
- Missing:
  - Gradient vector $\nabla f(x)$ for scalar functions of multiple variables.
  - Jacobian matrix $J_f(x)$ for vector-valued functions.
  - Hessian matrix $H_f(x)$ for curvature and optimization.

#### 4. Numerical Instability in `PolynomialRegression.fit`
In [lib/src/numeric/curve_fit/polynomial_regression.dart:38-42](file:///Users/renggli/Programming/Dart/Data/lib/src/numeric/curve_fit/polynomial_regression.dart#L38-L42):
```dart
final result = vandermondeTransposed
    .mulMatrix(vandermonde)
    .inverse
    .mulMatrix(vandermondeTransposed)
    .mulVector(ys);
```
Solving the normal equations $(V^T V)^{-1} V^T y$ via explicit inversion squares the condition number of the Vandermonde matrix ($\kappa(V^T V) = \kappa(V)^2$). For higher degrees, this causes catastrophic loss of precision.
**Fix**: Use QR decomposition (`vandermonde.qr.solve(ys)`) or SVD least-squares.

#### 5. Interpolation Limitations
- Current interpolation methods ([lib/src/numeric/interpolate/](file:///Users/renggli/Programming/Dart/Data/lib/src/numeric/interpolate/)) are: `linear`, `lagrange`, `nearest`, `next`, `previous`.
- High-degree Lagrange interpolation suffers from Runge's phenomenon (divergent edge oscillations).
- Missing:
  - **Natural and Clamped Cubic Spline Interpolation** (industry standard for smooth interpolation).
  - **PCHIP** (Piecewise Cubic Hermite Interpolating Polynomial) for shape-preserving, monotonic interpolation.
  - 2D grid interpolation (bilinear, bicubic).

#### 6. Defect in `fft.dart` on Fixed-Length Lists
In [lib/src/numeric/fft.dart:28-31](file:///Users/renggli/Programming/Dart/Data/lib/src/numeric/fft.dart#L28-L31):
```dart
final n = values.length.bitCeil;
while (values.length < n) {
  values.add(Complex.zero);
}
```
If `values` is a fixed-length list (e.g. allocated via `type.newList()` or `Float64List`), `values.add(...)` throws `UnsupportedError: Cannot add to a fixed-length list`.
Furthermore, `fft` mutates the input list in-place without warning in the function signature, and no real-to-complex FFT (RFFT) or 2D FFT (`fft2`) is supported.

---

### 2.5 Statistics Subsystem (`lib/src/stats/`)

#### 1. Empirical & Descriptive Statistics on Data Samples
[lib/src/stats/iterable.dart](file:///Users/renggli/Programming/Dart/Data/lib/src/stats/iterable.dart) provides `sum`, `product`, `mean`, `variance`, `standardDeviation`.
Missing:
- Quantiles & percentiles (`percentile`, `quantile`, `median`, `iqr`).
- Empirical skewness and kurtosis on sample vectors.
- Covariance matrix (`cov(Matrix)`) and Pearson/Spearman correlation matrices.
- Weighted statistics (`weightedMean`, `weightedVariance`).
- Moving/rolling window statistics (moving average, exponential moving average).

#### 2. Hypothesis Testing (Completely Missing)
There are currently zero statistical hypothesis tests in the package:
- Student's t-test (one-sample, two-sample independent, paired t-test).
- Chi-squared test (goodness-of-fit, test of independence).
- One-way ANOVA (F-test).
- Non-parametric tests: Mann-Whitney U, Wilcoxon signed-rank test.
- Normality tests: Shapiro-Wilk, Jarque-Bera.
- Kolmogorov-Smirnov test (comparing an empirical sample against any `Distribution`).

#### 3. Distribution Parameter Estimation (`fit`)
Theoretical distributions in `lib/src/stats/distributions/` do not provide a `fit(Iterable<double> samples)` method. Adding Maximum Likelihood Estimation (MLE) or method-of-moments fitting would allow users to estimate parameters directly from empirical data.

#### 4. Resampling Methods
`Jackknife` ([lib/src/stats/jackknife.dart](file:///Users/renggli/Programming/Dart/Data/lib/src/stats/jackknife.dart)) is implemented, but:
- **Bootstrap Resampling** (both non-parametric and parametric bootstrap) with percentile and BCa confidence intervals is missing.

#### 5. Multivariate Distributions
All distributions are univariate. Missing:
- Multivariate Normal distribution.
- Dirichlet distribution.
- Multinomial distribution.

---

### 2.6 Polynomial Subsystem (`lib/src/polynomial/`)

#### 1. Orthogonal Polynomial Families
In scientific computing and spectral methods, standard monomial representation ($x^n$) is numerically unstable for high degrees. Missing:
- Chebyshev polynomials ($T_n, U_n$).
- Legendre polynomials ($P_n$).
- Hermite polynomials ($H_n$).
- Laguerre polynomials ($L_n$).

#### 2. Polynomial Arithmetic & Algebra
- Greatest Common Divisor (GCD) using the Euclidean algorithm.
- Polynomial composition $P(Q(x))$.
- Rational function representation ($P(x) / Q(x)$).

#### 3. Documentation Typo
In [lib/src/polynomial/polynomial.dart:22](file:///Users/renggli/Programming/Dart/Data/lib/src/polynomial/polynomial.dart#L22):
`/// Constructs a default vector of the desired [dataType]...`
Should read "Constructs a default polynomial...".

---

### 2.7 Missing Structures Mentioned in Project Roadmap

In the project's [README.md:11](file:///Users/renggli/Programming/Dart/Data/README.md#L11):
> *"As of today this mostly includes data structures and algorithms for vectors and matrices, but at some point might also include graphs and other mathematical structures."*

#### 1. Graph Data Structures & Algorithms
- Directed and undirected graphs.
- Adjacency list and adjacency matrix representations.
- Pathfinding: Dijkstra's algorithm, A*, Bellman-Ford, Floyd-Warshall.
- Topological sort, strongly connected components, minimum spanning tree (Kruskal/Prim).

#### 2. Tabular Data / DataFrames
A lightweight DataFrame structure for data science:
- Heterogeneous typed columns (`Series<T>`).
- Row/column indexing and labeling.
- Group-by and aggregation operations.
- CSV / JSON import and export.

---

## 3. Testing & Code Quality Improvements

1. **Modularize Test Suite**:
   Per the project charter ([AGENTS.md](file:///Users/renggli/Programming/Dart/Data/AGENTS.md)):
   > *"Structure the tests following the same folder structure as the code under test (e.g., `lib/src/foo/bar.dart` -> `test/foo/bar_test.dart`)."*
   Currently, the test directory contains monolithic test files (`stats_test.dart` is 103 KB, `matrix_test.dart` is 92 KB, `tensor_test.dart` is 58 KB). These should be decomposed into subdirectories matching `lib/src/`.
2. **Missing Test Coverage**:
   - `Tensor.binaryOperation` with a pre-allocated `target` parameter and broadcasting (which triggers the bug identified in §2.1).
   - In-place mutation aliasing in `Matrix.copyInto` (which triggers the bug identified in §1.2).

---

## 4. Prioritized Implementation Roadmap

| Priority | Category | Subsystem | Proposed Task |
| :--- | :--- | :--- | :--- |
| **P0 (Bug Fix)** | Correctness | `tensor` | Fix target shape check in `binaryOperation` ([operation.dart:83](file:///Users/renggli/Programming/Dart/Data/lib/src/tensor/operations/operation.dart#L83)). |
| **P0 (Bug Fix)** | Correctness | `type` | Fix `IntegerField.scale` rounding order ([integer.dart:292](file:///Users/renggli/Programming/Dart/Data/lib/src/type/impl/integer.dart#L292)). |
| **P0 (Bug Fix)** | Correctness | `numeric` | Fix `fft` crash on fixed-length lists ([fft.dart:30](file:///Users/renggli/Programming/Dart/Data/lib/src/numeric/fft.dart#L30)). |
| **P1 (Architecture)**| Safety | `matrix`/`vector` | Implement alias detection in `copyInto` using `Storage.storage`. |
| **P1 (Architecture)**| Concurrency | `type` | Remove mutable global static variables (`DataType.index`, `integer`, `float`). |
| **P1 (Feature)** | Core ND | `tensor` | Add axis-based reductions (`sum`, `mean`, `min`, `max`, `std`, `var`, `argmin`, `argmax`). |
| **P1 (Feature)** | Numerical | `numeric` | Replace normal equations in `PolynomialRegression` with QR/SVD decomposition. |
| **P1 (Feature)** | Interpolation | `numeric` | Implement Natural and Clamped Cubic Spline interpolation. |
| **P1 (Feature)** | Optimization | `numeric` | Add 1D Brent minimization and multi-dimensional Nelder-Mead / BFGS optimization. |
| **P2 (Feature)** | Statistics | `stats` | Add descriptive statistics (quantiles, IQR, empirical covariance/correlation) and Student's t-test. |
| **P2 (Feature)** | Linear Algebra | `matrix` | Implement complex matrix decompositions and iterative sparse solvers (Conjugate Gradient). |
| **P2 (Performance)**| Performance | `tensor` | Add contiguous-layout fast loops and SIMD vectorization for float/int operations. |
| **P3 (Feature)** | Mathematics | `polynomial` | Add orthogonal polynomials (Chebyshev, Legendre) and polynomial GCD. |
| **P3 (Roadmap)** | Data Struct | `graph` / `table`| Implement basic Graph data structures and lightweight DataFrame / Series. |
