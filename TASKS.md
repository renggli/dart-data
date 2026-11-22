# CAS Roadmap: Correctness, Performance, Coverage & API Cleanup (`TASKS.md`)

Baseline from `run.txt` at `HEAD` (`0904425e`): **102,106 / 158,651 passed (64.4%)**, **43,233 failed (27.3%)** (`1,130` differentiation, `576` wrong-result integration, `41,527` unevaluated integration), **13,312 errors (8.4%)** (`7,096` `hyper`, `3,227` 500ms timeouts, `2,196` `appellf1`, `680` `RootSum`, `56` `expint`, `20` 2-arg `zeta`).

No backward compatibility is required for any API or internal refactor below.

---

## Phase 1: Correctness Bugs Affecting Users (Highest Trust Impact)

### [TASK-91] Fix the 576 Wrong-Result Integration Bugs (`Integration Correctness`, ~576 fixes)

- **Impact:** Eliminates silent wrong antiderivatives — the highest-severity user-facing bug class in a CAS.
  - `t_1_2_1_3` (105) + `t_1_2_1_2` (48) = **153 wrong quadratic radical integrals**
  - `hebisch` (**103 wrong exponential/logarithmic integrals**)
  - `t_4_3_tangent` (`t_4_3_1_2`: 22, `t_4_3_3_1`: 22, `t_4_3_2_1`: 21 = **65 wrong tangent/cotangent integrals**)
  - `t_1_1_1_3` (27) + `t_1_1_1_2` (18) + `t_1_1_2_2` (17) = **62 wrong rational binomial-product integrals**
- **Files:**
  - `lib/src/symbolic/calculus/integration/radical.dart`
  - `lib/src/symbolic/calculus/integration/rational.dart`
  - `lib/src/symbolic/calculus/integration/trigonometric.dart`
  - `lib/src/symbolic/calculus/integration/substitution.dart`
  - `test/symbolic/calculus/integration/`
- **Specification:**
  1. **Quadratic radicals (`t_1_2_1_2`, `t_1_2_1_3`):**
     - Fix `(A + B*x) / ((d + e*x)^k * sqrt(a + b*x + c*x^2))` substitution sign/prefactor bugs (`#1194`, `#1233`, `#1234`, `#1450`) and perfect-square discriminant `b^2 - 4ac == 0` handling (`#213`: `x / sqrt(9x^2 - 12x + 4)` must respect the branch sign of `sqrt((3x - 2)^2)` rather than dropping the sign factor).
  2. **Rational binomial products (`t_1_1_1_2`, `t_1_1_1_3`, `t_1_1_2_2`):**
     - Fix partial-fraction / pole-order coefficient bugs in `1 / (x^2 * (a + b*x)^3 * (c + d*x)^3)` (`t_1_1_1_3#287`).
  3. **Tangent/cotangent products (`t_4_3_*`):**
     - Fix sign/complex-coefficient handling in `(a + i*a*tan(c + d*x)) * cot(c + d*x)^2` (`t_4_3_2_1#7`) and `sqrt(a - a*sin^2(u)) * tan(u)^3` (`t_4_1_7#442`, where `sqrt(a*(1 - sin^2(u)))` was conflated with `sqrt(a)*cos(u)` without preserving sign).
  4. **Hebisch log/exp (`hebisch#64` etc.):**
     - Audit and fix logarithmic-derivative / substitution factor errors in `substitution.dart` and `integration.dart`.
- **Verification:**
  - Wrong-result integration count across `rubi_integrate` and `hebisch_integrate` drops from 576 to `< 50`.
  - Add targeted regression tests in `test/symbolic/calculus/integration/`.

---

### [TASK-92] Fix Differentiation Branch-Cut & Algebraic Simplification Mismatches (`Differentiation`, ~700–1,000 fixes)

- **Impact:** Fixes the majority of the **1,130 remaining differentiation failures** (pushing differentiation pass rate from **98.6% → 99.5%+**), heavily concentrated in:
  - `t_4_5_secant` (422), `t_4_2_cosine` (188), `hebisch` (119), `t_4_1_sine` (66), `t_4_3_tangent` (60).
- **Root cause:**
  - `simplify/power.dart` / `differentiation.dart` combines or splits `sqrt(a) * sqrt(b) <-> sqrt(a * b)` and `sqrt(1 / cos(u))` without `Assumptions.positive`, introducing principal-branch sign flips when `cas_runner` evaluates derivatives numerically at complex/negative parameter values (e.g., `t_4_5_4_2#252`: `asinh(sqrt(a)*tan(c + d*x)/sqrt(a/cos(c + d*x) + a))`).
- **Files:**
  - `lib/src/symbolic/calculus/differentiation.dart`
  - `lib/src/symbolic/algebra/simplify/power.dart`
  - `bin/cas_suites/cas_test_case.dart` (verify test-point sampling avoids branch-cut boundaries when checking analytic equivalence)
  - `test/symbolic/calculus/differentiation_test.dart`
- **Specification:**
  1. Audit `differentiation.dart` and `simplify/power.dart` for unsound `sqrt(u*v) -> sqrt(u)*sqrt(v)` / `(u^a)^b -> u^(a*b)` rewrites under `Assumptions.none`.
  2. Verify `asinh`/`acosh`/`atanh` chain-rule derivatives preserve exact branch signs (`1 / sqrt(1 + u^2)` vs `sqrt(u^2 - 1)`).
- **Verification:**
  - `dart run bin/cas_runner.dart -s "_differentiate" -q` exceeds **99.5%** pass rate.

---

## Phase 2: Performance & Timeout Elimination

### [TASK-93] Eliminate the 3,227 Integration Timeouts (`Performance`, ~3,200+ timeouts eliminated)

- **Impact:** **3,227 cases hit the 500ms timeout** — directly causing UI freezes on complex user expressions:
  - `hebisch/hebisch.jsonl`: **1,274 timeouts**
  - `t_1_2_1_quadratic` (`t_1_2_1_3`: 185, `t_1_2_1_2`: 174): **359 timeouts**
  - `t_6_hyperbolic` (`t_6_1_1`: 67, `t_6_1_7`: 46, `t_6_3_7`: 44, `t_6_1_5`: 43): **200+ timeouts**
  - `t_4_trig` (`t_4_3_2_1`: 50, `t_4_1_2_1`: 48, `t_4_2_4_2`: 48, `t_4_1_2_2`: 41, `t_4_5_4_2`: 39): **226+ timeouts**
  - `t_1_1_1_3` (52), `t_1_2_2_quartic` (45), `t_1_2_3_general` (45).
- **Files:**
  - `lib/src/symbolic/calculus/integration/integration.dart`
  - `lib/src/symbolic/calculus/integration/rational.dart`
  - `lib/src/symbolic/calculus/integration/radical.dart`
  - `lib/src/symbolic/calculus/integration/trigonometric.dart`
  - `lib/src/symbolic/calculus/integration/parts.dart`
  - `lib/src/symbolic/algebra/expand.dart`, `factor.dart`, `term_accumulator.dart`
- **Specification:**
  1. **Unified AST complexity & recursion budget (`IntegrationContext`):** Pass a lightweight budget object (node count cap, recursion depth, memoization table of failed sub-integrals so the same sub-integrand is never retried across IBP/substitution/linearity branches).
  2. **Fix quadratic/binomial expansion blowup (`t_1_2_1_*`, `t_1_1_1_3`):** Avoid blindly calling `.expand()` on high-degree symbolic-parameter rational denominators (`(a + b*x)^m * (c + d*x)^n`) before checking factored structure; memoize polynomial GCDs/factorizations within a single integration call.
  3. **Fix `hebisch` nested exp/log blowup:** Cap Risch/substitution depth and skip expensive multivariate factoring when the integrand contains nested transcendental towers (`exp(exp(...))`, `ln(exp(...) + ...)`).
  4. **Fast bailout in `parts.dart` & `trigonometric.dart`:** Reject IBP/Weierstrass candidates immediately if the transformed integrand exceeds `3x` the original AST node count or increases nesting depth.
- **Verification:**
  - Total 500ms timeouts across all 17 CAS suites drop from **3,227** to **`< 100`** (and full runner wall-clock time drops dramatically).

---

## Phase 3: High-Impact Symbolic Capabilities

### [TASK-94] First-Class `Hypergeometric` (`1F1`, `2F1`, `pFq`), `ExpIntegralE`, `HurwitzZeta`, `Min`/`Max` (`AST / Special / Evaluator`, ~7,180+ errors eliminated)

- **Impact:** Eliminates **7,180+ `Unknown function` errors** in `run.txt` and exposes existing `package:data/special.dart` numerical routines (`hypergeometric1F1*`, `hypergeometric2F1*`) to the symbolic CAS:
  - `hyper` (**7,096 errors**)
  - `expint` (**56 errors** — generalized exponential integral $E_n(z)$)
  - 2-arg `zeta(s, a)` (**20 errors** — Hurwitz zeta)
  - `Max`/`Min` (**7 errors**), `loggamma` (**2 errors**)
- **Files:**
  - `lib/src/symbolic/ast/special_function.dart`
  - `lib/symbolic.dart`, `lib/src/symbolic/parser.dart`
  - `lib/src/symbolic/textualization/string.dart`, `latex.dart`, `mathml.dart`
  - `lib/src/symbolic/algebra/simplify/special.dart`
  - `lib/src/symbolic/calculus/differentiation.dart`, `series.dart`
  - `lib/src/symbolic/compiler/bytecode.dart`, `evaluator.dart`
  - `bin/cas_suites/cas_test_case.dart`
- **Specification:**
  1. **`Hypergeometric(List<Expr> upper, List<Expr> lower, Expr z)`** (single canonical AST node for ${}_pF_q(a_1,\dots,a_p; b_1,\dots,b_q; z)$, with convenience named constructors or direct `Hypergeometric([a], [b], z)` / `Hypergeometric([a, b], [c], z)`):
     - Exact differentiation: $\frac{d}{dz}{}_pF_q(\mathbf{a}; \mathbf{b}; z) = \frac{\prod a_i}{\prod b_j} {}_pF_q(\mathbf{a}+1; \mathbf{b}+1; z)$ (plus chain rule on `z`).
     - Simplification: `z = 0 -> 1`, cancelling equal upper/lower parameters, terminating polynomial when an upper parameter is a small non-positive integer, elementary reductions (`0F0 -> exp(z)`, `1F0(a;;z) -> (1-z)^(-a)`).
     - Evaluation: delegate `(p=1, q=1)` to `hypergeometric1F1`/`hypergeometric1F1Complex`, `(p=2, q=1)` to `hypergeometric2F1`/`hypergeometric2F1Complex`, and general `(p, q)` to convergent series evaluation.
     - Map SymPy's `hyper((a...), (b...), z)` in `cas_test_case.dart`.
  2. **`ExpIntegralE(Expr n, Expr z)`** (or rewrite `expint(n, z) -> z^(n - 1) * UpperGamma(1 - n, z)` for `n != 1`, `UpperGamma(0, z)` for `n == 1`) with derivative $-E_{n-1}(z)$.
  3. **`Min(List<Expr>)` / `Max(List<Expr>)`** and optional 2nd parameter on `Zeta(s, [a])` for Hurwitz zeta $\zeta(s, a)$ (derivative $-s \zeta(s+1, a)$).
- **Verification:**
  - `Unknown function: hyper`, `expint`, `zeta` (2-arg), `Min`, `Max` errors drop to **0**.
  - Differentiation cases containing `hyper` (`rubi_differentiate` / `independent_differentiate`) pass at >95%.

---

### [TASK-95] High-Impact Symbolic Integration Families (`Integration`, ~6,000–10,000+ new passes)

- **Impact:** Targets the 4 largest user-facing unevaluated clusters in `run.txt`:
  1. **Inverse trig & inverse hyperbolic IBP with rational/algebraic factors (`~2,600` cases):** `t_5_3_4` (1,160 `atan`), `t_7_3_6` (800 `atanh`), `t_7_4_2` (641 `acoth`).
     - Unified rule: for $\int R(x)\, F(u(x))\,dx$ where $F \in \{\operatorname{asin}, \operatorname{acos}, \operatorname{atan}, \operatorname{acot}, \operatorname{asinh}, \operatorname{acosh}, \operatorname{atanh}, \operatorname{acoth}\}$ and $R(x)$ has an elementary antiderivative $G(x)$, integrate by parts $G(x) F(u(x)) - \int G(x) F'(u(x)) u'(x)\,dx$ (reducing immediately to a rational or quadratic-radical integral!).
  2. **Binomial & generalized algebraic products (`~2,890` cases):** `t_1_1_1_3` (1,224), `t_1_1_3_2` (969), `t_1_2_1_2` (698).
     - Complete Chebyshev differential binomial reductions for $x^m (a + b x^n)^p$ (all 3 integrability cases: $p \in \mathbb{Z}$, $\frac{m+1}{n} \in \mathbb{Z}$, $\frac{m+1}{n} + p \in \mathbb{Z}$) and multi-step Ostrogradsky / Hermite reduction for $P(x) / (a + b x^n)^m$.
  3. **Trigonometric & secant/cosine/tangent products (`~4,600` cases):** `t_4_2_4_2` (1,108), `t_4_5_4_2` (874), `t_4_3_2_1` (849), `t_4_1_2_2` (696), `t_4_2_2_1` (663), `t_4_5_1_2` (583), `t_4_3_3_1` (558).
     - Unified reduction for $(a + b\operatorname{trig}(c + d x))^p \operatorname{trig}(c + d x)^q$ (converting `sec`/`csc`/`cot` cleanly into canonical `cos`/`sin`/`tan` forms before applying odd-power substitution, power-reduction, or Weierstrass substitution).
  4. **Fast structural logarithmic/exponential derivative-divides (`hebisch` 4,348 + `blake` 2,287):**
     - Recognize $\int \frac{P(u) u'}{Q(u)}\,dx$ and $\int R(x, e^{g(x)})\,dx$ via normalized substitution candidate extraction for compound `exp(...)` and `ln(...)` subexpressions.
- **Files:**
  - `lib/src/symbolic/calculus/integration/parts.dart`
  - `lib/src/symbolic/calculus/integration/radical.dart`
  - `lib/src/symbolic/calculus/integration/rational.dart`
  - `lib/src/symbolic/calculus/integration/trigonometric.dart`
  - `lib/src/symbolic/calculus/integration/substitution.dart`
- **Verification:**
  - Overall CAS pass rate rises above **72–75%+** with zero regression on wrong-result counts.

---

## Phase 4: Codebase Simplification & Breaking API Cleanup

### [TASK-96] Clean Up `package:data/symbolic.dart` Public API & AST Naming (No Backward Compatibility)

- **Motivation:** Align `package:data/symbolic.dart` with the clean, non-stuttering canonical naming already applied to `package:data/special.dart` and stop leaking internal helpers from `lib/symbolic.dart`.
- **Files:**
  - `lib/symbolic.dart`
  - `lib/src/symbolic/ast/special_function.dart`
  - All internal & test callers (`lib/src/symbolic/**`, `test/**`, `web/**`, `bin/**`, `doc/**`)
- **Specification:**
  1. **Drop stuttering suffixes on special-function AST classes** (1:1 symmetry with `package:data/special.dart`):
     - `ExpIntegralEi` → `ExpIntegral`
     - `LogIntegralLi` → `LogIntegral`
     - `SinIntegralSi` → `SinIntegral`
     - `CosIntegralCi` → `CosIntegral`
     - `SinhIntegralShi` → `SinhIntegral`
     - `CoshIntegralChi` → `CoshIntegral`
  2. **Merge `EllipticE` and `EllipticEIncomplete`:** Unify into a single `EllipticE(Expr k, {Expr? phi})` (matching `ellipticE(k, {phi})` in `lib/special.dart` and `EllipticPi(n, k, {phi})`).
  3. **Tighten `lib/symbolic.dart` exports:**
     - Remove internal barrel `export 'src/symbolic/ast.dart'` — export public AST files directly from `lib/symbolic.dart` (per `AGENTS.md` architecture rule).
     - Remove internal-only exports from `lib/symbolic.dart`: `LinearFormExtension` (integration helper), `isZeroExpr` (internal helper), `SymbolicPolynomialFactory` (or make clearly scoped).
  4. **Unify `Expr` evaluation/approximation entrypoints:** Ensure `expr.evaluate([vars])`, `expr.evaluateComplex([vars])`, `expr.toFunction1D(var)`, `expr.toComplexFunction1D(var)` have consistent parameter ordering and behavior across all AST nodes (no silent divergence between `approximate()` and `evaluate()`).
- **Verification:**
  - `dart analyze` clean, `dart test test/deps_test.dart test/symbolic/ test/web_examples_test.dart test/doc_examples_test.dart` 100% passing.

---

### [TASK-97] Decompose Monolithic `lib/src/symbolic/` Files & Deduplicate Shared Helpers (`Maintainability / Simplification`)

- **Motivation:** Nine files in `lib/src/symbolic/` exceed 1,100–2,400 lines (`rational.dart` 2,408, `limit.dart` 2,287, `integration.dart` 2,015, `summation.dart` 1,904, `series.dart` 1,832, `radical.dart` 1,530, `definite.dart` 1,395, `trigonometric.dart` 1,313, `transcendental.dart` 1,300), making bugs hard to isolate and duplicating algebraic helpers (numerator/denominator splitting, polynomial extraction, sign determination, AST size counting).
- **Files:**
  - `lib/src/symbolic/calculus/integration/rational.dart` → split into `rational_partial_fractions.dart`, `rational_hermite.dart`, `rational_binomial.dart`
  - `lib/src/symbolic/calculus/limit.dart` → split into `limit.dart` (entry & composition rules), `limit_gruntz.dart` (MRV/Gruntz engine), `limit_asymptotic.dart` (rational/exp-poly/Stirling/squeeze rules)
  - `lib/src/symbolic/calculus/integration/definite.dart` → split into `definite.dart` (Newton-Leibniz & pole splitting) and `definite_tables.dart` (special-case improper integral tables)
  - `lib/src/symbolic/algebra/helpers.dart` (or consolidate in `rational.dart`/`domain.dart`): deduplicate repeated `splitNumeratorDenominator`, `_getSign` / `_asymptoticSign`, `_isNonPosInt`, and AST node-count guards currently duplicated across `limit.dart`, `definite.dart`, `integration.dart`, and `series.dart`.
- **Verification:**
  - No single file in `lib/src/symbolic/` exceeds ~1,000 lines; `dart test test/deps_test.dart` confirms acyclic DAG and zero orphan/barrel violations; `dart test test/symbolic/` 100% passing.
