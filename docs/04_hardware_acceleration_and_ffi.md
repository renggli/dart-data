# Subsystem Architecture: Hardware Acceleration & FFI

## 1. Overview & Objective

Linear algebra and tensor computations on large datasets are memory- and compute-intensive. While Dart's AOT and JIT compilers produce efficient machine code, they cannot compete with hand-tuned SIMD vectorization, cache blocking, and multithreading found in production BLAS (Basic Linear Algebra Subprograms) and LAPACK (Linear Algebra Package) libraries such as **OpenBLAS**, **Apple Accelerate**, and **BLIS**.

The primary objective of this subsystem is to provide **transparent hardware acceleration** for common operations (matrix multiplication, linear solves, SVD, eigenvalues, norms, reductions) with:

1. **Zero-Copy Data Transfer**: Operating directly on existing memory buffers without copying data between Dart and native heaps whenever possible.
2. **Open-Source & Native Library Integration**: Using standard open-source libraries (OpenBLAS) and OS-provided frameworks (macOS Accelerate).
3. **Graceful Fallback**: Providing pure-Dart and Dart SIMD (`Float32x4List`) fallbacks when native libraries are unavailable or when running on Dart Web / WebAssembly.

---

## 2. Architectural Design

```text
+-------------------------------------------------------------------------+
|                  High-Level Tensor & Matrix API                         |
|      (Matrix.mulMatrix, Tensor.matmul, SVD, QR, Eigenvalue, Solver)     |
+-------------------------------------------------------------------------+
                                    |
+-------------------------------------------------------------------------+
|                  Acceleration Dispatcher (Router)                       |
|   - Checks hardware availability, data type, dimensions, & layout       |
+-------------------------------------------------------------------------+
            |                                           |
   [Native Library Available]                 [Fallback / Web / Small N]
            |                                           |
+---------------------------+               +---------------------------+
|      BLAS / LAPACK FFI    |               |  Pure Dart / SIMD Engine  |
|  - macOS: Accelerate.fwk  |               |  - Dart SIMD (Float32x4)  |
|  - Linux: libopenblas.so  |               |  - Loop-unrolled fallback |
|  - Windows: openblas.dll  |               +---------------------------+
+---------------------------+
```

### 2.1 Zero-Copy Memory Model

In standard Dart code, typed arrays like `Float64List` reside in the Dart garbage-collected heap. Passing GC-managed memory directly to native code can risk pointer invalidation if garbage collection moves memory during execution.

To achieve true zero-copy without data corruption:

1. **Native-Backed Buffer Option**:
   - For high-performance matrix and tensor workloads, buffers can be allocated in native memory via `calloc` / `malloc` using `dart:ffi`.
   - Dart views these native buffers directly via `Pointer<Double>.asTypedList(length)`, incurring zero overhead in Dart.
   - When calling BLAS (e.g. `cblas_dgemm`), the raw `Pointer` is passed directly to the native function.
   - Memory is freed deterministically via `dispose()` or registered with a `NativeFinalizer` for automatic garbage collection when unreachable.
2. **Contiguous Dart Heap Buffers**:
   - For matrices allocated on the Dart heap (`Float64List`), if the runtime supports leaf FFI calls (`@ffi.Native(isLeaf: true)`), pointers to the typed data memory are passed directly without GC interference during the leaf call.
   - For non-leaf calls or strided views, a tiny temporary scratch buffer is used only if strides are non-contiguous.

### 2.2 BLAS & LAPACK API Binding Scope

The subsystem targets the industry-standard **CBLAS** and **LAPACKE** C interfaces:

#### Level 1 BLAS (Vector Operations)

- `cblas_daxpy` / `cblas_saxpy`: $y \leftarrow \alpha x + y$ (scaled vector addition).
- `cblas_ddot` / `cblas_sdot`: Dot product $x^T y$.
- `cblas_dnrm2` / `cblas_snrm2`: Euclidean ($L_2$) norm $\|x\|_2$.
- `cblas_dscal` / `cblas_sscal`: $x \leftarrow \alpha x$.

#### Level 2 BLAS (Matrix-Vector Operations)

- `cblas_dgemv` / `cblas_sgemv`: $y \leftarrow \alpha A x + \beta y$.
- `cblas_dtrmv` / `cblas_strmv`: Triangular matrix-vector multiply.

#### Level 3 BLAS (Matrix-Matrix Operations)

- `cblas_dgemm` / `cblas_sgemm`: General matrix multiplication $C \leftarrow \alpha A B + \beta C$.
- `cblas_dsymm` / `cblas_ssymm`: Symmetric matrix multiplication.
- `cblas_dtrmm` / `cblas_strmm`: Triangular matrix multiplication.

#### LAPACK (Decompositions & Solvers)

- `LAPACKE_dgesv` / `sgesv`: Linear system solver $A X = B$ via LU decomposition.
- `LAPACKE_dpotrf` / `spotrf`: Cholesky factorization.
- `LAPACKE_dgeqrf` / `sgeqrf`: QR decomposition.
- `LAPACKE_dgesvd` / `sgesvd`: Singular Value Decomposition (SVD).
- `LAPACKE_dsyev` / `ssyev`: Eigenvalues and eigenvectors of symmetric matrices.

### 2.3 Row-Major vs. Column-Major Layout Handling

BLAS historically expects Fortran column-major ordering, whereas Dart multi-dimensional tensors are row-major (C-order).
The CBLAS standard supports both layouts via the `CBLAS_ORDER` parameter:

```c
cblas_dgemm(CblasRowMajor, CblasNoTrans, CblasNoTrans, M, N, K, alpha, A, lda, B, ldb, beta, C, ldc);
```

By utilizing `CblasRowMajor`, `package:data` operates directly on row-major contiguous memory layouts without transposing buffers before or after native calls.

### 2.4 Dynamic Library Discovery & Cross-Platform Support

The FFI loader checks known platform library locations on startup:

```dart
DynamicLibrary? loadBlasLibrary() {
  if (Platform.isMacOS || Platform.isIOS) {
    // macOS Accelerate framework includes full BLAS and LAPACK
    return DynamicLibrary.open(
      '/System/Library/Frameworks/Accelerate.framework/Accelerate',
    );
  } else if (Platform.isLinux || Platform.isAndroid) {
    for (final name in ['libopenblas.so.0', 'libopenblas.so', 'libblas.so.3']) {
      try {
        return DynamicLibrary.open(name);
      } catch (_) {}
    }
  } else if (Platform.isWindows) {
    for (final name in ['openblas.dll', 'libopenblas.dll']) {
      try {
        return DynamicLibrary.open(name);
      } catch (_) {}
    }
  }
  return null;
}
```

### 2.5 SIMD & Pure Dart Fallback

For environments without native binaries (e.g. Flutter Web, WebAssembly, sandboxed systems):

- Vector operations on `Float32List` are accelerated using Dart's native `Float32x4List` and `Float32x4` SIMD types, processing 4 single-precision floats per instruction.
- Matrix multiplication for small dimensions ($N < 64$) routes to an optimized pure-Dart cache-blocked loop ($O(N^3)$ with cache tiling), bypassing native FFI invocation overhead.

---

## 3. Prioritized Implementation Task List

| Task ID | Phase | Priority | Description | Verification / Success Criteria |
| :--- | :--- | :--- | :--- | :--- |
| **HW-01** | FFI Setup | **P0** | Implement dynamic library loader for macOS Accelerate, Linux OpenBLAS, and Windows OpenBLAS with graceful detection. | Tests confirm detection on macOS/Linux/Windows with fallback when library is missing. |
| **HW-02** | Level 3 BLAS | **P0** | Bind `cblas_dgemm` and `cblas_sgemm` for row-major matrix multiplication with zero-copy buffer passing. | Benchmark: $1000 \times 1000$ double matrix multiply executes $\ge 20\times$ faster than pure Dart. |
| **HW-03** | Level 1 & 2 BLAS | **P1** | Bind Level 1 (`dot`, `nrm2`, `axpy`, `scal`) and Level 2 (`gemv`) BLAS functions for float64 and float32. | Unit test accuracy matches Dart reference implementation within $10^{-12}$. |
| **HW-04** | LAPACK Solvers | **P1** | Bind LAPACK `dgesv` (linear solver) and `dpotrf` (Cholesky factorization) with automatic fallback. | Solve $500 \times 500$ linear system in $<10$ ms. |
| **HW-05** | LAPACK SVD & QR | **P1** | Bind LAPACK `dgesvd` (SVD) and `dgeqrf` (QR decomposition). | Accurately reconstruct matrices: $\|A - U \Sigma V^T\| < 10^{-12}$. |
| **HW-06** | Native Memory | **P2** | Implement `NativeTensor` / `NativeMatrix` allocating via `calloc` and using `NativeFinalizer` for zero-overhead FFI interoperability. | Verify zero copies during repeated matrix multiplications. |
| **HW-07** | Dart SIMD | **P2** | Implement SIMD fast-path for `Float32List` using `Float32x4List` for element-wise addition, multiplication, and dot products on Web/non-FFI platforms. | Benchmark: Web/non-FFI float32 vector ops achieve $3\times$ speedup over scalar loops. |
