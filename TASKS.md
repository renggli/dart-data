# Project Review & Actionable Tasks

Actionable review items across all subsystems (`type`, `tensor`, `acceleration`, `linear`, `special`, `polynomial`, `numeric`, `stats`, `dataframe`, `symbolic`), web applications (`web/`), examples (`example/`), benchmarks (`benchmark/`), tests (`test/`), and documentation (`README.md`, `ARCHITECTURE.md`).

---

## 1. Bugs and Edge Cases

### 1.1 `type` Subsystem

- [x] **1.1.1 `UnmodifiableFloat64ComplexList.sublistView` strips unmodifiability and returns a mutable view**
  - **Severity**: Critical
  - **Location**: `lib/src/type/types/complex.dart:193-197, 265-270`
  - **Problem**: `UnmodifiableFloat64ComplexList` extends `Float64ComplexList` and inherits `sublistView`, which wraps `Float64List.sublistView(data, 2 * start, 2 * end)` in a mutable `Float64ComplexList._`. In the Dart SDK, calling `Float64List.sublistView` on an `UnmodifiableFloat64ListView` accesses `.buffer.asFloat64List(...)`, returning a mutable `Float64List` over the underlying buffer. Mutating the returned `sublistView` mutates the backing storage of the `UnmodifiableFloat64ComplexList`.
  - **Fix**: Override `sublistView` in `UnmodifiableFloat64ComplexList` to return `UnmodifiableFloat64ComplexList(super.sublistView(start, end))`.

- [x] **1.1.2 `Uint64DataType` max bound is wrong ($2^{63}-1$ instead of $2^{64}-1$) and `cast`/`Uint64List` wrap to negative `int` on Dart VM**
  - **Severity**: Critical
  - **Location**: `lib/src/type/types/integer.dart:64-68, 285-312`
  - **Problem**: `Uint64DataType.max` (`line 300`) computes `BigInt.from(454279) * BigInt.from(649657) * BigInt.from(31252369) == 9223372036854775807` ($2^{63} - 1$, signed 64-bit max) instead of $2^{64} - 1$. Meanwhile, `safeBits` (`line 295`) is `isJavaScript ? 53 : 63` while `bits` (`line 292`) is `64`. In `IntegerDataType.cast` (`lines 64-68`), `BigInt.from(intVal).toUnsigned(64).toInt()` converts values in $[2^{63}, 2^{64}-1]$ (or negative `intVal`) back to a negative 64-bit signed `int` on the Dart VM.
  - **Fix**: Align `Uint64DataType.bits` and `cast` with 63-bit unsigned positive `int` semantics on Dart VM (`bits = 63` or mask bit 63 in `cast`), or document the signed 64-bit `int` limitation of `Uint64List` on the VM and fix `max` / `cast` consistently.

- [x] **1.1.3 `DataType.fromInstance` and `DataType.fromIterable` infer an overly narrow `DataType` for `Object`/`Object?` containers, causing `TypeError` on heterogeneous elements**
  - **Severity**: Critical
  - **Location**: `lib/src/type/utils/derive.dart:11-29`, `lib/src/tensor/tensor.dart:109-127`
  - **Problem**: When `T` is `Object`, `Object?`, or `dynamic` (e.g. `Tensor<Object?>.fromObject([1.0, 'a'])`), `_fromType(T)` returns `null`. `fromInstance<T>(instance)` then inspects the first element (`1.0`), resolves `Float64DataType` (`DataType<double>`), and casts it via `as DataType<T>`, which succeeds due to generic covariance (`DataType<double>` is a subtype of `DataType<Object?>`). `effectiveType.newList(...)` then allocates a `Float64List`, and writing `'a'` into `data` throws a runtime `TypeError`.
  - **Fix**: In `fromIterable<T>`, inspect all elements (or when `T == Object` / `T == Object?` / `T == dynamic` and elements have mixed runtime types, fall back to `DataType.object<T>()` / `DataType.nullableObject()` / `DataType.dynamicType`).

- [x] **1.1.4 `FloatField.division` throws `UnsupportedError` on `b == 0.0`, `NaN`, `Infinity`, or quotients $> 2^{63}-1$**
  - **Severity**: Warning
  - **Location**: `lib/src/type/types/float.dart:170`
  - **Problem**: `FloatField.division(double a, double b)` executes `(a ~/ b).roundToDouble()`. In Dart, `double ~/ double` converts the quotient to a 64-bit `int` first, which throws `UnsupportedError` when `b == 0.0`, when `a` or `b` is `NaN`/`Infinity`, or when `|a / b| > 2^{63} - 1` (e.g. `1e25 ~/ 1.0`).
  - **Fix**: Replace `(a ~/ b).roundToDouble()` with `(a / b).truncateToDouble()`.

- [x] **1.1.5 `FractionDataType.cast(BigInt)` truncates arbitrary-precision `BigInt` via `.toInt()`**
  - **Severity**: Warning
  - **Location**: `lib/src/type/types/fraction.dart:31-32`
  - **Problem**: `else if (value is BigInt) { return Fraction(value.toInt()); }` converts `BigInt` via `.toInt()`, wrapping to 64-bit signed `int` on the VM even though `Fraction(BigInt, [BigInt])` natively accepts arbitrary-precision `BigInt` numerators.
  - **Fix**: Return `Fraction(value)` directly without calling `.toInt()`.

- [x] **1.1.6 `BigIntEquality.isClose` overflows `double` and `BigIntField.scale` throws on `NaN`/`Infinity`**
  - **Severity**: Warning
  - **Location**: `lib/src/type/types/bigint.dart:54, 87`
  - **Problem**: `BigIntEquality.isClose` computes `(a - b).abs().toDouble() <= epsilon`, which loses precision above $2^{53}$ and overflows to `double.infinity` above $1.8 \times 10^{308}$. `BigIntField.scale` calls `Fraction.fromDouble(factor.toDouble())`, which throws `ArgumentError` if `factor` is `NaN` or `Infinity`.
  - **Fix**: In `BigIntEquality.isClose`, guard `epsilon.isNaN` and `epsilon < 0`, return `true` if `epsilon == double.infinity`, and compare `(a - b).abs()` using `BigInt` when `epsilon >= 1.0`.

- [x] **1.1.7 `ObjectDataType.name` loses type parameter `T` when `_defaultValue == null`, and `.nullable` drops `_defaultValue`**
  - **Severity**: Warning
  - **Location**: `lib/src/type/types/object.dart:18-20, 26`
  - **Problem**: Line 18 checks `_defaultValue == null` to return `'object'`, so `DataType.nullableObject<String>().name` returns `'object'` instead of `'object<String?>'`. Line 26 (`ObjectDataType<T?> get nullable => ObjectDataType<T?>(null);`) discards `_defaultValue`.
  - **Fix**: Check `T == dynamic || T == Object || T == Object?` for `'object'`, and preserve `_defaultValue` in `get nullable`.

- [x] **1.1.8 `NullableDataType<T>` does not override `equality`**
  - **Severity**: Warning
  - **Location**: `lib/src/type/types/nullable.dart:11-90`
  - **Problem**: `NullableDataType<T>` inherits `DataType.equality` (`const NaturalEquality()`), so `DataType.float64.nullable.equality.isClose(1.0, 1.0 + 1e-12, 1e-6)` uses `a == b` (`false`) and `isEqual(double.nan, double.nan)` returns `false` instead of delegating to `delegate.equality`.
  - **Fix**: Override `Equality<T?> get equality` in `NullableDataType<T>` to handle `null` values and delegate non-null comparisons/hashes to `delegate.equality`.

- [x] **1.1.9 `TypedDataType.copyList` evaluates single-pass `Iterable`s twice**
  - **Severity**: Warning
  - **Location**: `lib/src/type/types/typed.dart:44-55`
  - **Problem**: `copyList` reads `final listLength = iterable.length;` (`line 48`) and then calls `result.setRange(..., iterable)` (`line 53`), iterating lazy/single-pass iterables twice.
  - **Fix**: Use the `length` + `setRange` fast path only when `iterable is List<T>` or `iterable is EfficientLengthIterable<T>`, and iterate in a single pass otherwise.

---

### 1.2 `tensor` Subsystem

- [x] **1.2.1 `Tensor` comparison operators `<`, `<=`, `>`, `>=` return `true` for `NaN > x` and `-0.0 < 0.0`**
  - **Severity**: Critical
  - **Location**: `lib/src/tensor/operations/operation.dart:275-295`
  - **Problem**: `Tensor.operator <`, `<=`, `>`, and `>=` delegate to `type.comparator(a, b)`. For `FloatDataType`, `comparator` is `a.compareTo(b)`. In Dart, `double.nan.compareTo(1.0)` is `1` (`> 0`) and `(-0.0).compareTo(0.0)` is `-1` (`< 0`). Consequently, `Tensor.fromIterable([double.nan]) > Tensor.fromIterable([1.0])` evaluates to `[true]` and `Tensor.fromIterable([-0.0]) < Tensor.fromIterable([0.0])` evaluates to `[true]`, violating IEEE 754 semantics.
  - **Fix**: In `OperationTensorExtension.<`, `<=`, `>`, and `>=`, when `a is num && b is num`, use `a < b`, `a <= b`, `a > b`, and `a >= b` directly instead of `type.comparator`.

- [x] **1.2.2 `binaryOperation` in-place contiguous fast path omits stride equality check**
  - **Severity**: Critical
  - **Location**: `lib/src/tensor/operations/operation.dart:105-153`
  - **Problem**: Unlike `unaryOperation` (`line 57`, which checks `areShapesEqual(target.layout.strides, layout.strides)`), `binaryOperation` (`lines 129-152`) checks `sameStartAddress(...)` and `isContiguous` without checking `areShapesEqual(target.layout.strides, layout.strides)`. For layouts with singleton dimensions (`shape[i] == 1`) where `Layout` marks non-canonical strides as `isContiguous = true`, in-place binary operations can mis-index or alias when strides differ, while disjoint views of the same buffer fall back to allocating a full temporary tensor even when `!hasOverlap(...)`.
  - **Fix**: Verify `areShapesEqual(target.layout.strides, layout.strides)` in the contiguous fast path and use `!hasOverlap(...)` when start addresses differ.

- [x] **1.2.3 `Layout` constructor allows negative `offset` and `Tensor.fromList` does not validate buffer bounds**
  - **Severity**: Critical
  - **Location**: `lib/src/tensor/layout.dart:61-109`, `lib/src/tensor/tensor.dart:93-105`
  - **Problem**: `Layout(shape: [3], offset: -5)` succeeds with `isContiguous == true`. Passing such a layout to `Tensor.fromList` or `Float64Tensor` causes out-of-bounds buffer access or native FFI memory corruption on contiguous fast paths.
  - **Fix**: Validate `offset >= 0` in `Layout(...)`, require canonical positive strides or normalize singleton strides for `isContiguous`, and verify reachable index bounds against `data.length` in `Tensor.fromList`.

- [x] **1.2.4 `Float64Tensor.copy`, `Float64Vector.copy`/`cumsum`/`cumprod`, and `Float64Matrix.copy` silently detach from `target` if `target` is not backed by `Float64List`**
  - **Severity**: Critical
  - **Location**: `lib/src/tensor/float64_tensor.dart:160-161`, `lib/src/linear/float64_vector.dart:332-333, 387-393`, `lib/src/linear/float64_matrix.dart:429-430`
  - **Problem**: These methods accept `{Tensor<double>? target}` / `{Vector<double>? target}` / `{Matrix<double>? target}` and wrap the result with `Float64Tensor.fromDoubleTensor(...)`. If `target` is backed by a `Float32List` or `List<double>`, `fromDoubleTensor` allocates a new `Float64List` copy, breaking the return-target identity contract.
  - **Fix**: Narrow the parameter types to `Float64Tensor? target`, `Float64Vector? target`, and `Float64Matrix? target` (or throw `ArgumentError` if `target.data is! Float64List`).

- [x] **1.2.5 `Tensor.norm` and `Vector.norm` do not reject `pNorm < 1` or `NaN`, and unscaled `norm(2)` fallback overflows to `Infinity`**
  - **Severity**: Warning
  - **Location**: `lib/src/tensor/operations/reduction.dart:185-230`, `lib/src/linear/vector.dart:279-328`
  - **Problem**: Passing `pNorm <= 0` or `pNorm.isNaN` is not rejected (`norm(0)` returns `Infinity`, `norm(double.negativeInfinity)` returns `NaN`). Additionally, the non-BLAS `norm(2)` loop computes unscaled `sumSq += normVal * normVal`, overflowing to `Infinity` for elements $\ge 10^{155}$ even when the Euclidean norm is finite.
  - **Fix**: Validate `if (pNorm.isNaN || pNorm < 1) throw ArgumentError.value(pNorm, 'pNorm', 'Must be >= 1');` and use Blue's/LAPACK scaled summation for `pNorm == 2`.

- [x] **1.2.6 `Tensor.operator ==` ignores `type.equality`**
  - **Severity**: Warning
  - **Location**: `lib/src/tensor/tensor.dart:348-363`
  - **Problem**: `Tensor.operator ==` compares elements via `it1.current != it2.current` instead of `type.equality.isEqual(it1.current, it2.current)`, violating `==` reflexivity for tensors containing `double.nan` when compared with a copy of themselves.
  - **Fix**: Use `!type.equality.isEqual(it1.current, it2.current)` in `Tensor.operator ==`.

---

### 1.3 `acceleration` Subsystem

- [x] **1.3.1 `BlasDart.dnrm2`, `snrm2`, `dscal`, and `sscal` silently return `0.0` or no-op for negative `incX`**
  - **Severity**: Critical
  - **Location**: `lib/src/acceleration/blas/blas_dart.dart:69, 98, 176, 191`, `lib/src/acceleration/blas/blas_validation.dart:33-41`
  - **Problem**: `checkBlasInc` only rejects `inc == 0` and allows `incX < 0`. `BlasDart.ddot`, `daxpy`, `dgemv`, `dsyr2`, and `dtrmv` handle `incX < 0`, whereas `dnrm2`, `snrm2`, `dscal`, and `sscal` check `if (n <= 0 || incX <= 0) return ...;`, silently returning `0.0` or doing nothing for negative strides.
  - **Fix**: Either handle `incX < 0` in `Blas.dnrm2`, `snrm2`, `dscal`, and `sscal` (using `incX.abs()` since norm and scaling are order-independent) or reject `incX < 0` in parameter validation.

- [x] **1.3.2 `Vforce.convolve` and `Vforce.correlate` corrupt results when `output` aliases `signal` or `filter`, and ignore `output` when `rLen <= 0`**
  - **Severity**: Critical
  - **Location**: `lib/src/acceleration/vforce/vforce_dart.dart:107-139`, `lib/src/acceleration/vforce/vforce.dart:210, 244`
  - **Problem**: In `VforceDart.convolve` and `VforceDart.correlate`, `output[n]` is overwritten in-place during the outer loop while subsequent iterations read `signal[n + p]`. If `output` aliases `signal` or `filter`, inputs are clobbered mid-loop. Additionally, when `rLen <= 0`, `Vforce.convolve` and `Vforce.correlate` return a new `Float64List(0)` before validating or returning a caller-supplied `output`.
  - **Fix**: Validate `output` before early returns, and if `sharesMemory(output, signal) || sharesMemory(output, filter)`, accumulate into a temporary buffer before copying into `output`.

- [x] **1.3.3 Unbounded native memory leak in FFTW plan and vDSP setup caches**
  - **Severity**: Warning
  - **Location**: `lib/src/acceleration/fft/fft_native.dart:38-44, 247-343`
  - **Problem**: `_vdspFwdSetups`, `_vdspInvSetups`, `_fftw1dFwdPlans`, `_fftw1dInvPlans`, `_fftw2dFwdPlans`, and `_fftw2dInvPlans` cache native pointers keyed by signal dimensions with no capacity bound and never call `vDSP_DFT_DestroySetupD` or `fftw_destroy_plan`.
  - **Fix**: Bind `vDSP_DFT_DestroySetupD` and `fftw_destroy_plan` and enforce an LRU capacity limit (e.g. 64 entries per cache), destroying evicted native plans/setups.

- [x] **1.3.4 `Lapack` methods skip `lda`/`ldb` and matrix bounds validation when `n == 0` or `nrhs == 0`**
  - **Severity**: Warning
  - **Location**: `lib/src/acceleration/lapack/lapack.dart:28-30, 56-58, 86-88, 120-123, 152-154`
  - **Problem**: In `Lapack.dpotrf`, `dsyev`, `dgesv`, `dgels`, and `dgesvd`, the early return `if (n == 0) return true;` occurs before `checkBlasMatrixBounds` and `lda` validation (unlike `Blas`, which validates `lda` before early return).
  - **Fix**: Move `lda`/`ldb` and matrix bounds validation before the `n == 0` / `m == 0` early return.

---

### 1.4 `linear` Subsystem

- [x] **1.4.1 Sparse matrix constructors (`CooMatrix`, `CsrMatrix`, `CscMatrix`) do not validate index bounds or pointer invariants**
  - **Severity**: Critical
  - **Location**: `lib/src/linear/sparse/coo_matrix.dart:28-47`, `lib/src/linear/sparse/csr_matrix.dart:30-53`, `lib/src/linear/sparse/csc_matrix.dart:29-52`
  - **Problem**: `CooMatrix(...)` does not check `0 <= rowIndices[k] < rowCount` or `0 <= colIndices[k] < colCount`. `CsrMatrix(...)` and `CscMatrix(...)` do not check `pointers.first == 0`, `pointers.last == values.length`, pointer monotonicity `pointers[i] <= pointers[i + 1]`, or coordinate bounds. Malformed arrays cause silent wrong answers in `get()` and out-of-bounds crashes in `apply()`, `toCsr()`, `toCsc()`, and `toDense()`.
  - **Fix**: Validate pointer boundary invariants, monotonicity, and index bounds in the primary constructors of `CooMatrix`, `CsrMatrix`, and `CscMatrix`.

- [x] **1.4.2 `SingularValueDecomposition` enters an infinite loop or returns unconverged results on `NaN`/`Infinity` inputs**
  - **Severity**: Critical
  - **Location**: `lib/src/linear/decomposition/svd.dart:425-617`
  - **Problem**: Unlike `EigenvalueDecomposition`, `_computeSvd` never checks if the input matrix contains `NaN` or `Infinity`. In `while (mDim > 0)`, `iter` is only incremented in `case 3` (`line 581`), so repeated `case 1` or `case 2` transitions never increment `iter`, and breaking on `iter >= 1000` leaves raw unconverged/unsorted values in `sVals`.
  - **Fix**: Check for `NaN`/`Infinity` upfront (filling `s`, `u`, `vt` with `double.nan` and returning immediately), and increment `iter` across all non-deflating cases.

- [x] **1.4.3 `Vector._scan` (`cumsum` / `cumprod`) checks `identical(tensor.data, target.tensor.data)` instead of `sharesMemory`**
  - **Severity**: Critical
  - **Location**: `lib/src/linear/vector.dart:514-521`
  - **Problem**: Two overlapping `Float64List.sublistView` instances or `Tensor` views over the same `ByteBuffer` are not `identical(tensor.data, target.tensor.data)`, allowing in-place `_scan` to overwrite source elements before reading them. Furthermore, if `identical(this, target)` is true on a reversed view (`strides: [-1]`), `_scan` does not copy and overwrites elements in-place.
  - **Fix**: Use `sharesMemory(tensor.data, target.tensor.data)` and require `target.tensor.strides[0] > 0 && sameStartAddress(...)` when avoiding a temporary copy.

- [x] **1.4.4 `Matrix.solve` on inconsistent systems with `colCount == 0` silently returns an empty matrix instead of throwing `StateError`**
  - **Severity**: Critical
  - **Location**: `lib/src/linear/matrix.dart:494-522`
  - **Problem**: When $A$ has shape $m \times 0$ ($m > 0$) and $B$ has shape $m \times k$ with non-zero entries, `Lapack.dgels(m: m, n: 0, ...)` returns `true` immediately because `n == 0`, and `Matrix.solve` returns a $0 \times k$ matrix instead of throwing `StateError('Linear system is inconsistent.')`.
  - **Fix**: Explicitly check `colCount == 0` in `Matrix.solve` and throw `StateError` if any entry of `b` is non-zero.

- [x] **1.4.5 `Matrix.syrk` accepts a `beta` parameter with no target `C` matrix and ignores `beta` in its pure-Dart fallback**
  - **Severity**: Warning
  - **Location**: `lib/src/linear/matrix.dart:910-980`
  - **Problem**: `Matrix.syrk({double alpha = 1.0, double beta = 0.0, bool transpose = false})` allocates a fresh zero matrix `result` rather than accepting a target matrix `C`. Passing `beta` to `Blas.dsyrk` multiplies the zero matrix by `beta`, while the pure-Dart fallback (`lines 975-979`) ignores `beta` completely.
  - **Fix**: Either add `{Matrix<T>? target}` to `syrk` (applying `beta * target` in both BLAS and fallback paths) or remove the unused `beta` parameter.

- [x] **1.4.6 Inconsistent symmetry checks and broken positivity check in `CholeskyDecomposition` and `EigenvalueDecomposition`**
  - **Severity**: Warning
  - **Location**: `lib/src/linear/decomposition/cholesky.dart:126-133, 189-203`, `lib/src/linear/decomposition/eigenvalue.dart:885-894`
  - **Problem**: `_decomposeFloat64` (`cholesky.dart:128`) and `_checkSymmetry` (`eigenvalue.dart:890`) use exact `!=`, rejecting `a.transposed * a` when $10^{-16}$ rounding asymmetry exists, whereas `_decomposeGeneric` (`cholesky.dart:194`) uses `equality.isClose(..., 1e-6)`. Furthermore, in `_decomposeGeneric` (`line 200`), `_ => field.norm(diagVal) > 0.0` treats negative values in custom fields (such as `Fraction(-4)`) as positive because `field.norm` returns absolute magnitude.
  - **Fix**: Check `_type.comparator(diagVal, zero) > 0` for ordered fields in `_decomposeGeneric`, and use relative tolerance symmetry checks consistently.

- [x] **1.4.7 `CooMatrix.toCsr()` and `CooMatrix.toCsc()` retain explicit zero entries when duplicate coordinates cancel out**
  - **Severity**: Warning
  - **Location**: `lib/src/linear/sparse/coo_matrix.dart:209-304`
  - **Problem**: When coalescing duplicate `(r, c)` entries that sum to `field.additiveIdentity` (e.g. `+3.0` and `-3.0`), the zero entry is still stored in `coalescedVals` and counted in `nnz`.
  - **Fix**: Skip appending the coalesced entry when `type.equality.isEqual(sum, field.additiveIdentity)`.

---

### 1.5 `special` Subsystem

- [x] **1.5.1 `beta(x, y)` overflows intermediate `gamma(x + y)` and returns `0.0` or `NaN` for $x, y \le 100$ with $x + y > 171.6$**
  - **Severity**: Critical
  - **Location**: `lib/src/special/beta.dart:21-24`
  - **Problem**: `beta(x, y)` checks `if (x > 100 || y > 100) return exp(betaLn(x, y));` and otherwise computes `gamma(x) * gamma(y) / gamma(x + y)`. Because `gamma(z)` overflows IEEE 754 `double` at $z > 171.6$, `beta(90, 90)` evaluates `finite / Infinity = 0.0` (instead of `5.284e-55`) and `beta(100, 100)` evaluates `Infinity / Infinity = NaN` (instead of `2.208e-60`).
  - **Fix**: Change line 21 to `if (x + y > 170) return exp(betaLn(x, y));`.

- [x] **1.5.2 Catastrophic cancellation and infinite-input loop in `hypergeometric1F1`**
  - **Severity**: Critical
  - **Location**: `lib/src/special/hypergeometric.dart:30-49`
  - **Problem**: `hypergeometric1F1(a, b, z)` sums the alternating power series directly for negative $z$. For `hypergeometric1F1(1.0, 2.0, -50.0)`, intermediate terms reach $10^{20}$ while the true value is $\approx 0.02$, returning garbage ($\sim \pm 10^{26}$) due to 53-bit cancellation. Additionally, when `z` is `±Infinity`, `term` becomes `NaN` and the loop runs all 1,500 iterations.
  - **Fix**: Handle `!zd.isFinite` upfront, and for `zd < 0` apply Kummer's first transformation $_1F_1(a; b; z) = e^z \, _1F_1(b - a; b; -z)$ (or asymptotic expansion for large $|z|$).

- [x] **1.5.3 `trigamma(double.negativeInfinity)` returns `0.0` instead of `double.nan`**
  - **Severity**: Warning
  - **Location**: `lib/src/special/digamma.dart:69-71`
  - **Problem**: `if (x.isInfinite) return 0.0;` returns `0.0` for `trigamma(double.negativeInfinity)`, even though $\psi_1(x)$ has poles at every non-positive integer and no limit as $x \to -\infty$ (unlike `digamma(double.negativeInfinity)` at line 22 which returns `double.nan`).
  - **Fix**: Change line 69 to `if (x.isInfinite) return x.isNegative ? double.nan : 0.0;`.

- [x] **1.5.4 `combination` and `permutation` return `0.0` instead of `double.nan` on `NaN` inputs**
  - **Severity**: Warning
  - **Location**: `lib/src/special/gamma.dart:270-272, 313-315`
  - **Problem**: `if (total.isNaN || choose.isNaN || choose < 0 || choose > total) return 0.0;` returns `0.0` on `NaN` inputs, whereas `combinationLn` and `permutationLn` return `double.nan`.
  - **Fix**: Check `if (total.isNaN || choose.isNaN) return double.nan;` before the range check.

- [x] **1.5.5 `lambertW1` corrupts solution via `exp` underflow for small negative $z$, and `lambertW0` overflows Halley denominator for large $z$**
  - **Severity**: Warning
  - **Location**: `lib/src/special/lambert_w.dart:41-56, 92-108`
  - **Problem**: In `lambertW1(z)` for $z \in [-10^{-300}, 0)$, `ew = exp(wVal)` underflows to `0.0` inside the Halley loop, causing each iteration to add $+2.0$ and drift $+50$ away from the already-accurate asymptotic initial guess. In `lambertW0(z)` for $z \approx 10^{307}$, `(wVal + 2.0) * fVal` overflows to `Infinity` in the Halley denominator.
  - **Fix**: Break out of the Halley loop when `ew == 0.0 || !ew.isFinite`, and formulate the Halley update using $r = w - z e^{-w}$ to avoid overflow.

- [x] **1.5.6 `gammapInv` lacks bracket safeguard when Halley step overshoots or underflows**
  - **Severity**: Warning
  - **Location**: `lib/src/special/gamma.dart:190-214`
  - **Problem**: Unlike `ibetaInv`, `gammapInv` does not maintain `[xMin, xMax]` bounds and breaks immediately if a trial step overshoots $\le 0$, returning an unrefined guess.
  - **Fix**: Track `[xMin, xMax]` bounds from the sign of `err` and bisect when the Halley step jumps out of bounds.

- [x] **1.5.7 Slow convergence of `hypergeometric2F1` for $z \in (-1.0, -0.5]$**
  - **Severity**: Suggestion
  - **Location**: `lib/src/special/hypergeometric.dart:100-138`
  - **Problem**: Pfaff's transformation $w = z / (z - 1)$ is only applied for `zd <= -1.0`, leaving $z \in (-1.0, -0.5]$ to run 2,000 terms of a slowly converging alternating series.
  - **Fix**: Apply Pfaff's transformation for `zd < -0.5`, mapping $(-1, -0.5)$ into $(1/3, 1/2)$.

---

### 1.6 `polynomial` Subsystem

- [x] **1.6.1 `DensePolynomial.divide` fails to reduce remainder over `int` ring, causing an infinite loop in `Polynomial.gcd` and `RationalFunction<int>`**
  - **Severity**: Critical
  - **Location**: `lib/src/polynomial/impl/dense_polynomial.dart:265-276`, `lib/src/polynomial/polynomial.dart:191-201`
  - **Problem**: Over `DataType.int32` / `int`, `field.div(curCoeff, leadB)` uses integer truncating division `~/`. When `curCoeff.abs() < leadB.abs()`, `factor` is `0` and `rCoeffs[i]` is never reduced, returning a remainder with $\deg(r) \ge \deg(b)$ and causing `Polynomial.gcd` (e.g. `Polynomial<int>.fromCoefficients([0, 1, 1]).gcd(Polynomial<int>.fromCoefficients([0, 2]))`) and `RationalFunction<int>` to hang in an infinite loop.
  - **Fix**: In `DensePolynomial.divide`, check `if (field.mul(factor, leadB) != curCoeff)` for exact integer rings and throw `UnsupportedError`, or use pseudo-division / primitive polynomial GCD over integer rings.

- [x] **1.6.2 `evaluateDouble`, `roots`, and `_coeffToComplex` throw `TypeError` for `BigInt`, `Fraction`, and `Complex` polynomials**
  - **Severity**: Warning
  - **Location**: `lib/src/polynomial/impl/dense_polynomial.dart:82-91, 368-374`, `lib/src/polynomial/impl/compressed_polynomial.dart:195-206, 607-613`, `lib/src/polynomial/polynomial.dart:502-508`
  - **Problem**: Casts `(this[i] as num).toDouble()`, which throws a `TypeError` when `T` is `BigInt`, `Fraction`, or `Complex` (none of which subtype `num`).
  - **Fix**: Convert coefficients via a helper supporting `num`, `BigInt`, `Fraction`, and `Complex`.

- [x] **1.6.3 Floating-point remainder instability in `Polynomial.gcd` and `RationalFunction` arithmetic**
  - **Severity**: Warning
  - **Location**: `lib/src/polynomial/polynomial.dart:191-233`, `lib/src/polynomial/impl/dense_polynomial.dart:283-289`, `lib/src/polynomial/rational.dart:59-79`
  - **Problem**: Remainder truncation in `divide` uses `tol = 1e-12 * maxCoeff` based only on the dividend. During Euclidean `gcd` over `double`, a residual rounding error of `1e-11` survives truncation and becomes `leadB` in the next division step, amplifying noise by $10^{11}$ and causing `gcd` and `RationalFunction.simplify()` to fail to cancel common factors.
  - **Fix**: Zero out floating-point remainder coefficients in `Polynomial.gcd` below a relative tolerance scaled to the current step norms.

- [x] **1.6.4 Uncleaned FFT rounding noise in `DensePolynomial.operator *`**
  - **Severity**: Warning
  - **Location**: `lib/src/polynomial/impl/dense_polynomial.dart:166-201`
  - **Problem**: For `outDegree >= 64` with `double` coefficients, FFT convolution leaves $\mathcal{O}(10^{-16})$ rounding noise in zero coefficients, turning sparse-structured products like $(x^{40} - 1)(x^{40} + 1)$ into dense polynomials with 79 non-zero $\sim 10^{-16}$ terms.
  - **Fix**: Zero out FFT product coefficients with magnitude below `1e-15 * maxCoeff` before trimming trailing zeros.

---

### 1.7 `numeric` Subsystem

- [x] **1.7.1 Dormand-Prince ODE solver (`_rk45`) accepts `NaN` trial steps as converged (`maxErrorRatio == 0.0`)**
  - **Severity**: Critical
  - **Location**: `lib/src/numeric/ode/solve_ode.dart:266-280`
  - **Problem**: `_rk45` accumulates step error via `if (ratio > maxErrorRatio) maxErrorRatio = ratio;`. When a trial step is too large and `f` or `y5` evaluates to `NaN` (e.g. `sqrt(y)` overshooting below zero), `ratio` is `NaN`, so `ratio > maxErrorRatio` is `false` for all components and `maxErrorRatio` stays `0.0`. Then `if (maxErrorRatio <= 1.0)` evaluates to `true`, accepting the `NaN` state and multiplying step size by $5\times$.
  - **Fix**: Check `if (ratio.isNaN || !y5[i].isFinite) { maxErrorRatio = double.infinity; break; }` in `_rk45`.

- [x] **1.7.2 Step interpolators return finite values for `double.nan` and grid monotonicity checks miss `NaN` knots**
  - **Severity**: Critical
  - **Location**: `lib/src/numeric/interpolation/step.dart:18, 31-43, 60, 72-78, 95, 107-113`, `lib/src/numeric/interpolation/linear.dart:29`, `lib/src/numeric/interpolation/cubic_spline.dart:51`, `lib/src/numeric/interpolation/pchip.dart:23`, `lib/src/numeric/interpolation/bilinear.dart:23, 28`, `lib/src/numeric/interpolation/bicubic.dart:28, 33`
  - **Problem**: In `NearestInterpolation`, `PreviousInterpolation`, and `NextInterpolation`, `xd <= _xs.first`, `xd >= _xs.last`, and `dLo < dHi` all evaluate to `false` when `x` is `double.nan`, returning `_ys[1]` or `_ys[0]` instead of `double.nan`. Furthermore, `if (_xs[i] >= _xs[i + 1])` across all 1D/2D interpolator constructors evaluates to `false` when `_xs` contains `double.nan`, silently accepting `NaN` knot coordinates.
  - **Fix**: Add `if (xd.isNaN) return double.nan;` at the start of `call` in `step.dart`, and replace `if (_xs[i] >= _xs[i + 1])` with `if (!(_xs[i] < _xs[i + 1]))` across all interpolator constructors.

- [x] **1.7.3 `integrate` fails when `poles` are combined with infinite bounds**
  - **Severity**: Critical
  - **Location**: `lib/src/numeric/integration.dart:106-117, 232-323`
  - **Problem**: When `poles` is non-empty and `a` or `b` is infinite (e.g. `integrate(f, -double.infinity, double.infinity, poles: [0.0])`), `_integratePoles` runs before infinite-bound splitting. On `[-Infinity, 0.0]`, `vIsPole` is `true`, so line 284 computes `length = v - u = +Infinity` and `limit = math.sqrt(length) = +Infinity`, applying $x = v - t^2$ on $[0, \infty)$ followed by $t = (1 - s^2)/s^2$, which overflows and fails.
  - **Fix**: Split off semi-infinite tails $(-\infty, p_{\min} - 1]$ and $[p_{\max} + 1, \infty)$ before running finite-interval pole substitutions in `_integratePoles`.

- [x] **1.7.4 Semi-infinite `integrate` masks interior `NaN`s as `0.0`**
  - **Severity**: Warning
  - **Location**: `lib/src/numeric/integration.dart:145, 160`
  - **Problem**: In semi-infinite coordinate transformations (`a == double.negativeInfinity` and `b == double.infinity`), `return res.isNaN ? 0.0 : res;` coerces any `NaN` across the entire domain into `0.0`, so `integrate((x) => double.nan, 0.0, double.infinity)` silently returns `(value: 0.0, error: 0.0)`.
  - **Fix**: Only coerce `res.isNaN` to `0.0` near the transformation boundary $t \to 0^+$ (`t < 1e-6`).

- [x] **1.7.5 `minimize` silently ignores constraints when `a` and `b` are provided without `method`**
  - **Severity**: Warning
  - **Location**: `lib/src/numeric/optimization.dart:60-65, 85`
  - **Problem**: When `a` and `b` are passed without `initialPoint`, `resolvedMethod` defaults to `OptimizationMethod.brent`. Line 85 checks `if (hasConstraints && resolvedMethod != OptimizationMethod.brent)`, silently ignoring `inequalities` and `equalities`.
  - **Fix**: Only default to unconstrained `brentMinimize` when `inequalities` and `equalities` are empty/null.

- [x] **1.7.6 `nelderMead` vertex sorting breaks on `NaN` objective evaluations**
  - **Severity**: Warning
  - **Location**: `lib/src/numeric/optimization/nelder_mead.dart:33`
  - **Problem**: `values[a].compareTo(values[b])` returns `0` when comparing `double.nan` with any number, corrupting simplex vertex ordering if the objective returns `NaN` at a trial step.
  - **Fix**: Treat `NaN` objective evaluations as `double.infinity` when sorting simplex vertices.

- [x] **1.7.7 Inconsistent non-convergence handling and missing `NaN` check in root finding (`solve`)**
  - **Severity**: Warning
  - **Location**: `lib/src/numeric/root_finding/solve.dart:148-174, 185-200, 224-239`
  - **Problem**: `_newtonRaphson` throws `StateError` on non-convergence after `maxIterations` (without checking if the final iterate converged), whereas `_brent` and `_bisection` silently return the unconverged iterate. Additionally, `_brent` does not check `if (fb.isNaN) return double.nan;` inside its loop.
  - **Fix**: Check `if (fb.isNaN) return double.nan;` in `_brent`, check `if (fn(x).abs() <= tolerance) return x;` after the loop in `_newtonRaphson`, and unify non-convergence handling.

- [x] **1.7.8 `derivative` evaluates zero-weight stencil nodes and rescales explicit `step`**
  - **Severity**: Warning
  - **Location**: `lib/src/numeric/calculus/derivative.dart:48-55`
  - **Problem**: Line 49 scales `final h = hBase * math.max(1.0, x.abs());` even when the caller explicitly passes `step`. Line 53 evaluates `weights[i] * function(x + (i - offset) * h)` even when `weights[i] == 0.0` (the center node for all odd derivative orders 1, 3, 5), wasting an evaluation and returning `NaN` (`0.0 * Infinity`) if `function` has a singularity at `x`.
  - **Fix**: Scale default `hBase` by `math.max(1.0, x.abs())` only when `step == null`, and skip stencil points with `weights[i] == 0.0`.

- [x] **1.7.9 `curveFit` standard errors when `df == 0` and `rSquared` when `ssTot == 0`**
  - **Severity**: Warning
  - **Location**: `lib/src/numeric/curve_fit.dart:168, 314, 539-541`
  - **Problem**: In `linearRegression` (line 168) and `multipleLinearRegression` (line 314), when `ssTot == 0.0` and `ssRes > 0.0`, `rSquared` returns `1.0` instead of `0.0`. In `curveFit` (lines 540–541), when `n == numParams` (`df == 0`), `math.max(df, 1)` divides by `1` instead of returning `double.nan` for `rse` and `standardErrors`.
  - **Fix**: Use `ssTot > 0.0 ? 1.0 - (ssRes / ssTot) : (ssRes == 0.0 ? 1.0 : 0.0)` everywhere, and return `double.nan` for `rse` and `standardErrors` when `df <= 0`.

---

### 1.8 `stats` Subsystem

- [x] **1.8.1 Infinite loop in `kolmogorovSmirnovTwoSample` and silent `0.0` statistic in `kolmogorovSmirnovTest` on `NaN` input**
  - **Severity**: Critical
  - **Location**: `lib/src/stats/hypothesis/kolmogorov_smirnov.dart:27-44, 67-95`
  - **Problem**: In `kolmogorovSmirnovTwoSample`, if either sample contains `double.nan`, `x = math.min(list1[i], list2[j])` evaluates to `double.nan`. Both inner loops `while (i < n1 && list1[i] <= x)` and `while (j < n2 && list2[j] <= x)` evaluate `<= double.nan` as `false`, so neither `i` nor `j` advances and the outer `while` loop hangs forever. In `kolmogorovSmirnovTest`, `NaN` entries produce `cdfVal = NaN` and are silently ignored (`dStat: 0.0, pValue: 1.0`).
  - **Fix**: Check for `NaN` values upfront in `kolmogorovSmirnovTest` and `kolmogorovSmirnovTwoSample` and return `statistic: double.nan, pValue: double.nan`.

- [x] **1.8.2 `rankData`, `spearmanCorrelation`, `mannWhitneyUTest`, and `wilcoxonSignedRankTest` produce corrupt finite results on `NaN` inputs**
  - **Severity**: Critical
  - **Location**: `lib/src/stats/descriptive.dart:150-169`, `lib/src/stats/hypothesis/mann_whitney.dart:28-30`, `lib/src/stats/hypothesis/wilcoxon.dart:29-46`
  - **Problem**: `rankData` sorts via `list[a].compareTo(list[b])` (which returns `0` for `NaN`) and assigns finite ranks `1.0 .. n` to `NaN` elements, causing `spearmanCorrelation` and `mannWhitneyUTest` to return finite statistics and p-values on `NaN` data. In `wilcoxonSignedRankTest`, `diffs.where((d) => d != 0.0)` keeps `double.nan` and counts every `NaN` as a negative rank difference (`wMinus += ranks[i]`).
  - **Fix**: Detect `NaN` in `rankData`, `spearmanCorrelation`, `mannWhitneyUTest`, and `wilcoxonSignedRankTest`, returning `double.nan`.

- [x] **1.8.3 `pca(standardize: true)` assigns unit variance (`1.0`) to constant zero-variance features**
  - **Severity**: Critical
  - **Location**: `lib/src/stats/pca.dart:144-150`, `lib/src/stats/descriptive.dart:730-747`
  - **Problem**: When `standardize: true`, `pca` delegates to `_pearsonCorrelationMatrix(centered)`. In `_pearsonCorrelationMatrix` (`descriptive.dart:736`), every diagonal entry is unconditionally set to `1.0` even when a column is constant (`stdDevs[i] == 0.0`), giving zero-variance features an eigenvalue of `1.0` and corrupting PCA components and `explainedVarianceRatio`.
  - **Fix**: Set the diagonal entry in `pca(standardize: true)` to `0.0` when `stdDevs[i] == 0.0`, and return `double.nan` in `pearsonCorrelationMatrix` for zero-variance columns to match `pearsonCorrelation`.

- [x] **1.8.4 `WeibullDistribution.probability` and `ParetoDistribution.probability` overflow to `NaN` for large parameters**
  - **Severity**: Warning
  - **Location**: `lib/src/stats/distributions/continuous/weibull.dart:83-90`, `lib/src/stats/distributions/continuous/pareto.dart:73-75`
  - **Problem**: `WeibullDistribution.probability` multiplies `pow(x / scale, shape - 1)` by `exp(-pow(x / scale, shape))`, producing `Infinity * 0.0 = NaN` in the tail. `ParetoDistribution.probability` divides `pow(scale, shape)` by `pow(x, shape + 1)`, producing `Infinity / Infinity = NaN` for large `shape`.
  - **Fix**: Compute `logProbability(x)` in log-space and evaluate `probability(x)` via `exp(logProbability(x))`.

- [x] **1.8.5 `DirichletDistribution.sample` returns `NaN` vector when small concentration parameters underflow**
  - **Severity**: Warning
  - **Location**: `lib/src/stats/distributions/multivariate/dirichlet.dart:134-150`
  - **Problem**: For small `alpha` (e.g. `0.005`), all `GammaDistribution(alpha[i], 1.0).sample()` draws can underflow to `0.0`, causing `0.0 / 0.0 = NaN` when normalizing by `sum`.
  - **Fix**: Sample in log-gamma space (or fall back to log-space normalization when `sum == 0.0`).

- [x] **1.8.6 `DegenerateDistribution` does not validate finite `k` and `JackknifeResampling.operator []` lacks index check**
  - **Severity**: Warning
  - **Location**: `lib/src/stats/distributions/continuous/degenerate.dart:21`, `lib/src/stats/resampling/jackknife.dart:109-110`
  - **Problem**: `DegenerateDistribution` allows `double.nan` or `double.infinity` for `k`. `JackknifeResampling.operator []` does not call `RangeError.checkValidIndex(index, this)`, producing misleading `RangeError` bounds from the underlying `list`.
  - **Fix**: Add `assert(k.isFinite)` to `DegenerateDistribution` and `RangeError.checkValidIndex(index, this)` to `JackknifeResampling.operator []`.

---

### 1.9 `dataframe` Subsystem

- [x] **1.9.1 `DataFrame.fillNull` throws `TypeError` on heterogeneous DataFrames**
  - **Severity**: Critical
  - **Location**: `lib/src/dataframe/dataframe.dart:273-283`
  - **Problem**: `DataFrame.fillNull(Object value)` calls `col.fillNull(value)` on every column with nulls. Because `col` is `Series<T>`, `col.fillNull(value)` performs a runtime covariance check `value as T`. If a `DataFrame` has both a `double` column and a `String` column with nulls, `df.fillNull(0.0)` throws `TypeError: 0.0 is not a subtype of type 'String'`. Even on a single `TypedSeries<double>` column, `df.fillNull(0)` throws `TypeError: 0 is not a subtype of type 'double'`.
  - **Fix**: Check type compatibility per column (coercing `int` to `double` for `TypedSeries<double>` and skipping incompatible columns, or accepting an optional `Map<String, Object>?` / column filter).

- [ ] **1.9.2 Broken `double.nan` ordering in `TypedSeries.sort`, `DataFrame.sortBy`, and `JoinMethod.sortMerge`**
  - **Severity**: Critical
  - **Location**: `lib/src/dataframe/series.dart:470-480`, `lib/src/dataframe/dataframe.dart:427-449`, `lib/src/dataframe/join.dart:243-267, 320-357`
  - **Problem**: Because `double.nan.compareTo(x)` and `x.compareTo(double.nan)` both return `0` for any finite `x`, `List.sort()` in `TypedSeries.sort` and `DataFrame.sortBy` violates comparator transitivity when `NaN` is present. Worse, in `_sortMergeJoinPairs` (`join.dart:256`), `compareRows` returns `0` whenever either row has `double.nan`, matching `NaN` keys with arbitrary finite keys.
  - **Fix**: Explicitly order `double.nan` after `+Infinity` in `TypedSeries.sort` and `DataFrame.sortBy`, and treat `NaN` keys as non-matching (like nulls) in `_sortMergeJoinPairs` and hash joins.

- [ ] **1.9.3 64-bit integer overflow/sign corruption in `ArrowIpc` (`_writeInt64` and `_writeUint64`)**
  - **Severity**: Critical
  - **Location**: `lib/src/dataframe/arrow/arrow_ipc.dart:1566-1586`
  - **Problem**: In `_writeInt64`, `val - 0x100000000 + 1` underflows 64-bit signed `int` on the Dart VM for `val < -9223372032559808513`, wrapping around to a positive number and corrupting both 32-bit words. In `_writeUint64`, `val ~/ 0x100000000` uses signed division on unsigned 64-bit values $\ge 2^{63}$, corrupting the output bytes.
  - **Fix**: Compute `final low = val & 0xFFFFFFFF;` and `final high = ((val - low) ~/ 0x100000000) & 0xFFFFFFFF;` in both `_writeInt64` and `_writeUint64`.

- [ ] **1.9.4 `exportSeriesToArrowC` throws `TypeError` when `TypedSeries.data` is not `TypedData` or uses `DataType.numeric`**
  - **Severity**: Critical
  - **Location**: `lib/src/dataframe/arrow/arrow_c_data_ffi.dart:406-420, 793-808`
  - **Problem**: Line 411 casts `series.data as TypedData`, which throws `TypeError` if `TypedSeries` was constructed with a regular `List<double>`/`List<int>` or `DataType.numeric` (`Series.fromList('x', <num>[1, 2.5])`).
  - **Fix**: Handle `DataType.numeric` and copy `series.data` into a `TypedData` buffer if `series.data is! TypedData`.

- [ ] **1.9.5 `GroupBy` `Agg.sum` overflows narrow integer types (`int8`/`int16`/`uint8`/`uint16`) and returns `0` for all-null groups**
  - **Severity**: Warning
  - **Location**: `lib/src/dataframe/groupby.dart:97-100, 238-244`, `lib/src/dataframe/series.dart:678-693`
  - **Problem**: `GroupBy` assigns `outTypes[outName] = srcCol.dataType` for `Agg.sum`, causing narrow integer sums to wrap modulo $2^8$ or $2^{16}$, and returns `0` (instead of `null`) when all values in a group are `null` (and `BoolSeries.sum` similarly returns `0` instead of `null` when all values are `null`).
  - **Fix**: Widen integer `Agg.sum` output columns to `DataType.int64` and return `null` when a group or `BoolSeries` has zero non-null values.

- [ ] **1.9.6 `Series.operator ==` fails on `double.nan` and `TypedSeries.slice` throws `RangeError` when `start > length`**
  - **Severity**: Warning
  - **Location**: `lib/src/dataframe/series.dart:200-221, 454-457`
  - **Problem**: `Series.operator ==` uses `this[i] != other[i]` instead of `dataType.equality.isEqual`, so a `Series` containing `double.nan` is not equal to a slice of itself. Additionally, `TypedSeries.slice(10, 12)` on a 5-element series calls `data.sublist(10, 5)` and throws `RangeError`, whereas `ArrowStringSeries.slice`, `BoolSeries.slice`, and `ObjectSeries.slice` clamp `startIndex` and return an empty `Series`.
  - **Fix**: Use `dataType.equality.isEqual` in `Series.operator ==` and clamp `startIndex = start.clamp(0, length)` in `TypedSeries.slice`.

- [ ] **1.9.7 `JoinDataFrameExtension.join` column name collision and `leftOn`/`rightOn` key duplication**
  - **Severity**: Warning
  - **Location**: `lib/src/dataframe/join.dart:119-170`
  - **Problem**: `final outName = usedNames.contains(col) ? '$col$suffix' : col;` throws `ArgumentError('Duplicate column name ...')` if `'$col$suffix'` is already in `usedNames` or `suffix` is empty. Also, `leftOn: ['id'], rightOn: ['id']` duplicates the key column instead of coalescing it like `on: ['id']`.
  - **Fix**: Disambiguate colliding column names iteratively until unique, and coalesce identical `leftOn`/`rightOn` key names.

- [ ] **1.9.8 CSV string trimming and null coercion break round-trip and chunk schema consistency**
  - **Severity**: Warning
  - **Location**: `lib/src/dataframe/csv/csv_reader.dart:65-69`, `lib/src/dataframe/csv/csv_stream.dart:44-46, 146-152, 165-169`
  - **Problem**: Quoted strings `"null"`, `"NA"`, and `""` are coerced to `null`, `CsvStream._buildDataFrame` trims whitespace from string columns when `columnTypes` is supplied, and `CsvStream.readChunks` infers column types independently per chunk.
  - **Fix**: Preserve quoted strings and untrimmed `DataType.string` values, and maintain consistent column types across `CsvStream.readChunks`.

- [ ] **1.9.9 `ArrowStringSeries.getBytes` silently returns empty `Uint8List` on out-of-bounds index**
  - **Severity**: Warning
  - **Location**: `lib/src/dataframe/arrow_string_series.dart:142-150`
  - **Problem**: `getBytes(int index)` returns `Uint8List(0)` when `index < 0 || index >= length` instead of throwing `RangeError` (unlike `operator []` and `isNull`).
  - **Fix**: Call `RangeError.checkValidIndex(index, this, 'index', length)` in `getBytes`.

---

### 1.10 `symbolic` Subsystem & `web/`

- [ ] **1.10.1 `Constant.undefined.isReal` and `Constant.infinity.isReal` evaluate to `true`**
  - **Severity**: Critical
  - **Location**: `lib/src/symbolic/ast/constant.dart:58`, `lib/src/symbolic/ast/expr.dart:218`, `lib/src/symbolic/algebra/simplify/transcendental.dart:462, 1350-1491`, `lib/src/symbolic/compiler/bytecode.dart:284`
  - **Problem**: `Constant.isReal` evaluates `value.b == 0.0 || value.isNaN`. Because `Constant.undefined` has `value = Complex.nan`, `Constant.undefined.isReal` and `isProvenReal(Constant.undefined, ...)` return `true`. Consequently, `Im(Constant.undefined).simplify()` and `Im(Constant.infinity).simplify()` return `0` instead of `Constant.undefined`, and `Re(Constant.undefined).simplify()` / `Conjugate(Constant.undefined).simplify()` treat `Constant.undefined` as real.
  - **Fix**: Change `Constant.isReal` to `!value.isNaN && !value.isInfinite && value.b == 0.0` (and match in `Expr._isRealSubtree`), and propagate `Constant.undefined` in `simplifyRe`, `simplifyIm`, `simplifyArg`, and `simplifyConjugate`.

- [ ] **1.10.2 `Expr.isReal` (`_isRealSubtree`) false positives and divergence from `isProvenReal`**
  - **Severity**: Critical
  - **Location**: `lib/src/symbolic/ast/expr.dart:216-262`, `lib/src/symbolic/algebra/simplify/transcendental.dart:448-494`
  - **Problem**: In `expr.dart:228-238`, `Ln`, `Asin`, `Acos`, `Acosh`, and `Atanh` only check domain bounds when `expr is RealNumeric`, returning `true` for `Asin(Constant.pi).isReal`, `Atanh(Constant.e).isReal`, `Acosh(IntegerNumber.zero).isReal`, and `Ln(-Variable('x')^2 - 1).isReal`. `LambertW` (`line 241`) falls through to `UnaryExpr`, returning `true` for `LambertW(IntegerNumber.of(-1))` and `LambertW(IntegerNumber.one, branch: -1)`. In `transcendental.dart:450-460`, `isProvenReal` unconditionally returns `true` for `Factorial`, `Binomial`, `Floor`, `Ceil`, `Round`, and `Sign` without checking their arguments (so `Im(Factorial(ComplexNumber.i)).simplify()` returns `0`).
  - **Fix**: Check argument realness for `Factorial`, `Binomial`, `Floor`, `Ceil`, `Round`, and `Sign` in `isProvenReal`, add `LambertW` domain/branch checks, and unify `Expr.isReal` with `isProvenReal(this, Assumptions.real)`.

- [ ] **1.10.3 `Constant.undefined` is not propagated by 25 of 26 `simplify*` functions in `transcendental.dart`**
  - **Severity**: Critical
  - **Location**: `lib/src/symbolic/algebra/simplify/transcendental.dart:20-388, 735-1491`
  - **Problem**: Only `simplifyLn` (`line 615`) checks `if (expr == Constant.undefined) return Constant.undefined;`. The other 25 `simplify*` functions wrap `Constant.undefined` in simplified AST nodes (e.g. `Sin(Asin(RealNumber(2.0))).simplify()` returns `Sin(Constant.undefined)` instead of `Constant.undefined`).
  - **Fix**: Propagate `Constant.undefined` at the entry of every `simplify*` function in `transcendental.dart`.

- [ ] **1.10.4 Bytecode compiler CSE register bug across `Piecewise` conditional branches reads uninitialized or stale registers**
  - **Severity**: Critical
  - **Location**: `lib/src/symbolic/compiler/bytecode.dart:244-265, 467-488, 510-513`
  - **Problem**: `countSubtrees` counts duplicate subexpressions across all branches of a `Piecewise` node. During `emit`, the first occurrence of a shared subexpression inside branch 0 emits `storeReg(regIdx)` inside branch 0's conditionally jumped block and marks `emittedRegs.add(regIdx)` globally. Later branches emit `loadReg(regIdx)`. When branch 0 is not taken at runtime, `storeReg(regIdx)` is skipped and the taken branch reads `0.0` or stale register state (e.g. `Expr.parse('piecewise(x > 0, sin(x) + 1, sin(x) - 1)').toFunction1D('x')(-pi / 2)` returns `-1.0` or `0.0` instead of `-2.0`).
  - **Fix**: Snapshot `emittedRegs` before emitting each `Piecewise` branch consequent (and `otherwise`) and restore it afterward so registers stored inside a conditional branch are never assumed initialized in sibling branches.

- [ ] **1.10.5 `ExprSyntax._unbindConstant` fails when `ComplexNumber` folds `i` and corrupts `exp(...)` when bound variable is `'e'`**
  - **Severity**: Critical
  - **Location**: `lib/src/symbolic/parser.dart:663-722`
  - **Problem**: When parsing `sum`, `product`, `integrate`, `diff`, or `limit` with dummy variable `'i'`, `2 * i` eagerly folds into `ComplexNumber(0, 2)` during parsing. `_unbindConstant` only checks `node == ComplexNumber.i` and `node == ComplexNumber.negativeI`, ignoring general `ComplexNumber` nodes, so `Expr.parse('sum(2 * i, i, 1, 5)').simplify()` returns `10*i` instead of `30`. Additionally, when `varName == 'e'`, lines 670–675 rewrite `Pow(Constant.e, exponent)` as `Pow(Variable('e'), ...)`, corrupting `exp(x)` inside `integrate(exp(x) * e, e)`.
  - **Fix**: Deconstruct `ComplexNumber(:final real, :final imaginary)` into `real + imaginary * Variable('i')` when `varName == 'i'`, and remove the `node.base == Constant.e` rewrite when `varName == 'e'`.

- [ ] **1.10.6 `_extractDominantPolynomialTerm` and `_polynomialDegreeAndLead` in `limit.dart` ignore unexpanded polynomial terms**
  - **Severity**: Critical
  - **Location**: `lib/src/symbolic/calculus/limit.dart:539-570, 732-774`
  - **Problem**: Neither function expands `expr` before inspecting `MonomialAccumulator` keys, and `_extractDominantPolynomialTerm` places any unexpanded term depending on `variable` (such as `(x + 1)^2` or `x * (x + 1)`) into `remainingTerms`. Consequently, `Expr.parse('exp((x + 1)^2) / exp(x^2 + 2*x)').limit('x', Constant.infinity)` returns `0` instead of `e`, and `Expr.parse('exp(x * (x + 1) - x^2)').limit('x', Constant.infinity)` returns `0` instead of `infinity`.
  - **Fix**: Call `expr.expand().simplify()` at the start of `_extractDominantPolynomialTerm` and `_polynomialDegreeAndLead`, and return `null` from `_extractDominantPolynomialTerm` if any term depending on `variable` has `_monomialDegree == null`.

- [ ] **1.10.7 Unevaluated `Limit` leakage in recursive `computeLimit` and wrong `Ln` limit at $0^-$**
  - **Severity**: Critical
  - **Location**: `lib/src/symbolic/calculus/limit.dart:57-134, 211-222`
  - **Problem**: Recursive `computeLimit` calls for `Pow(base, exponent)` (`line 86`) and `Pow(Constant.e, exponent)` (`line 100`) receive an unevaluated `Limit` node when inner evaluation fails and return `Pow(Constant.e, Limit(...))` instead of reaching `_computeInfiniteLimit` / `_gruntzLimit`. Also, `Ln(inner)` (`lines 125-127`) returns `-Constant.infinity` whenever `innerLim == 0` without checking that `inner` approaches $0^+$.
  - **Fix**: Fall through to the general limit pipeline when recursive `baseLim` or `expLim` is an unevaluated `Limit`, and verify `inner` approaches $0^+$ before returning `-Constant.infinity` for `Ln(inner)`.

- [ ] **1.10.8 `_expandSeriesTimesExpr` re-expands already-truncated `sLeft` polynomial, losing terms on multi-factor products with poles**
  - **Severity**: Critical
  - **Location**: `lib/src/symbolic/calculus/series.dart:677-726`
  - **Problem**: When `right` has a pole of order `q > 0`, `_expandSeriesTimesExpr` calls `sLeft.toExpr(includeOrder: false).toPowerSeries(..., order: sLeft.order + q)`. Because `sLeft` was already truncated at `sLeft.order`, re-expanding its polynomial AST pads higher degrees with zeros. Thus `Expr.parse('exp(x) * sin(x) / x').series('x', order: 3)` returns `1 + x + O(x^3)` instead of `1 + x + 1/3 * x^2 + O(x^3)`.
  - **Fix**: Track the original untruncated left factor product (or pre-sum pole orders across all factors in `_expandMulFactors`) so `boostedLeft` expands the original expression to `sLeft.order + q`.

- [ ] **1.10.9 `assumptions.copyWith(domains: ...)` in `summation.dart` wipes out caller's variable domain assumptions**
  - **Severity**: Critical
  - **Location**: `lib/src/symbolic/calculus/summation.dart:113-115, 225-227`
  - **Problem**: `computeSum` and `computeProduct` call `assumptions.copyWith(domains: {limitVarName: VariableDomain.integer})`, which replaces the entire `_domains` map and erases all per-variable assumptions supplied by the caller.
  - **Fix**: Use `assumptions.assume(limitVarName, VariableDomain.integer)`.

- [ ] **1.10.10 `MonomialAccumulator._reduceLogarithms` performs invalid branch-cut contractions and drops `assumptions`**
  - **Severity**: Critical
  - **Location**: `lib/src/symbolic/algebra/term_accumulator.dart:368-415, 565-582`, `lib/src/symbolic/algebra/simplify/additive.dart:49-51`
  - **Problem**: `_reduceLogarithms` contracts `Ln(a) + Ln(b) -> Ln(a * b)` without checking `isPositiveExpr`, which is invalid for negative/complex arguments, and neither `_reduceLogarithms`, `_doCombineFractions`, nor `simplifyNeg` forwards `assumptions: assumptions` to inner `simplify*` calls.
  - **Fix**: Require `isPositiveExpr` in `_reduceLogarithms` and thread `assumptions: assumptions` through all `simplify*` calls in `term_accumulator.dart` and `additive.dart`.

- [ ] **1.10.11 `SylvesterResultantSolver`, `solvePolynomialSystemEquations`, `matchQuadratic`, and `matchBiquadratic` fail on unexpanded polynomials**
  - **Severity**: Critical
  - **Location**: `lib/src/symbolic/solver/resultant.dart:12-22`, `lib/src/symbolic/solver/polynomial_system.dart:34-67`, `lib/src/symbolic/solver/polynomial.dart:9-20, 74-85`
  - **Problem**: `extractPolynomialCoefficients` returns `null` on unexpanded expressions such as `(x + y)^2 - 4`, causing `SylvesterResultantSolver.sylvesterMatrix` and `solvePolynomialSystemEquations(..., method: PolynomialSystemMethod.resultant)` to throw `ArgumentError` and `matchQuadratic`/`matchBiquadratic` to return `null`.
  - **Fix**: Expand input expressions (`expr.expand().simplify()`) before calling `extractPolynomialCoefficients`.

- [ ] **1.10.12 `Piecewise` stores mutable `branches` list and `ComplexNumber` constructor allows zero imaginary part**
  - **Severity**: Warning
  - **Location**: `lib/src/symbolic/ast/piecewise.dart:113`, `lib/src/symbolic/ast/number.dart:686`, `web/calculator/src/engine/commands/numbers.dart:275`
  - **Problem**: `Piecewise` stores the caller's `List<PiecewiseBranch>` directly without `List.unmodifiable`. `ComplexNumber` lacks `assert(!imaginary.isZero)` (unlike `FractionNumber`), and `web/calculator/src/engine/commands/numbers.dart:275` calls `ComplexNumber(...)` directly instead of `ComplexNumber.of(...)`.
  - **Fix**: Wrap `branches` in `List.unmodifiable` in `Piecewise`, add `assert(!imaginary.isZero)` to `ComplexNumber`, and use `ComplexNumber.of` in `numbers.dart:275`.

- [ ] **1.10.13 Asymmetric `ComplexNumber` operator folding and mixed-precision `ComplexNumber`**
  - **Severity**: Warning
  - **Location**: `lib/src/symbolic/ast/expr.dart:120-125, 145-152`
  - **Problem**: `2 + i` folds to `ComplexNumber(2, 1)` while `i + 2` returns `Add([i, 2])`; `2 * i` folds to `ComplexNumber(0, 2)` while `i * 2` returns `Mul([i, 2])`; and `RealNumber(2.0) * ComplexNumber.i` creates `ComplexNumber(IntegerNumber(0), RealNumber(2.0))` with mixed exact/inexact parts.
  - **Fix**: Fold `ComplexNumber` symmetrically on both sides of `+`, `-`, `*`, `/` and match `RealNumber` precision across real and imaginary parts.

- [ ] **1.10.14 `OrderTerm.substitute` and `Integral.substitute` bugs on bound variables, `Constant.undefined` parser round-trip, and `OrderTerm` degree-0 rendering**
  - **Severity**: Warning
  - **Location**: `lib/src/symbolic/ast/order_term.dart:34-40`, `lib/src/symbolic/ast/integral.dart:104-123`, `lib/src/symbolic/parser.dart:65-74`, `lib/src/symbolic/textualization/latex.dart:223-232`, `lib/src/symbolic/textualization/mathml.dart:296-310`
  - **Problem**: `OrderTerm.substitute` substitutes the bound variable inside `point` and fails to simplify to `0` when evaluated at `replacement == point`; `'undefined'` is missing from `ExprSyntax.standardConstants`; and `OrderTerm('x', 0, point: IntegerNumber.one)` renders as `O((x - 1)^{0})` instead of `O(1)` in LaTeX/MathML.
  - **Fix**: Fix `OrderTerm.substitute`, add `'undefined': Constant.undefined` to `ExprSyntax.standardConstants`, and check `if (order == 0)` before checking `point` in `latex.dart` and `mathml.dart`.

- [ ] **1.10.15 `simplifyRound` precision loss/crash on large `BigInt` fractions and missing `Ln` case in `_decomposeComplex`**
  - **Severity**: Warning
  - **Location**: `lib/src/symbolic/algebra/simplify/transcendental.dart:1233-1236, 1551-1701`
  - **Problem**: `simplifyRound` converts `numerator` and `denominator` to `double`, losing precision above $2^{53}$ and throwing `UnsupportedError` above $10^{308}$. `_decomposeComplex` lacks a `case Ln(:final expr):` branch, so `Re(Ln(z))`, `Im(Ln(z))`, and `Ln(z).toRectangular()` do not simplify.
  - **Fix**: Implement `simplifyRound` using exact `Integer` division/remainder, and add `case Ln(:final expr):` to `_decomposeComplex`.

- [ ] **1.10.16 Raw `int` overflow in polynomial factorization (`factor/univariate.dart` and `factor/multivariate.dart`)**
  - **Severity**: Warning
  - **Location**: `lib/src/symbolic/algebra/factor/univariate.dart:68-83, 176, 213, 371-391, 397, 430-447`, `lib/src/symbolic/algebra/factor/multivariate.dart:194-207, 264-277`
  - **Problem**: Converts `RationalNumber` coefficients to raw `int` (`asInt`), overflowing 64-bit `int` on VM (or 53-bit `int` on Web) during discriminant and synthetic division calculations.
  - **Fix**: Use `Integer` (`int | BigInt`) instead of raw `int`.

- [ ] **1.10.17 `PowerSeries` pole order loss in `_expandPow`, `_closedFormProduct` pole at 0, `_antiDerivative` dropping `assumptions`, and empty `terms` in `_differentiateIntegral`**
  - **Severity**: Warning
  - **Location**: `lib/src/symbolic/calculus/series.dart:908-922`, `lib/src/symbolic/calculus/summation.dart:741-762`, `lib/src/symbolic/calculus/integration.dart:159, 349-410, 2093-2116`, `lib/src/symbolic/calculus/differentiation.dart:250-252`
  - **Problem**: `_expandPow` does not boost base order when $m < 0, n > 1$; `_closedFormProduct` divides by `Gamma(0)` when linear products start at or cross $0$; `_antiDerivative` drops `assumptions` and `_wrapLnWithAbs` wraps all `Ln` nodes indiscriminately; and `_differentiateIntegral` lacks `[] => IntegerNumber.zero`.
  - **Fix**: Boost `_expandPow` order by $(n - 1)|m|$; handle non-positive integer roots in `_closedFormProduct`; forward `assumptions` into `_antiDerivative`; and add `[] => IntegerNumber.zero` in `_differentiateIntegral`.

- [ ] **1.10.18 `evaluate()` throws on unsimplified real-valued complex expressions, `Op.evalNode` returns `NaN` for `Derivative`/`Limit`/`Sum`/`Product`, and solver edge cases**
  - **Severity**: Warning
  - **Location**: `lib/src/symbolic/compiler/evaluator.dart:149-151, 607-645`, `lib/src/symbolic/solver/univariate.dart:96-105`, `lib/src/symbolic/solver/transcendental.dart:13, 48, 315-338`, `lib/src/symbolic/solver/system.dart:109-121`
  - **Problem**: `(ComplexNumber.i * ComplexNumber.i).evaluate()` throws `UnsupportedError`; `_evalNodeReal` returns `double.nan` for `Derivative`, `Limit`, `Sum`, and `Product`; `_solveUnfiltered` does not filter product roots that make co-factors `undefined`/`infinity`; `isolateAndInvert` drops `assumptions` and misses non-unit Lambert W ratios; and `solveEquations` returns `[]` on consistent overdetermined linear systems.
  - **Fix**: Fallback to `_runComplex` when `hasComplexLiterals` is true and return `res.a` if `res.b == 0`; evaluate `Derivative`/`Limit`/`Sum`/`Product` via substitution in `_evalNodeReal`; filter extraneous pole roots in `_solveUnfiltered`; generalize Lambert W ratio matching; and use `BareissEngine().rowEchelonWithPivots` for rectangular linear systems.

- [ ] **1.10.19 Inconsistent degree-mode conversion for trig functions in `web/calculator`**
  - **Severity**: Warning
  - **Location**: `web/calculator/src/engine/evaluator.dart:832-844`, `web/calculator/src/engine/sampling.dart:464-480`
  - **Problem**: In `AngleMode.deg`, `_convertTrigArgToDegrees` checks `expr.freeVariables.isEmpty` on the root expression instead of `inner.freeVariables.isNotEmpty` on the trig argument `inner`, causing `sin(30) + x` to convert `30` to radians twice during plotting while `subs(sin(x), x = 30)` evaluates in radians.
  - **Fix**: Check `inner.freeVariables.isNotEmpty` on each trig argument in `_convertTrigArgToDegrees`.

---

## 2. Performance Issues

- [ ] **2.1 `SingularValueDecomposition` ignores hardware-accelerated `Lapack.dgesvd` and allocates full $m \times m$ and $n \times n$ boxed `List<double>` arrays even when `computeVectors == false`**
  - **Severity**: Critical
  - **Location**: `lib/src/linear/decomposition/svd.dart:44-81, 252-265`, `lib/src/linear/decomposition/norm.dart:91, 143, 170`
  - **Problem**: `Lapack.dgesvd` is implemented across all platforms in `lib/src/acceleration/lapack/`, yet `SingularValueDecomposition` never calls it and instead runs a pure-Dart loop over boxed `List<double>` arrays (`aVals`, `uVals`, `sVals`, `vtVals`, `work`, `eList`, `vList`). Furthermore, even when `computeVectors: false` is passed—or when `matrix.norm2`, `matrix.cond`, and `matrix.rank` only need singular values `s`—`svd.dart` allocates $m \times m$ and $n \times n$ vector buffers and computes full singular vectors.
  - **Fix**: Route finite matrices in `SingularValueDecomposition` to `Lapack.dgesvd(jobu: computeVectors ? 'A' : 'N', jobvt: computeVectors ? 'A' : 'N', ...)`, replace all `List<double>` buffers in `svd.dart` with `Float64List`, skip allocating `uVals`/`vtVals` when `computeVectors == false`, and call `SingularValueDecomposition(this, computeVectors: false).s` in `norm2`, `cond`, and `rank`.

- [ ] **2.2 `CsrMatrix.matmul` has $\mathcal{O}(N \cdot (\text{nnz}(B) + \text{nnz}(A) + M))$ time and dense $\mathcal{O}(M \cdot N)$ space complexity**
  - **Severity**: Critical
  - **Location**: `lib/src/linear/sparse/csr_matrix.dart:186-214`
  - **Problem**: `CsrMatrix.matmul` multiplies column-by-column by allocating a dense unit vector `eJ`, calling `other.apply(eJ)`, and calling `this.apply(otherCol)`, performing $N$ full matrix-vector multiplications just to extract columns of `other` and materializing a dense `Matrix<T>`.
  - **Fix**: Implement Gustavson's row-wise sparse-sparse matrix multiplication when `other` is sparse (returning a `CsrMatrix<T>`) and direct sparse-dense row accumulation when `other` is a dense `Matrix<T>`.

- [ ] **2.3 `einsum` excludes batched matrix multiplication (`bij,bjk->bik`) from its BLAS fast path and allocates `List<int>` per inner-loop step**
  - **Severity**: Warning
  - **Location**: `lib/src/tensor/operations/einsum.dart:144-179, 223-251`
  - **Problem**: Line 145 (`if (batch.isEmpty)`) disables the `matmul` fast path whenever a batch index is present, even though `Tensor.matmul` natively supports batched 3D+ matrix multiplication via BLAS. In the fallback loop (`lines 223-251`), every inner iteration calls `getValue`/`setValue` with full coordinate validation and `toIndex` recomputation.
  - **Fix**: Route 2-operand batched contractions through permute + reshape + `Tensor.matmul`, and advance flat buffer offsets via precomputed stride deltas in the general odometer loop.

- [ ] **2.4 `Tensor.variance` and `Tensor.std` allocate 6–7 intermediate tensors and bypass `Vforce.mean` / `Vforce.variance`**
  - **Severity**: Warning
  - **Location**: `lib/src/tensor/operations/reduction.dart:133-177`
  - **Problem**: `variance()` allocates `thisDouble`, `meanTensor`, `diff = thisDouble - meanTensor`, `sq = diff * diff`, and `sumSq = sq.sum(...)`, traversing memory 5–6 times and never calling `Vforce.mean` or `Vforce.variance` on contiguous `Float64List` tensors.
  - **Fix**: Dispatch full-tensor contiguous `Float64List` `mean` and `variance` to `Vforce.mean` and `Vforce.variance`, and compute axis reductions in a two-pass scalar accumulator without allocating full-rank `diff` and `sq` tensors.

- [ ] **2.5 `Tensor.generate` and `concatenateAll`/`stackAll`/`tile`/`pad` allocate `List<int>` per element and recompute `toIndex`**
  - **Severity**: Warning
  - **Location**: `lib/src/tensor/tensor.dart:74-90`, `lib/src/tensor/operations/manipulation.dart:58-66, 113-120, 162-168, 206-209`
  - **Problem**: `Tensor.generate` iterates `effectiveLayout.keys` and calls `tensor.setValue(key, generator(key))` (recomputing `toIndex(key)` on a newly allocated contiguous layout). `concatenateAll`, `stackAll`, `tile`, and `pad` allocate two `List<int>` coordinate lists and call `getValue`/`setValue` on every single element.
  - **Fix**: Write `data[i++] = generator(key)` directly in `Tensor.generate`, and use stride-based flat loops (with `setRange` for contiguous axis-0 concatenation/stacking) in `manipulation.dart`.

- [ ] **2.6 `DataFrame.concat`, `DataFrame.sortBy`, `BoolSeries`, `ObjectSeries`, `ArrowStringSeries.min`/`max`, and `GroupBy` box elements unnecessarily**
  - **Severity**: Warning
  - **Location**: `lib/src/dataframe/dataframe.dart:239-250, 451-455`, `lib/src/dataframe/series.dart:628-665, 772-794`, `lib/src/dataframe/arrow_string_series.dart:324-345`, `lib/src/dataframe/groupby.dart:220-225`
  - **Problem**:
    1. `DataFrame.concat` boxes all values into `<Object?>[...col.values, ...otherCol.values]` and re-infers types via `Series.fromList`.
    2. `DataFrame.sortBy` rebuilds every column via `[for (final idx in indices) col[idx]]` and `Series.fromList`, decoding and re-encoding all UTF-8 strings in `ArrowStringSeries` and boxing all numbers in `TypedSeries`.
    3. `BoolSeries.filter`/`slice`/`sort` and `ObjectSeries.filter`/`slice` box elements into a temporary list instead of slicing `data` and `mask` directly.
    4. `ArrowStringSeries.min` and `max` decode every row into a `String` instead of comparing UTF-8 byte slices directly.
    5. `GroupBy._computeAgg` for `Agg.count` calls `col[indices[i]] != null` instead of `!col.isNull(indices[i])`.
  - **Fix**: Add buffer-level `concat` and `permute(List<int> indices)` methods on `Series` subclasses, slice `data`/`mask` directly in `BoolSeries` and `ObjectSeries`, compare UTF-8 byte ranges in `ArrowStringSeries.min`/`max`, and use `!col.isNull(...)` in `GroupBy`.

- [ ] **2.7 `NormalDistribution.sample` allocates a `sync*` generator and `UniformDistribution` on every call**
  - **Severity**: Warning
  - **Location**: `lib/src/stats/distributions/continuous/normal.dart:127-143`, `lib/src/stats/distributions/continuous/log_normal.dart:92`
  - **Problem**: `NormalDistribution.sample` calls `samples(random: random).first`, allocating a generator state machine and a `UniformDistribution(-1.0, 1.0)` on every call, generating two variates, and discarding one. This also slows down `GammaDistribution`, `StudentDistribution`, `PoissonDistribution`, and `MultivariateNormalDistribution` which call `normal.sample()` in their inner loops.
  - **Fix**: Implement `NormalDistribution.sample` directly using the Marsaglia polar method on `(random ?? _random).nextDouble()`.

- [ ] **2.8 Redundant `toList()` copies and double sorting in `stats/descriptive.dart`**
  - **Severity**: Warning
  - **Location**: `lib/src/stats/descriptive.dart:357-436, 578-579`
  - **Problem**: `DescriptiveVectorNumExtension` calls `toList()` before calling top-level functions that immediately call `.map((v) => v.toDouble()).toList()` a second time, and `_iqr` copies and sorts the input list twice.
  - **Fix**: Pass `this` directly as an `Iterable<num>` in `DescriptiveVectorNumExtension` and sort once in `_iqr`.

- [ ] **2.9 Unnecessary `BigInt` allocations in `combination`/`permutation` and per-call matrix allocations in `BicubicInterpolation`**
  - **Severity**: Warning
  - **Location**: `lib/src/special/gamma.dart:287-300, 320-332`, `lib/src/numeric/interpolation/bicubic.dart:160, 191, 214-275`, `lib/src/numeric/calculus/jacobian.dart:31`
  - **Problem**: `combination` and `permutation` allocate up to 1,000 `BigInt`s in a loop only to convert to `double` (and enter the `BigInt` branch for any float $\ge 2^{52}$ because `n.roundToDouble() == n`). `BicubicInterpolation` allocates 15 `List` objects per point evaluation. `jacobian` evaluates `function(point)` at the center only to read `.length`.
  - **Fix**: Accumulate `combination`/`permutation` in `double` for $n \le 2^{53}-1$ and use `combinationLn`/`permutationLn` above that; evaluate 1D cubic Hermite basis polynomials directly in `BicubicInterpolation`; and infer `numFuncs` from the first `fPlus.length` in `jacobian`.

- [ ] **2.10 $\mathcal{O}(\text{deg} \cdot \log K)$ complexity in `Polynomial.operator ==`, uncached `RationalFunction.simplify()`, linear `PowerSeries.pow`, and uncached `Expr.freeVariables`**
  - **Severity**: Warning
  - **Location**: `lib/src/polynomial/polynomial.dart:274-288`, `lib/src/polynomial/impl/compressed_polynomial.dart:579-582`, `lib/src/polynomial/rational.dart:169-182`, `lib/src/symbolic/calculus/series.dart:350-355`, `lib/src/symbolic/ast/expr.dart:187-205`
  - **Problem**: `Polynomial.operator ==` iterates `0..deg` instead of comparing non-zero terms in $\mathcal{O}(\text{termCount})$ time; `RationalFunction.operator ==` and `hashCode` recompute `simplify()` (`gcd`) on every call; `PowerSeries.pow` multiplies in an $\mathcal{O}(n)$ loop instead of $\mathcal{O}(\log n)$ binary exponentiation; and `Expr.freeVariables` / `dependsOn` recursively walk the AST on every call without caching.
  - **Fix**: Check `termCount == other.termCount` and compare non-zero terms in `Polynomial.operator ==`; cache `late final _canonical = simplify()` on `RationalFunction`; use binary exponentiation in `PowerSeries.pow`; and cache `late final Set<String> freeVariables` on composite `Expr` nodes.

---

## 3. Code Style and Readability

- [ ] **3.1 Top-level private declarations placed before public declarations (`AGENTS.md` Ordering Rule)**
  - **Severity**: Warning
  - **Location**:
    - `lib/src/acceleration/blas/blas_dart.dart:8` (`_gemmBlockSize` before `BlasDart`)
    - `lib/src/acceleration/fft/fft_native.dart:17` (`_fftwEstimate` before `FftNative`)
    - `lib/src/tensor/operations/contraction.dart:7-34` (`_normalizeAxes` before `ContractionTensorExtension`)
    - `lib/src/tensor/operations/manipulation.dart:7-24` (`_normalizeAxis` before `ManipulationTensorExtension`)
    - `lib/src/tensor/operations/operation.dart:5-47` (`_checkTargetHazard`, `_broadcastShapes`, `_broadcastLayout` before `OperationTensorExtension`)
    - `lib/src/tensor/operations/reduction.dart:11-84` (`_normalizeAxis`, `_reduceAxis` before `ReductionTensorExtension`)
    - `lib/src/numeric/interpolation/cubic_spline.dart:177-244` (`_MonotoneCubicSpline` before `AkimaSplineInterpolation` at line 253)
    - `lib/src/symbolic/algebra/factor/univariate.dart:371` (`_toPrimitiveIntCoeffs` before public functions at lines 394–504)
    - `lib/src/symbolic/algebra/simplify/transcendental.dart:583` (`_matchIntegerPiMultiple` before `simplifyExp`, `simplifyLn`, etc. at lines 602–1517)
    - `lib/src/symbolic/calculus/limit.dart:39` (`_negInfinity` before `computeLimit`)
    - `lib/src/symbolic/calculus/series.dart:152` (`_wrapSeriesPoint` before `PowerSeries`)
    - `lib/src/symbolic/calculus/summation.dart:1719` (`_isStrictlyInsideUnitDisk` before `evenZetaValue`)
    - `lib/src/symbolic/solver/system.dart:172` (`_isLinearSystem` before `solveSystemEquations`)
    - `lib/src/symbolic/solver/univariate.dart:54` (`_solveUnfiltered`, `_isPositiveRealRoot` before `satisfiesVariableDomain`, `isZeroExpr`, `deduplicateRoots`, `collectFactors`)
    - `lib/src/symbolic/textualization/string.dart:261` (`_formatOrderTerm` before `precedence`)
    - `web/calculator/src/model/value.dart:628` (`_containsRealNumber` before `formatRealDigits`)
    - `web/expressions/index.dart:444, 730, 1100, 1291, 1781` (private helpers interleaved with public functions)
    - `web/shared/chart.dart:388` (`_formatTick` before `drawGrid`, `drawCurve`, etc.)
  - **Problem**: Violates `AGENTS.md` ("All public members, methods, functions, variables, and constants must be placed at the top of classes and files... Private methods, functions, variables, and constants must be placed at the bottom of their respective classes and files").
  - **Fix**: Move all private top-level declarations below all public top-level declarations in each listed file.

- [ ] **3.2 Class member ordering violations (private fields/methods/constructors placed before public members, or fields placed at bottom of class)**
  - **Severity**: Warning
  - **Location**:
    - `lib/src/type/types/complex.dart:313` (`_source` field placed at bottom of `UnmodifiableFloat64ComplexList`)
    - `lib/src/type/types/nullable.dart:87` (`_comparator` field placed at bottom of `NullableDataType`)
    - `lib/src/linear/matrix.dart:533-664, 994-1043` (`_copyTensorToFloat64List`, `_solveRref`, `_solveUnderdeterminedMatrix`, `_tryAcceleratedGemv` placed before public methods/operators)
    - `lib/src/linear/vector.dart:501-542` (`_scan` placed before `operator ==` and `hashCode`)
    - `lib/src/acceleration/fft/fft_native.dart:32` (`_backend` placed before `isAvailable`, `fft1d`, `fft2d`)
    - `lib/src/dataframe/bitmask.dart:79` and `lib/src/dataframe/dataframe.dart:110` (private constructors `new _` placed before public fields/methods)
    - `lib/src/dataframe/csv/csv_stream.dart:335` (`_emitRow` placed before `close`, `addError`)
    - `lib/src/dataframe/arrow/arrow_ipc.dart:1263, 1478` (`_ensure`, `_getFieldPos` placed before public methods)
    - `lib/src/stats/distributions/discrete/rademacher.dart:90` (`_random` placed as static field after public methods)
    - `lib/src/symbolic/parser.dart:183-228` (`_mathSymbols` and private parser fields placed before public fields and methods)
    - `lib/src/symbolic/algebra/term_accumulator.dart:81, 368, 500, 522` (`_addMonomialTerm`, `_reduceLogarithms`, `_matchesShiftedPower`, `_isCombiningFractions` interleaved with public methods)
    - `lib/src/symbolic/compiler/evaluator.dart:58` (`_complexRegs` placed before public methods)
  - **Problem**: Violates `AGENTS.md` class member ordering conventions.
  - **Fix**: Place constructors first, class fields second, public getters/methods/operators third, and private constructors/methods at the bottom of each class.

- [ ] **3.3 Avoidable non-null assertions (`!`) and `dynamic` type annotations**
  - **Severity**: Suggestion
  - **Location**:
    - `lib/src/tensor/tensor.dart:113, 207` (`list!.length`, `Tensor<dynamic>`)
    - `lib/src/tensor/layout.dart:397, 405, 415, 423` (`slice.start!`, `slice.end!`)
    - `lib/src/tensor/operations/operation.dart:191` (`Tensor<dynamic>`)
    - `lib/src/tensor/operations/matmul.dart:196, 199, 218, 221` (`lda!`, `ldb!`)
    - `lib/src/tensor/operations/einsum.dart:69, 98, 129, 165, 169, 200, 232, 237` (`counts[char]!`, `dimMap[c]!`)
    - `lib/src/linear/matrix.dart:784-785, 856-857` (`mVal!`, `nVal!`)
    - `lib/src/stats/distributions/continuous/gamma.dart:66-67` & `inverse_gamma.dart:60-61` (`shape!`, `scale!`)
    - `lib/src/symbolic/parser.dart:509-691` (repeated `_asVariableName(v)!`)
  - **Problem**: Violates `AGENTS.md` ("Avoid using the non-null assertion operator (`!`) or `dynamic` types, if possible").
  - **Fix**: Promote nullable values via local variables or pattern matching and replace `Tensor<dynamic>` with `Tensor<Object?>`.

---

## 4. Missing or Broken Documentation

- [ ] **4.1 Broken code example in `README.md` (`matrix.solve(b)` with a `Vector` argument does not compile)**
  - **Severity**: Critical
  - **Location**: `README.md:69-70`
  - **Problem**: `README.md` shows `final b = Vector<double>.fromList([8.0, -11.0, -3.0]); final x = matrix.solve(b);`. However, `Matrix.solve` (`lib/src/linear/matrix.dart:456`) only accepts `Matrix<T> b`; solving for a vector requires `matrix.solveVector(b)`.
  - **Fix**: Update `README.md:70` to `final x = matrix.solveVector(b);`.

- [ ] **4.2 Factual discrepancies and missing `special` subsystem in `ARCHITECTURE.md` and `README.md`**
  - **Severity**: Warning
  - **Location**: `ARCHITECTURE.md:35-37, 54, 72, 96, 133, 135, 142, 151-161, 319, 323, 369-376, 397-398, 423, 665-666`, `README.md:20-21, 30, 128`, `benchmark/symbolic_benchmark.dart:5`
  - **Problem**:
    1. `ARCHITECTURE.md` completely omits a section for `package:data/special.dart` (`lib/src/special/`).
    2. `ARCHITECTURE.md:35-37` claims `Field<T>` has only basic ring/field operations and `ExtendedField<T>` has `abs, norm, sqrt, exp, log, conjugate`, whereas `Field<T>` defines all 23 methods and `ExtendedField<T>` is an empty interface.
    3. `ARCHITECTURE.md:54` references `Float64Vector.norm2` (actual method: `norm([num pNorm = 2])`).
    4. `ARCHITECTURE.md:72` documents positional `getRange(start, end, {axis})` (actual signature: `getRange({required int axis, int? start, int? end, int step = 1})`).
    5. `ARCHITECTURE.md:96` lists `var` (actual method: `variance`).
    6. `ARCHITECTURE.md:133, 135, 142` list `Vector.count` (actual: `length`), `matrix.transpose()` (actual: `matrix.transposed`), and `operator []((int, int))` (only `operator []=((int, int), T)` exists).
    7. `ARCHITECTURE.md:151-161` documents `{Vector<T>? target}` on `LinearOperator` methods, which do not exist in `lib/src/linear/operator.dart`.
    8. `ARCHITECTURE.md:319, 323` claim `Fft` provides real FFTs and `Vforce` methods are `sin, cos, ...` / `meanSquared` (actual: `vsin, vcos, ...`, no `meanSquared`).
    9. `ARCHITECTURE.md:369-376` claims 12 univariate distributions with `pdf`/`pmf`/`cdf`/`inverseCdf` and universal `.fit(data)` (actual: 23 univariate + 3 multivariate = 26 distributions with `probability`/`cumulativeProbability`/`inverseCumulativeProbability`, and `.fit()` on 12 of 23 univariate distributions). `README.md:20, 30, 128` also give conflicting counts (24 vs "Over 25").
    10. `ARCHITECTURE.md:397-398` states inequality constraints are $g_i(x) \le 0$ on line 397 and $c(x) \ge 0$ on line 398 (actual: $g_i(x) \le 0$).
    11. `ARCHITECTURE.md:423` references non-existent `laguerreEvaluate(n, x, {alpha})` and `laguerreL` in `orthogonal.dart`.
    12. `ARCHITECTURE.md:665-666` references a non-existent `parent` parameter on `Assumptions`.
    13. `benchmark/symbolic_benchmark.dart:5` claims Gröbner basis uses F4 (actual: Buchberger with Sugar strategy + FGLM).
  - **Fix**: Update `ARCHITECTURE.md`, `README.md`, and `benchmark/symbolic_benchmark.dart` to accurately reflect the codebase.

- [ ] **4.3 Missing `///` documentation comments on public classes, extensions, constructors, and methods**
  - **Severity**: Warning
  - **Location**:
    - `lib/src/symbolic/solver/multivariate_polynomial.dart:10-446` (30+ undocumented public members on `Monomial`, `MonomialOrder`, and `MultivariatePolynomial`, which are exported by `lib/symbolic.dart`)
    - `lib/src/tensor/operations/manipulation.dart:27` (`ManipulationTensorExtension`)
    - `lib/src/tensor/operations/matmul.dart:10` (`MatmulTensorExtension`)
    - `lib/src/tensor/operations/operation.dart:50` (`OperationTensorExtension`)
    - `lib/src/tensor/operations/reduction.dart:87` (`ReductionTensorExtension`)
    - `lib/src/type/models/equality.dart:18` (`NaturalEquality.new`)
    - `lib/src/acceleration/acceleration_error.dart:5` (`AccelerationError.new`)
  - **Problem**: Violates `AGENTS.md` ("Use triple-slash (`///`) doc comments for all public members").
  - **Fix**: Add `///` documentation comments to all listed public declarations.

- [ ] **4.4 Contradictory exception documentation for `AccelerationMode.accelerated`**
  - **Severity**: Warning
  - **Location**: `lib/acceleration.dart:13, 30-36`, `lib/src/acceleration/acceleration_mode.dart:13`
  - **Problem**: `lib/acceleration.dart:13` states `AccelerationMode.accelerated` throws `[AccelerationUnavailableError]`, whereas `lib/src/acceleration/acceleration_mode.dart:13` states it throws `[StateError]`.
  - **Fix**: Update `lib/src/acceleration/acceleration_mode.dart:13` to reference `[AccelerationUnavailableError]`.

---

## 5. Simplicity and Cleanness of Public APIs

- [ ] **5.1 Asymmetric `operator []` vs `operator []=` on `Matrix` and `Float64Matrix`**
  - **Severity**: Critical
  - **Location**: `lib/src/linear/matrix.dart:278-298`, `lib/src/linear/float64_matrix.dart:273-294`
  - **Problem**: `matrix[r]` (`Vector<T> operator [](int row)`) takes an `int` row index, enabling `matrix[r][c]` for both reading and writing (`matrix[r][c] = value`). However, `Matrix` and `Float64Matrix` define `void operator []=((int row, int col) pos, T value)` taking a record `(int, int)`, so `matrix[(r, c)] = value` compiles while `matrix[(r, c)]` does not compile, and `final row = matrix[r]` compiles while `matrix[r] = rowVec` does not compile.
  - **Fix**: Replace `operator []=((int row, int col) pos, T value)` with `operator []=(int row, Vector<T> values)` (while `matrix[r][c] = value` and `set(r, c, value)` handle 2D element assignment), restoring `[]` / `[]=` symmetry.

- [ ] **5.2 Redundant public alias `gammap` vs `lowRegGamma` in `special`**
  - **Severity**: Warning
  - **Location**: `lib/src/special/gamma.dart:96, 218`, `lib/special.dart:56, 61`
  - **Problem**: `gammap(num a, num x) => lowRegGamma(a, x);` is a duplicate alias for `lowRegGamma`, violating `AGENTS.md` ("Provide a single canonical way to perform an operation; avoid redundant convenience aliases").
  - **Fix**: Keep `gammap` (matching `gammaq` and `gammapInv`) as the single canonical function and remove `lowRegGamma`.

- [ ] **5.3 Inconsistent API surface between `Tensor`, `Matrix`, `Vector`, and their `Float64*` counterparts**
  - **Severity**: Warning
  - **Location**: `lib/src/linear/float64_vector.dart`, `lib/src/linear/float64_matrix.dart`, `lib/src/linear/decomposition/{cholesky,lu,qr,svd}.dart`
  - **Problem**:
    1. `Float64Vector` and `Float64Matrix` are missing unary `operator -()` (unlike `Tensor`, `Float64Tensor`, `Vector`, and `Matrix`), causing `-float64Vec` to fall back to `Vector<double>.operator -()` and lose its `Float64Vector` static type.
    2. `LUDecomposition.solve` (`lu.dart:187`) and `CholeskyDecomposition.solve` (`cholesky.dart:109`) throw `ArgumentError` on singular/non-SPD matrices, whereas `QRDecomposition.solve` (`qr.dart:179`) and `Matrix.solve` (`matrix.dart:603`) throw `StateError`.
    3. `LuMatrixExtension`, `QrMatrixExtension`, and `CholeskyMatrixExtension` are duplicated for `Matrix<T extends num>` and `Matrix<Complex>`, excluding `Matrix<Fraction>` and `Matrix<Expr>` even though the underlying decomposition classes are generic in `T`.
  - **Fix**: Add unary `operator -()` to `Float64Vector` and `Float64Matrix`; standardize singular/non-SPD solve failures on `StateError`; and unify `.lu`, `.qr`, `.cholesky`, `.det`, and `.inverse` into a single generic extension on `Matrix<T>`.

- [ ] **5.4 Untyped `Object data` parameter on `covarianceMatrix`, `pearsonCorrelationMatrix`, and `spearmanCorrelationMatrix`**
  - **Severity**: Warning
  - **Location**: `lib/src/stats/descriptive.dart:184, 188, 192`
  - **Problem**: Top-level matrix correlation/covariance functions accept `Object data` instead of `Matrix<num> data`, sacrificing static type safety.
  - **Fix**: Change parameter type to `Matrix<num> data` (since `Tensor<num>` already has extension methods `.covarianceMatrix()`, etc.).

- [ ] **5.5 `Field<T>` interface bloat vs empty `ExtendedField<T>`, parameter naming in `hypergeometric2F1`, and low-level exports in `symbolic`**
  - **Severity**: Suggestion
  - **Location**: `lib/src/type/models/field.dart:5-84`, `lib/src/special/hypergeometric.dart:56`, `lib/src/symbolic/solver/multivariate_polynomial.dart:170`, `lib/symbolic.dart:138-151`
  - **Problem**: `Field<T>` requires 23 methods while `ExtendedField<T>` is empty; `hypergeometric2F1(num a, num b, num cVal, num z)` names its third parameter `cVal` instead of `c`; `MultivariatePolynomial` exposes abbreviated `lm`, `lc`, `lt` getters; and `lib/symbolic.dart` exports internal solver engines (`BuchbergerEngine`, `FglmEngine`, `SylvesterResultantSolver`).
  - **Fix**: Provide default throwing implementations in a base `Field<T>` mixin/class (or separate `ExtendedField<T>`), rename `cVal` to `c`, replace `lm`/`lc`/`lt` with `leadingMonomial`/`leadingCoefficient`/`leadingTerm`, and keep low-level Gröbner/resultant engines internal behind `.solve(...)`.

---

## 6. Missing Features

- [ ] **6.1 `linear` & `tensor`: `isClose`, `Vector.normalized`, `Vector.cross`, `Matrix.kronecker`, `Matrix.pseudoinverse`, and sparse matrix algebra**
  - **Severity**: Suggestion
  - **Location**: `lib/src/tensor/`, `lib/src/linear/`, `lib/src/linear/sparse/`
  - **Problem**:
    1. `Tensor`, `Vector`, and `Matrix` lack an `isClose(other, {double epsilon = 1e-9})` method leveraging `type.equality.isClose`.
    2. `Vector` lacks `.normalized` (unit vector) and 3D `.cross(other)`.
    3. `Matrix` lacks `.kronecker(other)` and `.pseudoinverse` (Moore-Penrose pseudoinverse via SVD).
    4. Sparse matrices (`CooMatrix`, `CsrMatrix`, `CscMatrix`) lack `transposed`, `scale`, `+`, `-`, `==`, `hashCode`, and `toString`.
  - **Fix**: Implement `isClose` on `Tensor`/`Vector`/`Matrix`, `normalized` and `cross` on `Vector`, `kronecker` and `pseudoinverse` on `Matrix`, and basic algebraic/structural operations on sparse matrices.

- [ ] **6.2 `special` & `polynomial`: General-order Bessel functions, incomplete elliptic integrals, `zeta`, `polygamma`, and `laguerreEvaluate`**
  - **Severity**: Suggestion
  - **Location**: `lib/src/special/`, `lib/src/polynomial/orthogonal.dart`
  - **Problem**: `special` only implements order-0 and order-1 Bessel functions (`besselJ0`, `besselJ1`, etc.) and complete elliptic integrals (`ellipticK`, `ellipticE`), lacking general-order `besselJ(nu, x)`, `besselY(nu, x)`, `besselI(nu, x)`, `besselK(nu, x)`, incomplete elliptic integrals `ellipticF(phi, k)` / `ellipticEIncomplete(phi, k)`, Riemann `zeta(s)`, `polygamma(m, x)`, and `gammaqInv(a, q)`. `polynomial` lacks `laguerreEvaluate(n, x, {alpha})` advertised in `ARCHITECTURE.md`.
  - **Fix**: Add general-order Bessel functions, incomplete elliptic integrals, `zeta`, `polygamma`, `gammaqInv`, and `laguerreEvaluate`.

- [ ] **6.3 `numeric` & `stats`: Adaptive `bdf2` ODE step control, bound-constrained `minimize`, remaining distribution `.fit()` factories, and normality/contingency tests**
  - **Severity**: Suggestion
  - **Location**: `lib/src/numeric/ode/solve_ode.dart:335-419`, `lib/src/numeric/optimization.dart`, `lib/src/stats/distributions/`, `lib/src/stats/hypothesis/`
  - **Problem**:
    1. `OdeMethod.bdf2` uses a hardcoded 200-step uniform grid and ignores `abstol` and `reltol`.
    2. `minimize` lacks box bounds (`bounds: List<(double, double)>`) for multivariable optimization.
    3. 11 of 23 univariate distributions (`Cauchy`, `ChiSquared`, `F`, `Laplace`, `Logistic`, `Student`, `Weibull`, `Binomial`, `Hypergeometric`, `NegativeBinomial`, `Rademacher`) lack `.fit(samples)` factories promised in `ARCHITECTURE.md` Section 7.2.
    4. `stats` lacks `shapiroWilkTest` and `fisherExactTest`.
  - **Fix**: Add adaptive error-controlled step sizing to `bdf2`, box `bounds` support to `minimize`, `.fit()` factories to remaining univariate distributions, and `shapiroWilkTest` / `fisherExactTest` to `stats`.

- [ ] **6.4 `dataframe` & `symbolic`: `DataFrame.pivot`/`dropDuplicates`/`fromMatrix`, vector calculus operators (`divergence`, `curl`, `laplacian`), symbolic ODE solver (`solveOde`), and `example/symbolic_demo.dart`**
  - **Severity**: Suggestion
  - **Location**: `lib/src/dataframe/`, `lib/src/symbolic/calculus/`, `example/`
  - **Problem**:
    1. `DataFrame` lacks `dropDuplicates`, `pivot` / `melt`, and `DataFrame.fromMatrix` / `DataFrame.fromTensor` (to complement `toMatrix` / `toTensor`).
    2. `symbolic` provides `gradient`, `hessian`, and `jacobian`, but lacks `laplacian`, `divergence`, and `curl`, as well as a symbolic `solveOde` to mirror `package:data/numeric.dart`.
    3. `example/` has standalone demos for `numeric`, `polynomial`, and `stats`, but no `example/symbolic_demo.dart`.
  - **Fix**: Add `dropDuplicates`, `pivot`, and `fromMatrix`/`fromTensor` to `DataFrame`; add `laplacian`, `divergence`, `curl`, and `solveOde` to `symbolic`; and create `example/symbolic_demo.dart`.

---

## 7. Large Files, Complex Structure, Distributed Responsibility, and Dead Code

- [ ] **7.1 Dead code: `AccelerationFailedError` and unused functions in `web/expressions/algebra.dart`**
  - **Severity**: Warning
  - **Location**: `lib/src/acceleration/acceleration_error.dart:22-26`, `web/expressions/algebra.dart:5-13, 25-33, 38-39`
  - **Problem**: `AccelerationFailedError` is never instantiated or thrown anywhere in the codebase. In `web/expressions/algebra.dart`, `formatRealNumber` and `formatComplex` are dead code (never referenced), and `factorExpr` is a trivial 1-line pass-through.
  - **Fix**: Remove `AccelerationFailedError` (or throw it when native routines fail in `AccelerationMode.accelerated`) and remove the unused functions in `web/expressions/algebra.dart`.

- [ ] **7.2 Dead/identical branches and duplicated binary operator boilerplate across `Float64Tensor`, `Float64Vector`, and `Float64Matrix`**
  - **Severity**: Warning
  - **Location**: `lib/src/tensor/float64_tensor.dart:173-271`, `lib/src/linear/float64_vector.dart:188-315`, `lib/src/linear/float64_matrix.dart:353-402`
  - **Problem**: In `Float64Vector` and `Float64Matrix`, `if (other.tensor.data is Float64List)` and `else` contain identical loop bodies because `final b = other.tensor.data;` is declared outside the `if` and never type-promoted to `Float64List`. Furthermore, the same 30-line target validation and memory-hazard block is copy-pasted 10 times across `+`, `-`, `*`, `/` in `Float64Tensor`, `Float64Vector`, and `Float64Matrix`.
  - **Fix**: Promote `b` properly to `Float64List` and delegate contiguous binary elementwise operations in `Float64Vector` and `Float64Matrix` to `Float64Tensor`.

- [ ] **7.3 Duplicated Gaussian elimination (`system.dart` vs `bareiss.dart`), duplicated Levenberg-Marquardt (`curveFit` vs `fitNonlinear`), duplicated `_toDoubleMatrix`, and duplicated integer helpers**
  - **Severity**: Warning
  - **Location**:
    - `lib/src/symbolic/solver/system.dart:195-311` vs `lib/src/symbolic/linear/bareiss.dart:196-243`
    - `lib/src/numeric/curve_fit.dart:474-519` vs `lib/src/numeric/curve_fit.dart:633-673`
    - `lib/src/linear/decomposition/{cholesky,eigenvalue,lu,qr,svd}.dart` (`_toDoubleMatrix` duplicated 5 times)
    - `lib/src/symbolic/algebra/factor/univariate.dart:477-501` vs `lib/src/symbolic/algebra/factor/multivariate.dart:20-45` (`gcd`, `lcm`, `integerSqrt` duplicating `Integer` methods)
  - **Problem**: Multiple subsystems maintain duplicate implementations of the same algorithms and helpers.
  - **Fix**: Delegate `solveSystemEquations` in `system.dart` to `BareissEngine`; delegate `curveFit` optimization to `fitNonlinear`; share a single `toDoubleMatrix` helper in `linear`; and use `Integer.gcd`, `Integer.lcm`, and `Integer.isqrt` in `univariate.dart` and `multivariate.dart`.

- [ ] **7.4 Top-level files in `lib/src/numeric/` and orthogonal polynomial builders in `polynomial.dart` violate sub-package modularization**
  - **Severity**: Warning
  - **Location**: `lib/src/numeric/{curve_fit.dart, integration.dart, sampling.dart, fft.dart, optimization.dart}`, `lib/src/polynomial/polynomial.dart:302-491`
  - **Problem**: `curve_fit.dart` (676 lines), `integration.dart` (511 lines), `sampling.dart` (458 lines), `fft.dart` (196 lines), and `optimization.dart` (183 lines) sit at the root of `lib/src/numeric/` instead of feature sub-packages (`AGENTS.md`: "Functional modules must be decomposed into dedicated sub-packages within `lib/src/<subsystem>/<feature>/`"). Similarly, `chebyshevT`, `chebyshevU`, `legendreP`, `hermiteH`, `hermiteHe`, and `laguerreL` are implemented inside `polynomial.dart` instead of `orthogonal.dart`.
  - **Fix**: Organize `lib/src/numeric/` modules into feature sub-packages (mirroring in `test/numeric/`) and move orthogonal polynomial recurrence builders into `lib/src/polynomial/orthogonal.dart`.

- [ ] **7.5 Oversized monolithic files (`integration.dart`: 2,163 lines, `summation.dart`: 1,829 lines, `transcendental.dart`: 1,702 lines, `arrow_ipc.dart`: 1,587 lines, `matrix.dart`: 1,051 lines)**
  - **Severity**: Suggestion
  - **Location**: `lib/src/symbolic/calculus/integration.dart`, `lib/src/symbolic/calculus/summation.dart`, `lib/src/symbolic/algebra/simplify/transcendental.dart`, `lib/src/dataframe/arrow/arrow_ipc.dart`, `lib/src/linear/matrix.dart`
  - **Problem**:
    1. `integration.dart` (2,163 lines) combines definite improper/special integral pattern tables with indefinite rational, trig, radical, and by-parts integration.
    2. `summation.dart` (1,829 lines) combines finite summation, infinite series, and finite/infinite product evaluation.
    3. `transcendental.dart` (1,702 lines) combines trig/log/special/combinatorial simplification with domain provers (`isPositiveExpr`, `isProvenReal`) and complex rectangular decomposition (`_decomposeComplex`).
    4. `arrow_ipc.dart` (1,587 lines) embeds a full FlatBuffer reader/writer alongside Arrow IPC framing.
    5. `matrix.dart` (1,051 lines) embeds dense linear system solvers (`solve`, `solveVector`, `_solveRref`, `_solveUnderdeterminedMatrix`) alongside container operations.
  - **Fix**: Split definite vs indefinite integration in `calculus/integration/`; split product evaluation into `calculus/product.dart`; extract domain/complex decomposition from `transcendental.dart`; extract FlatBuffer serialization into `dataframe/arrow/flatbuffer.dart`; and move direct dense solvers into `linear/solvers/direct.dart` (maintaining 1:1 test file symmetry in `test/`).
