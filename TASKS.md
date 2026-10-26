# Actionable Code Review & Improvement Task List

This document provides a comprehensive, step-by-step execution plan derived from an in-depth review of `lib/` and `web/`. Tasks are organized by subsystem and ordered by priority so an agent can execute and verify each task sequentially.

## Execution Protocol for Agents

1. **Isolate & Test First**: Before modifying implementation files for any bug or edge-case task, add or update the corresponding unit test in `test/` (maintaining the 1:1 mirror with `lib/src/`) using `package:checks`. Do not maintain backward compatibility; rewrite and simplify existing code directly for maximum clarity and cleanliness.
2. **Verify Continuously (VM & JS)**: After completing each task or section, run `dart analyze` and execute the relevant unit tests (including `accelerationTest` across `auto`, `dart`, and `accelerated` modes where applicable) on both the Dart VM (`dart test`) and JavaScript (`dart test -p node` or `-p chrome`).
3. **Keep Documentation & Specifications Synchronized**: Update triple-slash (`///`) API doc comments, `README.md`, `AGENTS.md`, and `ARCHITECTURE.md` whenever behavior, contracts, or public symbols change.
4. **Formatting, Dependency DAG & Atomic Commits**: Run `dart format .` and `dart test test/deps_test.dart` before marking a section complete. Commit each completed section with a clean message describing what was fixed or improved (do not reference task IDs like `TASK-1.1` in commit messages).

---

## Phase 1: `type` & `tensor` Subsystems (`lib/type.dart`, `lib/tensor.dart`)

### [ ] TASK-1.1 (`High`): Fix `Tensor.copy()` on contiguous slices and `Tensor.filled` default shape

- **Files**: `lib/src/tensor/tensor.dart` (lines 44–55, 262–270), `lib/src/tensor/layout.dart` (lines 58–60), `test/tensor/tensor_test.dart`
- **Problem**:
  1. `Tensor.copy()` (lines 262–270) checks `if (layout.isContiguous)` and returns `Tensor<T>.internal(type: type, layout: layout, data: type.copyList(data))`. When a tensor is a contiguous slice (e.g., `matrix.subMatrix(1, 3, 0, 2)` or `vector.subVector(2, 5)`), `layout.isContiguous` is `true` while `layout.offset > 0` and `data.length > layout.length`. Consequently, `.copy()` copies the entire parent buffer and preserves a non-zero `layout.offset`, causing downstream consumers (`LUDecomposition`, `QRDecomposition`, `CholeskyDecomposition`, `EigenvalueDecomposition`) that read `copy().tensor.data` at index `0` to read the wrong memory!
  2. `Tensor.filled(value)` without `shape` calls `Layout(shape: null)`, which sets `rank = 0` and `length = 0`, allocating a 0-length `data` buffer that crashes with `RangeError` on `getValue([])`.
- **Action**:
  1. In `Tensor.copy()`, when `layout.isContiguous`, copy only the active range `[layout.offset, layout.offset + layout.length)` into a fresh buffer of length `layout.length` and construct a canonical `Layout(shape: layout.shape)` with `offset: 0`.
  2. In `Layout(...)` (`lib/src/tensor/layout.dart:58–60`), treat `shape == null` identically to `const <int>[]` so a rank-0 scalar layout always has `length == 1`.
  3. Add regression tests in `test/tensor/tensor_test.dart` for `Tensor.filled(42).getValue([])` and `subVector`/`subMatrix` `.copy()` verifying `copy.offset == 0` and `copy.data.length == copy.length`.

### [ ] TASK-1.2 (`High`): Fix aliasing hazard detection on `TypedData.sublistView` in `Tensor` operations

- **Files**: `lib/src/tensor/operations/operation.dart` (lines 51–54, 127–140, 180–192), `lib/src/type/utils/memory.dart` (lines 6–56), `test/tensor/operations/operation_test.dart`
- **Problem**:
  1. In `unaryOperation`, `binaryOperation`, and `hasHazardFor`, when `sharesMemory(target.data, sourceData)` is `true`, the code assumes in-place execution is safe if `target.layout.offset == source.layout.offset` and strides match. However, if `target.data` and `source.data` are two distinct `Float64List.sublistView`s of the same `ByteBuffer` (e.g., `sublistView(buf, 0, 4)` and `sublistView(buf, 1, 5)`), both have `layout.offset == 0` and `strides == [1]`, so the hazard check falsely skips buffering and corrupts the output.
  2. In `lib/src/type/utils/memory.dart`, `_viewInfo` does not unwrap `NullableList` or `UnmodifiableFloat64ComplexList`, returning `false` for `sharesMemory` and `hasOverlap`.
- **Action**:
  1. In `lib/src/tensor/operations/operation.dart`, only allow unbuffered in-place execution when `identical(targetData, sourceData)` (or when their underlying byte offsets also match) in addition to `target.layout.offset == source.layout.offset`.
  2. In `lib/src/type/utils/memory.dart`, unwrap `NullableList` and `UnmodifiableFloat64ComplexList` inside `_viewInfo`.
  3. Add unit tests with overlapping `Float64List.sublistView` tensors and `NullableList`-backed tensors.

### [ ] TASK-1.3 (`High`): Fix `Layout.reshape`, `Layout.flip`, and `Layout.transpose` edge cases

- **Files**: `lib/src/tensor/layout.dart` (lines 207–280), `test/tensor/layout_test.dart`
- **Problem**:
  1. `Layout.reshape` (line 251): Reshaping an empty tensor (`length == 0`, e.g. `shape: [0, 4]`) with `-1` (e.g. `[0, -1]`) computes `newLength = 0` and evaluates `length % newLength`, throwing `IntegerDivisionByZeroException` instead of `ArgumentError`.
  2. `Layout.flip` (line 274): When `dim == 0` (e.g. `shape: [0, 3]`), `newOffset = offset + (dim - 1) * strides[normAxis]` produces a negative `offset`.
  3. `Layout.transpose` (line 214): Rejects negative axis indices (`axis < 0`), whereas all other `Layout` and `Tensor` methods normalize `axis < 0 ? axis + rank : axis`.
- **Action**:
  1. In `Layout.reshape`, check `if (newLength == 0) throw ArgumentError.value(newShape, 'newShape', 'Cannot infer dimension (-1) when another dimension is 0');` before `length % newLength`.
  2. In `Layout.flip`, return `this` early when `dim <= 1`.
  3. In `Layout.transpose`, normalize negative axes via `final normAxis = axis < 0 ? axis + rank : axis;` before bounds checking.
  4. Add unit tests in `test/tensor/layout_test.dart`.

### [ ] TASK-1.4 (`Medium`): Fix `ReductionTensorExtension` and `ManipulationTensorExtension` validation bugs

- **Files**: `lib/src/tensor/operations/reduction.dart` (lines 32–35, 55–65, 115–132, 232–277, 314–358), `lib/src/tensor/operations/manipulation.dart` (lines 87–188), `test/tensor/operations/reduction_test.dart`, `test/tensor/operations/manipulation_test.dart`
- **Problem**:
  1. `sum`, `mean`, `variance`, `min`, and `max` do not validate that a caller-supplied `target.layout.shape` matches `outShape`.
  2. `mean` and `variance` index `layout.shape[axis < 0 ? axis + rank : axis]` before validating `axis`, throwing a raw list `RangeError` instead of `RangeError.range(axis, -rank, rank - 1, 'axis')`, and cast `(value as num).toDouble()` which fails on `Tensor<Complex>` / `Tensor<Fraction>`.
  3. `argmin` and `argmax` with `axis != null` throw `RangeError` instead of `StateError` when the reduced axis has length `0`.
  4. `stackAll` does not verify that all input tensors have matching `shape`s (unlike `concatenateAll`).
  5. `pad` and `tile` do not validate `padding[i].length == 2`, `padding[i][0] >= 0 && padding[i][1] >= 0`, or `reps[i] >= 0`.
- **Action**:
  1. Validate `target` shape in `sum` and `_reduceAxis`, normalize/check `axis` before indexing `layout.shape` in `mean` and `variance`, use `type.field.scale(sum, 1.0 / count)` for non-`num` field types, and throw `StateError` when `axisLen == 0` in `argmin`/`argmax`.
  2. Validate matching shapes in `stackAll` and non-negative parameters in `pad` and `tile`.
  3. Add unit tests covering each validation case.

### [ ] TASK-1.5 (`Medium`): Complete `Float64Tensor` `@redeclare` views and `Float64List` binary fast paths

- **Files**: `lib/src/tensor/float64_tensor.dart` (lines 1–240), `test/tensor/float64_tensor_test.dart`
- **Problem**:
  1. Calling `tensor[i]`, `tensor.flip()`, `tensor.getRange(...)`, `tensor.slice(...)`, or `tensor.copy()` on a `Float64Tensor` returns a boxed `Tensor<double>` instead of `Float64Tensor`.
  2. `Float64Tensor` lacks a `Float64Tensor.fromObject` factory.
  3. In `Float64Tensor.operator +`, `-`, `*`, `/`, `final b = other.data;` is typed as `List<double>`, missing unboxed `Float64List` indexing when `b is Float64List`.
- **Action**:
  1. Add `@redeclare` methods on `Float64Tensor` for `operator []`, `flip`, `getRange`, `slice`, and `copy`, plus `Float64Tensor.fromObject`.
  2. Specialize the contiguous loops in `operator +`, `-`, `*`, `/` when `other.data` is `Float64List`.
  3. Add unit tests in `test/tensor/float64_tensor_test.dart`.

### [ ] TASK-1.6 (`High`): Fix `DataType` bugs (`fromType`, integer bounds/casting, `IntegerField.pow`, `promoteWith`, `NullableDataType`)

- **Files**: `lib/src/type/utils/derive.dart` (lines 7–8), `lib/src/type/types/integer.dart` (lines 61–78, 241, 286, 360), `lib/src/type/types/bigint.dart` (lines 48–52, 82–86), `lib/src/type/types/fraction.dart` (lines 130–136), `lib/src/type/data_type.dart` (lines 156, 219–273), `lib/src/type/types/nullable.dart` (lines 15, 78–84), `lib/src/type/types/complex.dart` (line 282), `lib/src/type/models/field.dart` (lines 58–106), `test/type/data_type_test.dart`
- **Problem**:
  1. `DataType.fromType<T>()` evaluates `ObjectDataType<T>(null as T)`, throwing a `TypeError` for any non-nullable custom type `T` where `null is! T`.
  2. `SafeIntDataType.bits` is `53`, so `SafeIntDataType.cast(9007199254740991)` calls `.toSigned(53)` and wraps `max` (`2^53 - 1`, which requires 54 signed bits) to `-1`!
  3. `Uint64DataType.max` (`4294967296 * 4294967296 - 1`) overflows 64-bit signed `int` on Dart VM to `-1` (`max < min`).
  4. `IntegerDataType.cast(String)` returns `int.tryParse(value)` without applying `isSigned ? parsed.toSigned(bits) : parsed.toUnsigned(bits)`.
  5. `IntegerField.pow` uses `math.pow(base, exponent).truncate()`, losing precision above $2^{53}$, crashing on overflow (`Infinity.truncate()`), and returning `0` on negative exponents instead of throwing `RangeError` like `BigIntField.pow`.
  6. `BigIntField.scale` converts `int` factors via `factor.toDouble()`, losing precision for 64-bit integers $> 2^{53}$.
  7. `FractionField.nan` and `infinity` throw `IntegerDivisionByZeroException` instead of `UnsupportedError`.
  8. `DataType.promoteWith` returns `float32` for `float32.promoteWith(string)` and does not handle `fraction`, `quaternion`, `numeric`, or `NullableDataType`.
  9. `NullableDataType.==` and `hashCode` ignore `nullsFirst`.
  10. `ExtendedField<T>` redeclares the exact same 6 methods (`abs`, `norm`, `sqrt`, `exp`, `log`, `conjugate`) already on `Field<T>`.
  11. Private fields `_comparator` in `NullableDataType` and `_source` in `UnmodifiableFloat64ComplexList` are placed before public members; `DataType.equality` uses non-const `NaturalEquality<T>()`.
- **Action**:
  1. Fix `SafeIntDataType.cast` (clamp or wrap to 54 signed bits / `[-max, max]`), fix `IntegerDataType.cast(String)` bit wrapping, implement exact exponentiation by squaring in `IntegerField.pow` (throwing `RangeError` for `exponent < 0`), check `if (factor is int)` in `BigIntField.scale`, and throw `UnsupportedError` in `FractionField.nan`/`infinity`.
  2. Fix `DataType.promoteWith` to handle `NullableDataType`, `fraction`, `quaternion`, `numeric`, and non-numeric fallbacks to `DataType.object`.
  3. Include `nullsFirst` in `NullableDataType.==` and `hashCode`.
  4. Clean up `ExtendedField<T>` redundancy, member ordering, `const NaturalEquality<T>()`, and replace `dynamic` parameter types in `cast(Object? value)` where appropriate.
  5. Add unit tests in `test/type/data_type_test.dart`.

---

## Phase 2: `acceleration` & `linear` Subsystems (`lib/acceleration.dart`, `lib/linear.dart`)

### [ ] TASK-2.1 (`High`): Fix `FftNative` FFTW3 alignment flag (`FFTW_UNALIGNED`) and `AccelerationMode.accelerated` contract

- **Files**: `lib/src/acceleration/fft/fft_native.dart` (lines 17, 102–114, 150–151, 250–315), `test/acceleration/fft/fft_test.dart`
- **Problem**:
  1. `_getOrCreateFftwPlan1d` and `_getOrCreateFftwPlan2d` create cached plans with `ffi.nullptr` and `flags = _fftwEstimate` (`1 << 6`), then execute them via `fftw_execute_dft` on arbitrary Dart `Float64List` buffers (including `sublistView`s at odd 8-byte offsets). Without `FFTW_UNALIGNED` (`1 << 1`), FFTW assumes SIMD alignment when planning with `NULL` pointers, risking a hardware SIGSEGV on unaligned `Float64List` views.
  2. When `setup == null` or `plan == null` (or `log2n < 3` on vDSP), `FftNative` calls `FftDart` and returns `true`, violating the `Dispatcher` contract that `AccelerationMode.accelerated` must throw `AccelerationError` if native execution does not occur.
- **Action**:
  1. Add `const int _fftwUnaligned = 1 << 1;` and pass `_fftwEstimate | _fftwUnaligned` to `fftw_plan_dft_1d` and `fftw_plan_dft_2d`.
  2. Return `false` from `FftNative` when native library/plan creation fails, and support `log2n in 1..2` in vDSP (or handle trivial `n <= 1` uniformly).
  3. Add unit tests in `test/acceleration/fft/fft_test.dart` using odd-offset `Float64ComplexList` views.

### [ ] TASK-2.2 (`High`): Fix `Blas` and `Lapack` validation, negative-stride, `alpha == 0`, `dgels` mutation, and `LapackDart` `NaN`/convergence bugs

- **Files**: `lib/src/acceleration/blas/blas_validation.dart` (lines 83–98), `lib/src/acceleration/blas/blas_native.dart` (lines 78–198, 237–250, 303, 338, 545–612), `lib/src/acceleration/blas/blas_dart.dart` (lines 63–91, 146–277, 311, 354, 745–1073), `lib/src/acceleration/lapack/lapack.dart` (lines 20–265), `lib/src/acceleration/lapack/lapack_native.dart` (lines 250–261), `lib/src/acceleration/lapack/lapack_dart.dart` (lines 26, 95, 234, 313, 482–525), `test/acceleration/blas/blas_test.dart`, `test/acceleration/lapack/lapack_test.dart`
- **Problem**:
  1. `checkBlasMatrixBounds` does not check `if (offset < 0)`, and `Lapack` routines do not call `checkBlasOffset` or validate `wOffset` in `dsyev`/`ssyev`.
  2. `BlasNative.dgemv` and `sgemv` crash with `RangeError` when `m == 0 || n == 0` and `incY < 0` because they index `yOffset + i * incY` instead of starting at `startY = yOffset + (incY < 0 ? (1 - lenY) * incY : 0)`.
  3. `BlasDart.dnrm2`, `snrm2`, `dscal`, `sscal` process vectors when `incX < 0`, whereas CBLAS (`BlasNative`) treats `incX <= 0` in 1-vector routines as a no-op / `0.0`.
  4. `BlasDart.dgemv`, `sgemv`, `dsyrk`, `ssyrk`, `dsymm`, `ssymm`, `dtrmm`, `strmm` do not short-circuit when `alpha == 0.0`, producing `NaN` if `A`, `B`, or `x` contains `NaN`/`Infinity`.
  5. `LapackNative.dgels` mutates input `a` in-place on Linux/Windows (`_hasLapackeDgels`), whereas macOS (`_hasDgels`) and `LapackDart.dgels` copy `a` and leave `a` unmodified.
  6. `LapackDart.dpotrf`, `dgesv`, and `dgels` use `val <= 0.0` / `maxVal == 0.0` / `abs() < tol`, which evaluate to `false` on `NaN` and return `true` (success) instead of `false`; `LapackDart.dsyev` has no iteration limit on its QL loop.
- **Action**:
  1. Add `checkBlasOffset(offset, length, name)` to `checkBlasMatrixBounds` and validate `wOffset` in `Lapack.dsyev` / `Lapack.ssyev`.
  2. Fix `startY` for `incY < 0` in `BlasNative.dgemv`/`sgemv`, align `incX < 0` semantics between `BlasDart` and `BlasNative`, and short-circuit `alpha == 0.0` in all `BlasDart` routines.
  3. Copy `a` before calling `_lapackeDgels` in `LapackNative.dgels` so `a` is never unexpectedly clobbered on any platform.
  4. Use `NaN`-safe pivot checks (`!(val > 0.0)`, `!(maxVal > 0.0)`, `!(abs >= tol)`) in `LapackDart` and add a 30-iteration limit per eigenvalue in `LapackDart.dsyev`.
  5. Add unit tests across `auto`, `dart`, and `accelerated` modes.

### [ ] TASK-2.3 (`High`): Fix `Matrix` underdetermined complex solver, 0-dimension matrix crashes, and `Float32List` decomposition casts

- **Files**: `lib/src/linear/matrix.dart` (lines 405–431, 488, 538, 628, 678, 781–851), `lib/src/linear/float64_matrix.dart` (lines 173–183, 237–249, 287–298), `lib/src/linear/decomposition/lu.dart` (lines 65–70, 200), `lib/src/linear/decomposition/qr.dart` (lines 67–72, 128, 194, 257), `lib/src/linear/decomposition/cholesky.dart` (line 128), `test/linear/matrix_test.dart`, `test/linear/decomposition/lu_test.dart`, `test/linear/decomposition/qr_test.dart`
- **Problem**:
  1. `Matrix._solveUnderdeterminedVector` and `_solveUnderdeterminedMatrix` (lines 781–851) compute the QR decomposition of `transposed` ($A^T$) instead of `conjugateTranspose` ($A^*$) and omit `field.conjugate(...)` when solving $R^* y = b$, producing wrong solutions for complex underdetermined systems.
  2. `Matrix.solve`, `Matrix.solveVector`, `Float64Matrix.operator *`, and `Float64Matrix.apply` pass `lda: 0` or `ldb: 0` to `Blas`/`Lapack` on 0-dimension matrices (`0x0`, `Mx0`, `0xN`), throwing `ArgumentError: Leading dimension must be >= 1, got 0`.
  3. `LUDecomposition` and `QRDecomposition` check `if (_lu is Matrix<double>)` and then cast `_lu.tensor.data as Float64List`, which crashes with `TypeError` when given a `Matrix<double>` backed by `DataType.float32` (`Float32List`).
  4. `Float64Matrix.row` and `Float64Matrix.col` reject negative indices (`-1`), unlike `Matrix.row` and `Matrix.col`.
  5. `Matrix.solveVector` (lines 405–431) has a duplicate copy-pasted doc comment above its actual doc comment.
- **Action**:
  1. Replace `transposed` with `conjugateTranspose` and conjugate `rMat` entries in `_solveUnderdeterminedVector` and `_solveUnderdeterminedMatrix`.
  2. Handle `rowCount == 0 || colCount == 0 || nrhs == 0` early in `Matrix.solve`, `Matrix.solveVector`, `Float64Matrix.operator *`, and `Float64Matrix.apply`.
  3. Guard `LUDecomposition` and `QRDecomposition` fast paths with `.tensor.data is Float64List` (matching `CholeskyDecomposition`).
  4. Support negative row/column indices in `Float64Matrix.row` and `Float64Matrix.col`, and remove the duplicate doc comment on `Matrix.solveVector`.
  5. Add unit tests for complex underdetermined solves, empty matrices, `DataType.float32` decompositions, and negative row/col indexing on `Float64Matrix`.

### [ ] TASK-2.4 (`High`): Fix `CooMatrix`, `CsrMatrix`, `CscMatrix` duplicate coordinate coalescing and `solveIterative` / `EigenvalueDecomposition` convergence guards

- **Files**: `lib/src/linear/sparse/coo_matrix.dart` (lines 126–274), `lib/src/linear/sparse/csr_matrix.dart` (lines 73–86, 230–245), `lib/src/linear/sparse/csc_matrix.dart` (lines 72–85, 217–232), `lib/src/linear/solvers/iterative.dart` (lines 70–165), `lib/src/linear/decomposition/eigenvalue.dart` (lines 333, 472), `lib/src/linear/decomposition/svd.dart` (lines 133, 376–390), `test/linear/sparse/sparse_test.dart`, `test/linear/solvers/iterative_test.dart`
- **Problem**:
  1. `CooMatrix` documents that duplicate `(row, col)` entries are summed, which `apply` does, but `CooMatrix.get` returns only the first matching entry, `CooMatrix.toDense()` overwrites with the last matching entry, and `toCsr()` / `toCsc()` sort entries without coalescing duplicates—producing invalid CSR/CSC matrices with duplicate column/row indices!
  2. `solveIterative` with `IterativeMethod.gmres` enters an infinite loop when `restart <= 0`, and neither CG nor GMRES validates `x0.length == b.length`.
  3. `EigenvalueDecomposition._tql2` and `_hqr2` lack maximum iteration guards.
  4. `SingularValueDecomposition` lacks `solve(Matrix<num> b, {double? tolerance})` (present on `LUDecomposition`, `QRDecomposition`, `CholeskyDecomposition`) and has dead `rVal = stemp[i] / tVal` (`1.0`) scaling loops in `_computeSvd` cases 1 and 2.
- **Action**:
  1. Sum duplicate `(row, col)` entries in `CooMatrix.get`, `CooMatrix.toDense`, `CooMatrix.toCsr`, `CooMatrix.toCsc`, `CsrMatrix.fromCoo`, and `CscMatrix.fromCoo`.
  2. Validate `restart >= 1` and `x0.length == b.length` in `solveIterative`.
  3. Add iteration limits (`30 * nn`) to `_tql2` and `_hqr2` in `EigenvalueDecomposition`.
  4. Add `Matrix<double> solve(Matrix<num> b, {double? tolerance})` to `SingularValueDecomposition` and remove dead scaling blocks in `_computeSvd`.
  5. Add unit tests for duplicate COO entries, `solveIterative` validation, and `SingularValueDecomposition.solve`.

### [ ] TASK-2.5 (`Medium`): Support non-zero `offset` in `Float64Vector` & `Float64Matrix` fast paths and deduplicate `_extractContiguousFloat64`

- **Files**: `lib/src/linear/float64_vector.dart` (lines 183–357), `lib/src/linear/float64_matrix.dart` (lines 229–432), `lib/src/linear/matrix.dart` (lines 1196–1215), `lib/src/linear/decomposition/norm.dart` (lines 221–244), `lib/src/linear/solvers/tridiagonal.dart` (lines 116–134)
- **Problem**:
  1. `Float64Vector` and `Float64Matrix` require `tA.offset == 0 && tB.offset == 0` in all arithmetic and BLAS fast paths, forcing contiguous row views (`matrix[r]`), `subVector`, and `subMatrix` onto the slow boxed `Tensor` path.
  2. `_extractContiguousFloat64` / `_asFloat64List` is duplicated across `matrix.dart`, `norm.dart`, and `tridiagonal.dart`.
- **Action**:
  1. Use `tA.offset` and `tB.offset` directly in `Float64Vector` and `Float64Matrix` loops and `Blas` calls (`aOffset`, `bOffset`, `xOffset`).
  2. Consolidate `_extractContiguousFloat64` into a single shared helper in `lib/src/linear/`.

---

## Phase 3: `special`, `polynomial`, & `numeric` Subsystems (`lib/special.dart`, `lib/polynomial.dart`, `lib/numeric.dart`)

### [ ] TASK-3.1 (`High`): Fix `special` functions edge cases (`Bessel`, `Beta`, `Gamma`, `Hypergeometric`, `LambertW`)

- **Files**: `lib/src/special/bessel.dart` (lines 21–102, 232–374), `lib/src/special/beta.dart` (lines 17, 37, 51, 85, 195), `lib/src/special/gamma.dart` (lines 84, 126, 145, 222, 260, 290), `lib/src/special/hypergeometric.dart` (lines 10–35, 51–80), `lib/src/special/lambert_w.dart` (lines 46–50), `lib/src/special/erf.dart` (line 214), `lib/special.dart`, `test/special/bessel_test.dart`, `test/special/beta_test.dart`, `test/special/gamma_test.dart`, `test/special/hypergeometric_test.dart`, `test/special/lambert_w_test.dart`
- **Problem**:
  1. `besselI0`, `besselI1`, `besselJ0`, `besselJ1`, `besselY0`, `besselY1` return `NaN` at `±double.infinity` instead of their mathematical limits ($I_0(\pm\infty) = +\infty$, $I_1(\pm\infty) = \pm\infty$, $J_\nu(\pm\infty) = 0$, $Y_\nu(+\infty) = 0$). Also `besselJ1` and `besselY1` (lines 271, 367) use a 10-digit truncated literal `2.356194491` for $3\pi/4$ instead of `2.356194490192345`.
  2. `beta`, `betaLn`, `ibeta`, `ibetaInv`, `gammaq`, `lowRegGamma`, `combination`, and `permutation` throw `UnsupportedError: Infinity or NaN toInt` when `NaN` or `Infinity` inputs reach `.ceil()` or `BigInt.from(total)`, and `ibetaInv` clamps out-of-range `probability` instead of returning `double.nan`.
  3. `gammapInv` uses `epsilon = 1.0e-8` and only 12 iterations, limiting quantile precision for `Gamma`, `ChiSquared`, and `InverseGamma` distributions to ~8 digits.
  4. `hypergeometric1F1` and `hypergeometric2F1` reject terminating polynomial cases when $a$ or $b$ is a non-positive integer, and `hypergeometric2F1` fails to converge for large negative $z < -9$ when $b - a \in \mathbb{Z}$.
  5. `lambertW0` lacks the `if (w1.abs() < 1.0e-15) break;` guard (present in `lambertW1` at line 97), dividing by zero at the branch point $z = -1/e$.
- **Action**:
  1. Add `isInfinite` guards and full-precision `_threePiOver4 = 2.356194490192345` in `bessel.dart`.
  2. Add `isNaN` / domain guards and capped `maxIter` in `beta.dart` and `gamma.dart`, and tighten `gammapInv` to `1.0e-14` with up to 50 Halley/Newton steps.
  3. Handle terminating polynomial cases ($a \in \mathbb{Z}_{\le 0}$ or $b \in \mathbb{Z}_{\le 0}$) first in `hypergeometric1F1` and `hypergeometric2F1`.
  4. Add `if (w1.abs() < 1.0e-15) break;` in `lambertW0`.
  5. Add unit tests for all edge cases.

### [ ] TASK-3.2 (`High`): Fix `Polynomial` and `RationalFunction` bugs (`fromRoots`, `gcd`, `evaluateComplex`, `integrate` exactness, `CompressedPolynomial.compose`, `RationalFunction.hashCode`, `OrthogonalFamily`)

- **Files**: `lib/src/polynomial/polynomial.dart` (lines 94, 192–209), `lib/src/polynomial/impl/dense_polynomial.dart` (lines 82–102, 169, 286–321, 343–368), `lib/src/polynomial/impl/compressed_polynomial.dart` (lines 194–218, 400–410, 473–521), `lib/src/polynomial/rational.dart` (lines 23, 162–173), `lib/src/polynomial/orthogonal.dart` (lines 6–21, 121–171), `lib/polynomial.dart`, `test/polynomial/polynomial_test.dart`, `test/polynomial/rational_test.dart`, `test/polynomial/orthogonal_test.dart`
- **Problem**:
  1. `Polynomial<T>.fromRoots` (line 94) casts `(type ?? DataType.float64) as DataType<T>`, throwing a `TypeError` for `Polynomial<int>.fromRoots([1, 2])` or `Polynomial<Complex>.fromRoots(...)`.
  2. `Polynomial.gcd` returns `[1]` when both polynomials are zero (`gcd(0, 0)` should be `0`), and for `Polynomial<double>`, tiny floating-point remainder noise ($\sim 10^{-16}$) in `divide` prevents `gcd` from finding non-trivial common factors.
  3. `DensePolynomial.evaluateComplex` and `CompressedPolynomial.evaluateComplex` cast `(this[i] as num).toDouble()`, crashing with `TypeError` on `Polynomial<Complex>`!
  4. `DensePolynomial.integrate` and `CompressedPolynomial.integrate` call `field.scale(this[i], 1.0 / denom)`, injecting inexact `RealNumber` floats into `Polynomial<Expr>` and violating the symbolic exactness charter!
  5. `CompressedPolynomial.compose` allocates dense `DensePolynomial` intermediates and recomputes `_polyPower(other, exp)` from scratch for every term.
  6. `RationalFunction` does not check `numerator.type == denominator.type`, and its `hashCode` calls `simplify()` while `operator ==` uses cross-multiplication, violating the `a == b => a.hashCode == b.hashCode` contract under floating-point arithmetic.
  7. `laguerreL` is omitted from `OrthogonalFamily` and uses a separate top-level `laguerreEvaluate` function instead of `evaluateOrthogonalSeries`.
- **Action**:
  1. Derive `effectiveType` in `Polynomial.fromRoots` via `roots.isNotEmpty ? DataType.fromInstance(roots.first) : DataType.fromType<T>()`.
  2. Fix `gcd(0, 0)` to return the zero polynomial, and zero out tiny leading remainder coefficients below `1e-12 * norm` during float polynomial division/GCD.
  3. Support `Complex` coefficients in `evaluateComplex`.
  4. In `Polynomial.integrate`, divide by the exact ring/field integer sum of `multiplicativeIdentity` (`field.div(this[i], denomElement)`) instead of `field.scale(this[i], 1.0 / denom)`.
  5. Keep `CompressedPolynomial.compose` sparse using `CompressedPolynomial` accumulators and incremental exponent steps.
  6. Remove duplicate `==`/`hashCode` in `DensePolynomial` and `dynamicType` cast; fix `RationalFunction` equality/hashCode consistency; unify `laguerreL` into `OrthogonalFamily` and `evaluateOrthogonalSeries`.
  7. Add unit tests across `test/polynomial/`.

### [ ] TASK-3.3 (`High`): Fix `numeric` integration, root-finding, optimization, ODE, and interpolation bugs

- **Files**: `lib/src/numeric/integration.dart` (lines 60, 105, 125, 135, 200–210), `lib/src/numeric/root_finding/solve.dart` (lines 84–85, 157, 170, 207–208, 227), `lib/src/numeric/root_finding/solve_system.dart` (lines 65–72), `lib/src/numeric/optimization.dart` (line 86), `lib/src/numeric/optimization/quasi_newton.dart` (lines 44–48, 127, 146–150), `lib/src/numeric/optimization/nelder_mead.dart` (line 19), `lib/src/numeric/optimization/constrained.dart` (lines 58–416), `lib/src/numeric/ode/solve_ode.dart` (lines 43, 173, 243–252, 388–411, 472), `lib/src/numeric/interpolation/lagrange.dart` (lines 18–26), `lib/src/numeric/interpolation/bilinear.dart` (line 81), `lib/src/numeric/interpolation/bicubic.dart` (lines 58–138, 199, 268), `lib/src/numeric/calculus/derivative.dart` (line 30), `lib/src/numeric/calculus/gradient.dart` (line 20), `lib/src/numeric/calculus/hessian.dart` (line 19), `lib/src/numeric/calculus/jacobian.dart` (line 22), `lib/src/numeric/curve_fit.dart` (lines 177, 253, 468–559, 661–679), `lib/src/numeric/fft.dart` (lines 89–96), `lib/src/numeric/sampling.dart` (line 346)
- **Problem**:
  1. **Infinite-interval integration (`integration.dart:125, 135`)**: Truncates $t \in (0, 1]$ at `eps = math.max(tolerance * 1e-3, 1e-10)`, causing a $2 \times 10^{-5}$ error on $\int_1^\infty x^{-3/2}\,dx = 2$ (20,000× larger than `tolerance = 1e-9`). Also `(-infinity, infinity)` passes `tolerance` instead of `0.5 * tolerance` to each half.
  2. **Root finding (`solve.dart:84–85, 207–208`)**: Checks `if (fa.abs() < tolerance) return a;` at initial bracket endpoints, returning the wrong endpoint `a = 0.0` for scaled functions like $f(x) = 10^{-13}(x - 5)$ on $[0, 10]$! Also `_newtonRaphson` uses an unscaled `step = 1e-6` instead of `derivative(fn, x)`.
  3. **Quasi-Newton optimization (`quasi_newton.dart:44, 127, 146`)**: Backtracking line search condition `fxCandidate > ...` evaluates to `false` when `fxCandidate` is `NaN`, immediately accepting `NaN` steps! Also L-BFGS divides by zero when `yLast.dot(yLast) == 0.0`.
  4. **Nelder-Mead (`nelder_mead.dart:19`)**: `vertex[i] * 0.05 + step` is `0.0` when `vertex[i] == -20.0 * step`, collapsing the initial simplex.
  5. **Constrained optimization (`constrained.dart:197, 347–356`)**: `_BoxTransform.toY` pushes initial points within `0.1` of a bound to `lower + 0.1`, distorting small-scale problems, and uses 15 unnecessary `!` operators. `OptimizationMethod.brent` (`optimization.dart:86`) does not validate `initialPoint.length == 1`.
  6. **ODE solver (`solve_ode.dart:173, 243, 472`)**: In `_rk45`, if the final truncated step to `tEnd` (`step.abs() < minStep`) is rejected, line 243 (`step.abs() <= minStep`) aborts the entire integration with `converged = false` instead of shrinking the step. `_interpolateHermite` uses a linear scan instead of `binarySearchInterval`.
  7. **Interpolation & Calculus**: `LagrangeInterpolation` does not reject duplicate `xs`; `BicubicInterpolation` has duplicate `nx == 2` branches and duplicates `binarySearchInterval`; `BilinearInterpolation.gradient` and `BicubicInterpolation.gradient` return non-zero slopes when `(x, y)` is clamped outside the domain; `derivative`/`gradient`/`hessian`/`jacobian` do not validate `step > 0 && step.isFinite`; finite-difference Jacobian code is duplicated 5 times across `curve_fit.dart`, `solve_ode.dart`, and `solve_system.dart`.
- **Action**:
  1. In `integration.dart`, integrate transformed infinite domains from `0.0` to `1.0` with `if (t <= 0.0) return 0.0;` inside the wrapper, use `0.5 * tolerance` on split infinite intervals, and validate `tolerance > 0 && maxDepth >= 0`.
  2. In `solve.dart`, check `fa == 0.0` / `fb == 0.0` at endpoints and use `derivative(fn, x)` in `_newtonRaphson`.
  3. In `quasi_newton.dart`, reject non-finite `fxCandidate` (`!fxCandidate.isFinite || ...`) and guard `yLast.dot(yLast) > 0.0`.
  4. In `nelder_mead.dart`, use `vertex[i].abs() * 0.05 + step`.
  5. In `constrained.dart`, use `1e-12` boundary clamping, cap `innerMax`, eliminate `!` via local variable promotion, and validate `initialPoint.length == 1` for `OptimizationMethod.brent`.
  6. In `solve_ode.dart`, only abort at `minStep` when the step was not truncated by `tEnd`, validate input parameters, and use `binarySearchInterval` in `_interpolateHermite`.
  7. Deduplicate finite-difference Jacobian calls via `jacobian(...)`, validate `step` in calculus functions, fix `LagrangeInterpolation` duplicate check and `BicubicInterpolation` cleanup, validate dimensions in `fft2`/`polynomialRegression`/`multipleLinearRegression`, and replace generic `on Exception` in `sampling.dart`.
  8. Add unit tests for each fix across `test/numeric/`.

---

## Phase 4: `stats` & `dataframe` Subsystems (`lib/stats.dart`, `lib/dataframe.dart`)

### [ ] TASK-4.1 (`High`): Fix `DescriptiveVectorNumExtension` (`sum`, `mean`, `variance`) buffer offset bug on sliced vectors and `_quantile` validation

- **Files**: `lib/src/stats/descriptive.dart` (lines 342–368, 539–554), `test/stats/descriptive_test.dart`
- **Problem**:
  1. `DescriptiveVectorNumExtension.sum`, `mean`, and `variance` check `if (tData is Float64List && tensor.layout.isContiguous && length >= 64)` and pass `tData` directly to `Vforce.sum(x: tData)`, `Vforce.mean(x: tData)`, and `Vforce.variance(x: tData)`. When the vector is a contiguous slice (`subVector` or matrix row) with `length >= 64`, `tData` is the entire parent buffer, so `Vforce` computes the sum/mean/variance of the entire parent tensor instead of the slice!
  2. `_quantile` does not validate `quantile >= 0.0 && quantile <= 1.0` (crashing with `UnsupportedError` on `NaN`) and does not propagate `double.nan` elements in the input data.
- **Action**:
  1. Pass `Float64List.sublistView(tData, tensor.layout.offset, tensor.layout.offset + length)` to `Vforce.sum`, `Vforce.mean`, and `Vforce.variance`.
  2. Validate `quantile` in `[0.0, 1.0]` and return `double.nan` when input data contains `NaN`.
  3. Add unit tests in `test/stats/descriptive_test.dart` with sliced vectors of length $\ge 64$ and matrix rows.

### [ ] TASK-4.2 (`High`): Fix distribution, resampling, and hypothesis test bugs in `stats`

- **Files**: `lib/src/stats/distributions/continuous/log_normal.dart` (lines 48–80), `lib/src/stats/distributions/continuous/degenerate.dart` (lines 27–60), `lib/src/stats/distributions/continuous/inverse_gamma.dart` (line 65), `lib/src/stats/distributions/continuous/student_t.dart` (lines 108, 135), `lib/src/stats/distributions/continuous/chi_squared.dart` (line 70), `lib/src/stats/distributions/continuous/weibull.dart` (line 100), `lib/src/stats/distributions/continuous/pareto.dart` (line 90), `lib/src/stats/distributions/continuous/exponential.dart` (line 20), `lib/src/stats/distributions/discrete.dart` (line 49), `lib/src/stats/distributions/discrete/negative_binomial.dart` (lines 28–82), `lib/src/stats/distributions/discrete/bernoulli.dart` (lines 66, 69), `lib/src/stats/distributions/discrete/binomial.dart` (lines 86, 89), `lib/src/stats/distributions/discrete/uniform.dart` (line 78), `lib/src/stats/distributions/multivariate/dirichlet.dart` (lines 105–119), `lib/src/stats/resampling/jackknife.dart` (lines 16–21, 80–85), `lib/src/stats/resampling/bootstrap.dart` (lines 23–45), `lib/src/stats/hypothesis/chi_squared.dart` (lines 82–99), `lib/src/stats/hypothesis/jarque_bera.dart` (lines 22–24), `lib/src/stats/hypothesis/t_test.dart` (lines 66–70, 165–169, 211), `test/stats/`
- **Problem**:
  1. `LogNormalDistribution` is missing `@override double get lowerBound => 0.0;` and uses `1 + erf(...)` instead of `erfc(...)` in `cumulativeProbability`. `DegenerateDistribution` is missing `lowerBound => k` and `upperBound => k`.
  2. `InverseGammaDistribution.cumulativeProbability` computes `1.0 - lowRegGamma(...)` instead of `gammaq(...)` (catastrophic cancellation in the lower tail).
  3. `StudentDistribution.probability` overflows `pow(1 + x^2/dof, (dof+1)/2)` to `Infinity` for large `dof` (e.g. `dof = 500`), returning `0.0`.
  4. `ChiSquaredDistribution.probability(0.0)` returns `0.0` even when `dof == 2.0` (should be `0.5`) or `dof < 2.0` (should be `double.infinity`).
  5. `WeibullDistribution.sample` and `ParetoDistribution.sample` use `uniform.sample` directly instead of `1.0 - uniform.sample`, evaluating `log(0.0)` or dividing by `0.0` when `nextDouble() == 0.0`.
  6. `NegativeBinomialDistribution` allows `p == 0.0` (which crashes in `sample()`) and `p == 1.0` (where failure probability $1 - p = 0$ makes the distribution improper).
  7. `BernoulliDistribution`, `BinomialDistribution`, and `UniformDiscreteDistribution` return `±Infinity` instead of `double.nan` for `skewness`/`excessKurtosis` when variance is `0.0`, and `DiscreteDistribution.inverseCumulativeProbability(1)` returns `upperBound` (`10`) for `BinomialDistribution(10, 0.0)` instead of `0`.
  8. `DirichletDistribution.logProbability` fails to return `double.nan` when `x` contains `NaN` and `alpha` is `[1, ..., 1]`.
  9. `Jackknife` and `Bootstrap` use `assert` instead of throwing `ArgumentError`, and `Jackknife` crashes when `samples.length == 1` (requires `>= 2`).
  10. `chiSquaredContingency` does not reject negative counts or zero marginal sums; `jarqueBeraTest` returns `pValue: 1.0` on constant zero-variance samples; `tTestOneSample`/`tTestTwoSample`/`tTestPaired` compute two-sided confidence intervals even when `alternative` is one-sided.
- **Action**:
  1. Fix all distribution bounds, tail evaluations (`erfc`, `gammaq`, `exp(logProbability)`), `1.0 - uniform.sample`, degenerate skewness/kurtosis (`double.nan`), `NegativeBinomialDistribution` parameter bounds (`0.0 < p && p < 1.0`), and `DirichletDistribution` `NaN` check.
  2. Replace `assert` with `ArgumentError` in `Jackknife` (`samples.length >= 2`) and `Bootstrap`, and add missing `///` doc comments in `jackknife.dart` and `exponential.dart`.
  3. Fix `chiSquaredContingency`, `jarqueBeraTest`, and one-sided confidence intervals in `t_test.dart`.
  4. Add unit tests across `test/stats/`.

### [ ] TASK-4.3 (`High`): Fix `DataFrame`, `Series`, `GroupBy`, `Join`, `CsvReader`, and `Arrow` bugs

- **Files**: `lib/src/dataframe/dataframe.dart` (lines 44–56, 69–101, 552), `lib/src/dataframe/series.dart` (lines 207, 315, 375, 444–493, 529, 570–576, 643, 698–704, 763–766), `lib/src/dataframe/arrow_string_series.dart` (lines 30–42, 115, 121), `lib/src/dataframe/groupby.dart` (lines 74, 78, 150, 163, 220, 274), `lib/src/dataframe/join.dart` (lines 115–159), `lib/src/dataframe/csv/csv_reader.dart` (lines 80–87), `lib/src/dataframe/arrow/arrow_ipc.dart` (lines 95, 719, 757), `lib/src/dataframe/arrow/arrow_c_data_ffi.dart` (lines 250–255, 456–622), `test/dataframe/`
- **Problem**:
  1. `DataFrame` constructor silently allows duplicate column names, corrupting `_columnIndex`.
  2. `DataFrame.fromRows` only collects keys from `rows.first`, silently dropping columns that appear in later rows.
  3. `Series` subclasses do not validate `mask!.length == length` in constructors (`ArrowStringSeries` also does not validate `offsets.last <= bytes.length`), `isNull(index)` does not bounds-check `index` when `mask == null`, `BoolSeries.filter` and `ObjectSeries.filter` do not validate `filterMask.length == length`, and `TypedSeries.min`/`max` do not propagate `double.nan` when `NaN` is the first element or in `min`.
  4. `GroupBy`: `Agg.std` returns `0.0` when `count <= 1` whereas `Agg.variance` returns `null`; `Agg.sum` on an all-null `double` group initializes `total = 0` (`int`), losing `double` column type.
  5. `Join` (`join.dart:115–159`) rebuilds columns via untyped `DataFrame.fromColumns`, turning any column with 0 rows or all-`null` values into `ObjectSeries<Object?>` instead of preserving the source `Series` `DataType`!
  6. `CsvReader` (`csv_reader.dart:86`) parses 64-bit integers with `int.tryParse` and passes them to `TypedSeries<int>.fromList` without `type:`, which defaults to `DataType.int32` (`Int32List`) and **silently truncates integers outside $[-2^{31}, 2^{31}-1]$**!
  7. `ArrowIpc` (`arrow_ipc.dart:719`) checks `if (nullCount > 0 && vLength > 0)`, ignoring the validity bitmap when an external Arrow producer sets `nullCount == -1` (unknown null count); crashes on 0-length `Utf8` batches with empty offsets buffer (line 757); and does not validate matching schemas in `encodeBatches` (line 95).
  8. `arrow_c_data_ffi.dart` does not validate `n_children` or `n_buffers` / non-null buffer pointers before dereferencing FFI pointers.
- **Action**:
  1. Reject duplicate column names in `DataFrame._` and union keys across all rows in `DataFrame.fromRows`.
  2. Add constructor and `isNull`/`filter` bounds checks across all `Series` classes, fix `NaN` propagation in `TypedSeries.min`/`max`, and avoid boxing in `TypedSeries.sort`.
  3. Return `null` for `count < 2` in `Agg.std` and preserve `DataType` in `GroupBy` and `join`.
  4. Promote to `DataType.int64` in `CsvReader` when any integer exceeds `Int32` range, and use `ArrowStringSeries` for all-null CSV columns.
  5. Fix `nullCount != 0`, empty `Utf8` offsets, and schema validation in `ArrowIpc`, plus FFI struct validation in `arrow_c_data_ffi.dart`.
  6. Replace `dynamic` with `Object?` in `dataframe.dart`, `series.dart`, `groupby.dart`, and `join.dart`.
  7. Add unit tests across `test/dataframe/`.

---

## Phase 5: `symbolic` Subsystem (`lib/symbolic.dart`, `lib/src/symbolic/`)

### [ ] TASK-5.1 (`High`): Fix `VariableDomain.unknown` treated as real in `isRealExpr` and `_isSyntacticallyReal`

- **Files**: `lib/src/symbolic/algebra/simplify/transcendental.dart` (lines 547–583, 1533–1577), `lib/src/symbolic/algebra/simplify/additive.dart` (line 611), `test/symbolic/algebra/simplify_test.dart`
- **Problem**:
  `isRealExpr` (line 552) and `_isSyntacticallyReal` (line 1538) check `Variable(:final name) => assumptions.domainOf(name) != VariableDomain.complex`. Under `Assumptions.none`, `domainOf(name)` is `VariableDomain.unknown`, which is `!= VariableDomain.complex` (`true`)!
  Consequently, with `Assumptions.none`:
  - `Re(Variable('x')).simplify()` simplifies $\operatorname{Re}(x) \to x$.
  - `Im(Variable('x')).simplify()` simplifies $\operatorname{Im}(x) \to 0$.
  - `Conjugate(Variable('x')).simplify()` simplifies $\overline{x} \to x$.
  - `Abs(Pow(Variable('x'), IntegerNumber.two)).simplify()` simplifies $|x^2| \to x^2$.
  - `Sqrt(Exp(Variable('x'))).simplify()` simplifies $\sqrt{e^x} \to e^{x/2}$.
- **Action**:
  1. Consolidate `isProvenReal` (`additive.dart:611`), `isRealExpr` (`transcendental.dart:547`), and `_isSyntacticallyReal` (`transcendental.dart:1533`) into a single shared predicate that requires `domain == VariableDomain.real || domain == VariableDomain.positive || domain == VariableDomain.integer` for `Variable`.
  2. Add unit tests verifying that `Re(x)`, `Im(x)`, `Conjugate(x)`, `Abs(x^2)`, and `Sqrt(exp(x))` remain unsimplified under `Assumptions.none` and simplify under `Assumptions.real('x')`.

### [ ] TASK-5.2 (`High`): Enforce `RealNumber` contagion and ban implicit `.rationalize()` across `symbolic`

- **Files**: `lib/src/symbolic/ast/expr.dart` (lines 60–76, 215–226), `lib/src/symbolic/type/expr_data_type.dart` (lines 148–164), `lib/src/symbolic/calculus/integration.dart` (lines 349–362), `lib/src/symbolic/calculus/series.dart` (lines 114–116, 151–159), `lib/src/symbolic/calculus/limit.dart` (lines 642–648), `lib/src/symbolic/algebra/expand.dart` (lines 191–201), `lib/src/symbolic/algebra/simplify/multiplicative.dart` (lines 162, 167), `lib/src/symbolic/algebra/simplify/transcendental.dart` (lines 876–919, 1138–1279), `test/symbolic/`
- **Problem**:
  The Charter (`AGENTS.md`) strictly states: *"Floating-point numbers (`RealNumber`) are strictly numeric values and must never be treated as symbols or inferred as exact expressions... Real-to-rational conversion is supported exclusively as an explicit, separate operation via `.rationalize()`. When algebraic, transcendental, or power operations are applied to `RealNumber` inputs, they evaluate directly to numeric `RealNumber` results."*
  Violations found:
  1. `Expr.tryWrap` / `_wrapNum` (`expr.dart:215–226`): Converts `double` components of `Complex(2.0, 3.0)` to `IntegerNumber` when `value == value.truncateToDouble()`.
  2. `ExprField.scale` (`expr_data_type.dart:148–164`): Converts `double` `factor` to `IntegerNumber` or calls `.rationalize(maxDenominator: 64)`.
  3. `_doubleToBoundExpr` (`integration.dart:349–362`) and `_doubleToPoint` (`series.dart:114–116, 151–159`) and `_extractDominantPolynomialTerm` (`limit.dart:642–648`): Convert `double` bounds/points/coefficients to `IntegerNumber` or call `.rationalize(maxDenominator: 64)`.
  4. `_expandPow` (`expand.dart:191–201`): Treats `RealNumber(2.0)` exponent as exact integer `2` and returns `IntegerNumber.one` for `intExp == 0`.
  5. `simplifyMul` (`multiplicative.dart:162, 167`): Returns `IntegerNumber.zero` when `coeff` is `RealNumber(0.0)`.
  6. `simplifyFloor`, `simplifyCeil`, `simplifyRound` (`transcendental.dart:1182–1250`): Return `IntegerNumber` even when the argument is or contains a `RealNumber`, and evaluate exact closed constant expressions via IEEE-754 `double` `.evaluate()` (risking wrong integers near boundaries).
  7. `simplifySign(RealNumber)` returns `IntegerNumber` instead of `RealNumber`, and `simplifyBeta`, `simplifyFactorial`, `simplifyBinomial` lack `RealNumber` evaluation branches.
- **Action**:
  1. Remove all automatic `.rationalize()` and `double -> IntegerNumber` coercions in `expr.dart`, `expr_data_type.dart`, `integration.dart`, `series.dart`, `limit.dart`, and `expand.dart`.
  2. Preserve `RealNumber(0.0)` in `simplifyMul` and return `RealNumber` in `simplifySign`, `simplifyFloor`, `simplifyCeil`, `simplifyRound`, `simplifyBeta`, `simplifyFactorial`, and `simplifyBinomial` when any operand is `RealNumber`.
  3. Add unit tests verifying strict `RealNumber` contagion and no implicit rationalization.

### [ ] TASK-5.3 (`High`): Fix unsound inverse hyperbolic and `Arg(Conjugate)` simplifications, `ComplexNumber` formatting parentheses, and `BytecodeEvaluator`

- **Files**: `lib/src/symbolic/algebra/simplify/transcendental.dart` (lines 930, 948, 962, 1398), `lib/src/symbolic/textualization/formatting.dart` (lines 11–103), `lib/src/symbolic/textualization/latex.dart` (line 17), `lib/src/symbolic/textualization/mathml.dart` (line 24), `lib/src/symbolic/textualization/string.dart` (lines 15, 22), `lib/src/symbolic/compiler/evaluator.dart` (lines 146–152, 238–241), `test/symbolic/algebra/simplify_test.dart`, `test/symbolic/textualization/textualization_test.dart`, `test/symbolic/compiler/compiler_test.dart`
- **Problem**:
  1. `simplifyAcosh` (line 948) rewrites `Acosh(Cosh(x)) -> x`, which is false for real $x < 0$ ($\operatorname{acosh}(\cosh(-2)) = 2 \neq -2$). `simplifyAsinh` (line 930) and `simplifyAtanh` (line 962) rewrite `Asinh(Sinh(x)) -> x` and `Atanh(Tanh(x)) -> x` without checking `isProvenReal(x, assumptions)`.
  2. `simplifyArg` (line 1398) rewrites `Arg(Conjugate(z)) -> -Arg(z)` unconditionally, which fails on the branch cut $z \in (-\infty, 0)$ where $\arg(\overline{-1}) = \pi \neq -\pi$.
  3. `formatting.dart` (`needsPowBaseParens`, `needsMulLeftParens`, `needsMulRightParens`, `needsSubRightParens`, `needsNegOperandParens`, `stripLeadingNegative`) does not handle `ComplexNumber` or `Mod`, causing `Pow(ComplexNumber(1, 2), 2).toLatex()` to render `{1 + 2 i}^{2}`, `Mul([ComplexNumber(1, 2), x]).toLatex()` to render `1 + 2 i x`, and `(x - ComplexNumber(1, 2)).toLatex()` to render `x - 1 + 2 i` without parentheses!
  4. `string.dart:15` doc example uses non-existent `.toText()` instead of `.format()`.
  5. `BytecodeEvaluator._runReal` (`evaluator.dart:239`) does not catch `ArgumentError` from `evalGamma(v)` at non-positive integer poles ($0, -1, -2, \dots$), throwing instead of returning `double.nan`, and reuses mutable instance stacks across reentrant calls.
- **Action**:
  1. In `simplifyAcosh`, return `Abs(expr.expr).simplify(assumptions: assumptions)` when `isProvenReal(expr.expr, assumptions)`; guard `simplifyAsinh` and `simplifyAtanh` with `isProvenReal`; restrict `Arg(Conjugate(z)) -> -Arg(z)` to when `z` is proven not on $(-\infty, 0]$ (e.g. `isPositiveExpr`).
  2. Update `formatting.dart` parenthesization predicates and `stripLeadingNegative` to handle `ComplexNumber` and `Mod`.
  3. Fix `string.dart` doc comments, guard `Op.gamma` poles in `BytecodeEvaluator._runReal`, and make `BytecodeEvaluator` reentrant-safe.
  4. Add unit tests for all cases.

### [ ] TASK-5.4 (`High`): Fix symbolic calculus (`Derivative` with `point`, `integration`, `limit`, `series.toPolynomial`) and equation solver bugs

- **Files**: `lib/src/symbolic/calculus/differentiation.dart` (lines 156–158), `lib/src/symbolic/calculus/integration.dart` (lines 665–745, 1349–1377), `lib/src/symbolic/calculus/limit.dart` (lines 55–68, 189, 500, 509), `lib/src/symbolic/calculus/series.dart` (lines 70–130), `lib/src/symbolic/solver/polynomial_system.dart` (lines 48–60, 138–167), `lib/src/symbolic/solver/resultant.dart` (lines 131–133), `lib/src/symbolic/solver/transcendental.dart` (lines 192–202), `lib/src/symbolic/solver/univariate.dart` (lines 146–190), `test/symbolic/calculus/`, `test/symbolic/solver/`
- **Problem**:
  1. `differentiation.dart:156`: Differentiating `Derivative(inner, dVar, order: order, point: p)` ignores `point` and increments `order` as if `point == null`! When `point != null` and `!point.dependsOn(variable)`, the derivative of the constant evaluated value is `0`; when `point.dependsOn(variable)`, the chain rule applies.
  2. `integration.dart:665–745`: Doc comments advertise `tanh^2` and `sinh^n`/`cosh^n` ($3 \le n \le 10$) in `_integrateLinearTrigPower`, but their branches are missing.
  3. `limit.dart:57`: Unconditionally rewrites `Pow(base, exponent)` to `exp(exponent * ln(base))` before attempting direct substitution, failing when `base` approaches a negative real number (e.g. $\lim_{x \to 0} (-2 + x)^{3 + x} = -8$). Also uses hardcoded dummy variables `_h`, `_t`, `_u`, `_omega` without checking `expr.freeVariables`.
  4. `series.dart:70–130`: `toPolynomial` uses naive repeated symbolic differentiation instead of `toPowerSeries`, failing with division by zero on removable singularities like `sin(x)/x` at `0`.
  5. `polynomial_system.dart:138–153`: `_backSubstitute` picks the first polynomial in `lexExprs` containing `targetVar` *before* substituting `currentSolution`; if its leading coefficients vanish at `currentSolution` (`instantiated.isZero`), it returns `[]` and drops a valid root instead of checking the remaining basis polynomials!
  6. `resultant.dart:131`: `SylvesterResultantSolver.solve` solves `fAtY` without verifying roots against `gAtY`.
  7. `transcendental.dart:192–202`: `_invertSingleVariable` on `Pow(u, p) = c` misses negative roots when `p` is a negative even integer (`x^(-2) = 4`) or rational with even numerator (`x^(2/3) = 4`), and only checks `RationalNumber`/`RealNumber` for `c < 0` when `p` has even denominator (missing `-Constant.pi`).
  8. `univariate.dart:161, 185`: `_isPositiveRealRoot` ignores `assumptions`, and `isZeroExpr` treats explicit nonzero `RealNumber(1e-12)` as zero (`< 1e-10`).
- **Action**:
  1. Handle `point != null` in `differentiation.dart:156`.
  2. Add `Tanh` ($n=2$) and `Sinh`/`Cosh` ($3 \le n \le 10$) to `_integrateLinearTrigPower`.
  3. Try direct substitution before `exp(exponent * ln(base))` in `limit.dart` and generate fresh dummy variable names.
  4. Route `toPolynomial` through `toPowerSeries` first, falling back to repeated differentiation only on `UnsupportedError`/`StateError`.
  5. Fix `_backSubstitute` in `polynomial_system.dart` to substitute `currentSolution` into all candidate polynomials and select the lowest-degree non-zero univariate equation; verify resultant roots against both equations in `resultant.dart`.
  6. Fix `_invertSingleVariable` on `Pow`, `_isPositiveRealRoot`, and `isZeroExpr`.
  7. Add unit tests in `test/symbolic/calculus/` and `test/symbolic/solver/`.

---

## Phase 6: Web Applications (`web/`)

### [ ] TASK-6.1 (`High`): Fix `PlotValue` JSON serialization crash on `NaN`/`Infinity` and `Float64List` in `Surface3dData`

- **Files**: `web/calculator/src/model/value.dart` (lines 58–75, 130–149, 179–196), `test/web/` (or calculator serialization test)
- **Problem**:
  1. `buildSurface3dPlotValue` (`web/calculator/src/engine/sampling.dart:316`) writes `double.nan` into `zValues` for non-finite surface points, and `Surface3dData.toJson()` puts `'zValues': zValues` into the JSON map. Standard `jsonEncode` (used by `SessionSerializer.toLocalStorageJson` and URL sharing) **throws `JsonUnsupportedObjectError` on `double.nan` and `double.infinity`**!
  2. The same `jsonEncode` crash occurs if any coordinate in `PlotSegmentData` or `PlotMarkerData` is `NaN`/`Infinity`.
- **Action**:
  1. Encode non-finite doubles (`NaN`, `Infinity`, `-Infinity`) as `null` in `Surface3dData.toJson()` and `PlotSegmentData.toJson()`, and decode `null` back to `double.nan` in `Surface3dData.fromJson()` and `PlotSegmentData.fromJson()`.

### [ ] TASK-6.2 (`High`): Fix Calculator `UserFunction` parameter capture, missing `Assumptions` propagation, `approx` digits, `AngleMode.deg`, and RPN post-processing

- **Files**: `web/calculator/src/model/environment.dart` (lines 121–132), `web/calculator/src/engine/commands/algebra.dart` (lines 17–345), `web/calculator/src/engine/commands/calculus.dart` (lines 38–455), `web/calculator/src/engine/commands/numbers.dart` (lines 13–245), `web/calculator/src/engine/commands/complex.dart` (lines 130–182), `web/calculator/src/engine/commands/linear.dart` (lines 74–106), `web/calculator/src/engine/evaluator.dart` (lines 435–480, 584–801), `web/calculator/src/engine/rpn.dart` (lines 231–238, 525–542)
- **Problem**:
  1. `UserFunction.apply` (`environment.dart:121–132`) substitutes parameters sequentially (`for (var i = 0; i < params.length; i++) result = result.substitute(params[i], args[i])`), causing variable capture when an argument references a later parameter (e.g. `f(x, y) := x + 2*y` evaluated at `f(y, x)` returns `3*x` instead of `y + 2*x`).
  2. `ctx.assumptions` / `environment.settings.assumptions` is omitted across `expand`, `factor`, `solve` (system branch), `apart`, `together`, `cancel`, `collect`, `trigexpand`, `trigsimplify`, `taylor`, `series`, `gradient`, `hessian`, `jacobian`, `mod`, `factorial`, `binomial`, `floor`, `ceil`, `round`, and vector/matrix `.simplify()` calls in `algebra.dart`, `calculus.dart`, `numbers.dart`, `evaluator.dart`, and `rpn.dart`.
  3. `approx(expr, [digits])` (`numbers.dart:13–35`) advertises a second `[digits]` argument in its signature and examples (`approx(sin(1), 8)`), but completely ignores `args[1]`.
  4. `_applyAngleUnitOnTrigConstruct` (`evaluator.dart:784–800`) fails on `sec`, `csc`, `cot` (because `ExprSyntax.standardUnaryFunctions` constructs `Pow` or `Mul`, not `Sin`/`Cos`/`Tan`), is not applied when lifting unary functions over vectors/matrices, and inverse trig functions (`asin`, `acos`, `atan`) are not converted to degrees in `AngleMode.deg`.
  5. `RpnInterpreter._postProcessValue` (`rpn.dart:525–542`) ignores `ComplexDisplayMode.polar` and `ListValue` simplification, and duplicates `DEPTH` instead of calling `stack.pushDepth()`.
  6. `commands/complex.dart:130–182` reimplements `rect` and `polar` manually instead of calling `e.toRectangular(assumptions: ctx.assumptions)` and `e.toPolar(assumptions: ctx.assumptions)`.
  7. `commands/linear.dart:74–106` manually loops to compute matrix transpose and trace instead of using `m.transposed` and `m.trace`.
- **Action**:
  1. Perform simultaneous substitution in `UserFunction.apply` using temporary placeholder variables `Variable('\$param_$i')`.
  2. Pass `assumptions: ctx.assumptions` (and `environment.settings.assumptions`) to all symbolic and matrix/vector operations.
  3. Honor the optional `digits` argument in `approx(expr, [digits])` by rounding/formatting `RealNumber` values to `digits` significant figures.
  4. Fix `AngleMode.deg` for `sec`, `csc`, `cot`, inverse trig functions (`asin`, `acos`, `atan`), and vector/matrix elementwise calls.
  5. Share post-processing between `Evaluator` and `RpnInterpreter`, use `e.toPolar`/`e.toRectangular` in `complex.dart`, and use `m.transposed`/`m.trace` in `linear.dart`.

### [ ] TASK-6.3 (`High`): Fix Calculator `PlotView` parametric slider range, `Re-sample` button, window listener leak, LaTeX escaping, and Service Worker caching

- **Files**: `web/calculator/src/ui/plot_view.dart` (lines 204–223, 235–246, 278–283, 384–390, 463–468), `web/calculator/src/ui/scroll_view.dart` (lines 225–235), `web/calculator/src/ui/app.dart` (lines 732, 745–754), `web/calculator/src/model/value.dart` (lines 179–260, 545, 583), `web/calculator/sw.js` (lines 43–57), `web/shared/chart.dart` (lines 548, 560), `web/shared/webgl_surface.dart` (lines 118, 129)
- **Problem**:
  1. Moving a parameter slider on a parametric plot in `plot_view.dart:204–213` calls `buildParametricPlotValue` with hardcoded `0.0, 6.283185307179586` (`2π`) instead of preserving the parametric plot's original `minT`/`maxT`, and drops `angleMode` on 1D plots (line 215).
  2. Clicking `Re-sample` (`scroll_view.dart:225–235`) on an `odeplot(...)` or `plot([x(t), y(t)], t, t0, t1)` overwrites the input with `plot(expr, var, minX, maxX)`, breaking ODE and parametric plots.
  3. `PlotView.create`, `InteractiveChartController`, and `WebGLSurfaceRenderer` register `web.window.addEventListener('resize' / 'mousemove' / 'mouseup', ...)` on every worksheet re-render without ever removing disconnected listeners, leaking closures and canvases across the session.
  4. `InfoValue.toLatex` and `ErrorValue.toLatex` (`value.dart:545, 583`) only escape `}`, leaving `{`, `\`, `_`, `^`, `%`, `&`, `#`, `$` unescaped.
  5. `app.dart:732` has a dead ternary `snippet.endsWith('(') ? 0 : 0`, and `_showToast` (lines 745–754) does not clear previous timeouts.
  6. `web/calculator/sw.js:43–57` uses a strict cache-first strategy without network revalidation, preventing users from ever receiving updated JS/CSS bundles.
- **Action**:
  1. Store `minT`, `maxT`, and `angleMode` on `PlotValue` and pass them when resampling via parameter sliders.
  2. Hide/disable the `Re-sample` button for parametric and ODE plots (or preserve their command structure).
  3. Remove `window` event listeners automatically when `!canvas.isConnected` (using a self-removing listener wrapper).
  4. Escape all special LaTeX characters in `InfoValue.toLatex` and `ErrorValue.toLatex`, fix `_showToast` timer management and `app.dart:732`, and switch `sw.js` to network-first with offline cache fallback.

### [ ] TASK-6.4 (`Medium`): Fix bugs and Charter violations in `web/index.html`, `web/distributions/`, `web/expressions/`, and `web/shared/`

- **Files**: `web/index.html` (lines 347–350), `web/distributions/index.dart` (lines 429, 496–517), `web/expressions/index.dart` (lines 1009, 1719), `web/expressions/algebra.dart` (lines 1–39), `web/shared/chart.dart` (lines 401–427, 918, 963), `web/shared/style.css` (lines 655–687, 808–837, 989–991), `web/expressions/style.css` (lines 142–144)
- **Problem**:
  1. `web/index.html:347–350` contains invalid orphaned CSS properties and a stray closing `}` after `.cap-desc`.
  2. `web/distributions/index.dart:516` assigns `web.window.location.hash = ...` on every slider `input` frame, spamming hundreds of browser history entries during a single slider drag (unlike `web/expressions/index.dart:2173` which uses `window.history.replaceState`).
  3. `web/expressions/index.dart:1009` compiles `cachedD3?.toComplexFunction1D('x')` instead of `plotD3?.toComplexFunction1D('x')`, throwing `ArgumentError` whenever the expression has auxiliary variables (`a`, `b`, `y`).
  4. `web/shared/chart.dart:401` (`initCanvas`) and `web/expressions/index.dart:1719` (`estimateYBounds`) return unnamed positional records `(web.CanvasRenderingContext2D, double, double)?` and `(double, double)`, whereas `AGENTS.md` prefers named record fields.
  5. `web/shared/chart.dart:918, 963` concatenates `'${color}33'` and `'${color}3b'`, which breaks if `color` is `rgb(...)` or `rgba(...)`.
  6. `web/shared/style.css` has duplicate `.copy-btn` rule blocks (lines 655–687 and 808–837) and `.layer-checkbox` is duplicated in `web/expressions/style.css`.
- **Action**:
  1. Remove the orphaned CSS lines in `web/index.html:347–350` and deduplicate `.copy-btn` and `.layer-checkbox` in `web/shared/style.css` and `web/expressions/style.css`.
  2. Use `web.window.history.replaceState(null, '', '#${parts.join('&')}')` in `web/distributions/index.dart:516`.
  3. Change `cachedD3?.toComplexFunction1D('x')` to `plotD3?.toComplexFunction1D('x')` in `web/expressions/index.dart:1009`, and remove redundant `.simplify()` before `.factor()` in `web/expressions/algebra.dart:38`.
  4. Convert `initCanvas` and `estimateYBounds` return types to named records `({web.CanvasRenderingContext2D ctx, double width, double height})?` and `({double minY, double maxY})`, and use `ctx.globalAlpha` instead of hex string suffix concatenation in `chart.dart`.

---

## Phase 7: Documentation & Architecture Synchronization

### [ ] TASK-7.1 (`Low`): Synchronize `ARCHITECTURE.md` with current class and method names

- **Files**: `ARCHITECTURE.md` (sections 4.3, 4.4, 4.7, 7.2, 7.3)
- **Problem**:
  - Section 4.3 refers to `StringSeries` (actual class: `ArrowStringSeries`).
  - Section 4.4 refers to `Agg.var_` (actual enum value: `Agg.variance`).
  - Section 4.7 refers to `toArrowIpcBytes()` / `fromArrowIpcBytes()` (actual methods: `toArrowIpc()` / `fromArrowIpc()`).
  - Section 7.2 refers to `StudentTDistribution` and `DiscreteUniformDistribution` (actual classes: `StudentDistribution` and `UniformDiscreteDistribution`).
  - Section 7.3 refers to `kolmogorovSmirnov2Sample` (actual function: `kolmogorovSmirnovTwoSample`).
- **Action**:
  - Update `ARCHITECTURE.md` so all symbol references match the canonical public API in `lib/`.
