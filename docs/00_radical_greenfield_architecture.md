# Radical Greenfield Architecture: Zero-Backward-Compatibility Design

## 1. Executive Summary

This document presents a comprehensive, unconstrained redesign of `package:data` assuming **zero requirement for backward compatibility**. The objective is to design the cleanest, fastest, and most ergonomic scientific computing ecosystem for Dart 3.5+.

---

## 2. Core Paradigm Shifts

```text
========================================================================================
                          RADICAL GREENFIELD SYSTEM TOPOLOGY
========================================================================================

┌──────────────────────────────────────────────────────────────────────────────────────┐
│                                   Application Layer                                  │
│         DataFrame (Arrow Table)  │  Symbolic Expressions  │  Stats & Distributions   │
└───────────────────────────────────────────┬──────────────────────────────────────────┘
                                            │
┌───────────────────────────────────────────┴──────────────────────────────────────────┐
│                           Linear Algebra & Operator Layer                            │
│             LinearOperator<T> (Abstract contract: y = Ax, solve, shape)              │
│             ├─ Dense Tensor 2D View / BLAS GEMM                                      │
│             └─ Sparse Compressed Matrix (CsrMatrix, CscMatrix, CooMatrix)            │
└───────────────────────────────────────────┬──────────────────────────────────────────┘
                                            │
┌───────────────────────────────────────────┴──────────────────────────────────────────┐
│                               Unified Core: Tensor<T>                                │
│   - Flat MemoryBuffer<T> (Dart TypedData or Native C FFI Pointer with Finalizer)     │
│   - StrideLayout (rank, shape, strides, offset, isContiguous)                        │
│   - Zero-copy structural views: slice, transpose, reshape, broadcast, flip           │
│   - Strictly eager arithmetic operations (+, -, *, matmul, reductions)               │
└───────────────────────────────────────────┬──────────────────────────────────────────┘
                                            │
┌───────────────────────────────────────────┴──────────────────────────────────────────┐
│                              Type & Acceleration Core                                │
│   - Sealed DType token enum (DType.float64, DType.int32, DType.complex128)           │
│   - Complete AlgebraicField<T> (with abs, norm, sqrt, pow, exp, log, conjugate)      │
│   - Hardware Dispatcher: CBLAS / LAPACKE FFI -> Dart SIMD -> Contiguous Loops        │
└──────────────────────────────────────────────────────────────────────────────────────┘
```

### 2.1 Abolish the Scalar Lazy Arithmetic Anti-Pattern
- **Prior Flaw**: Arithmetic operations on `Matrix` and `Vector` returned lazy view classes (`MatrixMatrixMultiplicationMatrix`, `BinaryOperationMatrix`, `ConvolutionMatrix`), computing products or virtual closures on *every single scalar read*, causing megamorphic call sites and exponential recalculation.
- **Greenfield Rule**:
  - **Structural transformations** (slicing, transposition, reshaping, flipping, axis expansion/broadcasting) remain $O(1)$ zero-copy views on strided layouts.
  - **Arithmetic operations** (`+`, `-`, `*`, `matmul`, decompositions) are **strictly eager**, evaluating into contiguous target buffers.
  - Multi-operation fusion (e.g. $D = \alpha AB + \beta C$) is achieved via explicit target buffer arguments (`gemm(A, B, target: C)`) or the compiled **Symbolic Engine** (`docs/08_symbolic.md`), never via scalar per-read lazy views.

### 2.2 Unify Containers: One Multi-Dimensional Core (`Tensor<T>`)
- **Prior Flaw**: Three parallel, divergent container hierarchies (`Tensor`, `Matrix`, `Vector`) with 45+ specialized view classes and 10 separate matrix storage layouts.
- **Greenfield Design**:
  - **Single Dense Container**: `Tensor<T>` backed by flat typed memory and an $N$-dimensional `StrideLayout`.
  - **Zero-Cost 1D/2D Views**: `Vector<T>` and `Matrix<T>` are thin views over rank-1 and rank-2 tensors.
  - **Sparse Linear Algebra**: Compressed Sparse Row (`CsrMatrix<T>`), Compressed Sparse Column (`CscMatrix<T>`), and Coordinate List (`CooMatrix<T>`) share a common `abstract interface class LinearOperator<T>` with dense matrices, allowing solvers (Conjugate Gradient, GMRES) to operate polymorphically across dense and sparse representations.
  - **Purge 45+ View Classes**: Slicing, transposing, flipping, diagonals, and blocks are handled natively by `StrideLayout`.

### 2.3 Overhaul the Type System
- **Prior Flaw**: Heavyweight `DataType<T>` class hierarchy with type precision erasure (`Float32` and `Float64` both being `DataType<double>`), monolithic `Field<T>` lacking square roots and norms, and mutable global static variables (`DataType.index = uint32;`).
- **Greenfield Design**:
  - **Sealed `DType` Enum**: `enum DType { float32, float64, int32, int64, complex64, complex128, boolean }`.
  - **Complete Algebraic Stratification**: `Field<T>` includes `abs`, `norm`, `sqrt`, `pow`, `exp`, `log`, and `conjugate`. Matrix decompositions (QR, SVD, Cholesky) are written generically over any `Field<T>` without hardcoding to `double`.
  - **Zero Mutable Globals**: Default configurations are immutable compile-time constants or scoped via `Zone`.
  - **Safe Memory Aliasing**: The defunct `Storage` interface is replaced by `MemoryBuffer<T>` with buffer identity and overlap detection, eliminating silent data corruption in operations like `m.transpose().copyInto(m)`.

### 2.4 Native-Aligned Columnar Tabular Data (`DataFrame`)
- **Apache Arrow RecordBatch Compliance**: `Series<T>` stores raw contiguous typed lists (`Float64List`, `Int32List`) with an Arrow-compatible `Uint8List` validity bitmask (1 bit per entry, zero boxing for nullables).
- **Arrow C Data Interface**: Seamless zero-copy data exchange with Python (Polars/pandas) and DuckDB using pure `dart:ffi` structs without C compilers.
- **Relational Operations**: Hash-partitioned `groupBy`, joins (inner, left, outer), filtering, and instant conversion to 2D `Tensor<double>` for machine learning pipelines.

### 2.5 Integrated Symbolic Evaluation Engine
- **Exact Mathematics**: Full expression AST (`Expr`) with analytical differentiation (`diff`), canonical simplification, Taylor expansions, and LaTeX output.
- **Zero-Allocation JIT Compiler**: Compiles symbolic graphs into positional closures and fused tensor kernels executing contiguous buffer loops with zero heap allocation.

---

## 3. Subsystem Comparison: Legacy vs. Greenfield

| Dimension | Legacy Architecture | Greenfield Architecture |
| :--- | :--- | :--- |
| **Containers** | 3 divergent types (`Tensor`, `Matrix`, `Vector`) | Unified `Tensor<T>` core; `LinearOperator<T>` interface |
| **Evaluation Model** | Scalar lazy views with exponential read overhead | Strictly eager arithmetic; zero-copy structural layouts; compiled symbolic graphs |
| **View Classes** | >45 redundant wrapper classes in `view/` | Single unified `StrideLayout` (<5 classes) |
| **Sparse Storage** | 10 separate storage classes | 3 canonical formats (`CSR`, `CSC`, `COO`) implementing `LinearOperator` |
| **Hardware FFI** | None (pure Dart scalar loops) | Transparent CBLAS/LAPACKE dispatch + SIMD fallback |
| **Type System** | Monolithic `Field`, precision erasure, mutable statics | Stratified algebraic interfaces, sealed `DType`, immutable defaults |
| **Tabular Data** | None | Columnar `DataFrame` (Arrow-compliant, validity bitmask, zero-copy joins) |
| **Symbolic Math** | None | Symbolic AST, exact differentiation, and positional JIT compiler |

---

## 4. Prioritized Greenfield Roadmap

| Phase | Priority | Milestones |
| :--- | :--- | :--- |
| **Phase 1** | **P0** | Implement unified `Tensor<T>` with `MemoryBuffer<T>` (overlap detection) and `StrideLayout`. Purge all scalar lazy view classes. |
| **Phase 2** | **P0** | Stratify algebraic fields (`Field`, `RealField`, `ComplexField`). Implement sealed `DType`. Make all defaults `const`. |
| **Phase 3** | **P1** | Implement `LinearOperator<T>` contract. Build `CsrMatrix`, `CscMatrix`, and `CooMatrix` with Conjugate Gradient and GMRES solvers. |
| **Phase 4** | **P1** | Implement transparent CBLAS (`dgemm`) and LAPACK (`dgesv`, `dpotrf`, `dgeqrf`, `dgesvd`) hardware FFI dispatcher. |
| **Phase 5** | **P1** | Implement `DataFrame` with Arrow validity bitmasks, dictionary string encoding, and streaming CSV parser. |
| **Phase 6** | **P2** | Implement `Symbolic` subsystem: AST, exact differentiation, canonical simplifier, and positional tensor loop compiler. |
| **Phase 7** | **P2** | Modernize `numeric` (optimization, ODEs, splines) and `stats` (hypothesis testing, empirical quantiles, distributions). |
