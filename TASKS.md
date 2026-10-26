# Codebase Audit, Bug-Fix, Cleanup & Near-100% Coverage Task List

Step-by-step execution plan for an autonomous agent to resolve all regressions, incomplete items from the previous pass (`8052bea..HEAD`), newly identified bugs and charter violations across `lib/` and `web/`, eliminate dead/unreachable code, and reach near-100% unit test coverage across all non-FFI subsystems.

## Execution Protocol

1. **Sequential Execution**: Execute tasks in the order listed (`Phase 1` → `Phase 6`) to respect the sub-library DAG (`type` → `tensor` / `acceleration` → `linear` / `special` → `polynomial` / `numeric` → `stats` / `dataframe` / `symbolic` → `web`).
2. **Test-Driven Verification**: For every bug fix, write a failing unit test in the corresponding `test/` file (mirroring `lib/src/` 1:1) using `package:checks` (`check(...)`), apply the fix, and verify the test passes.
3. **Quality Gate per Task**:
   - Run `dart analyze` (must report 0 issues).
   - Run `dart format --output=none --set-exit-if-changed .`.
   - Run the affected unit test file(s) and `dart test test/deps_test.dart`.
4. **Charter Compliance**:
   - Use relative imports within `lib/`.
   - Place public declarations before private declarations in all classes and files.
   - Use named record fields (never `.$1`, `.$2`).
   - Avoid `dynamic` and `!` non-null assertions where type promotion or local variables apply.
   - Maintain single canonical APIs; remove dead, unreachable, or duplicate code directly.
   - Update `TASKS.md` by checking off `[x]` each completed task.

---

## Phase 1: Immediate Regressions & Broken Test Suite (`8052bea..HEAD`)

### [x] TASK-1.1: Fix `factorExpr` on Unsimplified Constant Products/Sums & Restore `test/web_examples_test.dart`
- **Files**:
  - `lib/src/symbolic/algebra/factor.dart` (lines 36–101)
  - `test/symbolic/algebra/factor_test.dart`
  - `test/web_examples_test.dart` (lines 290–305)
- **Problem**:
  - Commit `081d353` changed `web/expressions/algebra.dart:38` from `expr.simplify(assumptions: assumptions).factor(assumptions: assumptions)` to `expr.factor(assumptions: assumptions)`, breaking `test/web_examples_test.dart:297` (`12 * 2` → expected `'2 ^ 3 * 3'`, got `'24'`).
  - In `lib/src/symbolic/algebra/factor.dart:36–101`, `factorExpr` only prime-factors `IntegerNumber` and `FractionNumber` when passed as top-level atomic nodes (lines 38–47). When given an unsimplified constant expression like `Mul([IntegerNumber.of(12), IntegerNumber.of(2)])` or `Add([IntegerNumber.of(20), IntegerNumber.of(4)])`:
    - In the `Mul` branch (lines 70–95), `combineFactoredProducts(numFactored)` multiplies `12 * 2` into `IntegerNumber(24)` and returns `24` without prime-factoring it.
    - In step 4 (lines 98–100), `final expanded = expr.expand().simplify(assumptions: assumptions); if (expanded is Number ...) return expanded;` returns `IntegerNumber(24)` without prime-factoring it.
- **Actions**:
  1. In `lib/src/symbolic/algebra/factor.dart`, when the combined result in the `Mul` branch or `expanded` in step 4 is an `IntegerNumber` or `FractionNumber`, pass it through integer/fraction prime factorization (`_factorInteger`) so `expr.factor()` always produces prime-factored form on constant integer/rational expressions.
  2. Fix the broken doc comment in `lib/src/symbolic/algebra/factor.dart:28` (`IntegerNumber.from(5)` → `IntegerNumber.of(5)`).
  3. Add unit tests in `test/symbolic/algebra/factor_test.dart` for factoring unsimplified `Mul([12, 2])` and `Add([20, 4])`, and verify `dart test test/web_examples_test.dart` passes.
- **Verification**: `dart test test/symbolic/algebra/factor_test.dart test/web_examples_test.dart`

### [ ] TASK-1.2: Fix Apple Accelerate vDSP Small-Size Regression (`n = 2, 4`) & Alignment in `FftNative`
- **Files**:
  - `lib/src/acceleration/fft/fft_native.dart` (lines 119–215)
  - `test/acceleration/fft/fft_test.dart`
- **Problem**:
  - Commit `b1eb598` removed `if (n < 8)` from `_fft1dVdsp` (`lib/src/acceleration/fft/fft_native.dart:121`). However, Apple's `vDSP_DFT_Interleaved_CreateSetupD` only supports double-precision interleaved DFT lengths where `log2n >= 3` (`n >= 8`) and `log2n <= 12` (`n <= 4096`), returning `ffi.nullptr` for `n = 2` (`log2n = 1`) and `n = 4` (`log2n = 2`). On macOS systems without Homebrew `libfftw3.dylib`, calling `Fft.fft` or `Fft.fft2` with size `2` or `4` in `AccelerationMode.accelerated` returns `false` and throws `AccelerationFailedError`.
  - `_fft1dVdsp` passes `raw` directly to `_vdspDftInterleavedExecuteD` without checking 16-byte SIMD alignment (`raw.offsetInBytes % 16 == 0`), which can fault on odd-offset `Float64List.sublistView` buffers.
  - `_fft2dVdsp` (lines 176, 196) uses non-null assertions `setupCols!` and `setupRows!`.
- **Actions**:
  1. In `_fft1dVdsp` and `_fft2dVdsp`, handle `log2n == 1` (`n = 2`) and `log2n == 2` (`n = 4`) directly via exact butterfly formulas (or `FftDart.fft` / `FftDart.fft2`) so `_fft1dVdsp` and `_fft2dVdsp` succeed for all power-of-2 sizes `1 <= log2n <= 12`.
  2. In `_fft1dVdsp`, if `raw.offsetInBytes % 16 != 0`, copy into an aligned temporary `Float64List(2 * n)`, execute `_vdspDftInterleavedExecuteD`, and copy back.
  3. Eliminate `setupCols!` and `setupRows!` in `_fft2dVdsp` via local variable promotion.
  4. Add unit tests in `test/acceleration/fft/fft_test.dart` covering odd-offset `Float64List.sublistView` buffers and sizes `n = 2, 4, 8` across all acceleration modes.
- **Verification**: `dart test test/acceleration/fft/fft_test.dart`

### [ ] TASK-1.3: Fix `Lapack.dsyev` / `ssyev` and `EigenvalueDecomposition._tql2` `RangeError` on `NaN` / `Infinity`
- **Files**:
  - `lib/src/acceleration/lapack/lapack_dart.dart` (lines 360–520)
  - `lib/src/acceleration/lapack/lapack_native.dart` (lines 415–485, 520–588)
  - `lib/src/linear/decomposition/eigenvalue.dart` (lines 95–110, 270–315)
  - `test/acceleration/lapack/lapack_test.dart`
  - `test/linear/decomposition/eigenvalue_test.dart`
- **Problem**:
  - In `LapackDart.dsyev` (`lib/src/acceleration/lapack/lapack_dart.dart:475–512`) and `EigenvalueDecomposition._tql2` (`lib/src/linear/decomposition/eigenvalue.dart:275–313`), when the input matrix contains `NaN` or `Infinity`, `tst1` becomes `NaN`. In `while (mIdx < n) { if (e[mIdx].abs() <= eps * tst1) break; mIdx++; }`, `e[mIdx].abs() <= NaN` is always `false`, incrementing `mIdx` to `n` and crashing with `RangeError: Index out of range` at `d[mIdx]` and `e[i + 1]`.
  - When `n == 1` and `a[aOffset]` is `NaN`, `LapackDart.dsyev` (line 366) returns `true` instead of `false`.
  - `LapackNative.dsyev` and `LapackNative.ssyev` lack `NaN`/`Infinity` input/output checks (unlike `dpotrf`, `dgesv`, `dgels`).
- **Actions**:
  1. In `LapackDart.dsyev`, `LapackNative.dsyev`, and `LapackNative.ssyev`, validate that active matrix entries of `a` (in the specified triangle `uplo`) are finite (`!val.isNaN && !val.isInfinite`); return `false` immediately if any entry is non-finite. Also guard the `while (mIdx < n - 1)` loop in `LapackDart.dsyev` and `EigenvalueDecomposition._tql2` so `mIdx` can never exceed `n - 1`, and check `!tst1.isFinite` to abort or throw `StateError('Eigenvalue decomposition failed to converge.')`.
  2. Add unit tests in `test/acceleration/lapack/lapack_test.dart` and `test/linear/decomposition/eigenvalue_test.dart` with `NaN` and `Infinity` matrices for `n = 1` and `n = 2`.
- **Verification**: `dart test test/acceleration/lapack/lapack_test.dart test/linear/decomposition/eigenvalue_test.dart`

---

## Phase 2: `type`, `tensor`, `acceleration`, and `linear` Bugs & Cleanups

### [ ] TASK-2.1: Fix `DataType` (`ObjectDataType`, `Uint64DataType`), `memory.dart` Cross-Type Aliasing & `dynamic`
- **Files**:
  - `lib/src/type/data_type.dart` (lines 190–215)
  - `lib/src/type/types/integer.dart` (lines 55–80)
  - `lib/src/type/types/bigint.dart` (lines 25–35)
  - `lib/src/type/types/numeric.dart` (lines 15–30)
  - `lib/src/type/types/boolean.dart` (lines 18–30)
  - `lib/src/type/utils/memory.dart` (lines 1–90)
  - `test/type/data_type_test.dart`
- **Problem**:
  - `DataType.copyList` (`lib/src/type/data_type.dart:196`) unconditionally evaluates `fillValue ?? defaultValue` even when `newLength <= listLength`, and `DataType.castList` (`line 208`) calls `newList(len)` without `generate:`, crashing with `StateError: No defaultValue configured` for `ObjectDataType<T>` created via `DataType.fromType<DateTime>()`.
  - `Uint64DataType.cast` (`lib/src/type/types/integer.dart:59`) returns `-1` for `DataType.uint64.cast(-1)` and `DataType.uint64.cast(-1.0)` while wrapping `BigInt.from(-1)` via `toUnsigned(64).toInt()`. Also `IntegerDataType.cast(double.nan)` / `cast(double.infinity)` and `BigIntDataType.cast(double.nan)` throw `UnsupportedError` instead of `ArgumentError`, and `NumericDataType.cast(BigInt.one)` throws `ArgumentError` instead of converting `BigInt` to `int`/`double`.
  - `BooleanDataType.cast` (`lib/src/type/types/boolean.dart:22`) is case-sensitive on strings (`'TRUE'`, `'False'`).
  - `sameStartAddress` (`lib/src/type/utils/memory.dart:32–35`) does not verify `aInfo.elemSize == bInfo.elemSize`, missing cross-type `ByteBuffer` aliasing hazards (e.g. `Uint8List` source into `Float64List` target at byte offset 0).
  - `lib/src/type/utils/memory.dart` uses `List<dynamic>` instead of `List<Object?>` in 7 places.
- **Actions**:
  1. In `DataType.castList`, use `newList(len, generate: (i) => cast(list[i]))`. In `DataType.copyList`, only evaluate `fillValue ?? defaultValue` when `newLength > listLength` (use `newList(newLength, generate: (i) => list[i])` when `newLength <= listLength` and `fillValue == null`).
  2. Fix `IntegerDataType.cast`, `BigIntDataType.cast`, `NumericDataType.cast`, and `BooleanDataType.cast` to handle `BigInt`, case-insensitive trimmed boolean strings, unsigned 64-bit wrapping, and throw `ArgumentError` on `NaN`/`Infinity`.
  3. In `lib/src/type/utils/memory.dart`, require `aInfo.elemSize == bInfo.elemSize` in `sameStartAddress` and replace all `List<dynamic>` with `List<Object?>`.
  4. Add unit tests in `test/type/data_type_test.dart`.
- **Verification**: `dart test test/type/`

### [ ] TASK-2.2: Fix `Tensor` & `Layout` Edge Cases (`getRange` on Empty Flipped Slice, `NaN` Reductions, `Float64Tensor.slice`)
- **Files**:
  - `lib/src/tensor/layout.dart` (lines 218–225, 350–365)
  - `lib/src/tensor/tensor.dart` (lines 325–338)
  - `lib/src/tensor/float64_tensor.dart` (lines 40–50, 93–165)
  - `lib/src/tensor/operations/reduction.dart` (lines 80–110, 170–285)
  - `test/tensor/layout_test.dart`
  - `test/tensor/tensor_test.dart`
  - `test/tensor/float64_tensor_test.dart`
  - `test/tensor/operations/reduction_test.dart`
- **Problem**:
  - `Layout.getRange` (`lib/src/tensor/layout.dart:358`) computes `offset + start * strides[axis]` even when `count == 0` (unlike `Layout.slice` at line 432). On a flipped tensor (`offset: 2, strides: [-1]`), `getRange(axis: 0, start: 3, end: 3)` produces `offset == -1`, causing `.copy()` (`lib/src/tensor/tensor.dart:330`) to throw `RangeError` in `outData.setRange(0, 0, data, -1)`.
  - `Layout.transpose` (`lib/src/tensor/layout.dart:221`) throws `ArgumentError` for out-of-range axes whereas `Layout.flip` and `Layout.getRange` throw `RangeError.range`.
  - `ReductionTensorExtension` (`lib/src/tensor/operations/reduction.dart`):
    - `min`, `max`, `argmin`, `argmax`, and `norm(double.infinity)` fail to propagate `double.nan` because `double.compareTo` orders `NaN > x` and `absVal > maxVal` is `false` for `NaN`.
    - `min(axis: ...)` and `max(axis: ...)` throw `StateError` when `length == 0` even when reducing along a non-empty axis (e.g. shape `[0, 3]` with `axis: 1`), unlike `sum(axis: 1)` and `mean(axis: 1)` which return an empty tensor of shape `[0]`.
  - `Float64Tensor` is missing `@redeclare Float64Tensor slice(...)` (`lib/src/tensor/float64_tensor.dart`).
- **Actions**:
  1. Guard `count > 0` in `Layout.getRange` before advancing `offset`, and guard `len > 0` in `Tensor.copy` before `setRange`. Use `RangeError.range` in `Layout.transpose` for invalid axis indices.
  2. Propagate `NaN` in `min`, `max`, `argmin`, `argmax`, and `norm(double.infinity)` in `lib/src/tensor/operations/reduction.dart`, and allow `min(axis: ...)` / `max(axis: ...)` to delegate axis-length checks to `_reduceAxis` when `axis != null`.
  3. Add `@redeclare Float64Tensor slice(...)` to `Float64Tensor`.
  4. Add unit tests for all cases.
- **Verification**: `dart test test/tensor/`

### [ ] TASK-2.3: Fix `Blas` (`dnrm2`/`snrm2` Multi-Infinity `NaN`, `BlasNative` `alpha == 0`) & 0-Dimension `Matrix` / `matmul` Crashes
- **Files**:
  - `lib/src/acceleration/blas/blas_dart.dart` (lines 70–120)
  - `lib/src/acceleration/blas/blas_native.dart` (lines 365–405, 485–615, 810–975)
  - `lib/src/tensor/operations/matmul.dart` (lines 118–181)
  - `lib/src/linear/matrix.dart` (lines 422–820, 945–1205)
  - `lib/src/linear/vector.dart` (lines 280–290)
  - `lib/src/linear/float64_vector.dart`
  - `lib/src/linear/float64_matrix.dart`
  - `lib/src/linear/solvers/tridiagonal.dart` (lines 115–135)
  - `lib/src/linear/decomposition/norm.dart` (lines 30–45)
  - `test/acceleration/blas/blas_test.dart`
  - `test/linear/matrix_test.dart`
  - `test/tensor/operations/matmul_test.dart`
- **Problem**:
  - `BlasDart.dnrm2` and `BlasDart.snrm2` (`lib/src/acceleration/blas/blas_dart.dart:79–85, 106–112`) and `MatrixNormExtension.normFrobenius` (`lib/src/linear/decomposition/norm.dart:34–40`) compute `Infinity / Infinity = NaN` when two or more `double.infinity` values are present.
  - `BlasNative` does not short-circuit `alpha == 0.0` in `daxpy`, `saxpy`, `dsyr2`, `ssyr2`, `dgemv`, `sgemv`, `dsymm`, `ssymm`, `dtrmm`, `strmm`, causing `0.0 * NaN = NaN` discrepancy against `BlasDart`.
  - `_gemm2D` (`lib/src/tensor/operations/matmul.dart:157–177`) passes `lda = 0` to `Blas.dgemm` when multiplying `Matrix<double>.filled(2, 0, 0.0) * Matrix<double>.filled(0, 2, 0.0)` (`mDim > 1 && kDim == 0`), throwing `ArgumentError`.
  - `Matrix<double>.apply`, `Matrix.applyTranspose`, `Matrix.applyConjugateTranspose`, and `Matrix.syrk` (`lib/src/linear/matrix.dart:950–1195`) pass `lda = 0` or `ldc = 0` to `Blas` when `rowCount == 0` or `colCount == 0`, throwing `ArgumentError`.
  - `Matrix.matmul(LinearOperator<T> other)` (`lib/src/linear/matrix.dart:1114–1122`) throws `UnsupportedError` when `other` is a sparse matrix (`CooMatrix`, `CsrMatrix`, `CscMatrix`).
  - `Vector.norm(double.infinity)` (`lib/src/linear/vector.dart:281–288`) ignores `double.nan`.
  - `Matrix.solveVector` (`lib/src/linear/matrix.dart:422–546`) and `_solveUnderdeterminedVector` (`lines 769–805`) duplicate 155 lines of `Matrix.solve`, `Matrix.applyConjugateTranspose` (`lines 1076–1107`) duplicates 32 lines of `Matrix.applyTranspose` for `T == double`, and contiguous `Float64List` extraction is duplicated across `matrix.dart` and `tridiagonal.dart` (missed in previous `TASK-2.5`).
  - `Float64Vector` and `Float64Matrix` are missing `@redeclare` return types on `copy`, `normalized`, `cumsum`, `cumprod`, `hadamard`, `flippedHorizontal`, `flippedVertical`, `rotated`, `concatHorizontal`, `concatVertical`, `solve`, `solveVector`, `applyTranspose`, `applyConjugateTranspose`, and `syrk`.
- **Actions**:
  1. Fix `BlasDart.dnrm2`, `BlasDart.snrm2`, and `MatrixNormExtension.normFrobenius` to handle multiple `Infinity` values without dividing `Infinity / Infinity`. Add `alpha == 0.0` short-circuits in `BlasNative`.
  2. Guard `kDim == 0` in `_gemm2D` (`matmul.dart`) and guard `rowCount == 0 || colCount == 0` in `Matrix.apply`, `applyTranspose`, `applyConjugateTranspose`, and `syrk`.
  3. Support `LinearOperator<T>` (including sparse matrices) in `Matrix.matmul`, and propagate `NaN` in `Vector.norm(double.infinity)`.
  4. Deduplicate `Matrix.solveVector` (delegate to `solve(b.toMatrix()).col(0)` and remove `_solveUnderdeterminedVector`), deduplicate `Matrix.applyConjugateTranspose` (delegate to `applyTranspose(x)` when `T == double || T == int || T == num`), and share a single contiguous `Float64List` extraction helper.
  5. Add the missing `@redeclare` methods on `Float64Vector` and `Float64Matrix`.
- **Verification**: `dart test test/acceleration/blas/ test/linear/ test/tensor/operations/matmul_test.dart`

### [ ] TASK-2.4: Fix `LU`, `QR`, `Cholesky`, `solveIterative`, and Sparse Matrix Validation & `NaN` Handling
- **Files**:
  - `lib/src/linear/decomposition/lu.dart` (lines 20–56, 113–123, 184)
  - `lib/src/linear/decomposition/qr.dart` (lines 100–104, 265–275)
  - `lib/src/linear/decomposition/cholesky.dart` (lines 170–195)
  - `lib/src/linear/solvers/iterative.dart` (lines 125–132, 288–295)
  - `lib/src/linear/sparse/coo_matrix.dart` (lines 30–42)
  - `lib/src/linear/sparse/csr_matrix.dart` (lines 32–42, 80–92)
  - `lib/src/linear/sparse/csc_matrix.dart` (lines 32–42, 80–92)
  - `test/linear/decomposition/lu_test.dart`
  - `test/linear/decomposition/qr_test.dart`
  - `test/linear/decomposition/cholesky_test.dart`
  - `test/linear/solvers/iterative_test.dart`
  - `test/linear/sparse/sparse_test.dart`
- **Problem**:
  - `LUDecomposition.isNonsingular` (`lu.dart:118`) and `QRDecomposition.isFullRank` (`qr.dart:101`) return `true` when diagonal entries are `NaN` because `NaN == 0.0` and `NaN <= tol` are `false`.
  - `QRDecomposition._decomposeFloat64` (`qr.dart:267–272`) computes `Infinity / Infinity = NaN` when two `Infinity` values appear in a column.
  - `CholeskyDecomposition._decomposeGeneric` (`cholesky.dart:182–185`) divides by `_l.getUnchecked(k, k)` even when `_isSpd` is already `false` and the diagonal is `zero`, crashing with division-by-zero on exact fields (`Fraction`, `int`).
  - `_conjugateGradient` (`iterative.dart:128`) and `_gmres` (`iterative.dart:291`) check `res > tol`, which is `false` when `res` is `NaN`, silently returning a `NaN` vector instead of throwing `StateError`.
  - `CooMatrix`, `CsrMatrix`, and `CscMatrix` constructors only `assert` dimension and buffer invariants instead of throwing `ArgumentError` in production mode, and `CsrMatrix.get` / `CscMatrix.get` break early on `colIndices[ptr] > col` even if constructed with unsorted indices.
- **Actions**:
  1. Use `!(val.abs() > tol)` / `!val.isNaN` in `LUDecomposition.isNonsingular` and `QRDecomposition.isFullRank`; fix `Infinity / Infinity` scaling in `QRDecomposition._decomposeFloat64`; align `LuMatrixExtension.inverse` doc comment with `ArgumentError`.
  2. In `CholeskyDecomposition._decomposeGeneric`, abort or guard division when `_l.getUnchecked(k, k) == zero`.
  3. In `_conjugateGradient` and `_gmres`, use `!(norm <= tol)` so `NaN` residuals throw `StateError`.
  4. Replace constructor `assert`s in `CooMatrix`, `CsrMatrix`, and `CscMatrix` with explicit `ArgumentError` checks.
  5. Add unit tests for all cases.
- **Verification**: `dart test test/linear/`

---

## Phase 3: `special`, `polynomial`, `numeric`, `stats`, and `dataframe` Bugs & Charter Compliance

### [ ] TASK-3.1: Fix `special`, `polynomial`, and `numeric` Edge Cases
- **Files**:
  - `lib/src/special/hypergeometric.dart` (lines 105–130)
  - `lib/src/special/gamma.dart` (lines 270–282)
  - `lib/src/special/lambert_w.dart` (line 113)
  - `lib/src/polynomial/polynomial.dart` (lines 274–299)
  - `lib/src/polynomial/impl/compressed_polynomial.dart` (lines 25–40, 74, 390, 563–594)
  - `lib/src/polynomial/rational.dart` (lines 74–90)
  - `lib/src/numeric/optimization/constrained.dart` (lines 355–375)
  - `lib/src/numeric/ode/solve_ode.dart` (lines 465–485)
  - `lib/src/numeric/curve_fit.dart` (lines 42–88, 334)
  - `lib/src/numeric/integration.dart` (line 25)
  - `test/special/hypergeometric_test.dart`
  - `test/special/gamma_test.dart`
  - `test/polynomial/polynomial_test.dart`
  - `test/polynomial/rational_test.dart`
  - `test/numeric/optimization/constrained_test.dart`
  - `test/numeric/ode/solve_ode_test.dart`
  - `test/numeric/ode/ode_method_test.dart` (new 1:1 test file)
  - `test/numeric/root_finding/root_method_test.dart` (new 1:1 test file)
- **Problem**:
  - `hypergeometric2F1` (`lib/src/special/hypergeometric.dart:109, 121–125`): At $z \in [0.9, 1.0]$, when $c - a \in \mathbb{Z}_{\le 0}$ or $c - b \in \mathbb{Z}_{\le 0}$ (e.g. `hypergeometric2F1(0.5, 1.5, 1.5, 0.95)`), `gamma(cd - bd)` is `NaN` at the pole instead of `1 / gamma(cd - bd) = 0` annihilating `term1`, returning `NaN` instead of $(1 - z)^{-a}$.
  - `combination` (`lib/src/special/gamma.dart:273–276`): Checks `choose == total` before `total.isInfinite` (`combination(double.infinity, double.infinity)` returns `1.0` instead of `double.nan`), and `if (total.isInfinite)` does not check `choose.floorToDouble() == choose` (`combination(double.infinity, 1.5)` returns `double.infinity` instead of `double.nan`).
  - `Polynomial.operator ==` (`lib/src/polynomial/polynomial.dart:276`) and `CompressedPolynomial.operator ==` (`lib/src/polynomial/impl/compressed_polynomial.dart:565`) do not check `type == other.type`, breaking the `==`/`hashCode` contract when `Polynomial<num>` instances have different `DataType`s (`int32` vs `float64`), and `hashCode` returns `0` when `deg < 0`.
  - `RationalFunction.simplify` (`lib/src/polynomial/rational.dart:74–90`) densifies sparse `CompressedPolynomial`s via `Polynomial<T>.fromCoefficients(List<T>.generate(deg + 1, ...))` instead of using `.scale(invLc)`.
  - `_BoxTransform.toY` (`lib/src/numeric/optimization/constrained.dart:363, 366, 369`) regressed in commit `cb2c286` to `.clamp(0.05, 0.95)` and `1e-4` (displacing initial guesses within 5% of bounds) instead of `1e-12` (`clamp(1e-12, 1.0 - 1e-12)`).
  - `_interpolateHermite` (`lib/src/numeric/ode/solve_ode.dart:479–481`) still uses an $O(N)$ linear scan when `tEnd < t0` (`!isAscending`) instead of binary search.
  - `leastSquares` (`lib/src/numeric/curve_fit.dart:42–88`) crashes with `ArgumentError` on empty (`0x0` or `Mx0`) matrices because `lda: cols` is `0`.
  - Missing 1:1 test files `test/numeric/ode/ode_method_test.dart` and `test/numeric/root_finding/root_method_test.dart`.
- **Actions**:
  1. Fix `hypergeometric2F1` pole annihilation at $z \in [0.9, 1.0]$ when $c - a$ or $c - b$ is a non-positive integer; fix `combination` infinity checks in `gamma.dart`; remove redundant `const _e = e;` in `lambert_w.dart`.
  2. Fix `Polynomial` and `CompressedPolynomial` `==` / `hashCode` consistency, preserve `CompressedPolynomial` in `RationalFunction.simplify` via `.scale(invLc)`, and move private constructor `CompressedPolynomial._` after public factories.
  3. Fix `_BoxTransform.toY` clamping to `1e-12` in `constrained.dart`, use binary search for descending `t` in `_interpolateHermite` (`solve_ode.dart`), guard empty matrices in `leastSquares` (`curve_fit.dart`), add missing `///` doc comments on `IntegrationIssue.new` and `LevenbergMarquardtResult.new`, and create `test/numeric/ode/ode_method_test.dart` and `test/numeric/root_finding/root_method_test.dart`.
- **Verification**: `dart test test/special/ test/polynomial/ test/numeric/`

### [ ] TASK-3.2: Fix `stats` Distribution `NaN`/`Infinity` Validation, Zero-Variance Skewness/Kurtosis, and Charter Compliance
- **Files**:
  - `lib/src/stats/descriptive.dart` (lines 596, 622)
  - `lib/src/stats/pca.dart` (lines 11, 56–57, 98)
  - `lib/src/stats/hypothesis/hypothesis_test_result.dart` (line 19)
  - `lib/src/stats/resampling/bootstrap.dart` (lines 40–66)
  - `lib/src/stats/distributions/continuous/*.dart`
  - `lib/src/stats/distributions/discrete/*.dart`
  - `lib/src/stats/distributions/multivariate/*.dart`
  - `test/stats/`
- **Problem**:
  - Sample `_skewness` (`lib/src/stats/descriptive.dart:596`) and `_kurtosis` (`line 622`) return `0.0` instead of `double.nan` when `m2 == 0.0` (zero variance), inconsistent with distribution `skewness`/`excessKurtosis` and `correlation`.
  - Distribution constructors across `continuous/`, `discrete/`, and `multivariate/` use inequalities like `alpha <= 0` that evaluate to `false` when `double.nan` is passed, allowing `NaN` parameters (and `infinite` parameters where finite values are required, or `populationSize == 0` in `HypergeometricDistribution`, or `dimensions == 0` in `MultivariateNormalDistribution`) to bypass `ArgumentError` validation.
  - `probability(double.nan)` and `cumulativeProbability(double.nan)` return `0.0` or `1.0` instead of `double.nan` in `DegenerateDistribution`, `ExponentialDistribution`, and `UniformDistribution`; `probability(double.infinity)` returns `double.nan` instead of `0.0` in `GammaDistribution`, `WeibullDistribution`, and `FDistribution`.
  - `DirichletDistribution.logProbability` (`lib/src/stats/distributions/multivariate/dirichlet.dart:103–118`) returns `double.infinity` or `-double.infinity` on the first coordinate `xi <= 0` before validating the remaining coordinates for `NaN`, `< 0`, or simplex sum `1.0`.
  - `BinomialDistribution.fit` and `PoissonDistribution.fit` throw `UnsupportedError` on `NaN`/`Infinity` samples, and `BinomialDistribution.fit` silently clamps `prob` instead of throwing `ArgumentError` when `n < maxVal`.
  - `UniformDistribution`, `UniformDiscreteDistribution`, and `MultinomialDistribution` allocate a new `Random()` on every `.sample()` call instead of reusing a file-private `_random`.
  - Charter violations: `std!` in `pca.dart`, member ordering in `bootstrap.dart` and `multivariate_normal.dart`, missing `///` doc comments on `PcaResult.new` and `HypothesisTestResult.new`.
- **Actions**:
  1. Return `double.nan` when `m2 == 0.0` in `_skewness` and `_kurtosis` (`descriptive.dart`).
  2. Harden parameter validation across all distribution constructors against `NaN`/`Infinity` (and require `populationSize >= 1` in `HypergeometricDistribution`, `dimensions >= 1` in `MultivariateNormalDistribution`, and `n >= maxVal` with finite samples in `BinomialDistribution.fit` / `PoissonDistribution.fit`).
  3. Fix `probability` and `cumulativeProbability` for `NaN` and `Infinity` inputs across `DegenerateDistribution`, `ExponentialDistribution`, `UniformDistribution`, `GammaDistribution`, `WeibullDistribution`, `FDistribution`, and `DirichletDistribution.logProbability`.
  4. Reuse file-private `_random` in `uniform.dart`, `discrete/uniform.dart`, and `multinomial.dart`, and fix charter/ordering/doc issues in `pca.dart`, `bootstrap.dart`, `multivariate_normal.dart`, and `hypothesis_test_result.dart`.
- **Verification**: `dart test test/stats/`

### [ ] TASK-3.3: Fix `dataframe` 64-Bit Integer Truncation, `GroupBy`/`describe` `NaN` Propagation, `Join` Type Promotion, and Charter Compliance
- **Files**:
  - `lib/src/dataframe/series.dart` (lines 24, 205, 338–348, 573, 706)
  - `lib/src/dataframe/dataframe.dart` (lines 84, 117–118, 282–335, 581)
  - `lib/src/dataframe/groupby.dart` (lines 73–75, 112–207, 254–275)
  - `lib/src/dataframe/join.dart` (lines 119–139, 238)
  - `lib/src/dataframe/arrow_string_series.dart` (lines 30–53, 230–236, 321, 333)
  - `lib/src/dataframe/csv/csv_stream.dart` (lines 23–143, 185–189, 268–278)
  - `lib/src/dataframe/json/json_stream.dart` (lines 17–91)
  - `lib/src/dataframe/json/json_decoder.dart` (line 287)
  - `lib/src/dataframe/arrow/arrow_ipc.dart` (lines 12–38, 317, 389, 521)
  - `test/dataframe/`
- **Problem**:
  - `TypedSeries.fromList` (`lib/src/dataframe/series.dart:339–347`) and `CsvStream._buildDataFrame` (`lib/src/dataframe/csv/csv_stream.dart:185–188`) still default `int` lists to `DataType.int32` (`Int32List`), silently truncating 64-bit integers outside `[-0x80000000, 0x7FFFFFFF]` (skipped in previous `TASK-4.3`).
  - `GroupBy` `Agg.min` and `Agg.max` (`lib/src/dataframe/groupby.dart:254–275`) and `DataFrame.describe` (`lib/src/dataframe/dataframe.dart:282–335`) do not propagate `double.nan` because `double.compareTo` sorts `NaN` after finite numbers.
  - `DataFrame.join` (`lib/src/dataframe/join.dart:136`) uses `leftCol.dataType` instead of `leftCol.dataType.promoteWith(rightCol.dataType)` for shared `on` key columns, failing on `JoinType.right` / `JoinType.outer` when the right key column has a wider type.
  - `ArrowStringSeries` constructor (`lib/src/dataframe/arrow_string_series.dart:30–53`) does not validate that `offsets` is monotonically non-decreasing (`offsets[i] <= offsets[i + 1]`), and `ArrowStringSeries.slice` (`line 230`) does not normalize an all-valid mask (`nullCount == 0`) to `null`.
  - `_CsvEventSink.add` (`lib/src/dataframe/csv/csv_stream.dart:268–278`) drops empty lines in single-column CSVs instead of emitting a `[null]` row.
  - Charter violations: `dynamic` in `csv_stream.dart` and `json_stream.dart`, `!` assertions across `dataframe`, member ordering in `series.dart`, `dataframe.dart`, `groupby.dart`, `arrow_ipc.dart` (plus swapped destructuring names `final (nullCount, length) = node;` at `arrow_ipc.dart:389`), and missing `///` doc comments on `Series` constructors.
- **Actions**:
  1. In `TypedSeries.fromList` and `CsvStream._buildDataFrame`, select `DataType.int64` when any `int` element is outside 32-bit signed range `[-0x80000000, 0x7FFFFFFF]`.
  2. Propagate `double.nan` in `GroupBy` `Agg.min`/`Agg.max` and `DataFrame.describe()`.
  3. Promote shared key column types via `leftCol.dataType.promoteWith(rightCol.dataType)` in `join.dart` and use `RowKeyExtractor.hasNull`.
  4. Validate monotonic `offsets` in `ArrowStringSeries`, normalize `newMask.nullCount == 0 ? null : newMask` in `ArrowStringSeries.slice`, and preserve empty lines as `[null]` in `csv_stream.dart`.
  5. Replace `dynamic` with `Object?` in `csv_stream.dart` and `json_stream.dart`, remove avoidable `!` operators, fix member ordering and swapped variable names in `arrow_ipc.dart:389`, and add missing `///` doc comments in `series.dart`.
- **Verification**: `dart test test/dataframe/`

---

## Phase 4: `symbolic` and `web` Bugs, Edge Cases & Charter Compliance

### [ ] TASK-4.1: Fix Indefinite `Integral` Free Variables & Differentiation, Definite Pole Detection on Infinite Intervals, and `Summation` Product Fallback
- **Files**:
  - `lib/src/symbolic/ast/integral.dart` (lines 85–125)
  - `lib/src/symbolic/calculus/differentiation.dart` (lines 30–35, 210–225)
  - `lib/src/symbolic/calculus/integration.dart` (lines 140–160)
  - `lib/src/symbolic/calculus/summation.dart` (line 706)
  - `test/symbolic/ast/integral_test.dart`
  - `test/symbolic/calculus/differentiation_test.dart`
  - `test/symbolic/calculus/integration_test.dart`
  - `test/symbolic/calculus/summation_test.dart`
- **Problem**:
  - `Integral.freeVariables` (`lib/src/symbolic/ast/integral.dart:88`) and `Integral.dependsOn` (`line 96`) exclude `this.variable` even when the integral is **indefinite** (`!isDefinite`). Consequently, differentiating an unevaluated indefinite integral `Integral(Sin(x ^ 2), 'x').derivative('x')` hits `if (!current.dependsOn(variable)) return IntegerNumber.zero;` in `differentiation.dart:33` and returns **`0`** instead of `Sin(x ^ 2)` (violating the Fundamental Theorem of Calculus and making `differentiation.dart:215–218` unreachable!).
  - In `Integral.substitute` (`lib/src/symbolic/ast/integral.dart:106–121`), the `!isDefinite` branch when `variable == this.variable && replacement is Variable` alpha-renames `boundVar` to `fresh` and immediately substitutes `fresh` with `replacement` (a no-op that fails to alpha-rename if `replacement.name` occurs free in `body`).
  - In `integrate` (`lib/src/symbolic/calculus/integration.dart:144`), interior pole detection is skipped whenever either bound is infinite (`!_isInfiniteBound(fromExpr) && !_isInfiniteBound(toExpr)`), causing `(x ^ -2).integrate('x', from: -Constant.infinity, to: Constant.infinity)` to return `0` and `(x ^ -2).integrate('x', from: -1, to: Constant.infinity)` to return `-1` despite the non-integrable pole at $x = 0$.
  - In `_closedFormProduct` (`lib/src/symbolic/calculus/summation.dart:706`), `if (expSum is! VariableFunction || expSum.name != 'sum')` checks for the legacy `VariableFunction('sum')` instead of `expSum is! Sum`, wrapping unevaluated `Sum` nodes into `Pow(Constant.e, Sum(...))` instead of returning an unevaluated `Product`.
- **Actions**:
  1. In `Integral.freeVariables` and `Integral.dependsOn`, keep `variable` free when `!isDefinite` (only bound when `isDefinite`), and fix `Integral.substitute` for indefinite integrals.
  2. Extend interior pole detection in `lib/src/symbolic/calculus/integration.dart:144` to semi-infinite $[a, \infty)$, $(-\infty, b]$ and doubly-infinite $(-\infty, \infty)$ intervals by checking whether any pole of the integrand lies strictly inside the open/half-open interval (e.g. `pole >= low - 1e-12` for $[a, \infty)$, `pole <= high + 1e-12` for $(-\infty, b]$, or any real pole for $(-\infty, \infty)$).
  3. Change `summation.dart:706` to `if (expSum is! Sum)`.
  4. Add unit tests for all 4 cases.
- **Verification**: `dart test test/symbolic/ast/integral_test.dart test/symbolic/calculus/`

### [ ] TASK-4.2: Fix Remaining `RealNumber` Contagion Gaps, `ExprField.conjugate`, `isIntegerExpr` False Positives, Parser Constant Shadowing, and `Derivative.format` Round-Tripping
- **Files**:
  - `lib/src/symbolic/type/expr_data_type.dart` (lines 51, 182–183)
  - `lib/src/symbolic/ast/number.dart` (lines 690–698)
  - `lib/src/symbolic/algebra/term_accumulator.dart` (lines 285–296, 755–760, 807, 844–845, 895–896)
  - `lib/src/symbolic/algebra/simplify/transcendental.dart` (lines 588–612, 1356–1465, 1565–1585)
  - `lib/src/symbolic/calculus/integration.dart` (lines 1510–1518)
  - `lib/src/symbolic/parser.dart` (lines 506–646)
  - `lib/src/symbolic/textualization/string.dart` (lines 100–106)
  - `test/symbolic/`
- **Problem**:
  - `ExprField.conjugate` (`lib/src/symbolic/type/expr_data_type.dart:182–183`) calls `Conjugate(a).simplify(assumptions: Assumptions.real)` instead of `Conjugate(a).simplify()`, stripping `Conjugate` from complex variables in `Matrix<Expr>.conjugateTranspose`. Also `ExprDataType.cast` (`line 51`) uses `dynamic` instead of `Object?`.
  - Remaining `RealNumber` contagion gaps:
    - `ComplexNumber.of(real, imaginary)` (`number.dart:694`): When `imaginary` is `RealNumber(0.0)` and `real` is `RationalNumber`, demotes to exact `real` instead of `RealNumber(real.toDouble())`.
    - `term_accumulator.dart` (`polynomialDegree`, `extractPolynomialCoefficients`, `_extractBaseMonomial`, `_asPositiveInt`, `_isTwo`) and `integration.dart` (`_extractSquareBase`): Convert `RealNumber` exponents into exact `IntegerNumber` exponents or `IntegerNumber.one` in $\sin^2(x) + \cos^2(x)$.
    - `simplifyMod`, `simplifyRe`, `simplifyIm`, `simplifyArg`, and `toPolarExpr` (`transcendental.dart:1356–1585`): Return exact `IntegerNumber.zero` or symbolic `Constant.pi` multiples on `RealNumber` inputs instead of `RealNumber`.
  - `isIntegerExpr` (`transcendental.dart:589–605`) unconditionally returns `true` for `Factorial(expr)`, `Binomial(left, right)`, and `Sign(expr)` without checking their arguments (so `Floor(Factorial(1/2)).simplify()` returns `Factorial(1/2)` and `Sin(Factorial(1/2) * pi).simplify()` returns `0`).
  - `Expr.parse` (`lib/src/symbolic/parser.dart:506–646`): In `sum(i, i, 1, 10)`, `product(i, i, 1, 4)`, `integrate(e, e)`, `diff(e^2, e)`, and `limit(e, e, 0)`, the body expression is parsed with `i`/`e`/`pi` mapped to `ExprSyntax.standardConstants` (`ComplexNumber.i`, `Constant.e`, `Constant.pi`) before binding the dummy variable name, so `Expr.parse('sum(i, i, 1, 10)').simplify()` evaluates to `10 * i` instead of `55`!
  - `Derivative.format` (`lib/src/symbolic/textualization/string.dart:104`) emits 3-argument `'diff(f, x, pt)'` when `order == 1 && point != null`, which `Expr.parse` (`parser.dart:531–550`) misparses as `order = pt` (throwing `FormatException` when `pt` is symbolic or turning `point: 2` into `order: 2, point: null`).
- **Actions**:
  1. Change `ExprField.conjugate` back to `Conjugate(a).simplify()` and change `dynamic` to `Object?` in `ExprDataType.cast`.
  2. Fix the `RealNumber` contagion gaps in `ComplexNumber.of`, `term_accumulator.dart`, `integration.dart`, and `transcendental.dart` (`simplifyMod`, `simplifyRe`, `simplifyIm`, `simplifyArg`, `toPolarExpr`).
  3. Tighten `isIntegerExpr` in `transcendental.dart`: `Factorial(expr)` requires `isIntegerExpr(expr) && isNonNegativeExpr(expr)`, `Binomial(n, k)` requires `isIntegerExpr(n) && isIntegerExpr(k)`, and `Sign(expr)` requires `isProvenReal(expr, assumptions)`.
  4. In `parser.dart` (`integrate`, `diff`, `limit`, `sum`, `product`), when the bound variable name matches a standard constant (`i`, `e`, `pi`), substitute that constant back to `Variable(varName)` in the body (or parse with `varName` shadowing `standardConstants`).
  5. In `string.dart:104`, always format `Derivative` with `point != null` using 4 arguments `'diff($exprStr, $variable, $order, $pt)'` so `Expr.parse(d.format()) == d`.
  6. Add unit tests covering all cases.
- **Verification**: `dart test test/symbolic/`

### [ ] TASK-4.3: Propagate `Assumptions` Completely Across `rational.dart`, `trig.dart`, `limit.dart`, `solver/`, and Calculator `linear.dart`
- **Files**:
  - `lib/src/symbolic/algebra/rational.dart` (lines 62, 101, 232, 250–572)
  - `lib/src/symbolic/algebra/trig.dart` (lines 42–85, 90–450)
  - `lib/src/symbolic/calculus/limit.dart` (lines 95–195)
  - `lib/src/symbolic/solver/univariate.dart` (lines 49–65)
  - `lib/src/symbolic/solver/system.dart` (lines 105–130)
  - `lib/src/symbolic/solver/polynomial_system.dart` (lines 40–70)
  - `web/calculator/src/engine/commands/linear.dart` (lines 31, 51, 121, 163, 183, 207, 228, 324, 350–352, 378, 392)
  - `test/symbolic/algebra/rational_test.dart`
  - `test/symbolic/algebra/trig_test.dart`
  - `test/symbolic/calculus/limit_test.dart`
  - `test/symbolic/solver/system_test.dart`
- **Problem**:
  - `together`, `collect`, and `apart` in `rational.dart` accept `{Assumptions assumptions = Assumptions.none}` at the top level, but internal helpers (`_togetherExpr`, `_togetherMul`, `_togetherPow`, `_togetherAdd`, `_collectAdditive`, `apart` body) call `.simplify()`, `simplifyMul`, `simplifyPow`, `simplifyAdd` without forwarding `assumptions`.
  - `expandTrig`, `simplifyTrig`, and `rewrite` in `trig.dart` do not forward `assumptions` into `_expandTrigExpr`, `_simplifyTrigExpr` (which calls `.cancel()` with `Assumptions.none` at line 333), `_rewriteToSinCos`, `_rewriteToExp`, or `_rewriteToTrig`.
  - `computeLimit` in `limit.dart` does not forward `assumptions` into `_computeFiniteLimit` or `_computeInfiniteLimit` (so `Limit(Sqrt(x^2)/x, 'x', 0).evaluateLimit(assumptions: Assumptions.positive)` fails to simplify `Sqrt(x^2)` to `x` during limit evaluation).
  - `solveEquation` (`univariate.dart:54`), `solveEquations` (`system.dart:109–123`), and `solvePolynomialSystemEquations` (`polynomial_system.dart:45–65`) do not forward `assumptions` into `_solveUnfiltered` or filter multivariate system solutions by `assumptions` (e.g. `Assumptions.real` or `Assumptions.positive`).
  - Calculator commands in `web/calculator/src/engine/commands/linear.dart` (`det`, `inv`, `charpoly`, `rref`, `nullspace`, `eigenvals`, `eigenvects`, `dot`, `cross`, `norm`) omit `assumptions: ctx.assumptions`.
- **Actions**:
  1. Thread `assumptions` through all internal helpers in `rational.dart`, `trig.dart`, and `limit.dart`.
  2. Pass `assumptions` into `_solveUnfiltered` in `univariate.dart` and filter multivariate system solutions against `assumptions` in `system.dart` and `polynomial_system.dart`.
  3. Pass `assumptions: ctx.assumptions` across all matrix/vector commands in `web/calculator/src/engine/commands/linear.dart`.
  4. Add unit tests verifying domain-dependent behavior (e.g. `Sqrt(x^2)` under `Assumptions.positive`, real/positive filtering in `solveEquations`).
- **Verification**: `dart test test/symbolic/ test/web/calculator/`

### [ ] TASK-4.4: Fix Web Calculator `AngleMode.deg` Plotting Bugs, Bound Parameter `i`/`e`/`pi` Shadowing, Window Listener Leaks, and `sw.js` Network-First Navigation
- **Files**:
  - `web/calculator/src/engine/sampling.dart` (lines 45–55, 160–170, 464–475)
  - `web/calculator/src/ui/plot_view.dart` (lines 208–218)
  - `web/calculator/src/language/grammar.dart` (lines 155–170)
  - `web/calculator/src/engine/evaluator.dart` (lines 420–490, 809–827)
  - `web/shared/chart.dart` (lines 545–570)
  - `web/shared/webgl_surface.dart` (lines 115–140)
  - `web/calculator/sw.js` (lines 40–58)
  - `test/web/calculator/evaluator_test.dart`
  - `test/web/calculator/worker_test.dart`
- **Problem**:
  - In `web/calculator/src/ui/plot_view.dart:208–216`, moving a parameter slider on a parametric plot calls `buildParametricPlotValue` without passing `angleMode: plot.isDegrees ? AngleMode.deg : AngleMode.rad`.
  - In `web/calculator/src/engine/sampling.dart:51, 164, 464–475`, `_convertTrigArgToDegrees` runs AFTER `_substituteParams` and multiplies the argument of every `Sin`, `Cos`, `Tan` node by `pi / 180` unconditionally — even when a constant trig subexpression like `sin(30)` in `plot(sin(x) + sin(30), x, 0, 360)` was ALREADY multiplied by `pi / 180` in `CalcEvaluator._constructUnaryFunction` (`evaluator.dart:815`). It also ignores `Asin`, `Acos`, `Atan`.
  - In `web/calculator/src/language/grammar.dart:161–162`, `CallOrSymbol` converts `i`, `e`, `pi` into `ExprLeafNode(stdConst)` at parse time before `boundParams` is checked in `evaluator.dart`, so user functions like `f(i) := i^2` or `sum(i, i, 1, 10)` in the calculator treat `i` as $\sqrt{-1}$ instead of the parameter/index `i`.
  - `web/shared/chart.dart:548, 560` and `web/shared/webgl_surface.dart:118, 129` attach `web.window.addEventListener('mousemove' / 'mouseup', ...)` on construction instead of attaching during drag (`mousedown` → `mouseup`), leaking window listeners when plots are re-rendered (skipped in previous `TASK-6.3`).
  - `web/calculator/sw.js:43–57` still uses strict `caches.match` cache-first without network-first / stale-while-revalidate fallback, preventing app updates (skipped in previous `TASK-6.3`).
  - `test/web/calculator/worker_test.dart:7` has a single top-level `group(...)`, violating `AGENTS.md`.
- **Actions**:
  1. Pass `angleMode` to `buildParametricPlotValue` in `plot_view.dart:208–216`.
  2. In `sampling.dart`, run `_convertTrigArgToDegrees` BEFORE `_substituteParams`, only convert `Sin`/`Cos`/`Tan` (and `Asin`/`Acos`/`Atan` output by `180 / pi`) when `expr.freeVariables.isNotEmpty` (since constant-argument trig calls were already converted in `evaluator.dart`), and add unit tests in `test/web/calculator/evaluator_test.dart`.
  3. Allow bound parameters and summation/product/calculus dummy variables to shadow `i`, `e`, `pi` in `grammar.dart` / `evaluator.dart`.
  4. Attach window `mousemove`/`mouseup` listeners only while dragging in `web/shared/chart.dart` and `web/shared/webgl_surface.dart`.
  5. Update `web/calculator/sw.js` fetch handler to network-first with cache fallback.
  6. Split the single top-level `group` in `test/web/calculator/worker_test.dart` into multiple functional `group`s.
- **Verification**: `dart test test/web/calculator/`

---

## Phase 5: Dead, Unreachable & Redundant Code Elimination

>Every line below was identified via coverage analysis and static flow inspection as mathematically or structurally unreachable, unused, or redundant. Remove or simplify these directly so no dead code remains in `lib/` or `web/`.

### [ ] TASK-5.1: Remove Unreachable & Dead Code Across `type`, `tensor`, `acceleration`, `linear`, `numeric`, `stats`, and `dataframe`
- **Files & Exact Targets**:
  1. **`lib/src/type/models/field.dart` (lines 6, 87) & `lib/src/type/models/equality.dart` (line 6)**:
     - `Field`, `ExtendedField`, and `Equality` are declared `abstract interface class` (which cannot be extended, only implemented), making their `const new();` constructors 100% unreachable. Remove `const new();` from those three `abstract interface class`es.
  2. **`lib/src/tensor/operations/operation.dart` (lines 114, 116, 118, 163)**:
     - Inside `if (target == null)`, `final resultType = type ?? target?.type ?? ...` evaluates `target?.type` when `target` is known to be `null`. Simplify to `final resultType = type ?? ...`.
  3. **`lib/src/acceleration/blas/blas_dart.dart` (lines 73, 100, 173, 189)**:
     - `var ix = xOffset + (incX < 0 ? (1 - n) * incX : 0);` immediately follows `if (n <= 0 || incX <= 0) return ...;`. Simplify to `var ix = xOffset;`.
  4. **`lib/src/linear/decomposition/eigenvalue.dart` (lines 463–468, 869–877)**:
     - `low` is `0` and `high` is `nn - 1` (`_n - 1`), so `if (i < low || i > high)` is 100% unreachable in `_orthes`/`_hqr2`. Remove the dead branches.
  5. **`lib/src/numeric/optimization.dart` (lines 78–79, 183–184)**:
     - Remove the duplicate `hasConstraints` check at lines 78–79 and the unreachable `case OptimizationMethod.brent:` branch at lines 183–184 (`brent` already returns at line 86).
  6. **`lib/src/stats/distributions/discrete/negative_binomial.dart` (lines 66–67, 74–75)**:
     - Remove unreachable `if (p == 0)` and `if (p == 1)` checks in `probability` and `cumulativeProbability` (constructor enforces `0 < p < 1`).
  7. **`lib/src/dataframe/tuple_key.dart` (lines 38–43)**:
     - Remove unused top-level `extractKey(List<Object?> values)` function.
- **Verification**: `dart analyze && dart test`

### [ ] TASK-5.2: Remove Unreachable & Duplicate Code Across `symbolic` and `web/calculator`
- **Files & Exact Targets**:
  1. **`lib/src/symbolic/algebra/simplify/transcendental.dart`**:
     - **Lines 54–64, 73–79, 88–90 (`simplifySin`), lines 136–146, 155–161, 170–174 (`simplifyCos`), lines 223, 232–240, 249–250 (`simplifyTan`)**: `piMult` is a reduced `RationalNumber` ($\gcd(\text{num}, \text{den}) = 1$), so non-coprime remainder cases (`case 2 || 4:`, `case 8 || 10:`, `case 3:`, `case 9:`, `case 0 || 6:` when `den == 6`; `case 2:`, `case 6:`, `case 0 || 4:` when `den == 4`; `case 0 || 3:` when `den == 3`) are 100% mathematically impossible. Remove all non-coprime remainder branches.
     - **Line 315 (`simplifyAcos`)**: `if (posExpr is Number && posExpr.isOne) return Constant.pi;` inside `if (isNeg)` is unreachable because `expr.isNegativeOne` already returned at line 309. Remove line 315.
     - **Lines 1216–1217 (`simplifyFloor`), 1251–1252 (`simplifyCeil`), 1286–1287 (`simplifyRound`)**: `case IntegerNumber(): return expr;` is unreachable because `if (isIntegerExpr(expr, assumptions: assumptions)) return expr;` already returned on the preceding line. Remove the redundant `case IntegerNumber():` branches.
     - **Lines 1580–1586 (`toPolarExpr`)**: Remove unreachable `if (r is Number && r.isZero)` (already handled at line 1565) and `if (theta is Arg && re is RealNumeric && im is RealNumeric && !im.isZero)` (already handled by `simplifyArg(ComplexNumber)`).
     - **Lines 1606–1614, 1623–1632 (`_decomposeComplex`)**: `case RealNumeric():`, `case Constant():`, `case Re():`, and `case Im():` are unreachable because `if (isProvenReal(expr, assumptions))` already returned `(re: expr, im: IntegerNumber.zero)` at line 1602. Remove those 4 unreachable switch cases.
  2. **`lib/src/symbolic/calculus/series.dart` (lines 65, 135–191, 259–270)**:
     - In `toPolynomial` (lines 80–191), `toPowerSeries` handles all supported analytic expansions. When `ps.poleOrder > 0`, throw `UnsupportedError('Cannot convert Laurent series with pole to Polynomial')`, and remove the 57-line duplicate differentiation fallback (lines 135–191).
     - Fix doc comment at line 65 (`Exp(x)` → `Pow(Constant.e, x)`) and move private `_checkCompatible` (line 259) below public methods in `PowerSeries`.
  3. **`lib/src/symbolic/ast/expr.dart` (lines 57–59) & `lib/src/symbolic/ast/number.dart` (lines 208, 218)**:
     - Remove unreachable `if (value is int)` inside `if (value is double)` in `expr.dart:57–59`, and simplify unreachable `: IntegerNumber.one` fallback in `_powReal` (`number.dart:208, 218`).
  4. **`lib/src/symbolic/algebra/simplify/power.dart` (lines 352–357) & `lib/src/symbolic/solver/polynomial.dart` (lines 110–120)**:
     - Remove unused `foldRationalPower` in `power.dart` (update `test/symbolic/algebra/simplify/power_test.dart` to test `RationalNumber.pow` / `simplifyPow` directly) and replace `sqrtConstant(c)` in `polynomial.dart` with `Pow(c, FractionNumber.half).simplify()`.
  5. **`lib/src/symbolic/calculus/summation.dart` (lines 990–993) & `lib/src/symbolic/calculus/integration.dart` (lines 2094–2123)**:
     - Remove the duplicate `if (inner == Constant.infinity ...)` branch in `summation.dart:990–993` that returns the exact same expression as line 993, and deduplicate `_evenZetaIntegralValue` (`integration.dart:2094–2123`) with `summation.dart`.
  6. **Member Ordering Fixes in `symbolic`**:
     - Move private methods below public members in `lib/src/symbolic/solver/multivariate_polynomial.dart:188–208` and `lib/src/symbolic/solver/trigonometric.dart:9–17`.
  7. **`web/calculator/src/engine/commands.dart` (line 55) & `web/calculator/src/model/stack.dart` (lines 204–212)**:
     - Remove unused `const new(this.name, [this.kind = ParamKind.expr]);` in `ParamSpec` (`commands.dart:55`).
     - In `web/calculator/src/engine/rpn.dart:235`, call `stack.pushDepth()` (or remove unused `RpnStack.pushDepth` from `stack.dart:204–212`).
- **Verification**: `dart analyze && dart test`

---

## Phase 6: Near-100% Meaningful Unit Test Coverage Across All Subsystems

>Goal: Reach **≥ 99% line coverage across `lib/`** (and comprehensive coverage across `web/calculator/src/{engine,language,model,worker}/`) by marking native FFI bindings and conditional platform stubs with `// coverage:ignore-file` and writing meaningful unit tests for every remaining uncovered branch.

### [ ] TASK-6.1: Mark Native FFI Bindings & Conditional Platform Stubs with `// coverage:ignore-file` and Test Public Barrel Exports
- **Files**:
  - Add `// coverage:ignore-file` at the top of FFI binding and conditional platform stub files:
    - `lib/src/acceleration/blas/blas_ffi.dart`
    - `lib/src/acceleration/blas/blas_native.dart`
    - `lib/src/acceleration/blas/blas_stub.dart`
    - `lib/src/acceleration/fft/fft_ffi.dart`
    - `lib/src/acceleration/fft/fft_native.dart`
    - `lib/src/acceleration/fft/fft_stub.dart`
    - `lib/src/acceleration/lapack/lapack_ffi.dart`
    - `lib/src/acceleration/lapack/lapack_native.dart`
    - `lib/src/acceleration/lapack/lapack_stub.dart`
    - `lib/src/acceleration/vforce/vforce_ffi.dart`
    - `lib/src/acceleration/vforce/vforce_native.dart`
    - `lib/src/acceleration/vforce/vforce_stub.dart`
    - `lib/src/acceleration/utils/library_loader_ffi.dart`
    - `lib/src/acceleration/utils/library_loader_stub.dart`
    - `lib/src/dataframe/arrow/arrow_c_data_ffi.dart`
    - `lib/src/dataframe/arrow/arrow_c_data_stub.dart`
- **Verification**: Run coverage collection and verify no FFI/stub files pollute the LCOV report.

### [ ] TASK-6.2: Unit Tests for `type`, `tensor`, `acceleration`, and `linear` Uncovered Branches
- **Target Files & Missing Test Cases**:
  1. **`lib/src/acceleration/blas/blas_dart.dart`** (`test/acceleration/blas/blas_test.dart`):
     - Test `Blas.sgemm` with blocked matrix dimensions ($M, N, K = 72 \ge 64$) for all 4 transpose combinations (`NoTrans`/`NoTrans`, `Trans`/`NoTrans`, `NoTrans`/`Trans`, `Trans`/`Trans`) and `beta == 0.0` vs `beta != 0.0`.
     - Test `Blas.dtrmv` and `Blas.strmv` across all combinations of `uplo` (`cblasUpper`, `cblasLower`), `transA` (`cblasNoTrans`, `cblasTrans`), and `diag` (`cblasNonUnit`, `cblasUnit`).
     - Test `Blas.dsyr2` and `Blas.ssyr2` with `cblasLower` and `alpha != 1.0`.
     - Test `Blas.ssyrk` with `cblasLower` / `cblasUpper`, `cblasTrans`, and `beta != 1.0`.
     - Test `Blas.dsymm` and `Blas.ssymm` with `side: cblasRight`, `uplo: cblasLower`, and `beta != 0.0`.
     - Test `Blas.dtrmm` and `Blas.strmm` across `side: cblasRight`, `uplo: cblasLower`, `transA: cblasTrans`, and `diag: cblasUnit`.
  2. **`lib/src/acceleration/lapack/lapack.dart`, `fft.dart`, `vforce.dart`, `dispatcher.dart`, `acceleration_manager.dart`**:
     - Test `Lapack.spotrf`, `Lapack.sgesv`, `Lapack.sgels`, `Lapack.ssyev`, `Lapack.zheev`, `Lapack.cheev` across `AccelerationMode.values`.
     - Test `AccelerationFailedError.toString()` and `AccelerationManager` mode switching/queries.
  3. **`lib/src/linear/matrix.dart`, `float64_matrix.dart`, `float64_vector.dart`, `eigenvalue.dart`, `sparse/*.dart`** (`test/linear/`):
     - Test `Matrix.rotated(3)`, `-matrix`, `Matrix.fromColumns` length mismatch error, rank-deficient rectangular `solve` / `solveVector`, `Float32` (`DataType.float32`) rectangular `solve`, `syrk`, and `apply` (`sgemv` / `ssyrk` paths).
     - Test `Float64Matrix` and `Float64Vector` arithmetic and `dot`/`apply` with non-contiguous views and `Float32` operands.
     - Test `EigenvalueDecomposition` on non-symmetric matrices requiring complex Schur division (`_cdiv` with `yr.abs() <= yi.abs()`), exceptional Wilkinson shifts (`iter == 10`), and complex eigenvector back-substitution (`_hqr2`).
     - Test `CsrMatrix.fromDense`, `CscMatrix.fromDense`, `CsrMatrix.toCsc`, `CsrMatrix.applyConjugateTranspose`, `CscMatrix.applyConjugateTranspose`, and dimension mismatch errors.
  4. **`lib/src/tensor/` & `lib/src/type/`** (`test/tensor/`, `test/type/`):
     - Test `Layout` validation errors, `ContractionTensorExtension`, `EinsumTensorExtension`, and `DataType` edge cases (`ComplexDataType`, `DynamicDataType`, `BigIntDataType`, `FloatDataType`).
- **Verification**: `dart test test/type/ test/tensor/ test/acceleration/ test/linear/`

### [ ] TASK-6.3: Unit Tests for `special`, `polynomial`, `numeric`, `stats`, and `dataframe` Uncovered Branches
- **Target Files & Missing Test Cases**:
  1. **`lib/src/dataframe/arrow/arrow_ipc.dart`** (`test/dataframe/arrow/arrow_ipc_test.dart`):
     - Test multi-batch `ArrowIpc.encodeBatches` + `ArrowIpc.decode` round-tripping across **all** series types in `_combineSeries`: `Float32`, `Int64`, `Int32`, `Int16`, `Int8`, `Uint64`, `Uint32`, `Uint16`, `Uint8`, `BoolSeries`, `ArrowStringSeries` (with and without nulls), and `ObjectSeries<String>` (with nulls).
  2. **`lib/src/dataframe/json/json_decoder.dart`, `json_stream.dart`, `csv_stream.dart`, `series.dart`, `dataframe.dart`, `arrow_string_series.dart`, `join.dart`**:
     - Test `JsonDecoder` empty inputs (`[]`, `{}`) and `FormatException` error branches across `records`, `split`, `columns`, `index`, and `values` orientations, plus `columnTypes` on empty records/split/index inputs.
     - Test `Series`, `DataFrame`, `ArrowStringSeries`, `CsvStream`, and `JsonStream` uncovered methods and error branches.
  3. **`lib/src/special/`, `lib/src/polynomial/`, `lib/src/numeric/`, `lib/src/stats/`**:
     - Test `beta.dart`, `gamma.dart`, `erf.dart`, `hypergeometric.dart` boundary branches.
     - Test `polynomial.dart`, `compressed_polynomial.dart`, `dense_polynomial.dart`, `formatting.dart` uncovered branches.
     - Test `numeric/integration.dart` (`IntegrateWarning.depthTooShallow` / `IntegrateError`), `numeric/ode/solve_ode.dart` (`rk45` step rejection & dense evaluation), `numeric/sampling.dart`, `numeric/curve_fit.dart`, `numeric/fft.dart`, `numeric/root_finding/solve.dart`, `solve_system.dart`, and `pchip.dart`.
     - Test `stats/hypothesis/t_test.dart`, `chi_squared.dart`, `kolmogorov_smirnov.dart`, `wilcoxon.dart`, `stats/distributions/discrete.dart`, `stats/distribution.dart`, `bootstrap.dart`, and `jackknife.dart`.
- **Verification**: `dart test test/special/ test/polynomial/ test/numeric/ test/stats/ test/dataframe/`

### [ ] TASK-6.4: Unit Tests for `symbolic` and `web/calculator` Uncovered Branches & Final Coverage Verification
- **Target Files & Missing Test Cases**:
  1. **`lib/src/symbolic/algebra/simplify/transcendental.dart`, `multiplicative.dart`, `power.dart`, `additive.dart`**:
     - Test `simplifySin`, `simplifyCos`, `simplifyTan` across all coprime quadrant multiples of $\pi/6$, $\pi/4$, $\pi/3$, $\pi/2$ (e.g. $7\pi/6$, $5\pi/4$, $4\pi/3$, $5\pi/6$, $3\pi/4$, $2\pi/3$).
     - Test `simplifyDerivative` (higher-order flattening and point evaluation), `simplifyLimit`, `simplifyPiecewise`, `simplifyRelational`, `simplifyBinomial`, `simplifyBeta`, `simplifyGamma`, and complex decomposition of `Sin`, `Cos`, `Sinh`, `Cosh`, `Pow` in `_decomposeComplex`.
  2. **`lib/src/symbolic/calculus/{summation.dart,integration.dart,limit.dart,series.dart,differentiation.dart}`**:
     - Test infinite series in `summation.dart` (`_tryAdditiveInfiniteSeries` via partial fractions, shifted geometric/polylogarithmic start indices `_adjustSeriesStart`, rational/radical ratios, and infinite product start adjustments `_adjustProductStart` + Euler `cosh` product).
     - Test hyperbolic squared integrals ($\operatorname{sech}^2(ax+b)$, $\operatorname{csch}^2(ax+b)$), definite Beta/log integrals, and Laplace/Fourier transform branches in `integration.dart`.
     - Test `Derivative.substitute` with bound variable capture/alpha-renaming in `test/symbolic/ast/derivative_test.dart`.
  3. **`lib/src/symbolic/solver/trigonometric.dart`, `univariate.dart`, `transcendental.dart`, `polynomial_system.dart`**:
     - Test `solve` on trigonometric equations with `RealNumber` RHS (`Sin(x) - 0.5`, `Cos(x) - 0.5`, `Tan(x) - 1.5`) to cover the `RealNumber` branches in `trigonometric.dart`.
  4. **`web/calculator/` (`test/web/calculator/evaluator_test.dart`, `rpn_test.dart`, `worker_test.dart`, `completion_test.dart`)**:
     - Add a comprehensive table-driven test iterating over `CommandRegistry.instance.all` to test `appliesTo`, `buildChipCall`, `EvaluatorContext.inferPrimaryVariable` (across `ExprValue`, `SeriesValue`, `VectorValue`, `MatrixValue`, `ListValue`), and matrix/vector lifting across `algebra.dart`, `calculus.dart`, `complex.dart`, `linear.dart`, `numbers.dart`, `numeric.dart`, `plot.dart`, and `session.dart`.
     - Test `RpnInterpreter` postfix operators (`²`, `³`, `⁴`, `!`), stack underflow error recovery in `RpnStack`, `UserFunction.toJson`/`fromJson`, `Session` relative result indexing (`r[-1]`) and error branches, `WorkerRequest`/`WorkerResponse` JSON protocol round-tripping (`protocol.dart`), and `CompletionEngine` user-function and command completions (`completion.dart`).
  5. **Final Coverage Gate**:
     - Run:
       ```sh
       dart test --coverage=coverage
       dart run coverage:format_coverage --packages=.dart_tool/package_config.json --lcov -i coverage -o coverage/lcov.info --check-ignore --report-on=lib/
       ```
     - Verify `lib/` line coverage is **≥ 99%**, then remove the temporary `coverage/` directory.
- **Verification**: `dart analyze && dart format --output=none --set-exit-if-changed . && dart test`
