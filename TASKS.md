# Release Tasks

Pre-release review of `lib/` at `2fc36d4`. Baseline: `dart analyze` clean, README snippets run, no `.$N` accessors, no TODO/FIXME markers, no temp-like test names.

**Severity**: `High` (wrong result, crash, or interop break), `Medium` (accuracy, charter, or API gap), `Low` (hygiene/perf).
**Verified** = reproduced with a scratch script. All other findings come from reading the code and should be confirmed with a failing test before fixing.

---

## R1. Symbolic: Unsound Branch Simplifications

| ID | Sev | Location | Problem | Fix |
| --- | --- | --- | --- | --- |
| R1.1 [COMPLETED] | High | `lib/src/symbolic/algebra/simplify/power.dart:177-201` | Verified: `(x^3)^(1/3) -> x` and `(x^2)^(1/3) -> x^(2/3)`. Both are wrong for `x<0` (principal branch). | Fold only for an integer outer exponent, a base proven non-negative, or an inner exponent in `(-1,1]`. |
| R1.2 [COMPLETED] | High | `lib/src/symbolic/algebra/simplify/multiplicative.dart:251-258` | Verified: `_combineRadicalBases` gives `sqrt(2)/sqrt(y) -> sqrt(2/y)`, `sqrt(2)sqrt(x)sqrt(y) -> sqrt(2xy)` and `x^(1/3)y^(1/3) -> (xy)^(1/3)` with no domain checks. | Require all but at most one numerator base, and every denominator base, to be proven positive. |
| R1.3 [COMPLETED] | High | `lib/src/symbolic/assumptions.dart:69-70` | Verified: `domainOf` returns the parent's default before it checks the child's `defaultDomain`, so `copyWith(defaultDomain: positive)` has no effect. | Walk the explicit `domains` up the chain, then fall back to `this.defaultDomain`. |
| R1.4 [COMPLETED] | High | `lib/src/symbolic/algebra/simplify/transcendental.dart:614-616,637-640` | Verified: `ln(x^3) -> 3ln(x)` and `ln(1/x) -> -ln(x)` are applied unconditionally. `ln(e^u) -> u` is too. | Require `u` real (for `e^u`), `u` positive, or `k` in `(-1,1]`. |
| R1.5 [COMPLETED] | Medium | `power.dart:169-175` | Verified: `(e^z)^w -> e^(zw)` has no condition. `exp(4i)^(1/2)` gives the wrong branch. | Restrict to an integer `w` or a real `z`. |
| R1.6 [COMPLETED] | Medium | `power.dart:256-265` | Verified: rule 7b turns `(x^3 y)^(1/3)` into `x y^(1/3)` under `Assumptions.real`, which is wrong for `x<0`. | Require an even `m` or a non-negative base. |
| R1.7 [COMPLETED] | Medium | `power.dart:28-35` | Verified: `0^x -> 0`, which is wrong at `x=0`. | Return 0 only when `Re(exponent)` is proven positive. |
| R1.8 [COMPLETED] | Medium | `lib/src/symbolic/ast/integral.dart:104` | Verified: indefinite `Integral.substitute('x', y)` substitutes the integrand but keeps `dx`. | Rename the integration variable, or return a lazy node. Mirror FU-1.1. |
| R1.9 [COMPLETED] | Medium | `power.dart:137-141` | `2.5^2` and `2^0.5` are never evaluated, unlike `Add`. | Use `powNumber` when an operand is a `RealNumber`. |
| R1.10 [COMPLETED] | Low | `lib/src/symbolic/ast/number.dart:153-156`, `power.dart:19-21`, `multiplicative.dart:41-54` | Float contagion is lost: `(1+i)^2.0 -> 2i`, `x^0.0 -> 1`, `0.0*x -> 0`. | Return a `RealNumber` result when an input was a `RealNumber`. |
| R1.11 [COMPLETED] | Low | `multiplicative.dart:280-285`, `power.dart:119,125,331,347` | Recursive `simplify*` calls drop `assumptions`. | Pass `assumptions` through on every call. |
| R1.12 [COMPLETED] | Low | `transcendental.dart` (Ln/Abs) | Missing reductions: `log(8,2) -> 1/3`, `ln(8)-3ln(2) -> 0`, `abs(xy) -> abs(x)abs(y)`. | Split integer prime powers in `ln`. Make `abs` multiplicative. |

## R2. Acceleration: Native vs. Dart Divergence

| ID | Sev | Location | Problem | Fix |
| --- | --- | --- | --- | --- |
| R2.1 [COMPLETED] | High | `lib/src/acceleration/lapack/lapack_native.dart:323-331` | The LAPACKE `dsyev` path transposes eigenvectors into rows. The Fortran and Dart paths return columns. | Remove the transpose. Add a test that checks eigenvectors. |
| R2.2 [COMPLETED] | High | `lapack_native.dart:244-257` | The Fortran `dgels` hardcodes `LDA=n` and passes row-major `B` as column-major, so it is wrong for `nrhs>1` or `lda≠n`. | Use `lda`. Transpose `B` through an arena buffer, as `dgesv` does. |
| R2.3 [COMPLETED] | High | `lib/src/acceleration/lapack/lapack.dart:19-110` | The `Lapack` facade has no argument or bounds checks, so native calls can read or write out of bounds. `LapackDart.dsyev(n=0)` hits `e[-1]`. | Add the `blas_validation` checks and an `n==0` early return to every entry point. |
| R2.4 [COMPLETED] | Medium | `lapack_native.dart:14-15,53` | `_hasDpotrf` is true when only `LAPACKE_dpotrf` exists, but the code calls `dpotrf_`. | Split the flags or add the LAPACKE binding. |
| R2.5 [COMPLETED] | Medium | `lib/src/acceleration/lapack/lapack_dart.dart:18-30,68-71,120,238` | `uplo` is ignored (`dsyev`, `dpotrf`). `dgesv` copies `n*lda` elements, past the validated bounds. | Read only the declared triangle. Copy only `n×n` and `n×nrhs` entries. |
| R2.6 [COMPLETED] | Medium | `lapack_dart.dart:136-212` | The `dgels` fallback uses normal equations, which squares the condition number. Native uses QR. | Implement Householder QR/LQ. |
| R2.7 [COMPLETED] | Medium | `lib/src/acceleration/blas/blas_dart.dart:290-336`, `blas_native.dart:184,236` | Dart `dsyr2`/`ssyr2` ignore `uplo`. The native `gemv` zero-size path misses `ConjTrans`. | Update only the `uplo` triangle, then mirror. Test `transA != cblasNoTrans`. |
| R2.8 [COMPLETED] | Medium | `lib/src/acceleration/vforce/vforce_native.dart:190`, `vforce.dart:102,180,209` | An empty filter throws natively. `convolve` is gated on `isAvailable`, not on `convD`. `vpow` and the unary ops don't validate lengths. | Add `hasConvolution`. Validate lengths in the facade. |
| R2.9 [COMPLETED] | Medium | `test/tensor/operations/`, `test/acceleration/lapack/lapack_test.dart:49-67` | `matmul` and `reduction` have no tests. The LAPACK tests don't check `dgels` values, `nrhs>1`, `lda≠n`, or eigenvectors. | Add `accelerationTest` suites for these cases. |

## R3. Tensor

| ID | Sev | Location | Problem | Fix |
| --- | --- | --- | --- | --- |
| R3.1 [COMPLETED] | Medium | `lib/src/tensor/tensor.dart:44-177` | `filled`/`generate`/`fromIterable` accept arbitrary `strides` but allocate only `layout.length`. Length mismatches truncate or pad silently. `fromObject` accepts ragged lists. | Validate the input or drop the `strides` parameter. Throw `ArgumentError`. |
| R3.2 [COMPLETED] | Medium | `lib/src/tensor/layout.dart:177-191,432-441` | `indices` allocates a `List` per element. `toKey` is O(rank²). Every non-contiguous path pays for this. | Use an allocation-free odometer over the strides. |
| R3.3 [COMPLETED] | Medium | `lib/src/tensor/float64_tensor.dart:46-50,141-219` | Copies the whole backing buffer of a non-`Float64List` operand, and `fromDoubleTensor` copies the whole buffer instead of the view. | Index the operand directly. Copy only the view. Dedupe the shape helpers. |
| R3.4 [COMPLETED] | Medium | `tensor.dart:145,219` | `fromObject(dynamic)` and `dynamic toNestedList()`. | Use `Object?`. |

## R4. Numeric / Linear / Polynomial

| ID | Sev | Location | Problem | Fix |
| --- | --- | --- | --- | --- |
| R4.1 [COMPLETED] | High | `lib/src/numeric/ode/solve_ode.dart:309-327` | BDF2 uses uniform-step coefficients on a truncated last step, which gives an O(h) endpoint error. | Use variable-step coefficients, or a BE/trapezoid last step. |
| R4.2 [COMPLETED] | High | `lib/src/numeric/root_finding/solve.dart:199-219` | Bisection ignores `f(a)==0`/`f(b)==0` and walks away from the root. NaN is not guarded. | Return the endpoint early. Add the NaN guard from `_brent`. |
| R4.3 [COMPLETED] | Medium | `lib/src/linear/solvers/iterative.dart:171-178` | GMRES collapses complex dot products to their norm. On breakdown, `krylovBasis[k+1]` throws `RangeError`. | Keep `H` in `T`, or restrict to real types. Break cleanly on breakdown. |
| R4.4 [COMPLETED] | Medium | `solve_ode.dart:244-248` | RK45 at `minStep` rejects forever until `maxSteps`. | Accept the step, or abort with `converged=false`. |
| R4.5 [COMPLETED] | Medium | `lib/src/linear/matrix.dart:466-470,515-519` | The docs promise `dgels` for rectangular solves, but the code uses pure-Dart QR. | Route `double` through `Lapack.dgels`. |
| R4.6 [COMPLETED] | Medium | `matrix.dart:441-446,490-495` | `dgesv` copies twice. A `Float64List` is stored under a `float32` `DataType`. | Copy once. Use the correct `DataType`. |
| R4.7 [COMPLETED] | Medium | `matrix.dart:429` | `S solve<S extends Object>(S b)` uses runtime `as S` casts. | Split into `solve(Matrix<T>)` and `solveVector(Vector<T>)`. |
| R4.8 [COMPLETED] | Medium | `lib/src/linear/decomposition/qr.dart:89`, `svd.dart:152` | Absolute rank tolerances (`1e-12`, `1e-15`) are not scale-invariant. | Use `max(m,n)·eps·max | diag | `. |
| R4.9 [COMPLETED] | Medium | `lib/src/polynomial/polynomial.dart:439-457` | `as num` cast fails for complex coefficients. The quadratic formula suffers cancellation. | Use the stable `q` formula. Handle the field or throw `ArgumentError`. |
| R4.10 [COMPLETED] | Low | `lu.dart:195-239`, `qr.dart:244-429` | The "Float64" paths still use virtual `getUnchecked`/`setUnchecked`. | Operate on the contiguous `Float64List`. |
| R4.11 [COMPLETED] | Low | `solve.dart:186`, `iterative.dart:111,246` | Newton/CG/GMRES return non-converged results silently. The tolerances are absolute. | Signal non-convergence. Use `‖r‖ ≤ tol·‖b‖`. |
| R4.12 [COMPLETED] | Low | `lib/src/polynomial/orthogonal.dart:40` | Public `clenshawEvaluate` is named after the algorithm (charter violation). | Rename, e.g. `evaluateOrthogonalSeries`. |
| R4.13 [COMPLETED] | Low | `iterative.dart:235-239`, `tridiagonal.dart:127-161` | GMRES allocates a vector per term. The Thomas algorithm is duplicated. | Use `addScaled`. Keep a single path. |

## R5. DataFrame / Arrow / CSV

| ID | Sev | Location | Problem | Fix |
| --- | --- | --- | --- | --- |
| R5.1 [COMPLETED] | High | `lib/src/dataframe/arrow/arrow_ipc.dart:156-172` | The Field never writes `children`, which Arrow C++/pyarrow reject (from memory, not tested). | Always emit an empty vector. Add a pyarrow round-trip check. |
| R5.2 [COMPLETED] | High | `arrow_ipc.dart:607-621` | Unsupported types silently map to `typeCode 0`. Half floats are read as 8-byte doubles. | Throw `UnsupportedError` at schema time. |
| R5.3 [COMPLETED] | Medium | `lib/src/dataframe/arrow/arrow_c_data_ffi.dart:237-246` | Struct import ignores the parent offset, length, and validity bitmap. | Apply the parent offset, or reject `offset≠0`. |
| R5.4 [COMPLETED] | Medium | `arrow_ipc.dart:160,469`, `arrow_c_data_ffi.dart:265` | `nullable` comes from the first batch only. `bodyLength` is unchecked. | Emit `nullable=true` or OR it across batches. Throw `FormatException`. |
| R5.5 [COMPLETED] | Medium | `lib/src/dataframe/csv/csv_stream.dart:345-361` | A trailing empty field at EOF is dropped. An unterminated quote never closes the sink. | Track a pending field. Close after `addError`. |
| R5.6 [COMPLETED] | Medium | `lib/src/dataframe/csv/csv_writer.dart:23-41` | `null` and `''` are both written as empty. A single-column null row is skipped on read. | Quote `''` as `""`. |
| R5.7 [COMPLETED] | Medium | `lib/src/dataframe/dataframe.dart:335,552,564`, `series.dart:173-187`, `json/json_decoder.dart`, `arrow/arrow_ipc.dart`, `tuple_key.dart` | Heavy `dynamic` use in public signatures (`filterBy`, `Series<dynamic>`). Overlaps FU-1.5. | Switch to `Object?`, starting with the public API. |

## R6. Stats / Special Functions

| ID | Sev | Location | Problem | Fix |
| --- | --- | --- | --- | --- |
| R6.1 [COMPLETED] | Medium | `lib/src/special/gamma.dart:126,223-230` | The incomplete gamma series and continued fraction run a fixed iteration count with no convergence test (about 1e-11 error). This affects Poisson, χ², Gamma, and Jarque-Bera. | Iterate until the relative term is below 1e-15, with a generous cap. |
| R6.2 [COMPLETED] | Medium | `lib/src/special/beta.dart:89,127-159` | `_betacf` caps at 100 iterations, too few for large `a`,`b`. `ibetaInv` uses `eps=1e-8` and 10 Newton steps. | Scale the cap with the parameters. Use `eps≈1e-14` plus a bisection fallback. |
| R6.3 | Medium | `lib/src/stats/distributions/continuous/student_t.dart:113-117`, `f.dart:111-115` | No `survival` override, so p-values floor at about 1e-16. The t cdf cancels for large negative x. | Use `ibeta`-based cdf and survival with symmetry. |
| R6.4 | Medium | `lib/src/special/erf.dart:173` | `erfcInv(x) = -erfInv(x-1)` cancels for small x. Normal quantiles go to −∞ below p≈1e-17. | Use a direct tail approximation or AS241. |
| R6.5 | Medium | `lib/src/stats/hypothesis/mann_whitney.dart:42-44` | No tie or continuity correction, so results don't match scipy/R. | Apply the tie-corrected σ and a ±0.5 correction. |
| R6.6 | Medium | `lib/src/stats/hypothesis/kolmogorov_smirnov.dart:27-37,101-118` | Wrong for discrete distributions. Inaccurate asymptotics for small n. | Reject `DiscreteDistribution`. Use the exact MTW method for n ≲ 100. |

## R7. Release Hygiene

| ID | Sev | Location | Problem | Fix |
| --- | --- | --- | --- | --- |
| R7.1 | High | `CHANGELOG.md:3-13` | No breaking-changes section. `lib/matrix.dart` and `lib/vector.dart` were removed, as were `Vector/Matrix.fromString`, `fromTensor`, `distance`, and `distanceSquared`. | Add a "Breaking changes" section with migration hints. |
| R7.2 | Medium | `CHANGELOG.md:3` | The heading still says `(Unpublished)`. | Fix it at release. |
| R7.3 | Medium | `lib/src/type/types/*.dart`, `lib/src/acceleration/blas/cblas_constants.dart` | Exported public members lack `///` docs (234 `public_member_api_docs` hits in total). | Document the exported members. Consider enabling the lint. |
| R7.4 | Low | `.pubignore` | It shadows `.gitignore`, so `pubspec.lock`, `coverage/` and `*.dart.js*` are published. | Copy those patterns. Check with `dart pub publish --dry-run`. |
| R7.5 | Low | `ARCHITECTURE.md:309` | Describes nested `domain/` directories, but the actual acceleration layout is flat. | Update the description. |
| R7.6 | Low | `README.md:16,30` | Claims a `Float32x4` SIMD fallback (none exists), says "GELSF" (should be GELS), and says "25+" dashboard distributions (actually 24). | Correct the text. |
| R7.7 | Low | `lib/src/acceleration/utils/library_loader.dart`, `lib/src/dataframe/arrow/arrow_c_data.dart` | Export-only conditional selectors inside `lib/src` (the charter prohibits barrels there). | Document the exception in `AGENTS.md`. |

---

## Carried Over: Open Follow-Ups (FU-*)

#### FU-1.1: `Derivative.substitute` Drops the Point Evaluation (Regression of TASK-1.8) — High

- **File**: `lib/src/symbolic/ast/derivative.dart` (`substitute`, ~L37–53).
- **Problem**: When `variable == this.variable` and `replacement` is not a `Variable`, it returns `Derivative(expr, variable)` unchanged. This throws the substitution away: `Derivative(x^2, 'x').substitute('x', 2).simplify()` gives `2*x`, not `4`. The task asked for either evaluate-then-substitute or an evaluation node.
- **Problem (variable capture)**: Renaming to a `Variable` replacement that is already free in `expr` captures it. For example, `d/dx (x*y)` with `x -> y` becomes `d/dy (y*y)`.
- **Fix**:
  1. Return `expr.derivative(variable, order: order).substitute(variable, replacement)`. If no closed form exists, return a point-evaluation node instead.
  2. Alpha-rename on capture, the same way `Integral`, `Limit`, `Sum`, and `Product` do.
  3. Add regression tests for both cases.

#### FU-1.2: Numeric Pole Integration Silently Hides Divergence — High

- **File**: `lib/src/numeric/integration.dart` (~L220–270, the endpoint-pole transform).
- **Problem**: `catch (_)` blocks, plus mapping `NaN` and `Infinity` to `0.0`, can turn a divergent integral (for example $\int_0^1 1/x\,dx$) into a finite number with no error or warning. This breaks the charter's convergence error/warning contract.
- **Fix**:
  1. Catch only specific exceptions.
  2. Propagate non-finite samples as a divergence or non-convergence flag (or an `IntegrationResult` warning).
  3. Add tests covering divergent endpoint singularities.

#### FU-1.3: `CurveFitResult.covariance` Uses a Diagonal Fallback When the Matrix Is Singular — Medium

- **File**: `lib/src/numeric/curve_fit.dart` (~L558–570).
- **Problem**: When $J^TJ$ is singular, a generic `catch (_)` replaces $(J^TJ)^{-1}$ with `1/diag`. This produces confident but wrong standard errors.
- **Fix**:
  1. Use an SVD pseudo-inverse, or return `NaN` or `Infinity` entries for non-identifiable parameters.
  2. Catch only the specific solver exception.
  3. Test with a degenerate model, e.g. `a*x + b*x`.

#### FU-1.4: Accelerated FFT Paths Are Incomplete — Medium

- **Files**: `lib/src/acceleration/fft/fft.dart`, `fft_dart.dart`.
- **Problems**:
  - Non-power-of-2 lengths always use Dart Bluestein. FFTW supports arbitrary sizes natively. Bluestein's inner power-of-2 FFTs also do not go through the accelerated `Fft.fft`.
  - `Fft.fft2` still throws for non-power-of-2 `rows`/`cols`, which is inconsistent with the 1D behavior.
- **Fix**:
  1. Send Bluestein's inner transforms through `Fft.fft`.
  2. Allow arbitrary sizes in `fft2` (row/column passes reuse the 1D path).
  3. Add `accelerationTest` coverage for odd and prime lengths in all modes.

#### FU-1.5 [COMPLETED]: Arrow C Data Public API Uses `dynamic` and Duplicates Entry Points — Medium

- **Files**: `lib/src/dataframe/dataframe.dart` (~L552–570), `series.dart` (~L173–190), `arrow/arrow_c_data*.dart`, `lib/dataframe.dart`.
- **Problems**:
  - `exportTo`/`importFrom` take `required dynamic` arguments, so type safety is lost and the charter's "avoid `dynamic`" rule is violated.
  - The low-level `exportDataFrameToArrowC`, `importDataFrameFromArrowC`, `exportSeriesToArrowC`, and `importSeriesFromArrowC` are also exported publicly. That gives two ways to do the same thing, which violates the single-canonical-API rule.
- **Fix**:
  1. Type the parameters as `ffi.Pointer<ArrowSchema>`/`ffi.Pointer<ArrowArray>` in an FFI-only extension, or as `Object` with a checked cast.
  2. Stop exporting the top-level helpers.
  3. Update `ARCHITECTURE.md`.

---

### 2. Charter & Hygiene Follow-Ups

#### FU-2.1: Generic `catch` Blocks Added Across `lib/` — Medium

- **Locations**:
  - `lib/src/symbolic/solver/polynomial_system.dart:52`
  - `lib/src/symbolic/solver/transcendental.dart:268,469`
  - `lib/src/symbolic/solver/univariate.dart:152,169` (`on Object`)
  - `lib/src/numeric/sampling.dart:340` (`on Object`)
  - `lib/src/numeric/root_finding/solve_system.dart:76`
  - the symbolic `integrate` simplification fallback
- **Fix**: Narrow each one to the exceptions it actually expects (`ArgumentError`, `UnsupportedError`, `StateError`). `catch (_)` in `library_loader_ffi.dart` (dynamic library probing) is acceptable but should be documented.

#### FU-2.2: Publishing Blocker: Git `dependency_overrides` on `more` — Medium

- **File**: `pubspec.yaml` L30–32. The agent kept this on purpose (it needs the `asinh` fix from git `dart-more`).
- **Fix**: Release `more` and pin the version constraint, then remove the override before publishing `0.16.0`. `dart pub publish --dry-run` currently fails.

#### FU-2.3: Close Gaps in the 1:1 Test Mirror — Low

- **Lib files without a matching `_test.dart`**:
  - `acceleration/blas/blas_validation`, `acceleration/utils/dispatcher`
  - `linear/operator`
  - `numeric/interpolation/{search,interpolator}`
  - `tensor/operations/{reduction,matmul}`
  - `polynomial/impl/formatting`
  - `stats/distribution`, `stats/distributions/errors`, `stats/hypothesis/hypothesis_test_result`
  - Enum/constant-only files (`*_method`, `acceleration_mode`, `cblas_constants`, `acceleration_error`, `library_loader`) can be skipped.
- **Orphan tests without a matching lib file**: `test/linear/linear_test.dart`, `test/linear/decomposition/complex_decomposition_test.dart`, `test/dataframe/json/json_test.dart`. Merge them into their canonical files or rename them.
- **Fix**: Move existing coverage for these into canonical files. Do not add new aggregate suites.

#### FU-2.4: Re-run Multi-Platform Tests — Low

- Run `dart test -p node,chrome` (and `-c dart2wasm` if configured). The changes touch `BigInt` paths (Pollard's rho, `Integer.from`, exact combinations) and UTF-8 byte sorting, where JS semantics can differ.

---

### 3. Verification Gaps (Quick Checks)

- **FU-3.1** (TASK-2.1): Confirm that `ln(negative)` → `ln|x| + iπ` applies only when the argument is a known negative number, and that `ln(x)` with `Assumptions.none` stays unevaluated.
- **FU-3.2** (TASK-6.2, BDF2): The Newton iteration uses a finite-difference Jacobian on every iteration (`_approximateJacobian` in `solve_ode.dart` ~L291). Reuse the Jacobian across iterations and steps (modified Newton), and report failure to converge through `OdeSolution.converged`.
- **FU-3.3** (TASK-6.1): Check that `DataFrame.describe()` and `concat()` handle nullable and mixed-type columns and keep the Arrow-backed series types (no forced boxing to `Series<dynamic>`).
- **FU-3.4** (TASK-3.3): `ExprSyntax.identifierTokenParser` and `numberTokenParser` were left public on purpose for `web/calculator`. Document this exception in `ARCHITECTURE.md`.
