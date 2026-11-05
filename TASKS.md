# Project Review & Actionable Tasks

Actionable step-by-step tasks across all subsystems (`type`, `tensor`, `acceleration`, `linear`, `special`, `polynomial`, `numeric`, `stats`, `dataframe`, `symbolic`), web applications (`web/`), tests (`test/`), and documentation (`ARCHITECTURE.md`). Every task specifies exact relative file paths, line ranges, root causes, minimal reproductions, and concrete fixes.

---

## 1. Bugs and Edge Cases

### 1.1 `type` Subsystem

- [x] **1.1.1 `DataType.fromIterable` and `DataType.fromInstance` fail on leading/interleaved `null` elements and static nullable types**
  - **Severity**: Critical
  - **Location**: `lib/src/type/utils/derive.dart:11-66`
  - **Problem**:
    1. **Leading `null` ignored**: In `DataType.fromIterable([null, 1, 2])`, on the first element (`null`), `candidate` is `null`, so `if (candidate != null) candidate = candidate.nullable; continue;` (`lines 28-31`) is a no-op. Element `1` then sets `candidate = DataType.integer` (non-nullable `Int32DataType`). Calling `DataType.fromIterable([null, 1, 2]).copyList([null, 1, 2])` or `Tensor.fromIterable([null, 1, 2])` crashes with `TypeError: null: type 'Null' is not a subtype of type 'int'`.
    2. **Interleaved `null` degrades to `ObjectDataType`**: In `DataType.fromIterable([1, null, 2])`, element `1` sets `candidate = DataType.integer`, `null` wraps it into `NullableDataType(DataType.integer)`, and element `2` has `elemType = DataType.integer`. Line 37 (`else if (candidate != elemType)`) compares `NullableDataType(int32) != int32` (`true`), degrading to `ObjectDataType` instead of `DataType.integer.nullable`.
    3. **Static nullable types (`int?`, `double?`, etc.)**: `_fromType(Type type)` (`lines 54-66`) only matches non-nullable types (`const (int)`, `const (double)`, etc.). In `fromInstance<int?>(1)` (`lines 11-19`), `_fromType(int?)` returns `null`, falling back to `_fromType(instance.runtimeType)` which returns non-nullable `Int32DataType` cast to `DataType<int?>`. Consequently, `Vector<int?>.fromList([1, null])` derives `Int32DataType` and throws a `TypeError` on `null`.
  - **Fix**:
    1. In `_fromType`, add cases for `const (bool?)`, `const (int?)`, `const (double?)`, `const (num?)`, `const (BigInt?)`, `const (Fraction?)`, `const (Complex?)`, `const (Quaternion?)`, and `const (String?)` returning `.nullable`.
    2. In `fromIterable`, track `var hasNull = _isNullableType<T>();`, set `hasNull = true` whenever `element == null`, maintain `candidate` as the unwrapped non-null `DataType`, and wrap with `candidate.nullable` at the end when `hasNull` is `true`.

- [x] **1.1.2 64-bit signed integer overflow in `IntegerEquality.isClose`**
  - **Severity**: Critical
  - **Location**: `lib/src/type/types/integer.dart:419`
  - **Problem**: `IntegerEquality.isClose` evaluates `(a - b).abs() <= epsilon`. On the 64-bit Dart VM, `a - b` wraps around on signed 64-bit overflow. When `a = 4611686018427387904` ($2^{62}$) and `b = -4611686018427387904` ($-2^{62}$), `a - b` overflows to `-9223372036854775808` ($-2^{63}$), whose `.abs()` is still `-9223372036854775808 <= 0.0`, returning `true` for two integers $2^{63}$ apart (even when `epsilon` is `0.0` or negative).
  - **Fix**: Guard `if (epsilon.isNaN || epsilon < 0) return false; if (a == b) return true;`, compute `final diff = a > b ? a - b : b - a;`, and when `diff < 0` (signed overflow), fall back to `(BigInt.from(a) - BigInt.from(b)).abs().toDouble() <= epsilon`.

- [x] **1.1.3 `FractionField.pow` silently truncates non-integer exponents to `int`**
  - **Severity**: Warning
  - **Location**: `lib/src/type/types/fraction.dart:92`
  - **Problem**: `Fraction pow(Fraction base, Fraction exponent) => base.pow(exponent.toInt());` calls `exponent.toInt()`, so `DataType.fraction.field.pow(Fraction(4), Fraction(1, 2))` truncates `1/2` to `0` and returns `Fraction(1)` instead of `Fraction(2)`.
  - **Fix**: When `exponent.denominator == BigInt.one`, use `base.pow(exponent.numerator.toInt())`; otherwise evaluate `Fraction.fromDouble(math.pow(base.toDouble(), exponent.toDouble()).toDouble())` (matching `sqrt`, `exp`, and `log` in `FractionField` at lines 101–107).

- [x] **1.1.4 `StringEquality.isClose` runs full $\mathcal{O}(|a|\cdot|b|)$ Levenshtein DP on `NaN`, `Infinity`, and large length differences**
  - **Severity**: Warning
  - **Location**: `lib/src/type/types/string.dart:33-37`
  - **Problem**: When `a != b` and `epsilon` is `double.nan`, `epsilon < 1` is `false`, so `_editDistance(a, b)` executes the full dynamic programming matrix before `<= double.nan` evaluates to `false`. It also runs `_editDistance` when `epsilon == double.infinity` or when `(a.length - b.length).abs() > epsilon`.
  - **Fix**: Guard `if (epsilon.isNaN || epsilon < 0) return false; if (a == b) return true; if (epsilon < 1) return false; if (epsilon.isInfinite) return true; if ((a.length - b.length).abs() > epsilon) return false;` before calling `_editDistance(a, b)`.

- [x] **1.1.5 Domain validation and rounding inconsistencies between `IntegerField` and `BigIntField`**
  - **Severity**: Warning
  - **Location**: `lib/src/type/types/integer.dart:357, 404-410`, `lib/src/type/types/bigint.dart:92-98, 132-151`
  - **Problem**:
    1. `IntegerField.sqrt(-1)` and `IntegerField.log(0)` call `math.sqrt(-1).truncate()` / `math.log(0).truncate()`, throwing `UnsupportedError: Infinity or NaN toInt` instead of `ArgumentError` (whereas `BigIntField.sqrt` and `BigIntField.log` throw `ArgumentError`).
    2. `IntegerField.exp` and `IntegerField.log` use `.truncate()` whereas `BigIntField.exp` and `BigIntField.log` use `.round()`.
    3. `BigIntField.scale(a, double.nan)` or `scale(a, double.infinity)` silently returns `BigInt.zero` (`line 93`), whereas `IntegerField.scale` throws `UnsupportedError`.
  - **Fix**: Validate `a < 0` in `sqrt`, `a <= 0` in `log`, and `!factor.isFinite` in `scale` with `ArgumentError` across both `IntegerField` and `BigIntField`, and use `.round()` consistently.

---

### 1.2 `tensor` Subsystem

- [x] **1.2.1 `_hasMemoryHazard` and `TensorCopyExtension.copy` miss memory aliasing on strided (`step > 1`) and negative-stride (`flip`) views**
  - **Severity**: Critical
  - **Location**: `lib/src/tensor/operations/operation.dart:190-203, 315-341`, `lib/src/tensor/layout.dart`
  - **Problem**: `_hasMemoryHazard` and `TensorCopyExtension.copy` call `hasOverlap(targetData, targetLayout.offset, opData, opLayout.offset, count)` where `count` is `layout.length`. `hasOverlap` (`lib/src/type/utils/memory.dart:43-68`) checks whether `[aOffset, aOffset + count)` overlaps `[bOffset, bOffset + count)`, which is only valid when all strides are `+1`.
    - For `t = Tensor.fromIterable([1, 2, 3, 4])`, `src = t.getRange(axis: 0, start: 0, end: 3, step: 2)` (`offset: 0, strides: [2], length: 2`, touching indices `{0, 2}`) and `dst = t.getRange(axis: 0, start: 2, end: 4)` (`offset: 2, strides: [1], length: 2`, touching indices `{2, 3}`): `hasOverlap` checks `[2, 4)` vs `[0, 2)` (`false`). `src.unaryOperation((x) => x * 10, target: dst)` then writes `dst[0]` (`data[2] = 10`) on iteration 0, clobbering `src[1]` (`data[2]`) before iteration 1 reads it, producing `[10, 100]` instead of `[10, 30]`.
    - Similarly, on a flipped view (`offset: 2, strides: [-2], length: 2`, touching indices `{2, 0}`), `[offset, offset + length)` checks `[2, 4)` instead of `[0, 3)`, missing overlap with `dst` at `[0, 2)`.
  - **Fix**: Add a `({int minOffset, int maxOffset}) get memorySpan` getter on `Layout` computing the exact reachable `[minIdx, maxIdx]` buffer span from `offset`, `shape`, and signed `strides` (the same arithmetic used in `Tensor.internal` at `lib/src/tensor/tensor.dart:32-44`), and pass `span.minOffset` and `span.maxOffset - span.minOffset + 1` to `hasOverlap`.

- [x] **1.2.2 `Float64Tensor`, `Float64Vector`, and `Float64Matrix` constructors do not normalize `tensor.type` to `DataType.float64`**
  - **Severity**: Warning
  - **Location**: `lib/src/tensor/float64_tensor.dart:29-38, 246`, `lib/src/linear/float64_vector.dart:30-35`, `lib/src/linear/float64_matrix.dart:30-35`
  - **Problem**: If a `Tensor<double>` is constructed with `type: DataType.numeric` or `ObjectDataType<double>()` over a `Float64List` buffer, `Float64Tensor(tensor)` accepts it because it only checks `tensor.data is! Float64List`. When a non-contiguous operation falls back to `_tensor + other` (`line 246`), `OperationTensorExtension` allocates the output via `type.newList(len)`, creating a `List<num>` or `List<double>` instead of a `Float64List`, and wraps it via `Float64Tensor._(...)`. Subsequent `.asTypedList` calls throw a `TypeError`.
  - **Fix**: In `Float64Tensor(Tensor<double> tensor)` (and `Float64Vector` / `Float64Matrix`), if `tensor.type != DataType.float64`, normalize the underlying tensor to `Tensor.internal(type: DataType.float64, layout: tensor.layout, data: tensor.data)`.

---

### 1.3 `acceleration` Subsystem

- [x] **1.3.1 `LapackDart.dgesvd` throws `RangeError` for any wide matrix ($m < n$) when `jobu: 'A'`**
  - **Severity**: Critical
  - **Location**: `lib/src/acceleration/lapack/lapack_dart.dart:1076, 1110`
  - **Problem**: When `m < n` (e.g., $2 \times 4$, so `rowsA = 2, colsA = 4`) and `jobu == 'A'` (`computeU == true`), `uCol` has length `rowsA * rowsA = 4` (`line 688`), while `mDim = math.min(colsA, rowsA + 1) = 3` (`line 856`).
    - In `case 3` (`line 1076`), `k` runs up to `mDim - 2 = 1 = rowsA - 1`. The guard `if (computeU && k < rowsA)` is `true` for `k = rowsA - 1 = 1`, so lines 1079–1081 index `uVals[(k + 1) * rowsA + i]` = `uVals[4]`, throwing `RangeError`.
    - The identical off-by-one bug exists in `case 4` at line 1110 (`if (computeU && lIdx < rowsA)`).
    - Reproduction: In `AccelerationMode.dart`, calling `Matrix<double>.fromRows([[1, 2, 3, 4], [5, 6, 7, 8]]).svd` throws `RangeError`.
  - **Fix**: Change line 1076 from `if (computeU && k < rowsA)` to `if (computeU && k < rowsA - 1)` and line 1110 from `if (computeU && lIdx < rowsA)` to `if (computeU && lIdx < rowsA - 1)`.

- [x] **1.3.2 `LapackDart.dgesvd` unconditionally returns `true` on QR non-convergence and divides `0.0 / 0.0` when `scale == 0.0` in `case 3`**
  - **Severity**: Critical
  - **Location**: `lib/src/acceleration/lapack/lapack_dart.dart:720, 930, 1025-1035`
  - **Problem**:
    1. At line 930, `if (iter >= 1000) break;` exits the SVD QR loop without reporting failure, and `dgesvd` unconditionally returns `true` at line 720 (unlike `LapackNative.dgesvd` which returns `info == 0`).
    2. At lines 1025–1035 (`case 3` shift calculation), when `scale == 0.0`, `final sm = stemp[mDim - 1] / scale;` evaluates `0.0 / 0.0 = NaN`, corrupting singular values and vectors with `NaN`.
  - **Fix**: Make `_computeSvd` return `bool` (`false` when `iter >= 1000`), propagate that return value from `LapackDart.dgesvd`, and guard `if (scale == 0.0)` in `case 3` by setting `shift = 0.0, f = 0.0, g = e[lIdx]`.

- [x] **1.3.3 `LapackNative.dgels` (Fortran `dgels_` path) reads out-of-range rows of `b` when $m < n$, and `dgesv`/`dgels` do not check `b` for `NaN`/`Infinity`**
  - **Severity**: Warning
  - **Location**: `lib/src/acceleration/lapack/lapack_native.dart:118-120, 273-385`, `lib/src/acceleration/lapack/lapack_dart.dart:80-82, 200-202`
  - **Problem**:
    1. In `LapackNative.dgels` line 316: `fB[j * maxMN + i] = (i < m || i < n) ? b[bOffset + i * ldb + j] : 0.0;`. Because `maxMN = math.max(m, n)` and `0 <= i < maxMN`, `i < m || i < n` is tautologically `true`! For underdetermined systems ($m < n$), only rows `0 <= i < m` of `b` hold input RHS values; rows `m <= i < n` are output space.
    2. Both `dgesv` and `dgels` check `a` for `NaN`/`Infinity` and return `false`, but neither checks input rows `0 <= i < m` of `b` for `NaN`/`Infinity`.
  - **Fix**: Change line 316 of `lapack_native.dart` to `fB[j * maxMN + i] = i < m ? b[bOffset + i * ldb + j] : 0.0;`, and check input elements of `b` (`0 <= i < m`, `0 <= j < nrhs`) for `NaN`/`Infinity` in `dgesv` and `dgels`.

- [x] **1.3.4 `VforceNative.convolve` and `VforceNative.correlate` lack the in-place buffer aliasing guard present in `VforceDart`**
  - **Severity**: Warning
  - **Location**: `lib/src/acceleration/vforce/vforce_native.dart:181-232`, `lib/src/acceleration/vforce/vforce.dart:210-260`
  - **Problem**: `VforceDart.convolve` and `VforceDart.correlate` allocate a temporary buffer when `output` shares memory with `signal` or `filter`, whereas `VforceNative.convolve` and `VforceNative.correlate` pass `signal.address`, `filter.address`, and `output.address` directly to `vDSP_convD`, corrupting output when `output` overlaps `signal` or `filter`.
  - **Fix**: Centralize the `hasOverlap` / buffer aliasing guard in `Vforce.convolve` and `Vforce.correlate` (or in `VforceNative`) so both native and Dart paths are protected.

- [x] **1.3.5 `Blas` validation functions do not reject negative dimensions (`n < 0`, `m < 0`, `k < 0`)**
  - **Severity**: Warning
  - **Location**: `lib/src/acceleration/blas/blas_validation.dart:54-230`
  - **Problem**: Unlike `Lapack` (which throws `ArgumentError` when `n < 0` or `m < 0`), `checkBlasVectorBounds`, `checkBlasGemvBounds`, `checkBlasSyr2Bounds`, `checkBlasTrmvBounds`, `checkBlasGemmBounds`, `checkBlasSyrkBounds`, `checkBlasSymmBounds`, and `checkBlasTrmmBounds` begin with `if (n <= 0) return;` (or `if (m <= 0 || n <= 0) return;`), silently accepting negative dimensions such as `n = -5`.
  - **Fix**: Throw `ArgumentError.value(n, 'n', 'Must be non-negative')` when `n < 0` (and similarly for `m < 0`, `k < 0`) before the `== 0` early return.

---

### 1.4 `linear` Subsystem

- [x] **1.4.1 `Matrix.syrk` has swapped `copy` target on early return, unvalidated `target` layout/aliasing on the BLAS path, and upper-triangle vs full-matrix discrepancy**
  - **Severity**: Critical
  - **Location**: `lib/src/linear/matrix.dart:753-847`
  - **Problem**:
    1. **Swapped `copy` arguments (`line 775`)**: When `dim == 0 || kDim == 0 || alpha == 0.0` and `beta != 1.0`, line 775 executes `result.tensor.copy(target: scaled.tensor);`, which copies `result` into the temporary `scaled` tensor instead of copying `scaled` into `result`. Calling `a.syrk(alpha: 0.0, beta: 2.0, target: c)` leaves `c` completely unmodified.
    2. **Unvalidated `target` layout/aliasing (`lines 793-826`)**: The BLAS path passes `c: result.tensor.data`, `cOffset: result.tensor.offset`, `ldc: dim` to `Blas.dsyrk`/`ssyrk` without checking `result.tensor.isContiguous` or `!sharesMemory(tensor.data, result.tensor.data)`. If `target` is a submatrix or transposed view, `Blas.dsyrk` writes with stride `dim` and corrupts memory.
    3. **Upper-triangle vs full symmetric output (`lines 794-846`)**: `Blas.dsyrk` (`lib/src/acceleration/blas/blas_dart.dart:548-555`) mirrors upper to lower triangle, whereas `LapackNative` / Apple Accelerate `cblas_dsyrk(uplo: cblasUpper)` ONLY writes the upper triangle of `C`! Meanwhile, the fallback path (`lines 829-846`) computes `(aOp * aOther).scale(...)`, filling both upper and lower triangles.
  - **Fix**:
    1. Change line 775 to `scaled.tensor.copy(target: result.tensor);`.
    2. Require `result.tensor.isContiguous && !sharesMemory(tensor.data, result.tensor.data)` on the BLAS fast path.
    3. Mirror the upper triangle into the lower triangle in `BlasNative.dsyrk` / `BlasNative.ssyrk` (matching `BlasDart.dsyrk` and `ARCHITECTURE.md` Section 5.3: *"dsyrk, ssyrk (symmetric rank-k update with automatic upper/lower triangle mirroring)"*) or in `Matrix.syrk`.

- [x] **1.4.2 `CsrMatrix` and `CscMatrix` violate the `==` / `hashCode` contract and corrupt `+` / `-` when constructed with unsorted or duplicate indices**
  - **Severity**: Critical
  - **Location**: `lib/src/linear/sparse/csr_matrix.dart:28-82, 268-306, 393-431`, `lib/src/linear/sparse/csc_matrix.dart:29-81, 266-304, 391-429`
  - **Problem**:
    1. `CsrMatrix(...)` and `CscMatrix(...)` constructors do not verify that `colIndices` (within each row) or `rowIndices` (within each column) are strictly increasing.
    2. `CsrMatrix.operator ==` (`line 421`) falls back to `toDense() == other.toDense()`, while `hashCode` (`lines 424-430`) hashes raw `colIndices` and `values` (and omits `rowPointers` completely!). Thus two equal `CsrMatrix` instances (or a matrix with an explicit `0.0` entry vs one without) can have `a == b` (`true`) and `a.hashCode == b.hashCode` (`false`), and moving a non-zero entry from row 0 to row 1 produces the same `hashCode`.
    3. `CsrMatrix.operator +` and `operator -` (`lines 274-294`) use a two-pointer merge that assumes strictly sorted `colIndices` per row; unsorted indices produce duplicate column entries in the result.
  - **Fix**:
    1. In `CsrMatrix` and `CscMatrix` constructors, validate that `colIndices` within each row (and `rowIndices` within each column) are strictly increasing (`indices[ptr] < indices[ptr + 1]`).
    2. Compute `hashCode` from `(row, col, value)` triplets of non-zero entries (`!type.equality.isEqual(val, field.additiveIdentity)`), and implement `operator ==` by comparing non-zero entries directly in $\mathcal{O}(\text{nnz})$ without allocating dense matrices via `toDense()`.

- [ ] **1.4.3 `Float64Vector.norm(2)` overflows/underflows on negative-stride (flipped) vectors**
  - **Severity**: Warning
  - **Location**: `lib/src/linear/float64_vector.dart:158-172`
  - **Problem**: When `pNorm == 2` and `t.strides[0] <= 0` (e.g., a flipped `Float64Vector`), line 169 executes `return math.sqrt(dot(this));` instead of delegating to `_vector.norm(pNorm)`. Because `dot(this)` computes unscaled `sum += v[i] * v[i]`, `Float64Vector.fromList([1e200, 1e200]).flipped.norm(2)` overflows to `Infinity`, whereas `_vector.norm(2)` uses Blue's scaled summation and returns `1.4142135623730951e200`.
  - **Fix**: Remove `return math.sqrt(dot(this));` (or pass `incX: t.strides[0].abs()` to `Blas.dnrm2` since Euclidean norm is order-independent).

- [ ] **1.4.4 `QRDecomposition._decomposeGeneric` uses unscaled norm summation that overflows on large `Complex` matrices**
  - **Severity**: Warning
  - **Location**: `lib/src/linear/decomposition/qr.dart:293-300`
  - **Problem**: `_decomposeGeneric` computes `sumsq += norm * norm; final nrm = math.sqrt(sumsq);` without scaling (unlike `_decomposeFloat64` at lines 244–262). For `Matrix<Complex>` with entries around `1e200`, `sumsq` overflows to `Infinity`, causing `tau = (Infinity + normXk) / Infinity = NaN`.
  - **Fix**: Use the same scaled `scale * math.sqrt(sumsq)` accumulation in `_decomposeGeneric` as in `_decomposeFloat64`.

- [ ] **1.4.5 `EigenvalueDecomposition._checkSymmetry` and `CholeskyDecomposition` misclassify small-magnitude skew-symmetric matrices as symmetric**
  - **Severity**: Warning
  - **Location**: `lib/src/linear/decomposition/eigenvalue.dart:876-891`, `lib/src/linear/decomposition/cholesky.dart:108-119, 175-181`
  - **Problem**: `_checkSymmetry` checks `if (diff > 1e-12 && (maxVal == 0.0 || diff / maxVal > 1e-12))`, requiring BOTH absolute difference `> 1e-12` AND relative difference `> 1e-12`. For a skew-symmetric matrix with entries of magnitude `1e-13` (e.g., `[[0.0, 1e-13], [-1e-13, 0.0]]`), `diff = 2e-13 <= 1e-12`, so `_checkSymmetry` returns `true` and `EigenvalueDecomposition` returns real eigenvalues `[-1e-13, 1e-13]` instead of imaginary `[0 + 1e-13i, 0 - 1e-13i]`. Similarly, `CholeskyDecomposition._decomposeGeneric` (`line 180`) uses a fixed absolute tolerance `1e-6`.
  - **Fix**: Check `diff > 1e-12 * maxVal` ( purely relative to matrix norm `maxVal`), without an unconditional `1e-12` or `1e-6` absolute threshold.

- [ ] **1.4.6 `solveIterative` (`_conjugateGradient`) runs all `maxIterations` when `pap` is `NaN` and lacks parameter validation**
  - **Severity**: Warning
  - **Location**: `lib/src/linear/solvers/iterative.dart:43-68, 113`
  - **Problem**: Line 113 (`if (field.norm(pap) == 0.0) break;`) evaluates to `false` when `pap` is `NaN`, running all `maxIterations` steps with `NaN`. Also, `solveIterative` does not validate `tolerance >= 0 && !tolerance.isNaN`, `maxIterations >= 0`, or `restart > 0`.
  - **Fix**: Validate `tolerance`, `maxIterations`, and `restart` at the start of `solveIterative`, and change line 113 to `if (!(field.norm(pap) > 0.0)) break;`.

---

### 1.5 `special` Subsystem

- [ ] **1.5.1 `gammaqInv` has an inverted sign in `afac` and an inverted Halley second-order correction**
  - **Severity**: Critical
  - **Location**: `lib/src/special/gamma.dart:254-295`
  - **Problem**:
    1. Line 258 computes `final afac = exp(a1 * (1.0 - lna1) - gln);` where `a1 = a - 1.0` and `lna1 = log(a1)`. Compare with `gammapInv` (`line 163`: `afac = exp(a1 * (lna1 - 1.0) - gln)`). Writing `1.0 - lna1` instead of `lna1 - 1.0` corrupts the derivative `tVal` by a factor of $\exp(2(a-1)(1 - \ln(a-1)))$ whenever `probability <= 0.25` and `a > 1.0` (e.g., `gammaqInv(10.0, 0.1)`).
    2. Line 289 computes `x += uVal / (1.0 - 0.5 * min(1.0, uVal * ((a - 1.0) / x - 1.0)));`. Since $f(x) = Q(a, x) - q = 0$ has $f'(x) = -tVal$, `err = gammaq(a, x) - q`, and `uVal = err / tVal = -f / f'`, Halley's denominator must be `1.0 + 0.5 * max(-1.0, uVal * ((a - 1.0) / x - 1.0))` (plus, not minus).
    3. Line 254 uses `const epsilon = 1.0e-8;` instead of `1.0e-14` (`gammapInv` line 154), terminating 6 orders of magnitude early.
  - **Fix**: Change line 254 to `const epsilon = 1.0e-14;`, line 258 to `final afac = exp(a1 * (lna1 - 1.0) - gln);`, and line 289 to `final h = uVal / (1.0 + 0.5 * max(-1.0, uVal * ((a - 1.0) / x - 1.0)));` with bracket bounds `[xMin, xMax]` matching `gammapInv`.

- [ ] **1.5.2 `polygamma(m, x)` ($m \ge 2$) lacks reflection formula for $x < 0$, causing $\mathcal{O}(|x|)$ loops or infinite loops**
  - **Severity**: Critical
  - **Location**: `lib/src/special/digamma.dart:118-137`
  - **Problem**: Unlike `digamma` (`line 29`) and `trigamma` (`line 78`), `polygamma(m, x)` for $m \ge 2$ only checks `if (value <= 0.0 && value.truncateToDouble() == value)` and then enters `while (value < 8.0) { shift += ...; value += 1.0; }`. For $x = -10^8 - 0.5$, it loops $10^8$ times; for $x = -10^{16} - 0.5$, `value + 1.0 == value` in IEEE 754 `double`, causing an infinite loop.
  - **Fix**: For `value <= 0.0`, apply the reflection relation $\psi^{(m)}(1 - x) + (-1)^{m+1} \psi^{(m)}(x) = (-1)^m \pi \frac{d^m}{dx^m} \cot(\pi x)$ by evaluating the $m$-th derivative of $\cot(\pi x)$ via polynomial recurrence in $u = \cot(\pi x)$ ($P_0(u) = u$, $P_{k+1}(u) = -(1 + u^2) P_k'(u)$).

- [ ] **1.5.3 `besselJ`, `besselY`, `besselI`, `besselK` throw `UnsupportedError` on infinite `nu`, return `NaN` on small/infinite `x`, and suffer catastrophic cancellation for non-integer `nu` at large `x`**
  - **Severity**: Critical
  - **Location**: `lib/src/special/bessel.dart:18, 41-74, 87, 120, 136-161, 176`
  - **Problem**:
    1. `if (nud.roundToDouble() == nud)` at lines 18, 87, 120, and 176 is `true` when `nud` is `±Infinity` or $|v| \ge 2^{52}$; calling `nud.toInt()` then throws `UnsupportedError`.
    2. In `besselJ(n, x)` (`lines 41-55`) and `besselI(n, x)` (`lines 136-143`), Miller's backward recurrence multiplies by `2 * k / xd` at each step without rescaling; for small `xd` (e.g., `besselJ(5, 1e-100)` or `besselI(10, 1e-10)`), `fPrev`/`fCur` overflows to `Infinity`, returning `Infinity / Infinity = NaN` instead of the leading series value.
    3. For non-integer `nu` (`lines 60-74, 148-161`), `x = double.infinity` returns `NaN`, and for `xd > 20` (e.g., `besselJ(0.5, 50.0)`), the alternating power series suffers total catastrophic cancellation because there is no Hankel asymptotic expansion for non-integer `nu`.
  - **Fix**:
    1. Guard `if (!nud.isFinite) return double.nan;` and only take the integer branch when `nud.abs() <= 1e7 && nud.roundToDouble() == nud`.
    2. In Miller's backward recurrence, rescale `fPrev`, `fCur`, and `sum` by `1e-100` whenever `fPrev.abs() > 1e100`, and use the power series directly when `xd.abs() < 1e-4`.
    3. Use Hankel's asymptotic expansion for `besselJ(nu, x)` / `besselY(nu, x)` and the large-$x$ asymptotic expansion for `besselI(nu, x)` / `besselK(nu, x)` when `xd > math.max(25.0, nud * nud)`.

- [ ] **1.5.4 `ellipticF` and `ellipticEIncomplete` throw on `phi = ±Infinity` and `ellipticF(pi / 2, 1.0)` returns `~19.06` instead of `Infinity`**
  - **Severity**: Warning
  - **Location**: `lib/src/special/elliptic.dart:86, 91-101, 114`
  - **Problem**:
    1. When `phi` is `±Infinity`, `(phiD / pi).round()` at lines 86 and 114 throws `UnsupportedError: Infinity or NaN toInt`.
    2. In `ellipticF(pi / 2, 1.0)` (`line 97`), `c = cos(pi / 2) ≈ 6.123e-17` is slightly non-zero in IEEE 754 float, so `_carlsonRF(c * c, 0.0, 1.0)` returns `~19.06` instead of `double.infinity` (inconsistent with `ellipticK(1.0) == double.infinity`).
  - **Fix**: Handle `phiD.isInfinite` before `(phiD / pi).round()`, and in `ellipticF` return `double.infinity * phiD.sign` when `kd.abs() == 1.0 && (absPsi >= pi / 2.0 - 1e-15 || n != 0)`.

- [ ] **1.5.5 `lambertW0` overflows Halley terms for $z > 10^{290}$ and `lambertW1` underflows `exp(wVal)` for $z \in [-10^{-320}, 0)$**
  - **Severity**: Warning
  - **Location**: `lib/src/special/lambert_w.dart:41-59, 97-115`
  - **Problem**: For `lambertW0(1e300)`, `wVal ≈ 684`, so `ew * w1` overflows to `Infinity` on iteration 0 and breaks out of the loop unrefined (leaving $10^{-3}$ relative error). For `lambertW1(-1e-320)`, `wVal < -736`, so `ew = exp(wVal)` underflows to `0.0` on iteration 0 and breaks unrefined.
  - **Fix**: When `!ew.isFinite || ew == 0.0` (or `wVal.abs() > 100.0`), refine $w + \ln|w| = \ln|z|$ in log-space via the overflow-free Halley/Newton update $r = w + \ln|w| - \ln|z|$, $\Delta w = \frac{r}{1 + 1/w}$.

- [ ] **1.5.6 `hypergeometric1F1` returns `NaN` for large negative `z` ($z \le -710$), `hypergeometric2F1` returns `NaN` for `z = -Infinity`, and `zeta(s)` overflows for $s < -170$**
  - **Severity**: Warning
  - **Location**: `lib/src/special/hypergeometric.dart:41-44, 107-110`, `lib/src/special/zeta.dart:34-43`
  - **Problem**:
    1. In `hypergeometric1F1(a, b, z)` (`line 43`), `exp(zd) * hypergeometric1F1(bd - ad, bd, -zd)` multiplies `0.0 * Infinity = NaN` when `zd <= -710`.
    2. In `hypergeometric2F1(a, b, c, z)` (`line 108`), `zd = double.negativeInfinity` computes `wVal = -Infinity / -Infinity = NaN`.
    3. In `zeta(s)` (`line 40`), `gamma(1.0 - sd)` overflows to `Infinity` when $s < -170.5$.
  - **Fix**: Add the large-negative-$z$ asymptotic expansion for `hypergeometric1F1` when `zd < -100.0`, handle `zd == double.negativeInfinity` in `hypergeometric2F1`, and evaluate `zeta(s)` for $s < -170$ using `gammaLn(1.0 - sd)` combined with $\sin(\pi s / 2)$.

---

### 1.6 `polynomial` Subsystem

- [ ] **1.6.1 `Polynomial.gcd` densifies sparse `CompressedPolynomial` instances into $\mathcal{O}(\text{degree})$ arrays**
  - **Severity**: Warning
  - **Location**: `lib/src/polynomial/polynomial.dart:196-264`
  - **Problem**: Inside the Euclidean loop (`lines 204-224`), `gcd` loops `for (var i = 0; i <= a.degree; i++)` and `for (var i = 0; i <= rem.degree; i++)`, allocates a dense `List<T>.generate(rem.degree + 1, ...)`, and constructs a `DensePolynomial`. For two sparse `CompressedPolynomial<double>` of degree $100,000$, `gcd` allocates dense $100,001$-element lists on every step. Also, at line 235 (`a.degree == 0`), it returns a `DensePolynomial` even when `this is CompressedPolynomial<T>`.
  - **Fix**: Iterate `a.coefficients.values` and `rem.coefficients.values` to compute `maxA` and `maxB`, filter `rem.coefficients.entries` via `Polynomial.fromMap` when `rem is CompressedPolynomial<T>`, and preserve `CompressedPolynomial` at line 235.

- [ ] **1.6.2 `coeffToDouble` silently drops the imaginary part of `Complex`, `formatPolynomialTerms` omits parentheses around `Complex` coefficients, and `RationalFunction` operators skip `_checkType`**
  - **Severity**: Warning
  - **Location**: `lib/src/polynomial/impl/formatting.dart:25-32, 48`, `lib/src/polynomial/rational.dart:128-163`
  - **Problem**:
    1. `coeffToDouble` (`formatting.dart:48`) returns `val.a.toDouble()` for `Complex`, silently discarding non-zero imaginary parts in `evaluateDouble`.
    2. `formatPolynomialTerms` (`formatting.dart:25-32`) formats `Polynomial<Complex>` terms at `exp > 0` as `'1.0 + 2.0ix'` instead of `'(1.0 + 2.0i)x'`.
    3. `RationalFunction` operators `+`, `-`, `*`, `/` do not verify `type == other.type`.
  - **Fix**: In `coeffToDouble`, throw `UnsupportedError` when `val is Complex && val.b != 0.0`; parenthesize multi-term coefficient strings at `exp > 0` in `formatPolynomialTerms`; and check `type == other.type` in `RationalFunction` binary operators.

---

### 1.7 `numeric` Subsystem

- [ ] **1.7.1 `_bdf2` marks the entire ODE solution `converged: false` whenever any single trial step is rejected and halved**
  - **Severity**: Critical
  - **Location**: `lib/src/numeric/ode/solve_ode.dart:338-378, 437-445`
  - **Problem**: In `_bdf2` (`lines 437-445`), when Newton iteration does not converge on a trial step (`!stepConverged`), it sets `allStepsConverged = false;` *before* halving `step` and retrying (`continue`). Even when the halved step converges cleanly and integration reaches `tEnd` within tolerance, `solveOde` returns `OdeSolution(..., converged: false)`. Additionally, the startup trapezoidal step (`lines 338-378`) does not halve `initialStep` if Newton fails to converge or LTE exceeds tolerance.
  - **Fix**: Only set `allStepsConverged = false` when `step.abs() <= minStep * (1.0 + 1e-12)` (when step-size reduction is exhausted and the solver breaks), and make the startup step adaptive.

- [ ] **1.7.2 `integrate` with infinite bounds and finite `poles` outside `[a, b]` integrates outside the user's domain `[a, b]`**
  - **Severity**: Critical
  - **Location**: `lib/src/numeric/integration/integration.dart:107-150`
  - **Problem**: At line 108, `final finitePoles = poles.where((p) => p.isFinite).toList()..sort();` does not filter `poles` to those inside `[min(a, b), max(a, b)]` (unlike line 153 for finite bounds). When integrating on `[0.0, double.infinity)` with `poles: [-5.0, 0.0]`, `pMax` is `0.0`, `pMin` is `-5.0`, and for `(a: -Infinity, b: 0)` with `poles: [5.0]`, `leftBound = pMin - 1.0 = 4.0 > b`, causing `integrate` to evaluate `function(x)` outside `[a, b]`.
  - **Fix**: Filter `finitePoles` at line 108 to `poles.where((p) => p.isFinite && p >= minAB && p <= maxAB).toList()..sort()`, and clamp `leftBound = a.isFinite ? a : math.min(b, pMin - 1.0)` and `rightBound = b.isFinite ? b : math.max(a, pMax + 1.0)`.

- [ ] **1.7.3 `minimize` silently ignores `inequalities` and `equalities` when `method: OptimizationMethod.brent` is passed, and `nelderMead` post-loop `reduce` picks `NaN`**
  - **Severity**: Warning
  - **Location**: `lib/src/numeric/optimization/minimize.dart:90`, `lib/src/numeric/optimization/nelder_mead.dart:132-135`, `lib/src/numeric/root_finding/solve.dart:196`
  - **Problem**:
    1. `minimize.dart:90` checks `if (hasConstraints && resolvedMethod != OptimizationMethod.brent)`, bypassing `minimizeConstrained` even when `inequalities` or `equalities` are non-empty.
    2. `nelder_mead.dart:135` selects `bestIdx` after the loop via `.reduce((a, b) => values[a] < values[b] ? a : b)`, which returns `b` when `values[b]` is `double.nan`.
    3. `_newtonRaphson` (`solve.dart:196`) returns `x` whenever `step.abs() < tolerance` even if `fx.abs()` is large due to a huge derivative.
  - **Fix**: Only bypass `minimizeConstrained` for `OptimizationMethod.brent` when `inequalities` and `equalities` are both empty; guard `NaN` in `nelder_mead.dart:135`; and require `fx.abs() <= math.max(tolerance, 1e-6)` when `step.abs() < tolerance` in `_newtonRaphson`.

---

### 1.8 `stats` Subsystem

- [ ] **1.8.1 `shapiroWilkTest` uses unadjusted Shapiro-Francia weights and a corrupted Royston (1992) transformation for $4 \le n \le 11$**
  - **Severity**: Critical
  - **Location**: `lib/src/stats/hypothesis/shapiro_wilk.dart:66-124`
  - **Problem**:
    1. At lines 110–113, for $4 \le n \le 11$, the code computes `mu = -2.273 + 0.459 * logN; sigma = exp(0.544 - 0.3997 * logN);` and `z = (log(1.0 - w) - mu) / sigma`. In Royston (1992, *Statistics and Computing* 2, 117–119, Table 1 / Algorithm AS R94), for $4 \le n \le 11$, the transformation is $y = -\ln(\gamma - \ln(1 - W))$ where $\gamma = -2.273 + 0.459 n$ (a function of $n$, not $\ln n$), with $\mu = 0.5440 - 0.39978 n + 0.025054 n^2 - 0.0006714 n^3$ and $\sigma = \exp(1.3822 - 0.77857 n + 0.062767 n^2 - 0.0020322 n^3)$.
    2. At lines 85–89, the weights $a_i$ are set to unadjusted $m_i / \|m\|$ without Royston's polynomial adjustments for $a_n$ (for $n \ge 4$) and $a_{n-1}$ (for $n \ge 6$) in $u = 1/\sqrt{n}$.
  - **Fix**: Implement Royston's (1992 / AS R94) weight adjustments for $a_n$ and $a_{n-1}$ and the exact $4 \le n \le 11$ transformation $(\gamma, y, \mu, \sigma)$.

- [ ] **1.8.2 Boundary PDF/logPDF at `x == 0.0` in `GammaDistribution`, `WeibullDistribution`, and `FDistribution`, and `median` in skewed discrete distributions**
  - **Severity**: Warning
  - **Location**: `lib/src/stats/distributions/continuous/gamma.dart:86-96`, `lib/src/stats/distributions/continuous/weibull.dart:121-135`, `lib/src/stats/distributions/continuous/f.dart:100-112`, `lib/src/stats/distributions/discrete/binomial.dart:84`, `lib/src/stats/distributions/discrete/hypergeometric.dart:99`, `lib/src/stats/distributions/discrete/negative_binomial.dart:94`
  - **Problem**:
    1. `GammaDistribution`, `WeibullDistribution`, and `FDistribution` check `if (x <= 0.0) return 0.0;` (and `-double.infinity` for `logProbability`), returning `0.0` at `x = 0.0` even when `shape == 1.0` (`Gamma(1, scale)` and `Weibull(1, scale)` equal `Exponential(1/scale)` with density `1/scale` at `0.0`, and `Infinity` when `shape < 1.0`; `F(2, d2)` has density `1.0` at `0.0` and `Infinity` when `d1 < 2.0`), inconsistent with `ChiSquaredDistribution`, `BetaDistribution`, and `ExponentialDistribution`.
    2. `BinomialDistribution`, `HypergeometricDistribution`, and `NegativeBinomialDistribution` define `median => mean.roundToDouble()` instead of `inverseCumulativeProbability(0.5).toDouble()` (e.g., `NegativeBinomialDistribution(1, 0.9)` returns `median = 9.0` whereas the true median where $\text{CDF}(k) \ge 0.5$ is `6.0`).
  - **Fix**: Handle `x == 0.0` in `GammaDistribution`, `WeibullDistribution`, and `FDistribution` matching `ChiSquaredDistribution`; and define `double get median => inverseCumulativeProbability(0.5).toDouble();` in `BinomialDistribution`, `HypergeometricDistribution`, and `NegativeBinomialDistribution`.

- [ ] **1.8.3 Edge cases in `chiSquaredTest`, `wilcoxonSignedRankTest`, `mannWhitneyUTest`, and `tTestTwoSample`**
  - **Severity**: Warning
  - **Location**: `lib/src/stats/hypothesis/chi_squared.dart:15-48`, `lib/src/stats/hypothesis/wilcoxon.dart:42-44, 69-78`, `lib/src/stats/hypothesis/mann_whitney.dart:70-82`, `lib/src/stats/hypothesis/t_test.dart:140-143`
  - **Problem**:
    1. `chiSquaredTest` does not reject negative or `NaN` observed counts, and when `obsSum == 0.0` with `expected != null`, it scales `exp` by `0.0` and throws a misleading `'Expected counts must be positive'` error.
    2. `wilcoxonSignedRankTest` throws `ArgumentError('All sample differences are zero')` on identical paired samples instead of returning `statistic: 0.0, pValue: 1.0` (like `tTestPaired` and `mannWhitneyUTest`), and both `wilcoxonSignedRankTest` and `mannWhitneyUTest` compute `count * count * count - count` in `int` (which can overflow on large tied samples).
    3. `tTestTwoSample` (`equalVariance: false`) returns `dof: 1.0` instead of `double.nan` when inputs contain `NaN`.
  - **Fix**: Validate `obs[i] >= 0 && obs[i].isFinite` and `obsSum > 0` in `chiSquaredTest`; return `statistic: 0.0, pValue: 1.0` when all differences are zero in `wilcoxonSignedRankTest`; compute `tieTerm` using `double` in `wilcoxon.dart` and `mann_whitney.dart`; and propagate `double.nan` to `dof` in `tTestTwoSample`.

---

### 1.9 `dataframe` Subsystem

- [ ] **1.9.1 `Series.fromList` throws `TypeError` or degrades to `ObjectSeries` when `NullableDataType` or coercible values (e.g. `int` in `float64`) are passed with an explicit `type`**
  - **Severity**: Critical
  - **Location**: `lib/src/dataframe/series.dart:35-81`
  - **Problem**:
    1. When `type` is a `NullableDataType` (e.g. `DataType.int32.nullable` or `DataType.float64.nullable`), `type is DataType<int>` / `type is DataType<double>` is `false` (because `DataType<int?>` is not a subtype of `DataType<int>`). `Series.fromList` either falls through to a boxed `ObjectSeries` (which then fails in `toArrowIpc` / `exportTo`) or, when `T` is statically `int`, crashes on `type as DataType<int>` at line 44.
    2. When `type: DataType.float64` is passed to `Series.fromList('x', [1, 2.5], type: DataType.float64)`, line 49 executes `list.map((element) => element as double?)`, throwing `TypeError: 1 is not a subtype of type 'double?'` before reaching `TypedSeries.fromList`'s `effectiveType.cast(val)`!
  - **Fix**: Unwrap `final effectiveType = type is NullableDataType ? type.delegate : type;` at the top of `Series.fromList`, and coerce non-null elements via `effectiveType.cast(element)` instead of hard `as int?` / `as double?` / `as String?` / `as bool?` casts.

- [ ] **1.9.2 `NaN` and `-0.0` key handling in `Series.unique()`, `Series.valueCounts()`, `DataFrame.dropDuplicates()`, `DataFrame.pivot()`, `GroupBy`, and `JoinMethod.sortMerge`**
  - **Severity**: Critical
  - **Location**: `lib/src/dataframe/tuple_key.dart:62-215`, `lib/src/dataframe/series.dart:278-306`, `lib/src/dataframe/dataframe.dart:294-317, 412-482`, `lib/src/dataframe/groupby.dart:200-211`, `lib/src/dataframe/join.dart:267-315`
  - **Problem**:
    1. Because `double.nan == double.nan` is `false` in Dart (and `DeepCollectionEquality` also uses `==`), `unique()`, `valueCounts()`, `dropDuplicates()`, `pivot()`, and `groupBy()` create a separate group/row for every single `NaN` occurrence instead of grouping `NaN` values together.
    2. In `JoinMethod.hash`, `-0.0 == 0.0` is `true`, so `-0.0` and `0.0` join keys match. In `JoinMethod.sortMerge` (`join.dart:290`), `(-0.0).compareTo(0.0)` returns `-1`, so `-0.0` and `0.0` fail to match!
    3. In `ArrowStringSeries.sort` (`arrow_string_series.dart:335-341`), strings are sorted by UTF-8 byte order (Unicode code-point order), whereas `DataFrame.sortBy` and `JoinMethod.sortMerge` compare strings with `String.compareTo` (UTF-16 code-unit order, which differs for U+E000..U+FFFF vs supplementary U+10000..U+10FFFF).
  - **Fix**:
    1. In `RowKeyExtractor` / `TupleKey` (and `unique`, `valueCounts`, `pivot`), canonicalize floating-point keys by mapping any `num` where `v.isNaN` to a constant `_NaNKey` sentinel (with reflexive `==` and constant `hashCode`) and normalizing `-0.0` to `0.0`.
    2. In `_sortMergeJoinPairs` (`join.dart:290`), check `if (valA == valB) continue;` before `valA.compareTo(valB)` so `-0.0` and `0.0` compare equal (`0`).

- [ ] **1.9.3 `GroupBy.aggregate` crashes on `DataType.numeric` sum promotion and when output column names collide with `byColumns`**
  - **Severity**: Critical
  - **Location**: `lib/src/dataframe/groupby.dart:88-160`
  - **Problem**:
    1. For `Agg.sum` (`lines 97-100`), `srcCol.dataType is DataType<double> ? DataType.float64 : DataType.int64` assigns `DataType.int64` when `srcCol` has `DataType.numeric` (`TypedSeries<num>`). When the group sum is a `double` (e.g., `3.5`), line 139 converts `resultCols[entry.key]` to `List<double?>`, and line 156 calls `Series.fromList(entry.key, entry.value, type: DataType.int64)`, throwing `TypeError: 3.5: type 'double' is not a subtype of type 'int?'`.
    2. If `byColumns` contains `'a_count'` and `aggregations` contains `{'a': [Agg.count]}`, `outName = 'a_count'` collides with the group key column in `resultCols`, appending both group keys and aggregated counts into the same list (`2 * numGroups` elements).
  - **Fix**: In `GroupBy.aggregate`, update `outTypes[entry.key] = DataType.float64` whenever line 139 promotes a column list to `double` (and map `DataType.numeric` to `DataType.float64` for `Agg.sum`), and disambiguate `outName` if it collides with `byColumns`.

- [ ] **1.9.4 `ArrowIpc` fails on `DataType.numeric`, string offset padding, and unvalidated FlatBuffer bounds, and `ArrowCData` crashes on unaligned FFI pointers**
  - **Severity**: Critical
  - **Location**: `lib/src/dataframe/arrow/arrow_ipc.dart:194-260, 327-353, 689-807`, `lib/src/dataframe/arrow/arrow_c_data_ffi.dart:491-658, 878-941`
  - **Problem**:
    1. `ArrowIpc._serializeType` (`arrow_ipc.dart:194-260`) and `_buildRecordBatchFlatBufferAndBody` (`lines 327-353`) do not handle `DataType.numeric` (throwing `UnsupportedError` or `TypeError` on `td as TypedData`), unlike `arrow_c_data_ffi.dart` which maps `DataType.numeric` to `float64`.
    2. In `ArrowIpc._readRecordBatch` for Utf8 strings (`lines 747-761`), `offCount = offLen ~/ 4` uses the padded buffer byte length instead of `colLength + 1`. If an Arrow producer pads the offsets buffer to 8/64-byte alignment inside `offLen`, `offsets.length > colLength + 1`, causing `ArrowStringSeries` to throw an `ArgumentError` on mask length mismatch.
    3. In `importSeriesFromArrowC` (`arrow_c_data_ffi.dart:492-625`), `arrayPtr.ref.buffers[1].cast<ffi.Double>().asTypedList(...)` throws `ArgumentError` in Dart VM if the external C buffer pointer is not 8-byte aligned (or 4-byte/2-byte aligned for 32-bit/16-bit types).
  - **Fix**:
    1. Support `DataType.numeric` (converting to `Float64List`) in `ArrowIpc`.
    2. Read exactly `colLength + 1` offsets in `ArrowIpc._readRecordBatch` (validating `offLen >= (colLength + 1) * 4` when `colLength > 0`) and validate buffer offsets/lengths against `body.length`.
    3. In `arrow_c_data_ffi.dart`, check pointer alignment (`ptr.address % elemBytes == 0`); if unaligned, copy bytes via `ptr.cast<ffi.Uint8>().asTypedList(byteLen)` into an aligned typed list. Also release `schema.ref.dictionary` and `array.ref.dictionary` if non-null in `_releaseArrowSchema` / `_releaseArrowArray`.

- [ ] **1.9.5 Edge cases in `DataFrame.withColumn`, `DataFrame.melt`, `DataFrame.pivot`, `DataFrame.slice`/`head`/`tail`, `CsvStreamTransformer`, and `Series.hashCode`**
  - **Severity**: Warning
  - **Location**: `lib/src/dataframe/dataframe.dart:219-232, 355-482, 626-645`, `lib/src/dataframe/csv/csv_stream.dart:48-52, 250-255`, `lib/src/dataframe/series.dart:200-226`
  - **Problem**:
    1. `DataFrame.withColumn`: replacing the sole column in a 1-column DataFrame with a `Series` of different length silently changes `rowCount` instead of throwing `ArgumentError`.
    2. `DataFrame.melt`: returns `ObjectSeries` for `valueName` when `rowCount == 0` because `valueDataType` is computed after the `totalRows == 0` early return, and does not use `promoteWith` when `valCols` have mixed numeric types (e.g. `int32` and `float64`).
    3. `DataFrame.pivot`: when `aggregate == null`, pivoted columns do not pass `type: valCol.dataType` to `Series.fromList`, degrading all-null category columns to `ObjectSeries`.
    4. `DataFrame.head` / `tail`: do not validate `RangeError.checkNotNegative(count, 'count')`, and `DataFrame.slice` does not clamp `end` to `>= startIndex`.
    5. `CsvStreamTransformer`: does not validate `separator.length == 1` and `quoteChar.length == 1` before calling `.codeUnitAt(0)`, and `CsvStream.readChunks` locks in `DataType.string` if a column is all-null in the first chunk or throws `ArgumentError` if chunk 1 is inferred as `int32` and chunk 2 contains a `double`.
    6. `Series.hashCode`: hashes raw `this[i]` instead of canonicalizing `NaN` / `-0.0` via `dataType.equality.hash`.
  - **Fix**: Validate `series.length == rowCount` in `withColumn`; compute `valueDataType` via `promoteWith` before the `totalRows == 0` check in `melt`; pass `type: valCol.dataType` when `aggregate == null` in `pivot`; validate `count >= 0` in `head`/`tail` and clamp `endIndex` in `slice`; validate `separator`/`quoteChar` and allow numeric widening across chunks in `CsvStream`; and use `dataType.equality.hash` in `Series.hashCode`.

---

### 1.10 `symbolic` Subsystem

- [ ] **1.10.1 Indefinite `Integral` drops its variable from `freeVariables` (causing `derivative` to return `0`) and definite `Integral` differentiation omits Leibniz boundary terms**
  - **Severity**: Critical
  - **Location**: `lib/src/symbolic/ast/integral.dart:54-61`, `lib/src/symbolic/calculus/differentiation.dart:52-55, 231-244`
  - **Problem**:
    1. `Integral.collectFreeVariables` (`integral.dart:54-61`) unconditionally removes `variable` (`inner.remove(variable)`) even when `isIndefinite` (`lower == null && upper == null`). For an indefinite integral $\int f(x)\,dx$, $x$ is a free variable of the antiderivative. Because `Integral(Sin(x^2), 'x').dependsOn('x')` returns `false`, `_differentiate` (`differentiation.dart:53`: `if (!expr.dependsOn(variable)) return IntegerNumber.zero;`) returns `0` immediately, making line 234 (`(null, null) => intVar == variable ? integrand : ...`) unreachable dead code!
    2. For a definite integral $\frac{d}{dx}\int_{l(x)}^{u(x)} f(t, x)\,dt$ (`differentiation.dart:237-241`), `_differentiate` only computes $\int_l^u \frac{\partial f}{\partial x}\,dt$ (and returns `0` when `intVar == variable`), omitting the Fundamental Theorem of Calculus / Leibniz rule boundary terms $f(u(x), x)\,u'(x) - f(l(x), x)\,l'(x)$ (which `ARCHITECTURE.md` Section 9.3 explicitly advertises!).
  - **Fix**:
    1. In `Integral.collectFreeVariables`, only remove `variable` when `isDefinite`; when `isIndefinite`, keep `variable` in `target`.
    2. In `differentiation.dart:237-241`, add `upperTerm - lowerTerm` ($f(u(x), x) u'(x) - f(l(x), x) l'(x)$) to the inner integral term.

- [ ] **1.10.2 `computeLimit` prematurely collapses $b^{u(x)}$ to `0`/`infinity` before Gruntz MRV analysis and fails on `Sinh`/`Cosh`/`Tanh` at infinity**
  - **Severity**: Critical
  - **Location**: `lib/src/symbolic/calculus/limit.dart:161-209, 479-500, 577-695`
  - **Problem**:
    1. `_resolveAsymptoticAbsAndPiecewise` (`limit.dart:479-500`) replaces any `Pow(base, exponent)` (where `base is RealNumeric`) with `0` or `Constant.infinity` *before* Gruntz MRV analysis. On `(2^x / 3^x).limit('x', Constant.infinity)` or `(2^(x + 1) / 2^x).limit('x', Constant.infinity)`, this creates `infinity * 0 = Constant.undefined` and aborts the limit!
    2. `_findDominantExpScale` (`limit.dart:610-632`) only recognizes `Pow(base: Constant.e, ...)`. Expressions containing `Sinh(x)`, `Cosh(x)`, `Tanh(x)`, or `Pow(2, x)` fail to find an MRV scale; thus `Sinh(x).limit('x', Constant.infinity)` and `(Sinh(x) / Cosh(x)).limit('x', Constant.infinity)` return unevaluated `Limit` nodes instead of `Constant.infinity` and `1`.
  - **Fix**:
    1. Remove the premature `Pow(base, exponent)` collapse in `_resolveAsymptoticAbsAndPiecewise`.
    2. In `_gruntzLimit`, rewrite hyperbolic functions (`Sinh`, `Cosh`, `Tanh`, `Asinh`, `Acosh`, `Atanh`) via `.rewrite(RewriteTarget.exp, assumptions: assumptions)` and rewrite positive numeric-base powers `Pow(base, exp)` (where `base is RealNumeric && base.sign > 0 && !base.isOne && exp.dependsOn(variable)`) as `Pow(Constant.e, exp * Ln(base))`, and add `Sinh`, `Cosh`, `Asinh`, `Acosh` to the fast-path elementary limit table (`lines 161-209`).

- [ ] **1.10.3 `BareissEngine` fails to detect zero rational pivots, producing wrong `rank()`, `rowEchelon()`, `nullSpace()`, and `eigenvectors()` on symbolic matrices**
  - **Severity**: Critical
  - **Location**: `lib/src/symbolic/linear/bareiss.dart:264-268, 404-408`
  - **Problem**: During `BareissEngine.rowEchelonWithPivots`, row elimination produces rational function entries with different polynomial denominators (e.g. `x` and `x - 1`). `_simplifyDifference` (`line 264`) only calls `(a - b).simplify()` when `_hasDiv(diff)` is `true`, and `_isExprZero` (`line 404`) only calls `expr.expand().simplify()` without combining fractions over a common denominator. Consequently, algebraically zero pivot expressions such as `4 - (2*x + 1)/x - (3 - (2*x + 1)/x)*(2*x - 1)/(x - 1)` are not recognized as zero, causing `Matrix<Expr>.rank()` to return `3` instead of `2` and `nullSpace()` to return `[]` on singular symbolic matrices.
  - **Fix**: Call `diff.cancel()` in `_simplifyDifference` when `_hasDiv(diff)` is `true`, and check `s.together()` in `_isExprZero` when `_hasDiv(s)` is `true`.

- [ ] **1.10.4 `simplifyArg` leaves literal `+ 0`, and `toPolarExpr`, `toRectangularExpr`, and `_collectAdditive` construct non-canonical AST nodes with `isSimplified: true`**
  - **Severity**: Critical
  - **Location**: `lib/src/symbolic/algebra/simplify/transcendental.dart:1456-1467, 1560-1563, 1590-1598`, `lib/src/symbolic/algebra/rational.dart:605-617`
  - **Problem**:
    1. `simplifyArg` (`transcendental.dart:1458-1466`) returns `simplifyAtan(...) + (real.isNegative ? ... : IntegerNumber.zero)` using raw `+`, so `Arg(ComplexNumber(2, 3)).simplify()` evaluates to `Add([Atan(3/2), 0])` (`atan(3/2) + 0`)!
    2. `toPolarExpr` (`transcendental.dart:1590-1598`) constructs `Mul([r, expPart], isSimplified: true)` directly. When `r` is itself a `Mul` (e.g. `2 * sqrt(2)` for `ComplexNumber(2, 2).toPolar()`), it creates a nested `Mul([Mul([2, 2^(1/2)]), e^(...)], isSimplified: true)`, violating the flattened `Mul` AST invariant.
    3. `toRectangularExpr` (`transcendental.dart:1560-1563`) constructs `Add([re, imTerm], isSimplified: true)` without sorting or combining terms via `simplifyAdd`.
    4. `_collectAdditive` (`rational.dart:605-617`) wraps `sumCoeff` in `Mul(factors, isSimplified: true)` without flattening when `sumCoeff is Mul`.
  - **Fix**: Return `atanTerm` directly when `!real.isNegative` and use `simplifyAdd` in `simplifyArg`; unpack `r` in `toPolarExpr` and `sumCoeff` in `_collectAdditive` when they are `Mul`; and use `simplifyAdd` in `toRectangularExpr`.

- [ ] **1.10.5 `Expr._isRealSubtree` ignores complex exponents on `Pow`, and `_isRealRoot` in `univariate.dart` ignores `Assumptions` on symbolic parameters**
  - **Severity**: Critical
  - **Location**: `lib/src/symbolic/ast/expr.dart:220-224`, `lib/src/symbolic/solver/univariate.dart:67, 280-293`
  - **Problem**:
    1. In `Expr._isRealSubtree` (`expr.dart:220-224`), `Pow(:final base, :final exponent)` checks `_isRealSubtree(base) && (exponent is IntegerNumber || (base is RealNumeric && !base.isNegative) || base is Abs)` without checking `_isRealSubtree(exponent)`. Thus `Pow(IntegerNumber.two, ComplexNumber.i).isReal` ($2^i$) falsely returns `true`.
    2. In `univariate.dart:280-293`, `_isRealRoot(expr)` checks `expr.isReal` without passing `assumptions` to `isProvenReal(expr, assumptions)`. Solving `x^2 - a = 0` for `x` with `Assumptions(domains: {'x': VariableDomain.real, 'a': VariableDomain.positive})` discards `-sqrt(a)` and `sqrt(a)` and returns `[]`!
  - **Fix**: Require `_isRealSubtree(exponent)` in `Expr._isRealSubtree`, and check `isProvenReal(expr, assumptions)` in `_isRealRoot` / `satisfiesVariableDomain`.

- [ ] **1.10.6 `evaluateDefiniteIntegral` misses interior poles of `Tan(u)` (returning $-\pi$ for $\int_0^\pi \tan^2(x)\,dx$)**
  - **Severity**: Critical
  - **Location**: `lib/src/symbolic/calculus/definite_integration.dart:216-267`
  - **Problem**: `extractDenominatorFactors` only inspects `Pow` nodes with negative exponents and misses `Tan(u)` ($\frac{\sin u}{\cos u}$, which has poles where $\cos u = 0$) and `Ln(u)` (singular at $u = 0$). Consequently, `Pow(Tan(x), 2).integrate('x', from: 0, to: Constant.pi)` fails to detect the order-2 pole at $x = \pi/2$, plugs $0$ and $\pi$ into the antiderivative $\tan(x) - x$, and returns $-\pi$ for a strictly non-negative integrand!
  - **Fix**: In `extractDenominatorFactors` / `hasInteriorPole`, treat `Tan(arg)` as having denominator factor `Cos(arg)` and check whether `arg` crosses $(k + \frac{1}{2})\pi$ inside `(low, high)` (and check `Ln(arg)` for `arg <= 0` inside `[low, high]`).

- [ ] **1.10.7 `LambertW(x, branch: -1)` series/limit at `0`, `summation.dart` `sqrt(x^2)` in even factorial series, `factorUnivariatePoly` square-free recursion, `solveSystemEquations` linearity check, `BytecodeEvaluator` complex subexpressions under `Re`/`Im`, and `_formatOrderTerm` double minus**
  - **Severity**: Warning
  - **Location**:
    - `lib/src/symbolic/calculus/series.dart:612-613` & `lib/src/symbolic/calculus/limit.dart:161-209`
    - `lib/src/symbolic/calculus/summation.dart:1020-1064`
    - `lib/src/symbolic/algebra/factor/univariate.dart:241-244`
    - `lib/src/symbolic/solver/system.dart:142-200` & `lib/src/symbolic/solver/transcendental.dart:223-228`
    - `lib/src/symbolic/compiler/bytecode.dart:296-610` & `lib/src/symbolic/compiler/evaluator.dart:144-156`
    - `lib/src/symbolic/parser.dart:689-691` & `lib/src/symbolic/textualization/string.dart:323-326`
  - **Problem**:
    1. `series.dart:612` expands `LambertW(x, branch: -1)` at `0` using the principal-branch $W_0$ Maclaurin series even though $W_{-1}(x) \to -\infty$ as $x \to 0^-$.
    2. `summation.dart:1022` computes `xVal = Pow(posRatio, 1/2).simplify()`, leaving `sqrt(x^2)` unsimplified in $\sum_{k=0}^\infty \frac{(-1)^k x^{2k+1}}{(2k+1)!} \to \frac{x \sin(\sqrt{x^2})}{\sqrt{x^2}}$ instead of $\sin(x)$ even though $\frac{\sin z}{z}$, $\cos z$, $\frac{\sinh z}{z}$, and $\cosh z$ are even functions where $\sqrt{x^2} \mapsto x$ is valid for all $x \in \mathbb{C}$.
    3. `factor/univariate.dart:241-244` does not recursively call `factorUnivariatePoly` on square-free components, leaving $(x^4 + 4)^2$ unfactored instead of $((x^2 - 2x + 2)(x^2 + 2x + 2))^2$.
    4. `solveSystemEquations` (`system.dart:183-189`) does not verify `eq - reconstructed == 0`, accepting non-linear equations containing zero-derivative functions like `Floor(x)`. Also, `transcendental.dart:223-228` drops `assumptions` when inverting `Pow(Constant.e, exponent) = c`.
    5. `BytecodeEvaluator._runReal` (`evaluator.dart:145`) returns `NaN` for `Im(Pow(x, 1/2)).evaluate({'x': -4.0})` because `hasComplexLiterals` is `false` and `sqrt(-4.0)` evaluates in real `double` arithmetic before `Op.im` runs.
    6. `parser.dart:689-691` fails to unbind the base `e` in `diff(e^2, e)`, and `string.dart:323-326` formats `OrderTerm('x', 2, point: -Variable('a'))` as `'O((x - -a)^2)'` instead of `'O((x + a)^2)'`.
  - **Fix**: Require `branch == 0` for `LambertW` Maclaurin series at `0` (and return `-Constant.infinity` for `LambertW(u, branch: -1)` limit at $0^-$); extract exact even powers in `summation.dart:1022`; recursively factor square-free components in `factor/univariate.dart`; verify `(eq - reconstructed).expand().simplify() == 0` in `solveSystemEquations` and forward `assumptions` in `transcendental.dart`; fall back to `_runComplex` when `_runReal` encounters `Re`/`Im`/`Arg`/`Conjugate` or `NaN` from complex-capable ops; distinguish `exp(...)` from `e^...` in `_unbindConstant`; and use `stripLeadingNegative(point)` in `_formatOrderTerm`.

---

### 1.11 `web/` Applications

- [ ] **1.11.1 `web/distributions` passes `double` to `DiscreteDistribution.cumulativeProbability(int)` and crashes on invalid URL hash parameters**
  - **Severity**: Critical
  - **Location**: `web/distributions/index.dart:291-297, 462-466, 930, 943, 1071`
  - **Problem**:
    1. Lines 930, 943, and 1071 call `activeDist.cumulativeProbability(k.toDouble())` and `activeDist.cumulativeProbability(targetX)` directly with a `double`. For discrete distributions, `activeDist` is `Distribution<int>`, throwing a `TypeError` (`type 'double' is not a subtype of type 'int'`) in `dart2wasm` or when `targetX` is a non-integer hover coordinate.
    2. `selectDistribution` (`lines 462-466`) assigns URL query overrides directly into `currentParamValues` without clamping to `[p.min, p.max]`, checking `.isFinite`, or rounding when `p.isInt` is `true`, crashing app initialization on URLs like `#normal?sigma=-1` or `#binomial?p=2`.
  - **Fix**: Add `double evalDistCumulativeProbability(num x)` (calling `(activeDist as Distribution<int>).cumulativeProbability(x.floor())` when `!activeDef.isContinuous`) and clamp/validate `parameterOverrides` in `selectDistribution`.

- [ ] **1.11.2 Mathematical typography violations in `web/index.html`, `web/expressions`, and `web/calculator` (`AGENTS.md`)**
  - **Severity**: Critical
  - **Location**: `web/index.html:567, 608, 664, 693, 749`, `web/expressions/index.dart:2098, 2186-2191`, `web/calculator/src/engine/sampling.dart:267`, `web/calculator/src/engine/commands/plot.dart:233`
  - **Problem**:
    1. `web/index.html` omits `movablelimits="false"` on all five `<mo>∑</mo>` tags inside `<munderover>` / `<munder>`.
    2. `web/expressions/index.dart:2186-2191` formats plot hover tooltip derivatives using prime notation (`f'(x):`, `f''(x):`, `f'''(x):`) instead of Leibniz notation (`df/dx:`, `d²f/dx²:`, `d³f/dx³:`), and line 2098 uses `'x0'` instead of `'x₀'`.
    3. `web/calculator/src/engine/sampling.dart:267` and `plot.dart:233` format ODE labels with prime notation (`"y' = $rhs, ..."`).
  - **Fix**: Add `movablelimits="false"` to `<mo>∑</mo>` in `web/index.html`, and replace all prime notation (`f'(x)`, `y'`) with Leibniz notation (`df/dx`, `dy/dt`).

- [ ] **1.11.3 Mobile `.calc-header { overflow-x: auto }` clips popovers, autocomplete keyboard navigation selects hidden items (`> 8`), and `nminimize` corrupts narrow user brackets `[a, b]`**
  - **Severity**: Critical
  - **Location**: `web/calculator/style.css:1411-1417`, `web/calculator/src/ui/input_bar.dart:368-378, 637`, `web/calculator/src/engine/commands/numeric.dart:130-136`
  - **Problem**:
    1. In `web/calculator/style.css:1411-1417`, `@media (max-width: 640px)` sets `overflow-x: auto` on `.calc-header`, which per CSS Overflow Level 3 forces `overflow-y: auto` and clips `#vars-drawer`, `#settings-popover`, and `.app-menu` inside the 44px header bar on mobile screens.
    2. In `input_bar.dart:637`, `_renderPopup` renders `.take(8)`, whereas `_onKeyDown` (`lines 368-378`) wraps `_selectedCompletionIdx` modulo `_currentCompletion.items.length`, selecting invisible items when more than 8 completions match.
    3. In `numeric.dart:130-135`, `nminimize(expr, x, a, b)` computes `minBound = math.min(a, b - 1.0)` and `maxBound = math.max(a + 1.0, b)`, expanding any bracket narrower than `1.0` (e.g. `[0.5, 0.9]` on `x - ln(x)`) outside `[a, b]` into `x < 0`!
  - **Fix**: Remove `overflow-x: auto` from `.calc-header` on mobile (or position `.calc-popover` with `position: fixed`); cap completion items to 8 in `CalcCompletion.complete` / `_onKeyDown`; and use `[math.min(a, b), math.max(a, b)]` directly when 4 arguments are passed to `nminimize` (and `[a - 1.0, a + 1.0]` when 3 arguments are passed).

- [ ] **1.11.4 Degree mode (`AngleMode.deg`), stale cell tracking, RPN Vars/Help actions, worker undo sync, RPN Unicode minus, and `+ Plot` chip in `web/calculator`**
  - **Severity**: Warning
  - **Location**:
    - `web/calculator/src/engine/evaluator.dart:169-182, 827-845` & `web/calculator/src/engine/sampling.dart:464-486`
    - `web/calculator/src/model/session.dart:78-115`
    - `web/calculator/src/ui/app.dart:90-91, 185-187, 405-408, 446-450, 479-483`
    - `web/calculator/src/worker/engine_client.dart:94, 356-362, 398`
    - `web/calculator/src/language/grammar.dart:295-360`
    - `web/calculator/src/ui/scroll_view.dart:72-76, 140-153`
  - **Problem**:
    1. In `AngleMode.deg`, `_constructUnaryFunction` skips degree conversion whenever `arg.freeVariables.isNotEmpty`, so user functions `f(x) := sin(x); f(90)` and `subs(sin(x), x = 90)` evaluate in radians, and `_convertTrigArgToDegrees` in `sampling.dart` double-scales nested trig expressions like `sin(cos(x))`.
    2. `Session.addResult` never calls `markDependentsStale(changedSymbols: ...)`, so reassigning `a := 5` in a new cell (or via RPN `STO`) leaves earlier cells depending on `a` unmarked.
    3. Clicking `Clear All` / `✕` in the Vars Drawer or `▶ example` in the Help Drawer while in RPN mode sends algebraic syntax (`clear(a)`) to `evaluateRpnLine`, failing with a syntax error.
    4. `EngineClient.resetAll()` ignores the worker response (`_canUndo` stays `false`), and `_spawnWorker()` leaves `_canUndo`/`_canRedo` stale after worker respawn.
    5. `rpnSignedNumber()` rejects Unicode minus `−5` and `rpnToken()` omits `√2`.
    6. `scroll_view.dart:72-76` shows the 1D `+ Plot` overlay chip when the latest plot is a 3D surface (`pv.is3d`) or ODE plot (`pv.isOde`), and canceling inline cell edit triggers a full worker re-evaluation.
  - **Fix**: Apply degree scaling uniformly in `_constructUnaryFunction` and remove `_convertTrigArgToDegrees` in `sampling.dart`; call `markDependentsStale` in `Session.addResult`; route Vars Drawer clear and Help Drawer examples through `evaluateScroll`; sync undo state in `resetAll()` and `_spawnWorker()`; support `−`/`–` and `√` in RPN grammar; and guard `latestPlot` with `!pv.isParametric && !pv.is3d && !pv.isOde` while restoring canceled cell edits locally.

- [ ] **1.11.5 Chart clipping, shaded interval endpoint, WebGL vertex attribute bleed, and state resets in `web/shared`, `web/expressions`, and `web/distributions`**
  - **Severity**: Warning
  - **Location**:
    - `web/shared/chart.dart:580-630, 788-860, 884, 917`
    - `web/shared/webgl_chart.dart:238-281, 359-380, 527-582` & `web/shared/webgl_surface.dart:681-720, 824-832`
    - `web/expressions/index.dart:2220-2276, 2298-2308`
    - `web/distributions/index.dart:559-581, 717-725, 838-866` & `web/distributions/config.dart:325-330, 605-609, 638-642`
  - **Problem**:
    1. `drawCurve` (`chart.dart:580-630`) clamps exit points on steep curves (`1/x`, `tan(x)`) to `[yMinPx, yMaxPx]`, but does not prepend a clamped entry point when re-entering the viewport from $\pm\infty$.
    2. `drawShadedInterval` (`chart.dart:788-860`) steps by `1.5` pixels and stops up to `1.49` pixels short of `endPx`, and `drawReferenceLine`/`drawPointMarker` (`lines 884, 917`) do not guard `NaN`.
    3. `WebGL2ChartLayer.drawPolyline` (`webgl_chart.dart:364-379`) leaves 4 vertex attributes enabled (`stride = 24`) when `drawAreaFill` (`stride = 12`) runs, and `webgl_surface.dart` never clears the hover readout when the cursor leaves the surface.
    4. `web/expressions`: `loadFromUrlHash` never clears `currentVariableDomains` before loading a new URL hash, and `_sliceFor1DPlot` fails when a single-variable expression uses a variable name other than `'x'` (e.g. `sin(t)`).
    5. `web/distributions`: `updateQuantileCalculator` displays `Undefined` at $p = 0$ or $p = 1$ on infinite-support distributions, `degenerate_continuous` renders a flat $y = 0$ line instead of an impulse stem at $x = k$, and cross-parameter clamping in `config.dart` desynchronizes slider values from `currentParamValues`.
  - **Fix**: Prepend clamped entry points in `drawCurve`; always sample `endPx` in `drawShadedInterval`; guard `!x.isFinite` in `drawReferenceLine`/`drawPointMarker`; disable vertex attributes after `gl.drawArrays` in `WebGL2ChartLayer` and clear hover readout in `WebGL2SurfaceView`; clear `currentVariableDomains` in `loadFromUrlHash` and map single free variables to `'x'` in `_sliceFor1DPlot`; and handle $p \in \{0, 1\}$, `degenerate_continuous` stems, and cross-parameter slider sync in `web/distributions`.

---

## 2. Duplicated Code, Simplification, Optimization & Cleanup

- [ ] **2.1 Eliminate duplicated `_tred2`/`_tql2` in `EigenvalueDecomposition`, duplicated BLAS dispatch in `Float64Matrix`/`Float64Vector`, and duplicated branches in `Float64Tensor._binaryOp`**
  - **Severity**: Warning
  - **Location**: `lib/src/linear/decomposition/eigenvalue.dart:63-103, 164-363`, `lib/src/linear/float64_matrix.dart:230-329`, `lib/src/linear/float64_vector.dart:127-155`, `lib/src/tensor/float64_tensor.dart:197-237`, `lib/src/linear/decomposition/qr.dart:44`
  - **Problem**:
    1. `EigenvalueDecomposition` only routes `matrix.type == DataType.float64` to `Lapack.dsyev` and maintains a 200-line copy of `_tred2` and `_tql2` duplicating `LapackDart.dsyev`, violating `AGENTS.md` (*"must call the unified accelerated facades (`Blas`, `Lapack`, `Fft`, `Vforce`) directly ... and must never duplicate fallback implementations outside the `acceleration` subsystem"*).
    2. `Float64Matrix.operator *` and `Float64Matrix.apply` duplicate narrow `isContiguous`-only BLAS calls (and copy `other.data` via `Float64List.fromList`), whereas `_matrix * other` and `_matrix.apply(x)` already route to `Blas.dgemm` and `Blas.dgemv` with full transposed and strided layout support.
    3. `Float64Tensor._binaryOp` (`lines 197-216` and `217-237`) contains two character-for-character identical 20-line branches.
    4. `QRDecomposition` (`qr.dart:44`) allocates `_tau = List<double>.filled(matrix.colCount, 0.0)` unconditionally even on the `Float64List` path where `_tau` is unused.
  - **Fix**: Route all symmetric `Matrix<num>` in `EigenvalueDecomposition` through `Lapack.dsyev` and delete `_tred2`/`_tql2`; delegate `Float64Matrix.operator *` and `apply` to `_matrix`; deduplicate `Float64Tensor._binaryOp`; and only allocate `_tau` when needed.

- [ ] **2.2 Eliminate boxing and duplicated logic in `DataFrame`, `Series`, `ValidityMask`, `CsvReader`/`CsvStream`, and `ArrowStringSeries`**
  - **Severity**: Warning
  - **Location**:
    - `lib/src/dataframe/dataframe.dart:99-140, 676-710, 755-788`
    - `lib/src/dataframe/series.dart:254-261, 523-530, 619, 761-768, 982-989`
    - `lib/src/dataframe/arrow_string_series.dart:63-108, 315-322`
    - `lib/src/dataframe/bitmask.dart:169-195`
    - `lib/src/dataframe/csv/csv_reader.dart:52-116` & `lib/src/dataframe/csv/csv_stream.dart:130-226`
  - **Problem**:
    1. `DataFrame.fromMatrix` and `DataFrame.fromTensor` box every element into a `List<Object?>` per column before calling `Series.fromList`.
    2. `DataFrame.toTensor` calls `Tensor<double>.filled(0.0, ...)` (writing `0.0` across the entire array) right before overwriting every element.
    3. `Series.fillNull` boxes all elements into a `List<T?>` instead of cloning `data` and writing `value` only at null mask positions.
    4. `ArrowStringSeries.fromList` allocates a separate `Uint8List` per non-null string (`List<Uint8List?>.filled`) instead of encoding into a single `BytesBuilder`.
    5. `CsvReader._parse` and `CsvStream._buildDataFrame` duplicate 55 lines of column type inference logic.
    6. All four `Series` subclasses duplicate the same `concat` fallback and `BoolSeries`/`ObjectSeries`/`ArrowStringSeries` lack `toString()` (defined only on `TypedSeries`).
  - **Fix**: Construct `TypedSeries` directly in `DataFrame.fromMatrix`/`fromTensor`; allocate uninitialized typed storage in `toTensor`; implement unboxed `fillNull` on `TypedSeries`/`BoolSeries`/`ObjectSeries`; use `BytesBuilder` in `ArrowStringSeries.fromList`; share the DataFrame column builder between `CsvReader` and `CsvStream`; and move base `concat` and `toString()` to `Series<T>`.

- [ ] **2.3 Consolidate duplicated symbolic zero-testing, AST term/factor collection, `rootConstant`, and `_bdf2` derivative caching**
  - **Severity**: Suggestion
  - **Location**:
    - `lib/src/symbolic/solver/univariate.dart:73-90, 126-143`, `lib/src/symbolic/type/expr_data_type.dart:196-199`, `lib/src/symbolic/linear/bareiss.dart:390-408`, `lib/src/symbolic/linear/faddeev_leverrier.dart:186-190`, `lib/src/symbolic/solver/polynomial.dart:115-153`, `lib/src/symbolic/solver/resultant.dart:158`
    - `lib/src/symbolic/algebra/factor/fraction.dart:50-75`
    - `lib/src/numeric/ode/solve_ode.dart:449-453`
  - **Problem**:
    1. Eight separate zero-testing helpers (`isZeroExpr`, `ExprField.isZero`, `BareissEngine._isExprZero`, `FaddeevLeVerrierEngine._isZero`, `PowerSeries._isZero`, `_isDefinitelyZero`, `_isZero`, `_isZeroCoeff`) and multiple additive/multiplicative collector helpers exist with subtly different behavior.
    2. `polynomial.dart:115-151` implements a custom `int`-only `integerNthRoot` using `math.pow`, duplicating exact arbitrary-precision radical extraction in `power.dart`.
    3. `_bdf2` (`solve_ode.dart:449-453`) re-evaluates `f(currentTime, yN)` and `f(tPrev, yPrev)` on every step instead of reusing cached evaluations from the previous steps.
  - **Fix**: Unify symbolic zero-testing into `isZeroExpr` (with rational `.together()` fallback); share `collectAdditiveTerms` and `collectFactors`; delegate `rootConstant` to `Pow(c, RationalNumber(1, n)).simplify()`; simplify net exponent cancellation in `fraction.dart`; and cache `fN`/`fPrev` across steps in `_bdf2`.

- [ ] **2.4 Deduplicate WebGL shader compilation, trig degree conversion, and redundant HTML/CSS rules in `web/`**
  - **Severity**: Suggestion
  - **Location**: `web/shared/webgl_chart.dart:527-582`, `web/shared/webgl_surface.dart:1080-1134`, `web/expressions/index.dart:2362-2394`, `web/calculator/src/engine/sampling.dart:450-486`, `web/index.html:15, 231-233, 552`, `web/distributions/index.html:15`, `web/expressions/index.html:15`
  - **Problem**:
    1. `_compileProgram` and `_compileShader` are duplicated verbatim between `webgl_chart.dart` and `webgl_surface.dart` (and neither deletes compiled shader objects after linking).
    2. `web/index.html`, `web/distributions/index.html`, and `web/expressions/index.html` redundantly load `LatinModern/mathfonts.css` (already imported by `web/shared/style.css:2`), and `web/index.html` defines `math msqrt > mrow` twice.
  - **Fix**: Share a single WebGL shader compiler helper in `web/shared/` that detaches and deletes `vs`/`fs` after linking, and remove the duplicate `<link>` and CSS rules in `web/`.

---

## 3. Code Style, Architecture & Documentation

- [ ] **3.1 Remove internal `export` directives inside `lib/src/symbolic/` and enforce in `test/deps_test.dart` (`AGENTS.md`)**
  - **Severity**: Warning
  - **Location**: `lib/src/symbolic/calculus/summation.dart:16`, `lib/src/symbolic/algebra/simplify/transcendental.dart:25`, `test/deps_test.dart`
  - **Problem**: `AGENTS.md` states: *"Intermediate internal barrel files inside `lib/src/` are prohibited; root `lib/<subsystem>.dart` files must export public declarations directly (conditional platform export selectors such as `library_loader.dart` and `arrow_c_data.dart` are allowed exceptions)."* Currently, `summation.dart:16` contains `export 'product.dart';` and `transcendental.dart:25` contains `export 'domain.dart';`.
  - **Fix**: Remove `export 'product.dart';` from `summation.dart` and `export 'domain.dart';` from `transcendental.dart`, import `product.dart` / `domain.dart` directly where needed, and add an assertion in `test/deps_test.dart` verifying that no file in `lib/src/` (other than conditional platform selectors) contains an `export` directive.

- [ ] **3.2 Fix top-level and class member ordering violations across `lib/` and `web/` (`AGENTS.md`)**
  - **Severity**: Warning
  - **Location**:
    - `lib/src/dataframe/arrow/arrow_c_data_ffi.dart:210` (`_releaseArrowSchema`, `_releaseArrowArray` before public functions)
    - `lib/src/dataframe/bitmask.dart:215` & `lib/src/dataframe/dataframe.dart:891` (private constructors `new _` placed at bottom of class instead of with constructors at top)
    - `lib/src/dataframe/csv/csv_stream.dart:63` (`_buildDataFrame` before `CsvStreamTransformer` at line 231)
    - `lib/src/stats/descriptive.dart:33` (`_variance` before `standardDeviation` at line 44)
    - `lib/src/symbolic/algebra/exact_constants.dart:140` (`_isRationalTimesSqrt` before `isNegativeSqrt3Over2` at line 143)
    - `lib/src/symbolic/algebra/simplify/multiplicative.dart:142` (`_combineRadicalBases` before `simplifyDiv` at line 197)
    - `lib/src/symbolic/algebra/structural_order.dart:90` (`_compareList` before `realScalarValue` at line 246)
    - `lib/src/symbolic/calculus/definite_integration.dart:14` (`_negInfinity` before `isInfiniteBound` at line 20)
    - `lib/src/symbolic/calculus/linear_form.dart:40` (`_matchLinear` before `partitionFactors` at line 58)
    - `lib/src/symbolic/calculus/series.dart:49` (`_wrapSeriesPoint` before `SymbolicPolynomialFactory` at line 140)
    - `lib/src/symbolic/compiler.dart:91` (`_compileBytecode` before `CompilerIterableExtension` at line 213)
    - `lib/src/symbolic/solver/polynomial_system.dart:67` (`_solveViaGroebner` before `filterSolutionsByAssumptions` at line 77)
    - `lib/src/symbolic/solver/system.dart:80` (`_collectDenominatorBases` before `solveSystemEquations` at line 142)
    - `lib/src/symbolic/solver/transcendental.dart:247` (`_solveLambertWEquation` before `isRealConstantOutOfRange` at line 397)
    - `lib/src/symbolic/solver/trigonometric.dart:47` (`_invertAngles` before `invertCos` at line 51)
    - `lib/src/symbolic/solver/univariate.dart:51` (`_filterByDomain` before `satisfiesVariableDomain` at line 55)
    - `lib/src/tensor/operations/operation.dart:190` (`_hasMemoryHazard` before `LogicalTensorExtension` at line 302)
    - `lib/src/type/utils/derive.dart:8` (`_fromType` before `fromInstance` at line 11)
    - `web/calculator/src/engine/sampling.dart:42` (`_convertTrigArgToDegrees` before `buildParametricPlotValue` at line 141)
    - `web/calculator/src/language/grammar.dart:39` (`_reservedNames` before `CalcGrammar` at line 410)
    - `web/calculator/src/worker/engine_client.dart:16` (`_dartLoader` before `EngineClient` at line 25)
    - `web/expressions/index.dart:573` (`_setHidden` before `updateImaginaryDetection` at line 759)
    - `web/shared/chart.dart:83` (`_defaultMinX` before `niceTicks` at line 366)
    - `web/shared/utils.dart:26` (`_copyToast` before `setAttrValue` at line 40)
  - **Problem**: Violates `AGENTS.md` (*"All public members, methods, functions, variables, and constants must be placed at the top of classes and files. Class fields (both public and private) must be placed after constructors (or together with their accessors). Private methods, functions, variables, and constants must be placed at the bottom of their respective classes and files"*).
  - **Fix**: Move all private top-level declarations below all public top-level declarations, and place private constructors immediately after public constructors at the top of `DataFrame` and `ValidityMask`.

- [ ] **3.3 Update `ARCHITECTURE.md` and outdated doc comments to match the current implementation**
  - **Severity**: Warning
  - **Location**: `ARCHITECTURE.md:472-495, 679-725`, `lib/src/polynomial/polynomial.dart:93`
  - **Problem**:
    1. `ARCHITECTURE.md` Section 7.2 (`lines 472-479`) lists non-existent `GumbelDistribution` and `RayleighDistribution`, omits `DegenerateDistribution`, `InverseGammaDistribution`, and `RademacherDistribution`, and claims *"12 univariate distributions support analytical or numerical MLE fitting"* when 22 of 23 univariate distributions implement `.fit(samples)`.
    2. `ARCHITECTURE.md` Section 7.3 (`lines 485-495`) omits `fisherExactTest` and `shapiroWilkTest`, and Section 7.4 omits `Jackknife`.
    3. `ARCHITECTURE.md` Section 10.2–10.5 (`lines 679-725`) omits `gammaqInv`, `polygamma`, `zeta`, `besselJ`, `besselY`, `besselI`, `besselK`, `ellipticF`, and `ellipticEIncomplete`.
    4. `lib/src/polynomial/polynomial.dart:93` doc comment for `Polynomial.fromRoots` shows `// p: 6.0 - 5.0*x + 1.0*x^2` instead of `x^2 - 5.0x + 6.0`.
  - **Fix**: Update `ARCHITECTURE.md` Sections 7.2–7.4 and 10.2–10.5 and the `Polynomial.fromRoots` doc comment.

---

## 4. Missing Features & API Consistency

- [ ] **4.1 Align `Matrix`, `Float64Matrix`, `SparseMatrix`, and `solveTridiagonal` APIs**
  - **Severity**: Suggestion
  - **Location**: `lib/src/linear/matrix.dart:471-476`, `lib/src/linear/float64_matrix.dart:90-99`, `lib/src/linear/sparse/{coo_matrix,csr_matrix,csc_matrix}.dart`, `lib/src/linear/solvers/tridiagonal.dart:64, 81, 90, 99`
  - **Problem**:
    1. `Float64Matrix.subMatrix` defaults `rowStart = 0` and `colStart = 0`, whereas `Matrix.subMatrix` requires `required int rowStart, required int colStart`.
    2. `Float64Matrix.fromList(int rowCount, int colCount, List<double> values)` has no counterpart `Matrix.fromList(int rowCount, int colCount, List<T> values, {DataType<T>? type})` on `Matrix<T>`.
    3. `CooMatrix`, `CsrMatrix`, and `CscMatrix` lack unary negation `operator -()`, and `CsrMatrix.scale` / `CscMatrix.scale` retain explicit zero entries when scaling by `0`.
    4. `solveTridiagonal` throws `ArgumentError` on singular matrices (zero pivot), whereas `Matrix.solve`, `Matrix.inverse`, `LUDecomposition.solve`, `QRDecomposition.solve`, and `CholeskyDecomposition.solve` all throw `StateError`.
  - **Fix**: Default `rowStart = 0, colStart = 0` in `Matrix.subMatrix`; add `Matrix.fromList`; add `operator -()` and zero-pruning in `scale` on sparse matrices; and throw `StateError` on singular matrices in `solveTridiagonal`.

- [ ] **4.2 Align `fisherExactTest` and `wilcoxonSignedRankTest` signatures in `stats`**
  - **Severity**: Suggestion
  - **Location**: `lib/src/stats/hypothesis/fisher_exact.dart:16`, `lib/src/stats/hypothesis/wilcoxon.dart:11-16`
  - **Problem**:
    1. `chiSquaredContingency` accepts `Matrix<num> table`, whereas `fisherExactTest` only accepts `List<List<int>> table` (despite its doc comment stating *"The input [table] must be a 2x2 matrix or list-of-lists"*).
    2. `mannWhitneyUTest` exposes `{bool continuityCorrection = true}`, whereas `wilcoxonSignedRankTest` hardcodes continuity correction without a `bool continuityCorrection = true` parameter.
  - **Fix**: Accept `Object table` (`Matrix<num>` or `List<List<num>>`) or `Matrix<num>` in `fisherExactTest`, and add `{bool continuityCorrection = true}` to `wilcoxonSignedRankTest`.

- [ ] **4.3 Complete `Series` statistical methods (`std`, `variance`, `median`, `quantile`, `count`) and `DataFrame.sample` / `fromCsv(columnTypes: ...)`**
  - **Severity**: Suggestion
  - **Location**: `lib/src/dataframe/series.dart:320-329, 791-794, 1048-1051`, `lib/src/dataframe/dataframe.dart:75, 578`
  - **Problem**:
    1. `Series<T>` only exposes `min`, `max`, `sum`, and `mean`, lacking `count` (non-null count), `std`, `variance`, `median`, and `quantile(double p)`.
    2. `BoolSeries.min`/`max` and `ObjectSeries.min`/`max` always return `null` even when elements are `bool` or `Comparable`.
    3. `DataFrame.describe()` (`line 578`) returns `0.0` for `std` when `n == 1`, whereas sample standard deviation with $n - 1$ degrees of freedom is `double.nan` (and `GroupBy` returns `null`).
    4. `DataFrame` lacks `sample(int count, {bool replace = false, Random? random})` and `DataFrame.fromCsv` lacks `columnTypes`.
  - **Fix**: Add `count`, `std`, `variance`, `median`, and `quantile` to `Series`; implement `min`/`max` on `BoolSeries` and `ObjectSeries`; return `double.nan` for `std` when `n == 1` in `describe()`; and add `DataFrame.sample` and `columnTypes` on `DataFrame.fromCsv`.

- [ ] **4.4 Clean up redundant procedural exports in `lib/symbolic.dart`, extend `simplifyConjugate` and `toPowerSeries`, and forward `assumptions` in `SymbolicMatrixExtension`**
  - **Severity**: Suggestion
  - **Location**: `lib/symbolic.dart:133-161`, `lib/src/symbolic/solver/ode.dart:53-79`, `lib/src/symbolic/algebra/simplify/transcendental.dart:1508-1538`, `lib/src/symbolic/calculus/series.dart:548-654`, `lib/src/symbolic/linear/matrix.dart:84-145, 399-414`
  - **Problem**:
    1. `lib/symbolic.dart` exports internal procedural helpers `evaluateDefiniteIntegral`, `computeProduct`, and `solveOdeEquation` alongside their canonical extension methods `.integrate(...)`, `.product(...)`, and `.solveOde(...)` (and `ode.dart` defines both top-level `solveOde` and `solveOdeEquation`), violating `AGENTS.md` (*"Provide a single canonical way to perform an operation; avoid redundant convenience aliases"*).
    2. `simplifyConjugate` does not distribute over `Erf`, `Erfc`, `Atan`, `Asinh`, or `Pow(base, exponent)` with positive `base`.
    3. `_expandToPowerSeries` throws `UnsupportedError` on `Sign`, `Floor`, `Ceil`, `Round` at non-singular points and on `Gamma`, `Digamma`, `Polygamma`, `Zeta`, `BesselJ` at analytic points.
    4. `SymbolicMatrixExtension.eigenvalues` and `eigenvectors` do not forward `assumptions` to `_algebraicMultiplicity`.
  - **Fix**: Keep the extension methods on `Expr` as the single canonical public API in `lib/symbolic.dart`; add `Erf`, `Erfc`, `Atan`, `Asinh`, and positive-base `Pow` rules to `simplifyConjugate`; support locally constant step functions and Taylor derivative fallback for special functions in `_expandToPowerSeries`; and pass `assumptions` to `_algebraicMultiplicity`.
