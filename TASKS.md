# Engineering Audit & Action-Oriented Task Specification (`package:data`)

This document provides a comprehensive, prioritized engineering roadmap of confirmed bugs, safety and FFI boundary hazards, public API inconsistencies, algorithmic performance optimizations, missing high-value features, and test/documentation gaps across all 10 subsystems of `package:data`.

Each task specifies:

- **Severity**: `Critical` (process crash / memory corruption / data loss / silent wrong mathematical result), `High` (runtime exception on valid input / major contract violation / severe performance bottleneck), `Medium` (API inconsistency / edge-case inaccuracy / charter rule violation), or `Low` (ergonomics / minor cleanup).
- **Target Files**: Exact repository-relative paths.
- **Problem & Evidence**: Concrete code behavior or reproducible failure output.
- **Actionable Fix & Acceptance Criteria**: Exact implementation steps and unit test requirements.

---

## 1. Critical Bugs & Memory / Process Safety Hazards

### TASK-1.1: Prevent Native CBLAS `cblas_xerbla` Process Aborts on Zero-Sized or Invalid Leading Dimensions

- **Severity**: Critical
- **Target Files**:
  - `lib/src/acceleration/blas/blas_native.dart`
  - `lib/src/acceleration/blas/blas_dart.dart`
  - `lib/src/tensor/operations/matmul.dart`
- **Problem & Evidence**:
  - Calling `Tensor.matmul` on zero-extent dimensions (e.g., `Tensor<double>.filled(0.0, shape: [2, 0]).matmul(Tensor<double>.filled(0.0, shape: [0, 2]))`) or calling `Blas.dgemm` / `Blas.dgemv` with `m == 0`, `n == 0`, or `k == 0` when `lda == 0` invokes Apple Accelerate's native `cblas_dgemm`/`cblas_dgemv` with `lda = 0`.
  - Native CBLAS requires `lda >= max(1, k)` (or `max(1, m)`) even when dimensions are zero; otherwise `cblas_xerbla` prints `LDA must be >= MAX(K,1): LDA=0 K=0. BLAS error: Parameter number 9 passed to cblas_dgemm had an invalid value` and **terminates the Dart VM process with exit code 255 (`abort()`)**.
  - Additionally, passing buffers smaller than required by `(n - 1) * incX.abs() + 1 + xOffset` (or matrix leading dimensions) to `blas_native.dart` passes raw pointers directly to C without bounds checking, causing out-of-bounds heap reads/writes in native mode while `blas_dart.dart` throws `RangeError`.
- **Actionable Fix & Acceptance Criteria**:
  1. In `blas_native.dart` (and `blas.dart`), add fast early returns when `n <= 0` (Level 1) or `m <= 0 || n <= 0` (Level 2/3, after applying `beta` scaling to `y`/`c` when `k == 0`), before invoking FFI `@Native` functions.
  2. Validate `trans`/`uplo`/`side`/`diag` enum constants, `lda >= max(1, ...)`, `incX != 0`, and buffer bounds (`offset >= 0` and required span fits within `.length`) in `Blas` before FFI dispatch; throw `RangeError` or `ArgumentError` consistently across `dart`, `auto`, and `accelerated` modes.
  3. In `lib/src/tensor/operations/matmul.dart`, when the contracted inner dimension `k == 0`, zero-fill `target` (using `type.field. additiveIdentity`) before returning so pre-allocated non-zero targets are not left with stale values.
  4. Verify with `accelerationTest` covering `0x0`, `2x0 * 0x2`, and out-of-bounds buffer views.

### TASK-1.2: Fix `Float64Vector` and `Float64Matrix` Unchecked Buffer Overruns & Silent Write Loss

- **Severity**: Critical
- **Target Files**:
  - `lib/src/linear/float64_vector.dart`
  - `lib/src/linear/float64_matrix.dart`
  - `lib/src/tensor/float64_tensor.dart`
- **Problem & Evidence**:
  - **Out-of-bounds read/write on views**: `Float64Vector.operator []` and `operator []=` check `if (layout.isContiguous && layout.offset == 0)` and index `_list[index]` directly without checking `index < length`. For a prefix subvector view `final sub = Float64Vector(v.subVector(0, 2))` of a 4-element vector `[10, 20, 30, 40]`, `sub.isContiguous` is `true` and `sub.layout.offset` is `0`, so `sub[3]` silently returns `40.0` instead of throwing `RangeError`!
  - **Silent write loss on non-`Float64List` backing**: `Float64Tensor.asTypedList` returns `data is Float64List ? data : Float64List.fromList(data)`. When a `Matrix<double>` or `Vector<double>` is backed by `Float32List` (e.g., created with `type: DataType.float32`) or a generic `List<double>`, `Float64Matrix(m).set(0, 0, 99.0)` writes into the temporary `Float64List.fromList(data)` copy and silently discards the mutation (`m.get(0, 0)` remains `1.0`), and `get1D`/`get2D` copy the entire buffer on every element read ($O(N)$ per access).
- **Actionable Fix & Acceptance Criteria**:
  1. In `Float64Tensor(...)`, `Float64Matrix(...)`, and `Float64Vector(...)` constructors, validate `tensor.data is Float64List` and throw `ArgumentError` if the underlying storage is not a `Float64List` (or provide an explicit `.fromDoubleTensor` copying factory), eliminating the defensive `Float64List.fromList` allocation in `asTypedList`.
  2. In `Float64Vector.operator []` / `operator []=` and `Float64Matrix.get` / `set` / `operator []`, enforce `RangeError.checkValidIndex(index, this, 'index', length)` (and row/col bounds checks for matrices) before accessing `_list`. Keep unchecked access strictly on `getUnchecked`/`setUnchecked` or `get1D`/`set1D`.
  3. Add unit tests in `test/linear/float64_vector_test.dart` and `test/linear/float64_matrix_test.dart` verifying that out-of-bounds indexing on `subVector(0, k)` throws `RangeError`.

### TASK-1.3: Fix `LUDecomposition` Out-of-Bounds Crash on Rectangular Matrices ($m < n$)

- **Severity**: Critical
- **Target Files**:
  - `lib/src/linear/decomposition/lu.dart`
- **Problem & Evidence**:
  - Calling `m.lu` on a wide rectangular matrix ($m < n$, e.g. $2 \times 3$) throws `RangeError (length): Invalid value: Not in inclusive range 0..5: 8` inside `LUDecomposition` because loop bounds and `lower`/`upper` dimensions assume $m \ge n$ (allocating $n \times n$ for `upper` and indexing row $i \ge m$ in `_lu`).
- **Actionable Fix & Acceptance Criteria**:
  1. Support general $m \times n$ LU factorization with `minMN = math.min(m, n)`: `lower` has shape $m \times \text{min}(m, n)$ with unit diagonal, and `upper` has shape $\text{min}(m, n) \times n$ (or restrict `LUDecomposition` to $m \ge n$ / square matrices with a clear `ArgumentError` and document it).
  2. Add tests for $2 \times 3$ and $3 \times 2$ matrices in `test/linear/decomposition/lu_test.dart`.

### TASK-1.4: Fix `DataFrame.sortBy` Null Comparator Crash & `DataFrame.toTensor` Silent Null/String Corruption

- **Severity**: Critical
- **Target Files**:
  - `lib/src/dataframe/dataframe.dart`
- **Problem & Evidence**:
  - In `DataFrame.sortBy` (`lib/src/dataframe/dataframe.dart` lines 253–269), when `valA != null && valB == null`, the comparator skips the `if (valA == null)` block and executes `(valA as Comparable).compareTo(valB)`, which immediately crashes with `TypeError: type 'Null' is not a subtype of type 'num' of 'other'`. Reproduction: `DataFrame.fromColumns({'x': [2, null, 1]}).sortBy('x')` throws `TypeError`.
  - In `DataFrame.toTensor` (`lib/src/dataframe/dataframe.dart` lines 354–384), null entries and non-numeric `Object`/`String` entries silently convert to `0.0` (`val is num ? val.toDouble() : 0.0`) instead of `double.nan` (for nulls) and throwing `FormatException`/`UnsupportedError` (for non-numeric columns).
- **Actionable Fix & Acceptance Criteria**:
  1. Fix `DataFrame.sortBy` to check `if (valB == null) return nullsLast ? -1 : 1;` before calling `compareTo`.
  2. In `DataFrame.toTensor`, map null values in numeric columns to `double.nan` (or add `{double nullValue = double.nan}`), and throw `UnsupportedError` if a selected column is non-numeric (`String`, `bool`, arbitrary objects).
  3. Add unit tests for sorting columns with interspersed nulls (`ascending: true/false`, `nullsLast: true/false`) and converting nullable/non-numeric columns to tensors.

### TASK-1.5: Fix Arrow IPC Multi-Batch Data Loss, Unaligned Buffer Views Crash, and Dictionary/Compression Handling

- **Severity**: Critical
- **Target Files**:
  - `lib/src/dataframe/arrow/arrow_ipc.dart`
- **Problem & Evidence**:
  - **Multi-batch overwrite**: In `ArrowIpc.decode` (`lib/src/dataframe/arrow/arrow_ipc.dart` lines 88–103), each `RecordBatch` message overwrites `resultDf = _readRecordBatch(...)` instead of accumulating batches, silently dropping all batches except the last one in multi-batch Arrow IPC streams/files produced by PyArrow, Polars, or DuckDB.
  - **Unaligned `Uint8List` view crash**: `_readRecordBatch` creates typed views via `Float64List.sublistView(bytes, ...)` assuming `bytes.offsetInBytes == 0`. When `bytes` is a `Uint8List.sublistView` starting at an offset not divisible by 8 (e.g. offset 4 from a network frame or file header), `ArrowIpc.decode` crashes with `RangeError: Offset (276) must be a multiple of BYTES_PER_ELEMENT (8)`.
  - **Silent corruption on dictionary-encoded or compressed batches**: Schema `dictionary` fields and `RecordBatch` `compression` fields are ignored, causing dictionary index buffers or LZ4/ZSTD compressed bytes to be reinterpreted as raw primitive values.
- **Actionable Fix & Acceptance Criteria**:
  1. Accumulate decoded columns across all `RecordBatch` messages and concatenate them (or construct chunked series) before returning the final `DataFrame`.
  2. Check `(bytes.offsetInBytes + dataStart) % elementSize == 0` before calling `sublistView`; when unaligned, copy the slice into an aligned `Uint8List` buffer first.
  3. Detect non-null `dictionary` on `Field` and non-null `compression` on `RecordBatch` and either support them or throw a descriptive `UnsupportedError`.
  4. Add tests in `test/dataframe/arrow/arrow_ipc_test.dart` for multi-batch streams and unaligned `Uint8List.sublistView` inputs.

### TASK-1.6: Fix Arrow C Data Interface Memory Leaks, Missing `offset` Handling, `null_count == -1`, and Charter Signature Mismatch

- **Severity**: Critical
- **Target Files**:
  - `lib/src/dataframe/arrow/arrow_c_data_ffi.dart`
  - `lib/src/dataframe/arrow/arrow_c_data_stub.dart`
- **Problem & Evidence**:
  - **Memory leak on import**: `ArrowCDataExtension.importFromC` / `SeriesCDataExtension.importFromC` never calls the producer's `release` callback on `ArrowSchema` or `ArrowArray` after copying the buffers (nor zeroes `schema.release`/`array.release`), leaking foreign C/Python/DuckDB memory on every import per the Arrow C Data specification.
  - **Non-zero `array.offset` ignored**: Imported arrays ignore `array.offset`, reading from index 0 of validity bitmaps, primitive buffers, and string offset buffers—producing corrupted data when importing sliced arrays from Polars/PyArrow.
  - **`null_count == -1` drops all nulls**: In Arrow C Data, `null_count == -1` means "unknown null count, check validity bitmap", but `_importValidityMask` checks `if (nullCount <= 0 || validityPtr == nullptr) return null;`, silently discarding all nulls when a producer sets `null_count = -1`!
  - **Charter API mismatch**: `AGENTS.md` mandates `exportTo({required outSchema, required outArray})` and `importFrom({required schema, required array})`, whereas the code uses positional `exportToC(schemaPtr, arrayPtr)` and `SeriesCDataExtension.importFromC(name, schemaPtr, arrayPtr)` (and lacks `DataFrame.importFrom` as a static/factory method).
- **Actionable Fix & Acceptance Criteria**:
  1. Rename methods to canonical `exportTo({required outSchema, required outArray})` and `importFrom({required schema, required array})` on `DataFrame` and `Series`.
  2. Respect `array.offset` across primitive buffers, validity bitmaps, and `Utf8` offset buffers.
  3. Treat `null_count != 0 && validityPtr != nullptr` (including `null_count == -1`) as having a validity bitmap, computing the actual null count from the bitmask when `null_count == -1`.
  4. Invoke the producer's `release` callbacks on `array` and `schema` in a `try`/`finally` block once import finishes.
  5. Guard partial allocations during `exportTo` so an exception on column $k$ releases columns $0 \dots k-1$.

### TASK-1.7: Fix Symbolic Definite Integration Returning Finite Values Across Divergent Singularities & Throwing on Negative Float Powers

- **Severity**: Critical
- **Target Files**:
  - `lib/src/symbolic/calculus/integration.dart`
- **Problem & Evidence**:
  - **False finite result on divergent integral**: `Expr.parse('1/x^2').integrate('x', from: -1, to: 1)` applies $F(b) - F(a) = (-1/1) - (-1/-1) = -2$ across the pole at $x = 0$, returning `-2` for $\int_{-1}^1 x^{-2}\,dx = +\infty$!
  - **Uncaught exception on `x^(-1.0)` and `1/(x*ln(x))`**:
    - `Expr.parse('x^(-1.0)').integrate('x')` and `Expr.parse('1/(x*ln(x))').integrate('x')` throw `UnsupportedError: Division by zero in negative power of zero` inside `_antiDerivPow` / `_tryChainRulePower` because `exponent` is `RealNumber(-1.0)` (not `IntegerNumber.negativeOne`, or in `1/(x*ln(x))`, $u = \ln(x)$ has power $-1$ which hits `pow + 1 = 0` division in `_tryChainRulePower`), violating the `AGENTS.md` rule: *"Symbolic integration (`integrate`) returns an unevaluated `Integral` AST node when no elementary closed-form antiderivative exists rather than throwing exceptions."*
  - **Logarithmic antiderivative missing `abs` on negative bounds**: `Expr.parse('1/x').integrate('x', from: -2, to: -1)` fails to evaluate to `ln(2)` because $\int x^{-1}\,dx$ returns `ln(x)` instead of `ln(abs(x))` (or handling negative intervals in definite evaluation).
- **Actionable Fix & Acceptance Criteria**:
  1. In `_tryChainRulePower` and `_antiDerivPow`, check `if (n == IntegerNumber.negativeOne || (n is RealNumber && n.value == -1.0))` and return `Ln(u)` (or `Ln(Abs(u))` under real assumptions). Wrap internal simplification in `_symbolicIntegrate` so any domain error falls back to returning an unevaluated `Integral` node rather than throwing.
  2. Before applying $F(b) - F(a)$ on finite intervals $[a, b]$, detect interior poles where denominator factors vanish on $[a, b]$ (e.g., via root solving on denominators of rational/trig expressions) and split the interval at interior singularities or return an unevaluated `Integral` / `Constant.infinity`.

### TASK-1.8: Fix `Derivative.substitute` and `Integral.substitute` Bound-Variable Capture & Point-Evaluation Bug

- **Severity**: Critical
- **Target Files**:
  - `lib/src/symbolic/ast/derivative.dart`
  - `lib/src/symbolic/ast/integral.dart`
  - `lib/src/symbolic/ast/limit.dart`
  - `lib/src/symbolic/ast/summation.dart`
- **Problem & Evidence**:
  - `Derivative(Expr.parse('x^2'), 'x').substitute('x', IntegerNumber.two).simplify()` substitutes `x = 2` *inside* the operand before differentiating, producing `Derivative(4, 'x') -> 0` instead of $\left.\frac{d}{dx}(x^2)\right|_{x=2} = 4$!
  - Similarly, `Integral(f, 'x', lower: a, upper: b).substitute('x', val)` substitutes the dummy integration variable `'x'` inside `f` even though `'x'` is bound in a definite integral, and when substituting a free variable `y -> x` into `Integral(f(x, y), 'x')`, variable capture occurs because bound `'x'` is not alpha-renamed.
- **Actionable Fix & Acceptance Criteria**:
  1. In `Definite Integral`, `Limit`, `Sum`, and `Product`, do not substitute the bound variable in the body (only in `lower`/`upper`/`point` bounds), and alpha-rename the bound variable if `replacement.freeVariables.contains(variable)`.
  2. In `Derivative.substitute(v, replacement)`, if `v == variable` and `replacement` is not a simple `Variable`, either evaluate the derivative first (`expr.derivative(variable, order: order).substitute(v, replacement)`) or keep an evaluation node rather than substituting a constant into the differentiation target.

### TASK-1.9: Fix `Integer` Safe-Range Assertion Crash in `RationalNumber` and `_exactIntegerRoot` for Large `BigInt`s

- **Severity**: Critical
- **Target Files**:
  - `lib/src/symbolic/ast/number.dart`
  - `lib/src/symbolic/number/rational.dart`
- **Problem & Evidence**:
  - `Pow(IntegerNumber(Integer.big(BigInt.one << 120)), FractionNumber.half).simplify()` crashes with `AssertionError: 'package:data/src/symbolic/number/integer.dart': line 30: '-maxSafe <= value && value <= maxSafe': Value 1152921504606846976 is outside the safe range, use Integer.from` because `_exactIntegerRoot` in `lib/src/symbolic/ast/number.dart` calls `Integer(rInt)` (the `const` small-integer constructor) instead of `Integer.from(rInt)` / `Integer.big(...)`.
  - Likewise, `RationalNumber.fromFraction` and `RationalNumber(int, int)` call `Integer(value)` directly instead of `Integer.from(value)`, failing when a `vm` 64-bit `int` exceeds $2^{53} - 1$.
- **Actionable Fix & Acceptance Criteria**:
  1. Replace all non-compile-time-constant `Integer(x)` calls in `lib/src/symbolic/ast/number.dart` and `lib/src/symbolic/number/rational.dart` with `Integer.from(x)` or `Integer.big(x)`.
  2. Add unit tests in `test/symbolic/number_test.dart` for exact roots and rationals with values $> 2^{53}$ and $> 2^{64}$.

---

## 2. High-Severity Correctness & Numerical Bugs

### TASK-2.1: Fix Symbolic Simplification Unsoundness Under `Assumptions.none` and Indeterminate `Infinity` Forms

- **Severity**: High
- **Target Files**:
  - `lib/src/symbolic/algebra/simplify/power.dart`
  - `lib/src/symbolic/algebra/simplify/multiplicative.dart`
  - `lib/src/symbolic/algebra/simplify/additive.dart`
  - `lib/src/symbolic/algebra/simplify/transcendental.dart`
  - `lib/src/symbolic/ast/expr.dart`
- **Problem & Evidence**:
  - **Indeterminate forms simplified to `0`**:
    - `Expr.parse('0 * infinity').simplify()` returns `0` instead of `Constant.undefined` because `simplifyMul` short-circuits to `0` on `IntegerNumber.zero` without checking for `Constant.infinity` or `Constant.undefined` factors.
    - `Expr.parse('infinity - infinity').simplify()` returns `0` because `TermAccumulator` cancels `+1 * infinity` and `-1 * infinity` like an ordinary variable.
  - **Domain-unsound algebraic rewrites**:
    - `Expr.parse('ln(x^2)').simplify(assumptions: Assumptions.real)` returns `2 * ln(x)` (undefined for $x < 0$; must be `2 * ln(abs(x))` for `real` and `2 * ln(x)` only for `positive`).
    - `Expr.parse('asin(sin(x))').simplify()`, `atan(tan(x)).simplify()`, and `acos(cos(x)).simplify()` unconditionally return `x` for all $x$, which is false outside the principal branch (e.g. $\arcsin(\sin(\pi)) = 0 \ne \pi$).
    - `Expr.parse('sqrt(x) * sqrt(y)').simplify()` (with `Assumptions.none`) collapses to `sqrt(x * y)`, which is false for negative/complex numbers ($\sqrt{-1}\sqrt{-1} = -1 \ne \sqrt{(-1)(-1)} = 1$).
    - `Expr.parse('(x^2)^(1/2)').simplify()` under `Assumptions.none` (where `defaultDomain` is `VariableDomain.unknown`) simplifies to `abs(x)`, which fails for complex $x = i$ ($\sqrt{i^2} = i \ne |i| = 1$).
    - `Expr.parse('ln(-1)').simplify()` throws `ArgumentError: Natural logarithm domain error: non-positive argument` instead of returning $i\pi$ (`Mul([ComplexNumber.i, Constant.pi])`) in a complex-capable CAS, and `ln(0)` / `0^(-1)` throw instead of returning `-Constant.infinity` / `Constant.undefined`.
    - `Expr.isReal` (`lib/src/symbolic/ast/expr.dart` lines 229–256) returns `true` for `Pow(IntegerNumber(-1), FractionNumber.half)` ($\sqrt{-1}$) and `Ln(IntegerNumber(-1))` before simplification because it only checks child `.isReal` without checking negative bases of fractional powers or negative arguments of `Ln`/`Asin`/`Acos`.
- **Actionable Fix & Acceptance Criteria**:
  1. In `simplifyMul` and `TermAccumulator`, check for `Constant.infinity` and `Constant.undefined` before zero-annihilation or additive cancellation: `0 * infinity -> Constant.undefined`, `infinity - infinity -> Constant.undefined`, `infinity + infinity -> Constant.infinity`.
  2. Restrict `sqrt(a) * sqrt(b) -> sqrt(a * b)` and `(a * b)^r -> a^r * b^r` to when at least one factor is known `positive` (or both are positive), and restrict `sqrt(x^2) -> abs(x)` and `abs(x)^2 -> x^2` to `real`/`integer`/`positive` domains (not `unknown`/`complex`).
  3. Simplify `ln(x^even)` to `even * ln(x)` only when `x` is `positive`, and to `even * ln(abs(x))` when `x` is `real`/`integer`.
  4. Remove unconditional `asin(sin(x)) -> x`, `acos(cos(x)) -> x`, `atan(tan(x)) -> x` for arbitrary symbolic `x` (keep `sin(asin(x)) -> x`, `cos(acos(x)) -> x`, `tan(atan(x)) -> x`, and evaluate inverse-of-trig only for numeric constants reduced into the principal branch).
  5. Evaluate `Ln(negative)` to `Ln(abs(x)) + i * pi` and fail-safe `isReal` on `Pow(base, exp)` with non-integer exponent unless `base` is proven non-negative.

### TASK-2.2: Wire Up Unused `exact_constants.dart` & Fix Symbolic Print/Parse Round-Trip Failures

- **Severity**: High
- **Target Files**:
  - `lib/src/symbolic/algebra/exact_constants.dart`
  - `lib/src/symbolic/algebra/simplify/transcendental.dart`
  - `lib/src/symbolic/textualization/string.dart`
  - `lib/src/symbolic/parser.dart`
- **Problem & Evidence**:
  - **Exact trig table never triggers on simplified expressions**: `Expr.parse('sin(pi/6)').simplify()` returns `sin(1/6 * pi)` (unsimplified!) instead of `1/2` because `pi / 6` simplifies to `Mul([FractionNumber(1, 6), Constant.pi])`, whereas `_matchPiMultiple` in `transcendental.dart` only matches `Pow(IntegerNumber, -1)` or `IntegerNumber` factors and misses `FractionNumber`! Similarly, `exp(i * pi).simplify()` returns `exp(i * pi)` instead of `-1`.
  - **Print/parse round-trip failures**:
    - `Pow(Variable('x'), IntegerNumber.negativeOne)` formats as `"1 / x"`, which reparses as `Mul([IntegerNumber.one, Pow(Variable('x'), IntegerNumber.negativeOne)])` (`e == Expr.parse(e.toString())` is `false`!).
    - `Mul([Variable('x'), RationalNumber(1, 2)])` formats as `"x * 1/2"`, which reparses as `Mul([Mul([Variable('x'), IntegerNumber.one]), Pow(IntegerNumber.two, IntegerNumber.negativeOne)])` (`eq == false`).
    - `Expr.parse('sum(i^2, i, 1, n)')` throws `FormatException: sum second argument must be a variable identifier, got: i` because the parser converts `i` to `ComplexNumber.i` before checking the summation index argument.
- **Actionable Fix & Acceptance Criteria**:
  1. In `transcendental.dart`, update `_matchPiMultiple` to match `FractionNumber(num, den) * Constant.pi` and handle Euler's identity `exp(i * k * pi)` in `power.dart`.
  2. In `parser.dart`, simplify `1 / rhs` directly to `Pow(rhs, IntegerNumber.negativeOne)` when the numerator is `IntegerNumber.one`, parenthesize `FractionNumber` when multiplied on the right in `string.dart` (or give `/` tighter rational binding), and allow `i` (or `e`) as bound variable identifiers in `sum(...)`, `product(...)`, `diff(...)`, `integrate(...)`, and `limit(...)`.
  3. Add property tests verifying `Expr.parse(e.toString()) == e` across all AST node shapes.

### TASK-2.3: Fix Special Functions (`gamma`, `gammap`, `gammapInv`, `combination`, `erf`) Bugs & Precision Limits

- **Severity**: High
- **Target Files**:
  - `lib/src/special/gamma.dart`
  - `lib/src/special/erf.dart`
- **Problem & Evidence**:
  - **`gammap` vs `gammapInv` contract contradiction**: `gammap(a, x)` (`lib/src/special/gamma.dart:90`) computes `lowRegGamma(a, x) * gamma(a)` (the *unregularized* lower incomplete gamma $\gamma(a, x)$), whereas `gammapInv(p, a)` inverts `lowRegGamma(a, x)` (the *regularized* lower incomplete gamma $P(a, x)$)! Thus `gammapInv(gammap(2, 1.5), 2)` does NOT return `1.5`. Standard convention (Numerical Recipes / SciPy `gammainc`) defines `gammap` as regularized $P(a, x)$.
  - **`gammapInv(1.0, a)` returns finite number instead of `double.infinity`**: `gammapInv(1.0, 2.0)` returns `143.4213562373095` (`math.max(100, a + 100 * sqrt(a))`) instead of `double.infinity`, breaking `ChiSquaredDistribution.inverseCumulativeProbability(1.0)` and `GammaDistribution.inverseCumulativeProbability(1.0)`.
  - **`gamma(double.infinity)` and `lowRegGamma(a, double.infinity)` return `NaN`**: `gamma(double.infinity)` returns `NaN` (should be `double.infinity`), and `lowRegGamma(2.0, double.infinity)` returns `NaN` (should be `1.0`).
  - **`combination(n, k)` and `permutation(n, k)` return `NaN` for $n > 170$**: `combination(200, 2)` computes `factorial(200) / (factorial(2) * factorial(198)) = Infinity / Infinity = NaN` instead of `19900.0`! Even for small $n$, `combination(5, 2)` uses `gamma` and suffers floating-point drift instead of exact multiplicative loop or `exp(combinationLn(n, k)).roundToDouble()`.
  - **`erf` / `erfc` accuracy capped at $\approx 1.2 \times 10^{-7}$**: `lib/src/special/erf.dart` uses the 10-term Numerical Recipes Chebyshev approximation with max error $1.2 \times 10^{-7}$, limiting `NormalDistribution.cumulativeProbability(1.96)` to `0.9750021070...` (wrong in the 8th digit vs exact `0.9750021048517795`) and `NormalDistribution.cumulativeProbability(-10)` underflows to `0.0` because `normal.dart` computes `0.5 * (1 + erf(z / sqrt2))` instead of `0.5 * erfc(-z / sqrt2)`.
- **Actionable Fix & Acceptance Criteria**:
  1. Replace `erf` / `erfc` with Cody's rational Chebyshev approximation (accurate to $10^{-16}$ across all double regimes) and use `0.5 * erfc(-z / sqrt2)` in `NormalDistribution.cumulativeProbability` and `survival`.
  2. Make `gammap(a, x)` an alias for (or replace `lowRegGamma` with) the regularized lower incomplete gamma $P(a, x)$, add regularized upper incomplete gamma `gammaq(a, x)` ($Q(a, x)$) so `ChiSquaredDistribution.survival` and `GammaDistribution.survival` avoid `1 - P(a, x)` catastrophic cancellation in the right tail, and return `double.infinity` from `gammapInv(1.0, a)`.
  3. Handle `x == double.infinity` in `gamma`, `gammaLn`, `lowRegGamma`, and `gammaq`.
  4. Compute `combination(n, k)` and `permutation(n, k)` via exact multiplicative accumulation for moderate integer $k$ and `exp(combinationLn(n, k))` for large arguments so `combination(200, 2) == 19900.0`.

### TASK-2.4: Fix `Blas` & `Lapack` Native/Dart Behavioral Divergences (`cblasConjTrans`, `dpotrf` In-Place Corruption, `dnrm2` Overflow)

- **Severity**: High
- **Target Files**:
  - `lib/src/acceleration/blas/blas_dart.dart`
  - `lib/src/acceleration/lapack/lapack.dart`
  - `lib/src/acceleration/lapack/lapack_native.dart`
  - `lib/src/acceleration/fft/fft_native.dart`
- **Problem & Evidence**:
  - **`cblasConjTrans` bug in `blas_dart.dart`**: For real matrices, `cblasConjTrans` (113) is mathematically identical to `cblasTrans` (112). In `blas_dart.dart`:
    - `dgemv` / `sgemv` throw `ArgumentError('Invalid trans: 113')` while native Accelerate succeeds and returns `[5.0, 7.0, 9.0]`.
    - `dgemm` / `sgemm` check `transA == cblasTrans` and treat `cblasConjTrans` as `cblasNoTrans`! Probe confirmed: `Blas.dgemm(transA: cblasConjTrans, ...)` produces `[7, 15, 10, 22]` in `dart` mode vs `[10, 14, 14, 20]` in `accelerated` mode.
  - **Negative increments (`incX < 0`) in `blas_dart.dart`**: CBLAS defines negative `incX` as starting at `(1 - n) * incX` relative to `xOffset`, whereas `blas_dart.dart` starts at `xOffset` and steps by `incX`, throwing `RangeError: -1` on the second element while native `ddot`/`daxpy` succeed.
  - **`dnrm2` / `snrm2` overflow/underflow in `blas_dart.dart`**: Naive `sum += xi * xi` overflows to `Infinity` for `1e200` and underflows to `0.0` for `1e-200`, whereas native CBLAS uses Blue's scaling algorithm and returns `1.414213562373095e+200` / `1.414213562373095e-200`.
  - **`Lapack.dpotrf` and `Lapack.dgels` in-place mutation before `auto` fallback**: When `Lapack.dpotrf` is called in `auto` mode on a non-SPD matrix like `[[4, 6], [6, 5]]`, `LapackNative.dpotrf` partially overwrites `a` in-place (`[2.0, 3.0, 6.0, 5.0]`) and returns `false`; `Dispatcher.callWithFallback` treats `false` as "native unavailable" and runs `LapackDart.dpotrf` on the **already-corrupted** array `a`!
  - **Apple Accelerate `vDSP_DFT_Interleaved_CreateSetupD` direction constant**: `lib/src/acceleration/fft/fft_native.dart` passes `direction = inverse ? 2 : 1` with `@ffi.Uint32() int direction`, whereas `<Accelerate/vDSP.h>` defines `enum vDSP_DFT_Direction { vDSP_DFT_FORWARD = +1, vDSP_DFT_INVERSE = -1 }` (signed `int32`). Passing `2` relies on undocumented internal `direction == 1 ? +1 : -1` branching in vDSP.
- **Actionable Fix & Acceptance Criteria**:
  1. In `blas_dart.dart`, treat `trans == cblasTrans || trans == cblasConjTrans` as transposed in `dgemv`, `sgemv`, `dgemm`, `sgemm`, `dtrmm`, `dsyrk`, `ssyrk`.
  2. Support negative increments in `blas_dart.dart` using `final startX = xOffset + (incX < 0 ? (1 - n) * incX : 0);` and implement scaled sum-of-squares in `dnrm2`/`snrm2`.
  3. In `Lapack`, distinguish between "native symbol unavailable" (should fall back to Dart in `auto` mode) and "matrix is singular / not positive definite (`info > 0`)" (must return `false` immediately without re-running Dart on the partially mutated buffer).
  4. In `fft_native.dart`, change the `vDSP_DFT_Interleaved_CreateSetupD` FFI signature for `direction` to `@ffi.Int32()` and pass `-1` (`vDSP_DFT_INVERSE`) for inverse transforms.

### TASK-2.5: Fix `Matrix.applyTranspose` Computing Conjugate Transpose $A^H x$ Instead of $A^T x$ for Complex Matrices

- **Severity**: High
- **Target Files**:
  - `lib/src/linear/matrix.dart`
- **Problem & Evidence**:
  - In `Matrix.applyTranspose` (`lib/src/linear/matrix.dart`), the generic loop applies `field.conjugate(getUnchecked(i, j))`, computing $A^H x$ (Hermitian conjugate transpose) instead of $A^T x$.
  - Probe confirmed: for $A = \begin{bmatrix} 1+2i & 3+4i \\ 5+6i & 7+8i \end{bmatrix}$ and $v = [1, i]^T$, `m.applyTranspose(v)` returns `[7+3i, 11+3i]` ($A^H v$) whereas `m.transposed.apply(v)` returns `[-5+7i, -5+11i]` ($A^T v$).
- **Actionable Fix & Acceptance Criteria**:
  1. Remove `field.conjugate` from `Matrix.applyTranspose` so `m.applyTranspose(v)` always equals `m.transposed.apply(v)`.
  2. If Hermitian adjoint multiplication is desired, provide `applyConjugateTranspose(v)` (or `conjugateTransposed.apply(v)`).

### TASK-2.6: Fix Numerical Optimization, Root-Finding, Integration, and ODE Solver Silent Failure & Convergence Bugs

- **Severity**: High
- **Target Files**:
  - `lib/src/numeric/optimization.dart`
  - `lib/src/numeric/optimization/brent.dart`
  - `lib/src/numeric/optimization/nelder_mead.dart`
  - `lib/src/numeric/optimization/constrained.dart`
  - `lib/src/numeric/root_finding/solve_system.dart`
  - `lib/src/numeric/integration.dart`
  - `lib/src/numeric/ode/solve_ode.dart`
- **Problem & Evidence**:
  - **`brent` and `nelderMead` hardcode `converged: true`**: Even when `maxIterations: 1` is exhausted far from the minimum, `minimize(..., method: OptimizationMethod.nelderMead, maxIterations: 1)` and `OptimizationMethod.brent` return `OptimizationResult(converged: true, ...)`!
  - **`minimize` with `bounds` or `constraints` silently ignores `method`**: Passing `bounds: [...]` and `method: OptimizationMethod.nelderMead` silently overrides the method and runs penalty-BFGS in `constrained.dart`.
  - **`solveSystem` silently succeeds on `NaN` residuals**: In `lib/src/numeric/root_finding/solve_system.dart`, `if (val > maxRes) maxRes = val;` evaluates to `false` when `val` is `NaN`, leaving `maxRes == 0.0 < tolerance` and returning the initial guess immediately as if it converged!
  - **`integrate` with `poles` fails with `IntegrateError` on integrable singularities**: `integrate((x) => 1.0 / sqrt(x.abs()), -1.0, 1.0, poles: [0.0])` throws `IntegrateError: IntegrateWarning.depthTooShallow near x = -4.57e-8` instead of converging to `4.0`, because adaptive Gauss-Kronrod uses a pure absolute tolerance and fixed `1e-12` pole offset without IMT/tanh-sinh endpoint transformation or relative error scaling.
  - **`solveOde` (`rk45`) lacks convergence status and `rk4` ignores `maxSteps`**: `solveOde` with `OdeMethod.rk45` silently truncates integration at `t < tEnd` when `maxSteps` is reached without setting a `converged`/`completed` flag on `OdeSolution` or throwing, while `OdeMethod.rk4` ignores `maxSteps` completely (and infinite-loops if `stepSize <= 0`).
- **Actionable Fix & Acceptance Criteria**:
  1. Track whether the stopping tolerance was actually met in `brent.dart` and `nelder_mead.dart` and set `converged: false` when the loop exits via `iter >= maxIterations`.
  2. In `solve_system.dart`, check `if (val.isNaN) throw StateError('Function evaluation returned NaN');`.
  3. In `integration.dart`, combine absolute and relative tolerance (`math.max(tolerance / numSubIntervals, relativeTolerance * i2.abs())`) and apply quadratic/tanh-sinh coordinate transformation on intervals adjacent to declared `poles` so integrable algebraic singularities like $x^{-1/2}$ converge cleanly.
  4. In `solve_ode.dart`, validate `stepSize > 0`, enforce `maxSteps` in `rk4`, and add `final bool converged` (or throw `StateError` on step exhaustion) to `OdeSolution`.

### TASK-2.7: Fix Statistics Distribution Quantiles, LogNormal Lower Bound & Hypothesis Test Bugs (`InvalidProbability.check(NaN)`, `LogNormal` Lower Bound, Discrete Quantiles, `ANOVA`, `KS`)

- **Severity**: High
- **Target Files**:
  - `lib/src/stats/distributions/errors.dart`
  - `lib/src/stats/distributions/discrete.dart`
  - `lib/src/stats/distributions/discrete/uniform.dart`
  - `lib/src/stats/distributions/discrete/poisson.dart`
  - `lib/src/stats/distributions/discrete/negative_binomial.dart`
  - `lib/src/stats/distributions/continuous/log_normal.dart`
  - `lib/src/stats/hypothesis/anova.dart`
  - `lib/src/stats/hypothesis/t_test.dart`
  - `lib/src/stats/hypothesis/kolmogorov_smirnov.dart`
  - `test/stats/distributions/continuous_test.dart`
  - `test/stats/distributions/discrete_test.dart`
- **Problem & Evidence**:
  - **`LogNormalDistribution.lowerBound` is `double.minPositive` (`5e-324`) instead of `double.negativeInfinity`**:
    - `lib/src/stats/distributions/continuous/log_normal.dart` (line 30) overrides `double get lowerBound => double.minPositive;`, whereas `LogNormalDistribution` should have a `lowerBound` of `double.negativeInfinity` (matching the default in `ContinuousDistribution`).
  - **`InvalidProbability.check(double.nan)` does not throw**: `if (probability < 0.0 || probability > 1.0)` evaluates to `false` when `probability` is `NaN`, allowing `NaN` into every `inverseCumulativeProbability` implementation (which in `DiscreteDistribution.inverseCumulativeProbability` causes an infinite `while (p > sum)` loop up to `upperBound`!).
  - **`UniformDiscreteDistribution(a, b).inverseCumulativeProbability(p)` off-by-one at exact quantiles**: `UniformDiscreteDistribution(0, 1).inverseCumulativeProbability(0.5)` returns `1` instead of `0` because it uses `a + ((b - a + 1) * probability).floor()` instead of `a + ((b - a + 1) * probability).ceil() - 1` (the smallest $k$ with $F(k) \ge p$).
  - **`PoissonDistribution` & `DiscreteDistribution` quantile hang for large $\lambda$ or $p \approx 1$**: `DiscreteDistribution.inverseCumulativeProbability` sums `probability(k)` linearly from `0` to `upperBound` (`DataType.integer.safeMax` = $2 \times 10^9$). When floating-point rounding causes $\sum_{k} P(X=k)$ to saturate at $1.0 - 10^{-16} < p$, the loop runs $2 \times 10^9$ iterations and hangs!
  - **`oneWayAnova` returns `F = 0, p = 1` when within-group variance is 0 and group means differ**: `final fStat = msw > 0.0 ? msb / msw : 0.0;` returns `statistic: 0.0, pValue: 1.0` for `[[1, 1], [2, 2]]` instead of `statistic: double.infinity, pValue: 0.0`. Same bug in `tTestOneSample` / `tTestTwoSample` when sample variance is `0` and $\bar{x} \ne \mu_0$.
  - **`kolmogorovSmirnovTest` discrete distribution crash & tail clamp**: `distribution.cumulativeProbability(list[i])` passes a `double` to `Distribution<num>.cumulativeProbability`, which throws a runtime `TypeError` when `distribution` is a `DiscreteDistribution` (expects `int`). Also `_kolmogorovPValue` hard-clamps `if (lambda >= 3.0) return 0.0;` even though $2 e^{-2 \cdot 3^2} \approx 3 \times 10^{-8}$ is representable in IEEE 754 `double`.
- **Actionable Fix & Acceptance Criteria**:
  1. In `lib/src/stats/distributions/continuous/log_normal.dart` (line 30), change `lowerBound` from `double.minPositive` to `double.negativeInfinity` (or remove the override so it inherits `double.negativeInfinity` from `ContinuousDistribution`), and update `test/stats/distributions/continuous_test.dart` (line 610) to check `check(dist.lowerBound).equals(double.negativeInfinity)`.
  2. Change `InvalidProbability.check` to `if (!(probability >= 0.0 && probability <= 1.0))` so `NaN` throws `InvalidProbability`.
  3. Fix `UniformDiscreteDistribution.inverseCumulativeProbability` to return `probability == 0 ? a : (a + ((b - a + 1) * probability).ceil() - 1).clamp(a, b)`.
  4. Implement Cornelis-normal initial guess + bracketed binary search using `cumulativeProbability(k)` in `DiscreteDistribution.inverseCumulativeProbability` (and use `ibeta` for `BinomialDistribution.cumulativeProbability` and `NegativeBinomialDistribution.cumulativeProbability` instead of $O(k)$ summation).
  5. Fix zero-variance edge cases in `oneWayAnova` and `tTest*`: if `msw == 0` (or `se == 0`), return `statistic: diff == 0 ? 0.0 : double.infinity` and `pValue: diff == 0 ? 1.0 : 0.0`.
  6. In `kolmogorovSmirnovTest`, pass `distribution is DiscreteDistribution ? list[i].floor() : list[i]` and replace the `lambda >= 3.0` cutoff with `lambda >= 6.5` (where $2 e^{-2\lambda^2} < 10^{-36}$).

### TASK-2.8: Fix `DataType` Promotion Bugs, `NullableDataType` Delegation, `Equality.isClose(..., 0)`, and `Dense`/`Compressed` Polynomial Hash Contract

- **Severity**: High
- **Target Files**:
  - `lib/src/type/data_type.dart`
  - `lib/src/type/types/nullable.dart`
  - `lib/src/type/types/integer.dart`
  - `lib/src/type/types/bigint.dart`
  - `lib/src/type/types/string.dart`
  - `lib/src/polynomial/impl/dense_polynomial.dart`
  - `lib/src/polynomial/impl/compressed_polynomial.dart`
- **Problem & Evidence**:
  - **Lossy integer type promotions**: `DataType.uint8.promoteWith(DataType.int8)` returns `DataType.int8` (truncating `128..255`!) instead of `DataType.int16`. Similarly `DataType.uint16.promoteWith(DataType.int16)` returns `DataType.int16` (should be `DataType.int32`), and `DataType.uint32.promoteWith(DataType.int32)` returns `DataType.int32` (should be `DataType.int64`).
  - **`DataType.fromType<num>()` crashes with `TypeError`**: `DataType.fromType<num>()` is missing a `num` branch and falls through to `ObjectDataType<T>(null as T)`, throwing `TypeError: type 'Null' is not a subtype of type 'num' in type cast`.
  - **`NullableDataType` does not delegate metadata getters**: `DataType.int32.nullable.isInteger` and `DataType.float64.nullable.isNumeric` return `false`!
  - **`equality.isClose(a, a, 0)` returns `false`**: `Int32DataType`, `BigIntDataType`, and `StringDataType` implement `isClose(a, b, epsilon)` with strict `< epsilon` instead of `<= epsilon`, so `DataType.int32.equality.isClose(5, 5, 0)` and `DataType.string.equality.isClose('a', 'a', 0)` return `false`!
  - **Broken `operator ==` / `hashCode` contract between `DensePolynomial` and `CompressedPolynomial`**:
    - `final d = Polynomial<double>.fromCoefficients([1.0, 0.0, 2.0]);`
    - `final c = CompressedPolynomial<double>.fromMap({0: 1.0, 2: 2.0});`
    - `d == c` is `true`, `c == d` is `true`, but `d.hashCode == c.hashCode` is `false`! `DensePolynomial.hashCode` hashes all coefficients from `0..degree` whereas `CompressedPolynomial.hashCode` hashes `(exponents, values)`.
  - **`CompressedPolynomial.divide` overwrites quotient terms**: In `lib/src/polynomial/impl/compressed_polynomial.dart` line 326, `qTerms[qExp] = factor;` overwrites instead of accumulating with `field.add` when floating-point rounding or integer division fails to annihilate the leading term in one step, and can loop indefinitely on `CompressedPolynomial<int>` when `field.div` truncates to `0`.
- **Actionable Fix & Acceptance Criteria**:
  1. Fix `DataType.promoteWith` so signed $N$-bit + unsigned $N$-bit promotes to signed $2N$-bit (`int16`, `int32`, `int64`, `bigInt`).
  2. Handle `T == num` in `DataType.fromType<T>()` (returning `DataType.numeric`), delegate `isNumeric`, `isInteger`, `isFloat`, `isSigned`, `bits` in `NullableDataType` to `delegate`, and change `< epsilon` to `<= epsilon` in all `Equality.isClose` implementations.
  3. Unify `Polynomial.hashCode` in the base `Polynomial<T>` class (e.g., hashing `Object.hashAll` over canonical `(exponent, coefficient)` pairs of non-zero terms) so equal `DensePolynomial` and `CompressedPolynomial` instances always produce identical `hashCode`s.
  4. In `CompressedPolynomial.divide`, explicitly strip the eliminated leading term from the remainder at each step and guard against zero quotient factors in integer rings.

### TASK-2.9: Fix `Layout` Immutability Breach, Unvalidated `transpose` Permutations, and `0`-Extent Broadcast Bug

- **Severity**: High
- **Target Files**:
  - `lib/src/tensor/layout.dart`
- **Problem & Evidence**:
  - **Mutable `shape` and `strides` lists**: `Layout.shape` and `Layout.strides` return the internal `Int32List` directly. Executing `layout.shape[0] = 999` mutates the layout in-place while `layout.length` remains `6`!
  - **Invalid `transpose` axes accepted**: `Layout(shape: [2, 3]).transpose([0, 0])` silently returns a corrupted layout with shape `[2, 2]` instead of throwing `ArgumentError` for duplicate/out-of-range axes.
  - **Zero-dimension broadcast bug**: `Layout(shape: [0]).broadcast(Layout(shape: [1]))` broadcasts dimension `0` with `1` to `math.max(0, 1) = 1` (producing a length-1 layout reading out of bounds on a 0-length buffer!) instead of `0` as required by NumPy/Array-API broadcasting rules (where an axis of size `1` stretches to match the other axis's size `0`).
- **Actionable Fix & Acceptance Criteria**:
  1. Wrap `shape` and `strides` in `UnmodifiableInt32ListView` (or `List.unmodifiable`).
  2. In `Layout.transpose`, validate that `axes` is a valid permutation of `0 .. rank - 1` (no duplicates, all in range).
  3. In `Layout.broadcast`, when one dimension is `1` and the other is `d` (including `d == 0`), the resulting dimension must be `d` (`0`), with stride `0` on the size-`1` operand.

---

## 3. Architectural & Charter Compliance Fixes

### TASK-3.1: Decouple `package:data/numeric.dart` from `package:data/symbolic.dart`

- **Severity**: High
- **Target Files**:
  - `lib/src/numeric/curve_fit.dart`
  - `lib/src/polynomial/polynomial.dart`
  - `lib/src/symbolic/algebra/polynomial_conversion.dart` (or `lib/src/symbolic/calculus/series.dart`)
- **Problem & Evidence**:
  - `AGENTS.md` strictly mandates: *"The `numeric` subsystem is a foundational mathematical layer that must have zero knowledge of or dependencies on `symbolic`."*
  - Currently, `lib/src/numeric/curve_fit.dart` imports `../../polynomial.dart` (`for polynomialRegression`), and `lib/src/polynomial/polynomial.dart` imports `../../symbolic.dart` (for `Polynomial.fromExpr`). Consequently, importing `package:data/numeric.dart` transitively pulls in the entire 21,000-line `symbolic` CAS and `petitparser`!
- **Actionable Fix & Acceptance Criteria**:
  1. Remove `import '../../symbolic.dart';` and `Polynomial.fromExpr` from `lib/src/polynomial/polynomial.dart`.
  2. Move symbolic-to-polynomial conversion into `lib/src/symbolic/` as an extension method `Expr.toPolynomial(String variable, {num point = 0, int order = 5})` (and/or `extension SymbolicPolynomialFactory on Polynomial` in `symbolic`).
  3. Add an architectural test asserting that transitive imports of `lib/numeric.dart`, `lib/linear.dart`, `lib/tensor.dart`, `lib/stats.dart`, `lib/special.dart`, and `lib/polynomial.dart` never import any file under `lib/src/symbolic/` or `lib/symbolic.dart`.
- **Implementation Report**:
  - `Polynomial.fromExpr` removed from polynomial subsystem and converted to `Expr.toPolynomial` and `SymbolicPolynomialFactory` in `lib/src/symbolic/calculus/series.dart`.
  - Clarified architectural rule: `package:petitparser` can be used anywhere in the codebase for any parsing-related concern; only the `symbolic` CAS subsystem is decoupled from foundational math layers.
  - Implemented the architectural boundary test suite in `test/architecture/dependency_decoupling_test.dart` using `package:more/graph.dart` rather than custom graph traversal code.

### TASK-3.2: Eliminate Positional Record Accessors (`.$1`, `.$2`), Named Record Gaps, and Intermediate Internal Barrel Files

- **Severity**: Medium
- **Target Files**:
  - `lib/src/stats/hypothesis/hypothesis_test_result.dart`
  - `lib/src/stats/resampling/bootstrap.dart`
  - `lib/src/stats/resampling/jackknife.dart`
  - `lib/src/polynomial/impl/compressed_polynomial.dart`
  - `lib/src/tensor/layout.dart`
  - `web/calculator/src/ui/soft_keys.dart`
  - `benchmark/runner.dart`
  - `lib/src/symbolic/ast.dart`
  - `lib/src/symbolic/algebra/simplify.dart`
- **Problem & Evidence**:
  - `AGENTS.md` states: *"Never use positional record field accessors (`.$1`, `.$2`, etc.). Prefer named record fields (or `typedef`s with named fields)."* and *"Intermediate internal barrel files inside `lib/src/` are prohibited; root `lib/<subsystem>.dart` files must export public declarations directly."*
  - `web/calculator/src/ui/soft_keys.dart:173–175` and `benchmark/runner.dart:52–55` use `. $1` / `.$2` directly.
  - Public APIs still return unnamed positional records:
    - `HypothesisTestResult.confidenceInterval` is `(double, double)?` (forcing `benchmark/runner.dart` to use `?.$1` and `?.$2`) instead of `({double lower, double upper})?`.
    - `BootstrapResult` / `JackknifeResult` confidence intervals use positional `(double, double)`.
    - `CompressedPolynomial.nonZeroTerms` yields `Iterable<(int, T)>` instead of `Iterable<({int exponent, T coefficient})>`.
    - `Layout.broadcast(Layout other)` returns `(Layout, Layout)` instead of `({Layout first, Layout second})` or `({Layout self, Layout other})`.
  - Intermediate barrel files exist in `lib/src/`: `lib/src/symbolic/ast.dart` (re-exporting `ast/*.dart` and `number/*.dart`), `lib/src/symbolic/algebra/simplify.dart` (re-exporting `simplify/*.dart`), `lib/src/dataframe/series.dart` (re-exporting `arrow_string_series.dart`), and `lib/src/acceleration/blas/blas.dart` (re-exporting `cblas_constants.dart`).
- **Actionable Fix & Acceptance Criteria**:
  1. Convert `confidenceInterval`, `nonZeroTerms`, `Layout.broadcast`, and `soft_keys.dart` tuples to named records (`({double lower, double upper})`, `({int exponent, T coefficient})`, etc.).
  2. Export leaf files directly from `lib/symbolic.dart`, `lib/dataframe.dart`, and `lib/acceleration.dart`, and remove intermediate `export` directives inside `lib/src/` (keeping only conditional FFI/stub exports).

### TASK-3.3: Remove Redundant Duplicate APIs and Unexported / Leaked Internal Symbols

- **Severity**: Medium
- **Target Files**:
  - `lib/src/dataframe/dataframe.dart`
  - `lib/src/dataframe/csv/csv_reader.dart`, `lib/src/dataframe/csv/csv_stream.dart`, `lib/src/dataframe/csv/csv_writer.dart`
  - `lib/src/dataframe/json/json_decoder.dart`, `lib/src/dataframe/json/json_encoder.dart`
  - `lib/src/dataframe/join.dart`
  - `lib/src/linear/matrix.dart`, `lib/src/linear/vector.dart`, `lib/src/linear/float64_vector.dart`
  - `lib/src/tensor/operations/contraction.dart`
  - `lib/src/numeric/sampling.dart`
  - `lib/src/polynomial/polynomial.dart`, `lib/src/polynomial/orthogonal.dart`
  - `lib/src/type/models/field.dart`, `lib/src/type/types/string.dart`, `lib/src/type/types/dynamic.dart`
- **Problem & Evidence**:
  - `AGENTS.md` states: *"Provide a single canonical way to perform an operation; avoid redundant convenience aliases, parameter aliases, or duplicate invocation styles."*
  - **Duplicate invocation pathways**:
    - `DataFrame`: `DataFrame.fromCsv` vs `CsvReader.parse`; `df.toCsv()` vs `CsvWriter.write(df)`; `CsvReader.parseStream` vs `CsvStream.readStream`; `DataFrame.fromJson` vs `JsonDecoder.decode`; `df.toJson()` vs `JsonEncoder.encode(df)`; `DataFrame.fromArrowIpc` vs `ArrowIpc.decode`; `df.toArrowIpc()` vs `ArrowIpc.encode(df)`; `df.sortMergeJoin(...)` vs `df.join(..., method: JoinMethod.sortMerge)`.
    - `Matrix`: `m.transpose()` vs `m.transposed`; `Float64Vector.norm2()` vs `v.norm(2)`.
    - `Vector` / `numeric`: `Vector.linspace` / `logspace` / `geomspace` vs top-level `linearSpaced` / `logarithmicSpaced` / `geometricSpaced` (and `linearSpaced` is exported from both `lib/linear.dart` and `lib/numeric.dart`).
    - `Tensor`: `a.innerProduct(b)` / `a.outerProduct(b)` extension methods vs top-level `innerProduct(a, b)` / `outerProduct(a, b)`; `tensordot` `axes` parameter typed as `Object` accepting 4 different shapes (`int`, `List<int>`, `(List<int>, List<int>)`, `List<List<int>>`).
    - `Polynomial`: `p.differentiate()` vs `p.derivative()`; `Polynomial.chebyshevT` / `chebyshevU` / `legendreP` / `hermiteH` / `hermiteHe` / `laguerreL` vs `OrthogonalPolynomials.*` and top-level `laguerreL`.
    - `solveOde`: accepts both `stepSize` and `initialStep` for the same quantity.
  - **Leaked internal helpers & unexported return types**:
    - `lib/type.dart` publicly exports `unsupportedOperation()` (from `field.dart`) and `editDistance()` (from `string.dart`), while `DataType.dynamicType` returns `DynamicDataType` which is not exported in `lib/type.dart`!
    - `lib/stats.dart` publicly exports `JackknifeResampling` alongside `Jackknife`.
    - `lib/polynomial.dart` publicly exports `OrthogonalPolynomials.computeRoots` (internal companion-matrix solver).
    - `lib/symbolic.dart` publicly exports internal `SymbolicParser` PetitParser token builders (`identifier`, `number`, etc.) and `IteratedExpr.equalsIterated`.
- **Actionable Fix & Acceptance Criteria**:
  1. Consolidate each duplicate pair to a single canonical API (e.g., keep `DataFrame.fromCsv` / `toCsv`, `fromJson` / `toJson`, `fromArrowIpc` / `toArrowIpc`, `df.join(..., method: ...)`; keep `Matrix.transposed`; keep `Polynomial.derivative()`; keep `linearSpaced`/`logarithmicSpaced`/`geometricSpaced`; unify `solveOde` on `stepSize`).
  2. Hide internal helpers (`_unsupportedOperation`, `_editDistance`, `_computeRoots`, `_equalsIterated`) and export `DynamicDataType` from `lib/type.dart`.
- **Implementation Report**:
  - Consolidated duplicate APIs across DataFrame, Matrix, Float64Vector, Vector/numeric sampling, Tensor contractions, and solveOde.
  - Hid internal helpers and exported `DynamicDataType`.
  - Exception to token builder privatization: `ExprSyntax.identifierTokenParser` and `ExprSyntax.numberTokenParser` remain public static parsers on `ExprSyntax` with full doc comments, as `web/calculator/src/language/grammar.dart` directly reuses and composes them for expression grammar rules.

### TASK-3.4: Clean Up `pubspec.yaml`, `.gitignore`, and Package Publishing Hygiene

- **Severity**: Medium
- **Target Files**:
  - `pubspec.yaml`
  - `CHANGELOG.md`
  - `.pubignore` (create)
- **Problem & Evidence**:
  - `pubspec.yaml` contains a git `dependency_overrides` block (`more: git: https://github.com/renggli/dart-more`) which blocks `dart pub publish`, even though the published `more: ^4.7.0` on pub.dev already satisfies all APIs used by `package:data` (confirmed via offline compilation probe).
  - `pubspec.yaml` declares `version: 0.15.0`, whereas `CHANGELOG.md` already has entries for `0.16.0`, `0.15.2`, `0.15.1`, and `0.15.0`.
  - `dart pub publish --dry-run` packages internal agent/development files (`AGENTS.md`, `EVALUATION.md`, `TASKS.md`, `ARCHITECTURE.md`, `doc/calculator_design.md`, `benchmark/`, `test/`, `web/` including untracked `web/distributions/index.dart.js.deps` and `.map`).
- **Actionable Fix & Acceptance Criteria**:
  1. Remove `dependency_overrides` from `pubspec.yaml` and bump `version: 0.16.0` to match `CHANGELOG.md`.
  2. Add a `.pubignore` file excluding `AGENTS.md`, `EVALUATION.md`, `TASKS.md`, `doc/`, `benchmark/`, `test/`, `web/`, and `.agents/`.
  3. Delete untracked build artifacts `web/distributions/index.dart.js.deps` and `web/distributions/index.dart.js.map`.
- **Implementation Report**:
  - Bumped version to `0.16.0` in `pubspec.yaml` matching `CHANGELOG.md`.
  - Added `.pubignore` excluding internal agent files, developer documents (`AGENTS.md`, `ARCHITECTURE.md`, `EVALUATION.md`, `TASKS.md`, `.agents/`), and non-package folders (`benchmark/`, `doc/`, `test/`, `web/`).
  - Removed untracked distribution build artifacts.
  - Instruction tweak: Kept `dependency_overrides` for `more` (`git: https://github.com/renggli/dart-more`) because required bug fixes (e.g. `asinh` asymptotic branch handling) in git `dart-more` are still needed until the next version of `dart-more` is released on pub.dev.

---

## 4. Public API Inconsistencies & Design Improvements

### TASK-4.1: Unify Naming, Method Signatures, and UI Label Capitalization Across Subsystems

- **Severity**: Medium
- **Target Files**:
  - `lib/src/tensor/operations/reduction.dart`
  - `lib/src/dataframe/groupby.dart`
  - `lib/src/dataframe/json/json_orient.dart`
  - `lib/src/linear/matrix.dart`, `lib/src/linear/vector.dart`
  - `lib/src/numeric/interpolation/*.dart`
  - `lib/src/stats/distributions/continuous/*.dart`
  - `lib/src/stats/hypothesis/kolmogorov_smirnov.dart`
  - `lib/src/symbolic/algebra/approximate.dart`, `lib/src/symbolic/linear/matrix.dart`
  - `web/distributions/index.html`, `web/distributions/index.dart`
- **Problem & Evidence**:
  - **Uncapitalized labels in the Distributions web application**:
    - In `web/distributions/index.html`, all `.attr-label` elements in the "Mathematical Properties" panel (lines 101–130: `mean`, `median`, `mode`, `variance`, `std deviation`, `skewness`, `kurtosis (exc)`, `bounds`) and the "Random Sampling" panel (lines 158–167: `sample mean`, `sample std dev`, `sample variance`) are lowercase, whereas `web/expressions/index.html` uses capitalized Title Case (`Parsed AST`, `Simplified`, etc.).
    - In `web/distributions/index.dart` (lines 998, 1022), the chart reference line labels `'med'` and `'mode'` are lowercase.
  - **Trailing underscore identifiers**: `Tensor.var_`, `GroupBy.var_`, and `JsonOrient.values_` use ugly trailing underscores (and `GroupBy.var_` generates output column names like `'salary_var_'`). Rename `var_` to `variance` (matching `Series.variance`, `Distribution.variance`, and `stats.variance`) and `JsonOrient.values_` to `JsonOrient.valueMatrix` or `JsonOrient.array`.
  - **Distribution constructor parameter order & naming**:
    - `GammaDistribution(shape, scale)` and `InverseGammaDistribution(shape, scale)` take `(shape, scale)`, whereas `WeibullDistribution(scale, shape)` and `ParetoDistribution(scale, shape)` take `(scale, shape)` (`k, lambda` vs `xo, alpha`)!
    - `CauchyDistribution([this.xo = 0, this.gamma = 1])`, `LaplaceDistribution([this.mu = 0, this.b = 1])`, and `LogisticDistribution([this.mu = 0, this.s = 1])` use cryptic Greek/symbol field names instead of `location` and `scale` (used by `NormalDistribution(mean, standardDeviation)`).
    - `HypergeometricDistribution` uses uppercase field names `N` and `K` (`final int N; final int K;`), violating Effective Dart `lowerCamelCase`.
  - **Hypothesis test naming**: `tTestTwoSample` vs `kolmogorovSmirnov2Sample` (`TwoSample` vs `2Sample`).
  - **Container equality (`==` / `hashCode`)**: `Tensor`, `Matrix`, `Vector`, and `DataFrame` do not override `operator ==` or `hashCode` (using reference identity), which also breaks `MultivariateNormalDistribution ==` and `DirichletDistribution ==` (they compare `mean == other.mean && covariance == other.covariance`, which evaluates to `false` for two distributions constructed with equal `Vector`/`Matrix` values!).
  - **`Interpolator` vs `Interpolator2D` call convention**: `Interpolator` uses `double call(double x)` (no `evaluate`), while `Interpolator2D` defines both `evaluate(double x, double y)` and `call(double x, double y)`, and `LagrangeInterpolation` / `CubicSpline` constructors accept `Iterable<num>` while `BilinearInterpolator` / `BicubicInterpolator` require `Vector<double>` and `Matrix<double>`.
  - **`SymbolicMatrixExtension.approximate` vs `ApproximationExtension.approximate`**: `Expr.approximate([Map<String, Expr> bindings = const {}])` takes `Map<String, Expr>`, whereas `Matrix<Expr>.approximate({Map<String, num> bindings = const {}})` takes named `Map<String, num>` (and `ARCHITECTURE.md` claims `approximate({int precision = 53, Assumptions assumptions = Assumptions.none})`).
- **Actionable Fix & Acceptance Criteria**:
  1. Capitalize all distribution labels in `web/distributions/index.html` (`Mean`, `Median`, `Mode`, `Variance`, `Std Deviation`, `Skewness`, `Kurtosis (Exc)`, `Bounds`, `Sample Mean`, `Sample Std Dev`, `Sample Variance`) and chart reference labels in `web/distributions/index.dart` (`'Med'`, `'Mode'`).
  2. Rename `var_` -> `variance` on `Tensor` and `GroupBy`, `kolmogorovSmirnov2Sample` -> `kolmogorovSmirnovTwoSample`, and `HypergeometricDistribution` fields `N, K, n` -> `populationSize, successStates, draws`.
  3. Standardize `location` / `scale` / `shape` parameter names and order across continuous distributions, and replace debug-only `assert(...)` in distribution constructors with runtime `ArgumentError.value` checks (so invalid parameters like `NormalDistribution(0, -1)` throw in release mode too).
  4. Implement structural `operator ==` and `hashCode` (or `DataType.equality` integration) on `Layout`, `Tensor`, `Matrix`, `Vector`, and `DataFrame` so value classes like `MultivariateNormalDistribution` satisfy value equality.
  5. Standardize `Interpolator` and `Interpolator2D` on `call` (removing duplicate `evaluate`), and unify `Expr.approximate` / `Matrix<Expr>.approximate` signatures.
- **Implementation Report**:
  - Capitalized telemetry and reference line labels in `web/distributions/index.html` and `web/distributions/index.dart`.
  - Renamed `Tensor.var_` to `Tensor.variance`, `Agg.var_` to `Agg.variance` (and output column suffix to `_variance`), `JsonOrient.values_` to `JsonOrient.array`, `kolmogorovSmirnov2Sample` to `kolmogorovSmirnovTwoSample`, and `HypergeometricDistribution` fields to `populationSize, successStates, draws`.
  - Standardized continuous distribution parameters: `WeibullDistribution(shape, scale)` and `ParetoDistribution(shape, scale)` aligned to `(shape, scale)`; Cauchy, Laplace, and Logistic standardized on `location, scale`.
  - Replaced debug assertions across all continuous and discrete distribution constructors with runtime `ArgumentError.value` validation, retaining `const` standard constructors where applicable.
  - Implemented structural value equality and hashing on `Layout`, `Tensor`, `Matrix`, `Vector`, `Series`, and `DataFrame`, verifying `MultivariateNormalDistribution` and `DirichletDistribution` value equality.
  - Standardized `Interpolator2D` on `double call(double x, double y)`, removing duplicate `evaluate`. Verified `Expr.approximate` and `Matrix<Expr>.approximate` alignment.

### TASK-4.2: Improve `Polynomial.toString` and `RationalFunction` Ergonomics

- **Severity**: Medium
- **Target Files**:
  - `lib/src/polynomial/polynomial.dart`
  - `lib/src/polynomial/rational.dart`
- **Problem & Evidence**:
  - `Polynomial.toString()` prints ugly `+ -` sequences such as `"x^2 + -5.0x + 6.0"` (visible in `example/polynomial_demo.dart` output and contradicted by the doc comment on `Polynomial.fromRoots` which claims `// x^2 - 5.0x + 6.0`).
  - `DensePolynomial` does not strip trailing zero coefficients on construction (`Polynomial<double>.fromCoefficients([1.0, 2.0, 0.0, 0.0]).coefficients` has length 4 while `degree` is 1).
  - `RationalFunction(num, den)` does not auto-simplify by `gcd` as claimed in `ARCHITECTURE.md` Section 7.2, and lacks `derivative()`, `evaluateComplex(Complex z)`, and scalar arithmetic operators.
- **Actionable Fix & Acceptance Criteria**:
  1. Format negative coefficients in `Polynomial.toString()` using ` - ` instead of `+ -`.
  2. Strip trailing zero coefficients in `DensePolynomial` (and wrap `coefficients` in an unmodifiable view).
  3. Add `derivative()` and `evaluateComplex(Complex z)` to `RationalFunction`.

---

## 5. Performance & Algorithmic Optimizations

### TASK-5.1: Reduce Numerical `jacobian` from $O(m \cdot n)$ to $O(n)$ Vector Function Evaluations & `curveFit` from $O(N^2 p)$ to $O(N p)$

- **Severity**: High
- **Target Files**:
  - `lib/src/numeric/calculus/jacobian.dart`
  - `lib/src/numeric/calculus/hessian.dart`
  - `lib/src/numeric/curve_fit.dart`
- **Problem & Evidence**:
  - **Numerical `jacobian`**: In `lib/src/numeric/calculus/jacobian.dart`, for each matrix entry `(i, j)` of the $m \times n$ Jacobian, `derivative((double xj) => f(x perturbed)[i], x[j])` is called inside a double loop over `i` and `j`. This evaluates the full vector function $f: \mathbb{R}^n \to \mathbb{R}^m$ **$m$ times per column** ($4 m n$ evaluations for 5-point stencil instead of $4 n$ evaluations!).
  - **`curveFit` Levenberg-Marquardt Jacobian**: `lib/src/numeric/curve_fit.dart` uses `jacobian(residualFn, p)` where `residualFn` evaluates the model at all $N$ data points. Because `jacobian` re-evaluates `residualFn` for every row `i = 0 .. N-1` and parameter `j = 0 .. p-1`, a 1,000-point curve fit with 3 parameters performs **$3{,}000{,}000$ model evaluations per LM iteration instead of $3{,}000$** ($1000\times$ slower)!
  - **Numerical `hessian`**: `lib/src/numeric/calculus/hessian.dart` computes both `(i, j)` and `(j, i)` independently without exploiting Hessian symmetry $H_{ij} = H_{ji}$, doing $2\times$ the necessary off-diagonal function evaluations.
  - **Unscaled finite-difference step `h`**: `derivative`, `gradient`, `jacobian`, `hessian`, and `curveFit` use a fixed absolute step `h = 1e-5` (or `1e-7`) instead of scaling by `math.max(1.0, x.abs()) * h`, losing all precision when $|x| \ge 10^8$.
- **Actionable Fix & Acceptance Criteria**:
  1. Rewrite `jacobian` to perturb coordinate `j` once per stencil offset, evaluate the vector $f(\mathbf{x} + s h \mathbf{e}_j)$ once, and accumulate across all $m$ output rows simultaneously ($O(n)$ vector evaluations).
  2. In `hessian`, compute only the upper triangle $j \ge i$ and mirror $H_{ji} = H_{ij}$.
  3. Scale default finite-difference step sizes by `math.max(1.0, x.abs())`.
  4. In `curve_fit.dart`, evaluate the perturbed parameter vector across the $N$ points directly in $O(N p)$ model calls.

### TASK-5.2: Fix BFGS $O(n^3)$ Matrix Multiply Update to $O(n^2)$ Rank-2 Update & Eliminate Redundant Evaluations

- **Severity**: High
- **Target Files**:
  - `lib/src/numeric/optimization/quasi_newton.dart`
- **Problem & Evidence**:
  - In `lib/src/numeric/optimization/quasi_newton.dart`, BFGS updates the inverse Hessian approximation $H_{k+1} = (I - \rho s y^T) H_k (I - \rho y s^T) + \rho s s^T$ by explicitly constructing two $n \times n$ dense matrices and performing two $O(n^3)$ matrix multiplications instead of computing the vector $w = H_k y$ in $O(n^2)$ and applying the rank-2 update $H_{k+1} = H_k - \rho (s w^T + w s^T) + \rho (1 + \rho (y^T w)) s s^T$ in $O(n^2)$.
  - Furthermore, after backtracking line search already evaluates `f(xNext)`, the main loop immediately calls `f(x)` again on the same point.
- **Actionable Fix & Acceptance Criteria**:
  1. Replace the $O(n^3)$ matrix-matrix product in BFGS with the $O(n^2)$ rank-2 vector update using $w = H y$.
  2. Reuse the function value `fNext` computed at the end of line search instead of re-evaluating `f(x)`.

### TASK-5.3: Fix `MatrixNormExtension` Recomputing Full SVD Twice on `norm2` and Every Call

- **Severity**: Medium
- **Target Files**:
  - `lib/src/linear/decomposition/norm.dart`
- **Problem & Evidence**:
  - `MatrixNormExtension.norm2` (`lib/src/linear/decomposition/norm.dart`) evaluates `svd.singularValues.isEmpty ? 0.0 : svd.singularValues[0]`, where `svd` is a getter that constructs a brand-new `SingularValueDecomposition` on each access—so calling `m.norm2` computes the full SVD **twice**!
- **Actionable Fix & Acceptance Criteria**:
  1. Bind `final s = svd.singularValues;` to a local variable in `norm2`, `cond`, and `rank`.

### TASK-5.4: Dispatch Unaccelerated Operations to `Blas`, `Lapack`, and `Vforce` Facades

- **Severity**: Medium
- **Target Files**:
  - `lib/src/tensor/operations/operation.dart`
  - `lib/src/tensor/operations/reduction.dart`
  - `lib/src/linear/decomposition/lu.dart`
  - `lib/src/linear/decomposition/qr.dart`
  - `lib/src/stats/distributions/multivariate/multivariate_normal.dart`
  - `lib/src/polynomial/impl/dense_polynomial.dart`
- **Problem & Evidence**:
  - `Tensor.sum()` (full reduction with `axis == null` on contiguous `Float64List`) uses a Dart loop instead of `Vforce.sum`.
  - In-place unary operations on a tensor (`a.sin(target: a)`) in `lib/src/tensor/operations/operation.dart` call `_hasHazard(this, target)` which flags `identical(a.data, target.data)` even when layouts are identical (`this.layout == target.layout`), allocating a redundant temporary copy on every in-place unary operation!
  - `MultivariateNormalDistribution` (`lib/src/stats/distributions/multivariate/multivariate_normal.dart`) implements its own private `_cholesky` loop instead of calling `covariance.cholesky` (which uses `Lapack.dpotrf`).
  - `DensePolynomial` (`lib/src/polynomial/impl/dense_polynomial.dart`) imports `FftDart.nextPowerOf2` directly from `lib/src/acceleration/fft/fft_dart.dart` instead of exposing `Fft.nextPowerOf2` on the `Fft` facade. Also, FFT-based multiplication is triggered for `Polynomial<int>` at degree $\ge 64$, introducing floating-point rounding errors into exact integer polynomials with large coefficients.
- **Actionable Fix & Acceptance Criteria**:
  1. Dispatch contiguous `Float64List` full `Tensor.sum()` to `Vforce.sum`.
  2. In `operation.dart`, allow zero-allocation in-place unary execution when `identical(a.data, target.data) && a.layout == target.layout`.
  3. Delegate `MultivariateNormalDistribution` Cholesky factorization to `covariance.cholesky`.
  4. Move `nextPowerOf2` onto the `Fft` facade and restrict FFT polynomial multiplication in `DensePolynomial` to floating-point/complex fields (`DataType.float64`, `DataType.float32`, `DataType.complex`), keeping exact fields (`int`, `BigInt`, `Fraction`) exact.

### TASK-5.5: Eliminate Per-Row Map Allocations & $O(N^2)$ Bottlenecks in `DataFrame` and `DataType.castList`

- **Severity**: Medium
- **Target Files**:
  - `lib/src/dataframe/dataframe.dart`
  - `lib/src/dataframe/arrow_string_series.dart`
  - `lib/src/dataframe/csv/csv_writer.dart`
  - `lib/src/type/data_type.dart`
- **Problem & Evidence**:
  - `DataFrame(columns)` constructor calls `columns.map((c) => c.name).toList()`, `columns.elementAt(i)` inside a loop, and `columns.map(...)` multiple times without materializing `columns` to a `List` first; if a lazy mapped `Iterable<Series>` is passed, every series is constructed 3 times!
  - `ArrowStringSeries.sort` decodes two UTF-8 strings on every comparator call ($O(N \log N)$ UTF-8 allocations) instead of comparing raw UTF-8 bytes lexicographically (which for UTF-8 is identical to code-point order!).
  - `DataType.castList(Iterable<dynamic> elements)` (`lib/src/type/data_type.dart`) calls `elements.length` on every iteration of `for (var i = 0; i < elements.length; i++)`, which is $O(N^2)$ when `elements` is a lazy `WhereIterable`.
- **Actionable Fix & Acceptance Criteria**:
  1. Materialize `final columnList = columns.toList(growable: false);` at the top of `DataFrame(Iterable<Series<dynamic>> columns)`.
  2. Compare raw UTF-8 `Uint8List` slices lexicographically in `ArrowStringSeries.sort`.
  3. Hoist `final list = elements is List ? elements : elements.toList(growable: false);` in `DataType.castList`.

---

## 6. High-Value Missing Features Users Expect

### TASK-6.1: `DataFrame` & `Series` Essential Tabular Operations

- **Severity**: Medium
- **Target Files**:
  - `lib/src/dataframe/dataframe.dart`
  - `lib/src/dataframe/series.dart`
  - `lib/src/dataframe/groupby.dart`
- **Missing Capabilities & Actionable Additions**:
  1. **Null handling**: `df.dropNulls({List<String>? subset})`, `df.fillNull(Object value)` / `series.dropNulls()`, `series.fillNull(T value)`.
  2. **Column & row transformations**: `df.rename(Map<String, String> mapping)`, `df.drop(List<String> columns)`, `df.withColumn(Series column)`, `df.concat(DataFrame other)` (vertical concatenation), `series.map<R>(R Function(T) fn)`, `series.unique()`, `series.valueCounts()`.
  3. **Summary statistics**: `df.describe()` returning a summary `DataFrame` (`count`, `mean`, `std`, `min`, `25%`, `50%`, `75%`, `max`).
  4. **Multi-column sorting & join keys**: Support `df.sortBy(List<String> columns, ...)` and `leftOn` / `rightOn` in `df.join(...)`.
  5. **Per-column `GroupBy.count()`**: Currently `GroupBy.count()` only counts non-nulls in the first non-key column; update it to count non-null values per aggregated column (matching Pandas/Polars).

### TASK-6.2: `numeric` & `stats` Completeness Improvements

- **Severity**: Medium
- **Target Files**:
  - `lib/src/numeric/curve_fit.dart`
  - `lib/src/numeric/ode/solve_ode.dart`
  - `lib/src/numeric/fft.dart`
  - `lib/src/stats/distributions/continuous/*.dart`
  - `lib/src/stats/distributions/discrete/*.dart`
- **Missing Capabilities & Actionable Additions**:
  1. **`CurveFitResult` parameter uncertainty metrics**: Compute and expose `Matrix<double> covariance` ($(J^T J)^{-1} \cdot \text{RSE}^2$) and `Vector<double> standardErrors` on `CurveFitResult` (fulfilling `AGENTS.md`: *"high-level parametric curve fitting with confidence metrics"*).
  2. **Stiff ODE solver & evaluation grid (`tEval`)**: Add an implicit/stiff method (e.g., `OdeMethod.bdf2` or `OdeMethod.radau` / implicit trapezoidal) and an optional `Iterable<double>? tEval` parameter to `solveOde` via dense Hermite interpolation.
  3. **Non-power-of-2 FFT (Bluestein / Chirp-Z)**: Support arbitrary-length signals in `Fft.fft` / `fft` via Bluestein's algorithm instead of throwing on non-power-of-2 lengths, and add `ConvolutionMode { full, same, valid }` to `convolve`.
  4. **Exact distribution medians & `logProbability`**: Implement `median` via `inverseCumulativeProbability(0.5)` in `ContinuousDistribution` (currently `GammaDistribution`, `BetaDistribution`, `FDistribution`, and `InverseGammaDistribution` return `double.nan` for `median`, and `ChiSquaredDistribution.median` uses an inaccurate approximation), and add `logProbability(T x)` to `Distribution<T>`.

### TASK-6.3: `symbolic` CAS Completeness Improvements

- **Severity**: Low
- **Target Files**:
  - `lib/src/symbolic/calculus/integration.dart`
  - `lib/src/symbolic/algebra/factor/univariate.dart`
- **Missing Capabilities & Actionable Additions**:
  1. **Elementary integrals**: Extend `_symbolicIntegrate` to handle standard trig powers and products ($\int \sin^2(x)\,dx$, $\int \cos^2(x)\,dx$, $\int \tan^2(x)\,dx$, $\int \sin(ax)\cos(bx)\,dx$, $\int \sec(x)\,dx$), completing-the-square quadratics ($\int \frac{1}{x^2 + bx + c}\,dx$, $\int \frac{1}{\sqrt{a - x^2}}\,dx$), and general $u' \cdot f(u)$ chain-rule forms like $\int \frac{\ln(x)}{x}\,dx$ and $\int \sinh(x)\cosh(x)\,dx$.
  2. **Integer & cyclotomic factoring**: Complete `IntegerNumber.factor()` for composite `BigInt`s $> 2^{63}$ (e.g. Pollard's rho) and support biquadratic/Sophie Germain polynomial factoring ($x^4 + 4$, $x^4 + x^2 + 1$).

---

## 7. Documentation, Examples & Test Suite Alignment

### TASK-7.1: Sync `ARCHITECTURE.md` and `README.md` with Actual Codebase Paths and Symbols

- **Severity**: Medium
- **Target Files**:
  - `ARCHITECTURE.md`
  - `README.md`
  - `example/README.md`
  - `lib/numeric.dart`
- **Problem & Evidence**:
  - **Non-existent file paths in `ARCHITECTURE.md`**:
    - Line 22: `lib/src/type/buffers/memory.dart` (actual: `lib/src/type/utils/memory.dart`).
    - Line 289: `lib/src/dataframe/json.dart` (actual: `lib/src/dataframe/json/json_encoder.dart`, `json_decoder.dart`, `json_orient.dart`, `json_stream.dart`).
    - Lines 317, 324: `lib/src/acceleration/ffi/` and `lib/src/acceleration/ffi/library_loader_ffi.dart` (actual: `lib/src/acceleration/utils/library_loader_ffi.dart`).
  - **Renames not reflected in `ARCHITECTURE.md`**:
    - Section 6 still references old algorithm-named functions (`brentMinimize`, `nelderMead`, `bfgs`, `lbfgs`, `minimizeConstrained`, `rk4`, `rk45`, `numericalDerivative`, `numericalGradient`, `numericalJacobian`, `numericalHessian`, `levenbergMarquardt`, `ifft`, `ifft2`) that were replaced by solution-oriented APIs (`minimize`, `solveOde`, `derivative`, `gradient`, `jacobian`, `hessian`, `curveFit`, `fitNonlinear`, `fft(..., inverse: true)`).
    - Section 4 claims `BoolSeries` uses bit-packed `ValidityMask` storage for values (actual `BoolSeries` in `lib/src/dataframe/series.dart` stores `final List<bool> data`) and references `df.column<T>(name)` (actual: `df.typedColumn<T>(name)`).
    - Section 6.4 claims `fft` is non-mutating and returns a new buffer (actual `void fft(List<Complex> buffer, {bool inverse = false})` mutates `buffer` in-place).
    - Section 8 claims `Assumptions` has a `parent` field and `copyWith` method (actual `Assumptions` has `assume` and `merge`, no `parent`/`copyWith`).
  - **`README.md` & `example/README.md` inaccuracies**:
    - `README.md` line 40 claims `BiCGSTAB` is implemented in `package:data/linear.dart`, and `example/README.md` claims `example/magic_square.dart` tests `SVD, Cholesky, GMRES, BiCGSTAB, CG` (only `conjugateGradient` and `gmres` exist in `IterativeMethod`, and `magic_square.dart` only runs `lu`, `qr`, `eigen`, and `inverse`).
- **Actionable Fix & Acceptance Criteria**:
  1. Update all stale file paths and function signatures in `ARCHITECTURE.md` to match the current codebase.
  2. Update `README.md` and `example/README.md` (or add BiCGSTAB to `IterativeMethod`).
  3. List `multipleLinearRegression`, `fft2`, and `convolve` in the library doc comment of `lib/numeric.dart`.

### TASK-7.2: Mirror `test/` Directory Hierarchy 1:1 with `lib/src/` and Split Single-Group Test Files

- **Severity**: Medium
- **Target Files**:
  - `test/polynomial/compressed_polynomial_test.dart` -> `test/polynomial/impl/compressed_polynomial_test.dart`
  - `test/polynomial/impl/dense_polynomial_test.dart` (create)
  - `test/tensor/contraction_test.dart`, `einsum_test.dart`, `manipulation_test.dart`, `operation_test.dart` -> `test/tensor/operations/`
  - `test/tensor/layout_test.dart` (create)
  - `test/linear/solvers/iterative_test.dart`, `test/linear/sparse/coo_matrix_test.dart`, `csc_matrix_test.dart`, `csr_matrix_test.dart` (split from `test/linear/linear_test.dart`)
  - `test/stats/distributions/continuous/*_test.dart`, `test/stats/distributions/discrete/*_test.dart` (mirror `lib/src/stats/distributions/`)
  - `test/type/utils/derive_test.dart` (create)
- **Problem & Evidence**:
  - `AGENTS.md` states: *"Structure the tests following the same folder structure as the code under test (e.g., `lib/src/foo/bar.dart` -> `test/foo/bar_test.dart`). Maintain a strict parallel hierarchy matching `lib/src/`."* and *"Group tests by functionality using `group('description', () { ... })`. Avoid declaring a single top-level group in a file."*
  - Currently, 40+ files in `lib/src/` lack their 1:1 counterpart in `test/` because tests are either placed at the wrong nesting level (`test/tensor/operation_test.dart` instead of `test/tensor/operations/operation_test.dart`, `test/polynomial/compressed_polynomial_test.dart` instead of `test/polynomial/impl/compressed_polynomial_test.dart`) or bundled into monolithic files (`test/linear/linear_test.dart`, `test/stats/distributions/continuous_test.dart`, `test/stats/distributions/discrete_test.dart`).
  - 93 of 188 test files wrap all tests in a single top-level `group('...', () { ... })`.
- **Actionable Fix & Acceptance Criteria**:
  1. Reorganize `test/` so every non-stub implementation file in `lib/src/` has a matching `test/<subsystem>/.../<file>_test.dart` file.
  2. Replace single top-level `group(...)` wrappers in test files with multiple functional `group(...)` blocks testing distinct aspects of each module.
  3. Remove the remaining `closeTo(...).isTrue()` calls in `test/linear/decomposition/complex_decomposition_test.dart` in favor of idiomatically typed `check(...)` assertions.
