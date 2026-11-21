# Special Functions Redesign, Complex Unification & CAS Roadmap (`TASKS.md`)

All previous tasks (`[TASK-65]`–`[TASK-70]`) were verified against `HEAD` (`d31a623b`): `dart analyze` clean, 607 / 607 symbolic & dependency unit tests passing in 2s, and full 17-suite CAS runner at **94,244 / 158,635 (59.4%)**.

---

## Target Design for `package:data/special.dart` (No Backward Compatibility)

### Design Principles

1. **Single Canonical Name per Mathematical Function:** Remove all redundant aliases (`besselJ0/J1/Y0/Y1/I0/I1/K0/K1`, `trigamma`, `lambertW0`/`lambertW1`, `ellipticEIncomplete`) and fix inconsistent naming (`gammap`/`gammaq`/`ibeta`, stuttering `sinIntegralSi`).
2. **Paired Top-Level Real & Complex Functions (`<name>` and `<name>Complex`):**
   - Every analytic special function provides two top-level functions with identical parameter order: `double <name>(...)` and `Complex <name>Complex(...)`, exported directly from `lib/special.dart`.
   - Real-only probability quantile inverses (`erfInv`, `erfcInv`, `gammaPInv`, `gammaQInv`, `betaIInv`) remain real-only.
   - **File layout (`AGENTS.md` ordering):** In each `lib/src/special/<family>.dart` file, place all public `<name>` and `<name>Complex` functions (fully documented with `///`) together at the top of the file, and place all private helpers (`_*`) below them.
3. **Zero Numerical Duplication in `lib/src/symbolic/`:** `evaluator.dart`, `approximate.dart`, and `simplify/special.dart` delegate directly to `package:data/special.dart`.

### Canonical Function Table (`package:data/special.dart`)

| File | Real (`double`) | Complex (`Complex`) | Removed / Renamed |
| --- | --- | --- | --- |
| `gamma.dart` | `gamma(x)`, `gammaLn(x)`, `lowerGamma(s, x)`, `upperGamma(s, x)`, `gammaP(a, x)`, `gammaQ(a, x)`, `gammaPInv(p, a)`, `gammaQInv(p, a)`, `factorial(x)`, `factorialLn(x)`, `binomial(n, k)`, `binomialLn(n, k)`, `permutation(n, k)`, `permutationLn(n, k)` | `gammaComplex`, `gammaLnComplex`, `lowerGammaComplex`, `upperGammaComplex`, `factorialComplex`, `binomialComplex` | `gammap`→`gammaP`, `gammaq`→`gammaQ`, `gammapInv`→`gammaPInv`, `gammaqInv`→`gammaQInv`, `combination`→`binomial`, `combinationLn`→`binomialLn` |
| `beta.dart` | `beta(a, b)`, `betaLn(a, b)`, `betaI(x, a, b)`, `betaIInv(p, a, b)` | `betaComplex`, `betaLnComplex` | `ibeta`→`betaI`, `ibetaInv`→`betaIInv` |
| `digamma.dart` | `digamma(x)`, `polygamma(m, x)` | `digammaComplex`, `polygammaComplex` | Drop `trigamma` (`polygamma(1, x)`) |
| `zeta.dart` | `zeta(s)` | `zetaComplex` | — |
| `polylog.dart` | `polylog(s, z)` | `polylogComplex` | Export `polylogComplex` in `lib/special.dart` |
| `erf.dart` | `erf(x)`, `erfc(x)`, `erfi(x)`, `erfInv(x)`, `erfcInv(x)` | `erfComplex`, `erfcComplex`, `erfiComplex` | — |
| `fresnel.dart` | `fresnelS(x)`, `fresnelC(x)` | `fresnelSComplex`, `fresnelCComplex` | — |
| `exp_integral.dart` | `expIntegral(x)`, `logIntegral(x)`, `sinIntegral(x)`, `cosIntegral(x)`, `sinhIntegral(x)`, `coshIntegral(x)` | `expIntegralComplex`, `logIntegralComplex`, `sinIntegralComplex`, `cosIntegralComplex`, `sinhIntegralComplex`, `coshIntegralComplex` | Drop `Ei`/`Li`/`Si`/`Ci`/`Shi`/`Chi` stutter suffixes |
| `bessel.dart` | `besselJ(nu, x)`, `besselY(nu, x)`, `besselI(nu, x)`, `besselK(nu, x)` | `besselJComplex`, `besselYComplex`, `besselIComplex`, `besselKComplex` | Drop `bessel{J,Y,I,K}{0,1}` (keep private fast paths) |
| `elliptic.dart` | `ellipticK(k)`, `ellipticF(phi, k)`, `ellipticE(k, {num? phi})`, `ellipticPi(n, k, {num? phi})` | `ellipticKComplex`, `ellipticFComplex`, `ellipticEComplex`, `ellipticPiComplex` | Merge `ellipticEIncomplete(phi, k)` into `ellipticE(k, phi: phi)`; add `ellipticPi` |
| `lambert_w.dart` | `lambertW(x, {int branch = 0})` | `lambertWComplex(z, {int branch = 0})` | Merge `lambertW0`/`lambertW1` into `lambertW(..., branch: 0 | -1)` |
| `hypergeometric.dart` | `hypergeometric1F1(a, b, z)`, `hypergeometric2F1(a, b, c, z)` | `hypergeometric1F1Complex`, `hypergeometric2F1Complex` | — |

---

## Phase 1: Clean Up `package:data/special.dart` API & Callers

### [TASK-71] Refactor `package:data/special.dart` to Canonical Names & Top-of-File Public Layout (`API Cleanup`)

- **Files:**
  - `lib/special.dart`
  - `lib/src/special/*.dart` (all 12 files)
  - All callers in `lib/src/stats/`, `lib/src/symbolic/`, `test/`, `doc/`, `bin/`
- **Specification:**
  1. Apply every rename and removal in the Canonical Function Table above directly across `lib/src/special/*.dart`:
     - Make `bessel{J,Y,I,K}{0,1}` private (`_besselJ0`, etc.) while keeping them as fast paths inside `besselJ`/`besselY`/`besselI`/`besselK`.
     - Remove `trigamma` (replace callers with `polygamma(1, x)`).
     - Merge `lambertW0`/`lambertW1` into `double lambertW(num z, {int branch = 0})` (throw `ArgumentError` for branches other than `0` or `-1`).
     - Merge `ellipticEIncomplete(phi, k)` into `double ellipticE(num k, {num? phi})`.
     - Rename `gammap`/`gammaq`/`gammapInv`/`gammaqInv`/`combination`/`combinationLn`/`ibeta`/`ibetaInv` and `expIntegralEi`/`logIntegralLi`/`sinIntegralSi`/`cosIntegralCi`/`sinhIntegralShi`/`coshIntegralChi`.
     - Export `polylogComplex` in `lib/special.dart` (remove `show polylog`).
  2. Enforce ordering in every `lib/src/special/*.dart` file: all public functions (documented with `///`) at the top of the file, all private helpers below.
  3. Update all callers across `lib/`, `test/`, `bin/`, and `test/doc_examples_test.dart`.
- **Verification:**
  - `dart analyze` clean (0 issues).
  - `dart test test/special/ test/stats/ test/symbolic/ test/deps_test.dart test/doc_examples_test.dart` passes 100%.

---

## Phase 2: Implement Complete `<name>Complex` Functions in `lib/src/special/`

### [TASK-72] Add Complex Gamma, Incomplete Gamma, Beta, Digamma, Polygamma & Zeta (`lib/src/special/`)

- **Impact:** Unlocks **438+ `uppergamma` cases** in `rubi_differentiate` plus complex `Gamma`, `Factorial`, `Binomial`, `Beta`, `Digamma`, `Polygamma`, and `Zeta`.
- **Files:**
  - `lib/src/special/gamma.dart` (`gammaComplex`, `gammaLnComplex`, `lowerGammaComplex`, `upperGammaComplex`, `factorialComplex`, `binomialComplex`)
  - `lib/src/special/beta.dart` (`betaComplex`, `betaLnComplex`)
  - `lib/src/special/digamma.dart` (`digammaComplex`, `polygammaComplex`)
  - `lib/src/special/zeta.dart` (`zetaComplex`)
  - `test/special/gamma_test.dart`, `beta_test.dart`, `digamma_test.dart`, `zeta_test.dart`
- **Specification:**
  Place each `<name>Complex` directly beside its real counterpart at the top of its file, with all private helpers below:
  1. **`gammaComplex(z)` & `gammaLnComplex(z)`:** Complex Lanczos ($g = 7$, 9 coefficients) with Euler reflection $\Gamma(z) = \frac{\pi}{\sin(\pi z)\Gamma(1 - z)}$ for `z.a < 0.5`.
  2. **`factorialComplex(z)` & `binomialComplex(n, k)`:** `gammaComplex(z + Complex.one)` and `(gammaLnComplex(n + 1) - gammaLnComplex(k + 1) - gammaLnComplex(n - k + 1)).exp()`.
  3. **`upperGammaComplex(s, z)` & `lowerGammaComplex(s, z)`:** Lentz modified continued fraction when `|z| >= |s| + 1 && z.a > -z.b.abs()`, convergent power series $\gamma(s, z) = z^s e^{-z} \sum_{n=0}^{120} \frac{z^n}{s(s+1)\cdots(s+n)}$ otherwise.
  4. **`betaComplex(a, b)` & `betaLnComplex(a, b)`:** via `gammaLnComplex`.
  5. **`digammaComplex(z)` & `polygammaComplex(m, z)`:** reflection for `z.a < 0.5`, recurrence shift to `|z| >= 8`, asymptotic Bernoulli series.
  6. **`zetaComplex(s)`:** Borwein/Euler-Maclaurin alternating eta for `s.a >= 0.5` and Riemann functional equation for `s.a < 0.5`.
- **Verification:**
  - Unit tests verify agreement with real functions on $\mathbb{R}$ (`< 1e-12`) and complex functional identities ($\Gamma(z+1) = z\Gamma(z)$, $\Gamma(s, z) + \gamma(s, z) = \Gamma(s)$, $\psi(z+1) = \psi(z) + 1/z$).

---

### [TASK-73] Add Complex Elliptic Integrals (`K`, `F`, `E`, `Pi`) & Real `ellipticPi` (`lib/src/special/elliptic.dart`)

- **Impact:** Directly enables fixing **~4,000+ `elliptic_f`/`elliptic_e` failures** in `rubi_differentiate` and **3,382 `elliptic_pi` errors** in `run.txt`!
- **Files:**
  - `lib/src/special/elliptic.dart` (`ellipticKComplex`, `ellipticFComplex`, `ellipticEComplex`, `ellipticPi`, `ellipticPiComplex`)
  - `test/special/elliptic_test.dart`
- **Specification:**
  1. Place all 8 public functions (`ellipticK`/`ellipticKComplex`, `ellipticF`/`ellipticFComplex`, `ellipticE`/`ellipticEComplex`, `ellipticPi`/`ellipticPiComplex`) at the top of `elliptic.dart`, with all private Carlson helpers (`_carlsonRF*`, `_carlsonRD*`, `_carlsonRC*`, `_carlsonRJ*`) below.
  2. Implement complex Carlson duplication algorithms using modulus $k$ ($m = k^2$), handling $|\operatorname{Re}(\phi)| > \pi/2$ via quasi-periodicity.
- **Verification:**
  - Unit tests verify agreement on $\mathbb{R}$ (`< 1e-12`) and complex finite-difference derivatives $\partial_\phi F$, $\partial_\phi E$, $\partial_\phi \Pi$.

---

### [TASK-74] Add Complex Error, Fresnel, Integral Functions, Bessel, Lambert W & Hypergeometric (`lib/src/special/`)

- **Impact:** Completes 100% complex coverage across `package:data/special.dart`.
- **Files:**
  - `lib/src/special/erf.dart` (`erfComplex`, `erfcComplex`, `erfiComplex`)
  - `lib/src/special/fresnel.dart` (`fresnelSComplex`, `fresnelCComplex`)
  - `lib/src/special/exp_integral.dart` (`expIntegralComplex`, `logIntegralComplex`, `sinIntegralComplex`, `cosIntegralComplex`, `sinhIntegralComplex`, `coshIntegralComplex`)
  - `lib/src/special/bessel.dart` (`besselJComplex`, `besselYComplex`, `besselIComplex`, `besselKComplex`)
  - `lib/src/special/lambert_w.dart` (`lambertWComplex`)
  - `lib/src/special/hypergeometric.dart` (`hypergeometric1F1Complex`, `hypergeometric2F1Complex`)
  - `test/special/erf_test.dart`, `fresnel_test.dart`, `exp_integral_test.dart`, `bessel_test.dart`, `lambert_w_test.dart`, `hypergeometric_test.dart`
- **Specification:**
  Place each `<name>Complex` beside its real counterpart at the top of its file, with all private helpers below:
  1. **`erfComplex`, `erfcComplex`, `erfiComplex`:** power series for `|z| < 4`, Lentz CF for `|z| >= 4`, `erfiComplex(z) = -i * erfComplex(i * z)`.
  2. **`fresnelSComplex`, `fresnelCComplex`:** generalize existing complex series/CF in `fresnel.dart` from `double` to `Complex`.
  3. **`expIntegralComplex` .. `coshIntegralComplex`:** power series for `|z| < 4`, existing `_expIntegralE1Complex` CF for `|z| >= 4`.
  4. **`besselJComplex`, `besselYComplex`, `besselIComplex`, `besselKComplex`:** power series (`|z| <= 12`) + Hankel asymptotic expansion (`|z| > 12`) + connection formulas.
  5. **`lambertWComplex(z, {int branch = 0})`:** complex Halley iteration for branches `0` and `-1`.
  6. **`hypergeometric1F1Complex`, `hypergeometric2F1Complex`:** complex Kummer/Gauss series with Euler/Pfaff linear transformations when `|z| >= 0.8`.
- **Verification:**
  - Unit tests in `test/special/` verifying real-axis agreement (`< 1e-12`) and complex derivative / functional identities.

---

## Phase 3: Unify `lib/src/symbolic/` onto `<name>Complex`

### [TASK-75] Wire `evaluator.dart`, `approximate.dart`, and `simplify/special.dart` onto `<name>Complex` (`Symbolic Cleanup`, ~4,200+ fixes)

- **Impact:** Deletes all 29 `UnsupportedError('Complex ... evaluation is only supported on R')` blocks in `evaluator.dart`, fixes `_approximateBinary` and `simplify/special.dart` for floating-point `ComplexNumber`, and fixes **~4,200+ failures** in `rubi_differentiate` and `independent_differentiate`!
- **Files:**
  - `lib/src/symbolic/compiler/evaluator.dart` (`BytecodeEvaluator._runComplex`)
  - `lib/src/symbolic/algebra/approximate.dart` (`_approximateUnary`, `_approximateBinary`)
  - `lib/src/symbolic/algebra/simplify/special.dart`
  - `test/symbolic/compiler/evaluator_test.dart`, `test/symbolic/algebra/approximate_test.dart`
- **Specification:**
  1. **`evaluator.dart`:** Replace all 29 special-function `UnsupportedError` blocks in `_runComplex` with direct `<name>Complex(...)` calls. Keep `UnsupportedError` only for real-ordered discrete ops (`floor`, `ceil`, `round`, `mod`).
  2. **`approximate.dart`:** Add shared `_complexToExpr(Complex c)` and update `_approximateBinary` to fall back to `_complexToExpr(rebuilt.evaluateComplex())` when either operand is `ComplexNumber` or `realVal.isNaN`.
  3. **`simplify/special.dart`:** Evaluate floating-point `ComplexNumber` inputs (those containing a `RealNumber` part) uniformly via `<name>Complex(...)` while keeping exact rational/Gaussian `ComplexNumber` inputs symbolic.
- **Verification:**
  - `dart test test/symbolic/ test/deps_test.dart` passes 100%.
  - `dart run bin/cas_runner.dart -s "^rubi_differentiate$" -t "t_1_1_1_2.jsonl#(1168|1186|1187|1188)$|t_2_1.jsonl#(0|18)$"` passes **6 / 6 (100.0%)**.

---

## Phase 4: High-Impact Multi-Subsystem CAS Gaps

### [TASK-76] First-Class `EllipticPi(n, phi, k)` and `Atan2(y, x)` AST Nodes (`AST / Parsing / Calculus`, ~3,520 errors fixed)

- **Impact:** Eliminates **3,382 `Unknown function: elliptic_pi`** errors and **138 `Unknown function: atan2`** errors in `run.txt`.
- **Files:**
  - `lib/src/symbolic/ast/special_function.dart` (`EllipticPi`), `lib/src/symbolic/ast/trigonometric.dart` (`Atan2`)
  - `lib/symbolic.dart`, `lib/src/symbolic/parsing/syntax.dart`, `bin/cas_suites/cas_test_case.dart`
  - `lib/src/symbolic/textualization/string.dart`, `latex.dart`, `mathml.dart`
  - `lib/src/symbolic/algebra/simplify.dart`, `simplify/special.dart`, `simplify/transcendental.dart`
  - `lib/src/symbolic/calculus/differentiation.dart`, `lib/src/symbolic/compiler/bytecode.dart`, `evaluator.dart`, `approximate.dart`
- **Specification:**
  1. `EllipticPi(n, phi, k)`: delegates to `ellipticPi` / `ellipticPiComplex`, maps SymPy's `elliptic_pi(n, phi, m)` -> `EllipticPi(n, phi, sqrt(m))` in `cas_test_case.dart`, differentiates as `phi' / ((1 - n*sin(phi)^2) * sqrt(1 - k^2*sin(phi)^2))`.
  2. `Atan2(y, x)`: exact quadrant simplifications, derivative `(x*y' - y*x') / (x^2 + y^2)`, real `math.atan2(y, x)` and complex `-i * ln((x + i*y) / sqrt(x^2 + y^2))`.
- **Verification:**
  - `dart run bin/cas_runner.dart -s "^independent_differentiate$" -q` has 0 `elliptic_pi` errors; `rubi_integrate` `t_4_1_7#(576|577)` has 0 `atan2` errors.

---

### [TASK-77] Exponential-of-Inverse-Hyperbolic Simplification `exp(atanh|asinh|acosh(u))` (`Simplification`, ~1,916 fixes)

- **Impact:** Unlocks **~1,916 unevaluated cases** in `rubi_integrate` (`t_7_3_6`, `t_7_4_2`) and strengthens general simplification.
- **Files:** `lib/src/symbolic/algebra/simplify/power.dart`, `bin/cas_suites/algebra_suite.dart`, `test/symbolic/algebra/simplify_test.dart`
- **Specification:** Simplify `exp(k * atanh(u)) -> ((1 + u)/(1 - u))^(k/2)` (rational `k`), `exp(±asinh(u)) -> sqrt(u^2 + 1) ± u`, `exp(±acosh(u)) -> u ± sqrt(u^2 - 1)`.
- **Verification:** `algebra` suite 100%; `rubi_integrate` `t_7_3_6|t_7_4_2` pass rate jumps sharply.

---

### [TASK-78] Square-Root Radical Denesting `sqrt(a ± b*sqrt(c))` (`Simplification / Algebra`)

- **Files:** `lib/src/symbolic/algebra/simplify/power.dart`, `bin/cas_suites/algebra_suite.dart`, `test/symbolic/algebra/simplify_test.dart`
- **Specification:** When `a, b, c` are rationals (`a > 0, c > 0, b != 0`) and `d = sqrt(a^2 - b^2 * c)` is rational, simplify `sqrt(a + b*sqrt(c)) -> sqrt((a + d)/2) + sign(b) * sqrt((a - d)/2)`.
- **Verification:** `wester|algebra` suites 100%.

---

### [TASK-79] Quadratic Trigonometric Equations $a\sin^2 u + b\sin u \cos u + c\cos^2 u = d$ (`Solvers`)

- **Files:** `lib/src/symbolic/solver/trigonometric.dart`, `bin/cas_suites/solvers_linear_suite.dart`, `test/symbolic/solver/trigonometric_test.dart`
- **Specification:** Replace `d` with `d*(sin(u)^2 + cos(u)^2)`, handle `cos(u) == 0` when `a + d == 0`, divide by `cos(u)^2` to solve `(a + d)*tan(u)^2 + b*tan(u) + (c + d) = 0`, and invert `tan(u) = t_k`.
- **Verification:** `solvers_linear` suite 100%.

---

### [TASK-80] Stirling Asymptotic Limits, Special-Function Maclaurin Series, and Alternating/Digamma Infinite Sums (`Limits / Series / Summation`)

- **Files:** `lib/src/symbolic/calculus/limit.dart`, `series.dart`, `summation.dart`, `bin/cas_suites/gruntz_limits_suite.dart`, `series_sums_products_suite.dart`
- **Specification:** Stirling asymptotic fallback for `Factorial`/`Gamma` at `+oo`; Maclaurin series at `0` for `Erf`, `Erfc`, `Erfi`, `SinIntegralSi`, `SinhIntegralShi`, `FresnelS`, `FresnelC`; alternating Dirichlet eta, Gregory-Leibniz, and two-pole `Digamma` infinite sums.
- **Verification:** `gruntz_limits|series_sums_products` suites 100%.

---

### [TASK-81] High-Impact Integration Fixes: `t_1_2_1_2`/`t_1_2_1_3` Wrong-Sign Bugs, `x^m * P(x)`, and `x^k / (a + b*x^n)^m` (`Integration`, ~2,350+ fixes)

- **Files:** `lib/src/symbolic/calculus/integration/radical.dart`, `integration.dart`, `rational.dart`
- **Specification:** Omit `Abs` inside `Ln` in `_tryQuadraticRadicalConst` when `quad` has negative discriminant (`t_1_2_1_2`/`t_1_2_1_3`, ~154 wrong results); expand `x^m * P(x)` for symbolic `m` (`t_1_1_1_3`, ~1,195 cases); add 1-step Ostrogradsky reduction for `x^k / (a + b*x^n)^m` (`t_1_1_3_2`, ~1,013 cases).
- **Verification:** `rubi_integrate` `t_1_2_1_2|t_1_2_1_3|t_1_1_1_3|t_1_1_3_2` pass rate jumps sharply.
