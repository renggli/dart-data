# Subsystem Architecture: Tensor, Matrix, and Vector Unification

## 1. Overview & Current Inconsistencies

`package:data` currently maintains three separate, disconnected systems for multi-dimensional data:

- **`Tensor<T>`** ([lib/src/tensor/tensor.dart](../lib/src/tensor/tensor.dart)): N-dimensional dense array backed by a flat buffer and a unified strided `Layout`. All layout transformations (slice, transpose, flip, reshape, expand, collapse) are zero-copy view manipulations. Arithmetic operations are **eager**.
- **`Matrix<T>`** ([lib/src/matrix/matrix.dart](../lib/src/matrix/matrix.dart)): 2D data structure featuring 10 storage classes and over 20 specialized lazy view classes ([lib/src/matrix/view/](../lib/src/matrix/view/)). Arithmetic operations are **lazy views**.
- **`Vector<T>`** ([lib/src/vector/vector.dart](../lib/src/vector/vector.dart)): 1D data structure mirroring Matrix's lazy view architecture.

```
CURRENT FRAGMENTED STATE:

   Tensor<T>                    Matrix<T>                      Vector<T>
  (ND Strided)                 (2D Storage)                  (1D Storage)
 [Layout Engine]           [25 Lazy View Classes]        [12 Lazy View Classes]
  * is element-wise         * is matrix multiply          * is element-wise
  Eager evaluation          Lazy view evaluation          Lazy view evaluation
  No sparse formats         Dense + Sparse formats        Dense + Sparse formats
```

### 1.1 Key Inconsistencies & Defects

1. **Operator Semantic Conflict**:
   - `a * b` in `Matrix` computes the **matrix product** (algebraic $A \times B$).
   - `a * b` in `Tensor` and `Vector` computes the **element-wise product** (Hadamard $A \odot B$).
   - In `Matrix`, there is no dedicated operator or method for element-wise multiplication.
   - In `Tensor`, matrix multiplication (`matmul`) does not exist.

2. **Hidden Cubic Recomputation in Lazy Matrix Views**:
   - [`MatrixMatrixMultiplicationMatrix.getUnchecked(row, col)`](../lib/src/matrix/view/matrix_matrix_multiplication_matrix.dart#L31-L41) computes the inner dot product *on the fly every time an element is read*.
   - Accessing elements in a loop or chaining operations like `(A * B) * C` produces exponential or cubic recalculation overhead.

3. **Class Explosion vs. Strided Layout**:
   - `Matrix` creates a brand-new class for every view: `TransposedMatrix`, `FlippedHorizontalMatrix`, `FlippedVerticalMatrix`, `RotatedMatrix`, `SubMatrix`, `RowMatrix`, `ColumnMatrix`.
   - `Tensor` handles every one of these transformations with zero allocations simply by updating `shape`, `strides`, and `offset` in `Layout`.

4. **Tensor Target Aliasing Hazard with Broadcasting**:
   - In [`lib/src/tensor/operations/operation.dart:82-95`](../lib/src/tensor/operations/operation.dart#L82-L95):
     Target shape validation correctly verifies `thisLayout` matches `target.layout`. However, if `target` shares memory buffer with `this` or `other` while broadcasting occurs (e.g., broadcasting a $1 \times N$ row vector into an $M \times N$ matrix in-place), writing to `target` prematurely overwrites the broadcast source elements before they can be read for subsequent rows, causing silent data corruption. A temporary buffer is required when `target` aliases either operand under non-trivial broadcasting strides.

5. **Lack of Fast Paths for Contiguous Memory**:
   - Every tensor operation steps through multi-dimensional `IndexIterator` mixed-radix calculations. For contiguous tensors, a simple flat loop over typed buffers runs 10x-50x faster.

---

## 2. Unified Target Architecture

We unify dense representations on the strided `Layout` engine, while preserving specialized sparse formats behind clean, common interfaces.

```
TARGET UNIFIED ARCHITECTURE:

                          +----------------------+
                          |    NDArray<T>        |
                          | (Common Storage & ND)|
                          +----------------------+
                                     |
              +----------------------+----------------------+
              |                                             |
   +----------------------+                      +----------------------+
   |      Tensor<T>       |                      |      Matrix<T>       |
   | (Arbitrary ND array) |                      | (Rank-2 Specialization)
   +----------------------+                      +----------------------+
              |                                             |
   +----------------------+                      +----------+-----------+
   |      Vector<T>       |                      |                      |
   | (Rank-1 Extension)   |            +-------------------+  +-------------------+
   +----------------------+            |  DenseMatrix<T>   |  |  SparseMatrix<T>  |
                                       | (Tensor 2D Layout)|  | (CSR, CSC, COO)   |
                                       +-------------------+  +-------------------+
```

### 2.1 Core Unification Strategy

1. **Dense Matrix and Dense Vector are Tensor Views**:
   - `DenseMatrix<T>` is a 2D view over `Tensor<T>`:

     ```dart
     abstract class Matrix<T> implements Storage {
       int get rowCount;
       int get colCount;
       T get(int row, int col);
       void set(int row, int col, T value);
       
       // Algebraic operations
       Matrix<T> mulMatrix(Matrix<T> other);
       Matrix<T> hadamard(Matrix<T> other);
       Matrix<T> operator *(Matrix<T> other) => mulMatrix(other);
     }
     
     class DenseMatrix<T> implements Matrix<T> {
       final Tensor<T> _tensor; // Rank 2 tensor
       DenseMatrix(this._tensor) : assert(_tensor.rank == 2);
       
       @override
       Matrix<T> get transposed => DenseMatrix(_tensor.transpose([1, 0]));
     }
     ```

   - All 25 lazy matrix view classes for slicing, transposing, and flipping are replaced by native zero-copy `Layout` operations.

2. **Operator Disambiguation**:
   - In all rank-2 linear algebra classes (`Matrix`), `*` represents matrix multiplication (`mulMatrix`). Hadamard multiplication is explicitly `hadamard(other)` or `elementMultiply(other)`.
   - In `Tensor<T>`, `*` represents element-wise multiplication with broadcasting. Matrix multiplication is provided via `matmul(other)` (supporting 2D matrix multiplication and batched N-D matrix multiplication).
   - In `Vector<T>`, `*` is element-wise multiplication. Dot product is `dot(other)`. Outer product is `outer(other)`.

3. **Predictable Eager vs. Lazy Rules**:
   - **Lazy**: Geometric structural transformations (slice, transpose, reshape, broadcast, reverse) are always zero-copy lazy `Layout` views.
   - **Eager**: Arithmetic operations ($+$, $-$, $\times$, $\div$, matrix multiplication, decompositions) are eagerly evaluated and allocate a target buffer, avoiding cascading recomputation penalties.

### 2.2 Tensor Linear Algebra & Batched MatMul

Implement batched `matmul` for tensors:

```dart
Tensor<T> matmul(Tensor<T> other) {
  // Supports (..., M, K) x (..., K, N) -> (..., M, N)
  // Utilizes hardware-accelerated BLAS GEMM when available
}
```

### 2.3 Contiguous Layout Fast Paths

Before falling back to generic `IndexIterator`, operations check if layouts are contiguous in memory:

```dart
if (layout.isContiguous && other.layout.isContiguous && target.layout.isContiguous) {
  final aData = buffer;
  final bData = other.buffer;
  final outData = target.buffer;
  for (var i = 0; i < length; i++) {
    outData[i] = field.add(aData[i], bData[i]);
  }
  return target;
}
```

### 2.4 Axis Reductions

Full suite of reduction operations across specified axes:

```dart
Tensor<T> sum({int? axis, bool keepDims = false});
Tensor<T> mean({int? axis, bool keepDims = false});
Tensor<T> min({int? axis, bool keepDims = false});
Tensor<T> max({int? axis, bool keepDims = false});
Tensor<T> std({int? axis, bool keepDims = false, int ddof = 0});
Tensor<int> argmin({int? axis, bool keepDims = false});
Tensor<int> argmax({int? axis, bool keepDims = false});
```

---

## 3. Prioritized Implementation Task List

| Task ID | Phase | Priority | Description | Verification / Success Criteria |
| :--- | :--- | :--- | :--- | :--- |
| **TNS-01** | Correctness | **P0** | Guard against broadcast target memory aliasing in `Tensor.binaryOperation` ([operation.dart:82-95](../lib/src/tensor/operations/operation.dart#L82-L95)) when target aliases an operand with broadcasting strides. | Add unit test verifying in-place broadcasting into aliased target buffer evaluates without data corruption. |
| **TNS-02** | Performance | **P0** | Add contiguous layout fast-path loops in `binaryOperation` and unary operations to bypass `IndexIterator` when strides are standard. | Benchmark: Contiguous float64 tensor addition achieves 10x-20x throughput improvement. |
| **TNS-03** | Reductions | **P1** | Implement axis reductions (`sum`, `mean`, `min`, `max`, `std`, `var`, `argmin`, `argmax`) with `axis` and `keepDims` options. | Verify correctness against NumPy reference test vectors for 1D, 2D, and 3D tensors. |
| **TNS-04** | Manipulation | **P1** | Implement `concatenate`, `stack`, `split`, `tile`, and `pad` on `Tensor`. | Unit tests for multi-axis stacking and concatenation. |
| **TNS-05** | Linear Alg | **P1** | Implement `matmul` on `Tensor` supporting 2D and batched N-D matrix multiplication. | Test batched multiplication `[B, M, K] x [B, K, N] -> [B, M, N]`. |
| **TNS-06** | Unification | **P2** | Refactor `DenseMatrix` to wrap a 2D `Tensor` layout; eliminate redundant matrix view classes (`TransposedMatrix`, `FlippedMatrix`, `SubMatrix`). | All matrix tests pass; reduced code footprint by >1,500 lines. |
| **TNS-07** | Operators | **P2** | Add `hadamard` to `Matrix` and add vector operations (`outer`, generalized $L_p$ `norm`, `normalized`, `cumsum`, `cumprod`). | Full unit test coverage for new vector and matrix operations. |
| **TNS-08** | Sparse Alg | **P2** | Implement iterative sparse linear solvers (Conjugate Gradient, GMRES) directly on CSR/CSC formats without dense conversion. | Solve $10,000 \times 10,000$ sparse Poisson system in <50ms without OOM. |
