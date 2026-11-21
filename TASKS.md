# High-Impact CAS Integration Fixes (`TASKS.md`)

All previous tasks (`[TASK-44]`–`[TASK-49]`) were verified against `HEAD` (`3793e87a`): `dart analyze` clean, 589 / 589 symbolic & dependency unit tests passing, 283 / 283 (100.0%) on built-in CAS suites, `mit_bee_integrate` at 247 / 322 (76.7%), `mit_bee_official_integrate` at 312 / 544 (57.4%), `independent_integrate` at 1,342 / 1,778 (75.5%), `rubi/t_1_2_1_4#37..46` at 10 / 10 (100%), and `rubi/t_4_1_1_1#0..6` at 7 / 7 (100%).

One sign defect was caught in `[TASK-49]` (`mit_bee#31, #73, #80`), and 4 high-impact integration clusters across `rubi_integrate` (`t_4_trig_functions`, `t_3_logarithms`, `t_6_hyperbolic_functions`) and `independent_integrate` are specified below in dependency order.

---

## [TASK-50] Preserve `Sign(f)` When Pulling Even Powers Out of `sqrt(...)` in `tryRealRadicalRewrite` (`P0-Bug`)

- **Impact:** Fixes the 3 sign-flip failures in `mit_bee_integrate` (`#31`, `#73`, `#80`) and 3 corresponding failures in `mit_bee_official_integrate` (`#31`, `#73`, `#80`), bringing `mit_bee_integrate` to **250 / 322 (77.6%)** with **0 wrong results**.
- **Files:**
  - `lib/src/symbolic/calculus/integration/radical.dart` (`tryRealRadicalRewrite`)
  - `test/symbolic/calculus/integration_test.dart`
- **Problem:**
  In `[TASK-49]`, `tryRealRadicalRewrite` replaced `sqrt(f^2)` with `f` (e.g. `sqrt(cos(x)^2 / sin(x)) -> cos(x) / sqrt(sin(x))` and `sqrt(1 + tan(x)^2) -> 1 / cos(x)`). On intervals where `cos(x) < 0` (such as `x = 1.63, 2.11`), `sqrt(cos(x)^2) = |cos(x)| = -cos(x)`, so the antiderivative `2 * sqrt(sin(x))` has the opposite sign of the integrand and fails `verifyDerivative`.
- **Specification:**
  In `tryRealRadicalRewrite` (`lib/src/symbolic/calculus/integration/radical.dart`):
  - Whenever an odd power `f^k` is pulled out of `sqrt(f^(2*k))` (including `sqrt(1 + tan(u)^2) -> sqrt(1 / cos(u)^2)` where `f = cos(u)` and `k = -1`, or `sqrt(cos(u)^2 / sin(u))` where `f = cos(u)` and `k = 1`):
    - If `k.isOdd` and `!isPositiveExpr(f, assumptions: assumptions)`, track `Sign(f)` as an external locally-constant sign factor!
    - Integrate the sign-stripped expression via `antiDerivative(..., depth: depth + 1, assumptions: assumptions)`.
    - If no unevaluated `Integral` remains, multiply the resulting antiderivative by the accumulated `Sign(f)` factor(s) (since `d/dx(Sign(f)) == 0`, `d/dx(Sign(f) * F(x)) == Sign(f) * F'(x)` matches the integrand for ALL real `x` where `f(x) != 0`!).
- **Verification:**
  - `dart run bin/cas_runner.dart -s "^mit_bee_integrate$" -t "#(23|31|73|80)$"` passes **4 / 4 (100.0%)**.
  - `dart test test/symbolic/ test/deps_test.dart` passes.

---

## [TASK-51] Expand Powered Trig/Hyperbolic Binomials `(a + b*sin(u))^m * cos(u)^n` (`P1-Coverage`, ~1,000+ fixes)

- **Impact:** Unlocks **1,000+ cases** across `rubi_integrate` `t_4_trig_functions` (`t_4_1_1_2.jsonl#11..26`: `(a + a*sin(c + d*x))^2 * cos(c + d*x)^6`, `(a + a*sin(c + d*x))^2 / cos(c + d*x)^7`, `(a + a*sin(c + d*x))^3 * cos(c + d*x)^5`, etc.) and `t_6_hyperbolic_functions`.
- **Files:**
  - `lib/src/symbolic/calculus/integration/trigonometric.dart` (`tryExpandTrigBinomialProduct`)
  - `lib/src/symbolic/calculus/integration/integration.dart` (`_antiDerivMul`)
  - `test/symbolic/calculus/integration_test.dart`
- **Problem:**
  In `_antiDerivMul`, step 5 distributes over bare `Add` factors, but does NOT expand `Pow(Add, m)` (`2 <= m <= 6`) when multiplied by trigonometric or hyperbolic powers (e.g. `(a + a*sin(u))^2 * cos(u)^6`). Once expanded into a sum of `sin(u)^p * cos(u)^q` terms, `tryTrigPowerProduct` already integrates every term in closed form!
- **Specification:**
  1. Add `Expr? tryExpandTrigBinomialProduct(List<Expr> varFactors, String variable, {required Assumptions assumptions, int depth = 0})` in `lib/src/symbolic/calculus/integration/trigonometric.dart`:
     - Only run when `depth < 2`.
     - Look for a factor `Pow(base: final Add addBase, exponent: IntegerNumber(asInt: final m?))` with `2 <= m <= 6` and `addBase.terms.length <= 3`, where `addBase` contains `Sin`, `Cos`, `Tan`, `Sinh`, `Cosh`, or `Tanh` of a linear argument in `variable`, AND all other `varFactors` are powers (positive or negative integer) of `Sin`, `Cos`, `Tan`, `Sinh`, `Cosh`, or `Tanh` of linear arguments in `variable`.
     - Expand `Pow(addBase, m)` via `.expand().simplify(assumptions: assumptions)`, multiply by the remaining factors, distribute across the resulting `Add`, and integrate term-by-term via `antiDerivative(..., depth: depth + 1, assumptions: assumptions)`.
     - Return the simplified sum only if no unevaluated `Integral` remains.
  2. Call `tryExpandTrigBinomialProduct(varFactors, variable, assumptions: assumptions, depth: depth)` in `_antiDerivMul` (`lib/src/symbolic/calculus/integration/integration.dart`) right after `tryTrigPowerProduct`.
- **Verification:**
  - Add unit tests for `(a + a*sin(c + d*x))^2 * cos(c + d*x)^6` and `(a + a*sin(c + d*x))^2 / cos(c + d*x)^7`.
  - `dart run bin/cas_runner.dart -s "^rubi_integrate$" -t "t_4_1_1_2.jsonl#(11|12|13|15|23|24|25|26)$"` passes **8 / 8 (100.0%)**.

---

## [TASK-52] Generalize `x^n / ln(c * x)^k` Integration to Scaled Logs, Negative `n`, and Powers `k >= 2` (`P1-Coverage`, ~400+ fixes)

- **Impact:** Unlocks **hundreds of cases** in `rubi_integrate` `t_3_logarithms` (`t_3_1_2.jsonl#21..30`: `x^3 / ln(c*x)`, `1 / (x^2 * ln(c*x))`, `x^3 / ln(c*x)^2`, etc.).
- **Files:**
  - `lib/src/symbolic/calculus/integration/rational.dart` (`tryAntiDerivDiv`, `_tryPowerOverLogPower`)
  - `test/symbolic/calculus/integration_test.dart`
- **Problem:**
  In `rational.dart:241`, the `x^n / ln(x)` rule only matches bare `Ln(Variable(variable))` (rejecting `Ln(c * x)`), only matches positive `x^n` in `left` (rejecting `1 / (x^2 * ln(c * x))` where `x^2` is in `right`), and only handles `k == 1` (rejecting `x^3 / ln(c * x)^2`).
- **Specification:**
  Replace the inline block at `rational.dart:240-271` with a dedicated helper `Expr? _tryPowerOverLogPower(Expr left, Expr right, String variable, {required Assumptions assumptions})`:
  1. Decompose `left / right` into `(scale, nExp, cConst, kInt)` matching `scale * x^n / ln(c * x)^k`:
     - Extract all factors from `left` (positive exponent) and `right` (negative exponent).
     - Exactly one logarithmic factor `Ln(inner)^(-k)` with integer `k >= 1 && k <= 6`, where `inner.matchLinear(variable)` is `(a: final c, b: final b)` with `b is Number && b.isZero` (i.e. `inner == c * x`).
     - All remaining variable-dependent factors must be `x` or `Pow(x, e)` with `!e.dependsOn(variable)` (sum their exponents into `nExp`).
     - All constant factors multiply into `scale`.
  2. Integrate `x^n / ln(c * x)^k` via the exact reduction:
     - If `nExp == IntegerNumber.negativeOne`:
       - If `k == 1`: `logAntiderivative(Ln(inner), assumptions)`.
       - If `k >= 2`: `-Pow(Ln(inner), IntegerNumber.of(1 - k)) / IntegerNumber.of(k - 1)`.
     - Else (let `np1 = (nExp + IntegerNumber.one).simplify()`):
       - Base case `k == 1`:
         - If `nExp is Number && nExp.isZero`: `LogIntegralLi(inner) / c`.
         - Else: `ExpIntegralEi((np1 * Ln(inner)).simplify()) / Pow(c, np1)`.
       - Recursive step `k >= 2`:
         $$\int \frac{x^n}{\ln(c x)^k}\,dx = -\frac{x^{n + 1}}{(k - 1)\ln(c x)^{k - 1}} + \frac{n + 1}{k - 1}\int \frac{x^n}{\ln(c x)^{k - 1}}\,dx$$
  3. Multiply by `scale` and `.simplify(assumptions: assumptions)`.
- **Verification:**
  - Add unit tests for `x^3 / ln(c*x)`, `1 / (x^2 * ln(c*x))`, and `x^3 / ln(c*x)^2`.
  - `dart run bin/cas_runner.dart -s "^rubi_integrate$" -t "t_3_1_2.jsonl#(21|22|23|26|27|28|29|30)$"` passes **8 / 8 (100.0%)**.

---

## [TASK-53] Shifted Trig/Hyperbolic Integrals `(sin|cos|sinh|cosh)(a + b*x) / (c + d*x)^k` and Hyperbolic Power Reduction (`P1-Coverage`, ~600+ fixes)

- **Impact:** Unlocks **hundreds of cases** in `rubi_integrate` `t_6_hyperbolic_functions` (`t_6_1_1.jsonl#4..14`: `sinh(a + b*x) / (c + d*x)^k`, `(c + d*x)^4 * sinh(a + b*x)^2`, `sinh(a + b*x)^2 / (c + d*x)^k`) and `t_4_trig_functions`.
- **Files:**
  - `lib/src/symbolic/calculus/integration/trigonometric.dart` (`_reduceTrigPower`)
  - `lib/src/symbolic/calculus/integration/rational.dart` (`tryAntiDerivDiv`, `_tryTrigOrHypOverLinearPower`)
  - `test/symbolic/calculus/integration_test.dart`
- **Problem:**
  1. `_reduceTrigPower` (`trigonometric.dart:495`) only reduces `Sin^n` and `Cos^n`, NOT `Sinh^n` and `Cosh^n`, so `(c + d*x)^4 * sinh(a + b*x)^2` (`t_6_1_1#7`) fails!
  2. `rational.dart:274` only handles `sin(a*x) / x^k` and `cos(a*x) / x^k` with zero constant shifts (`b == 0` and denominator `x^k`), missing shifted linear arguments `(sin|cos|sinh|cosh)(a + b*x) / (c + d*x)^k` and squared forms `sinh(a + b*x)^2 / (c + d*x)^k`.
- **Specification:**
  1. In `_reduceTrigPower` (`lib/src/symbolic/calculus/integration/trigonometric.dart:495`):
     - Add `Sinh` and `Cosh` for `n = 2, 3, 4`:
       - `sinh(u)^2 = (cosh(2*u) - 1) / 2`, `cosh(u)^2 = (cosh(2*u) + 1) / 2`
       - `sinh(u)^3 = (sinh(3*u) - 3*sinh(u)) / 4`, `cosh(u)^3 = (cosh(3*u) + 3*cosh(u)) / 4`
       - `sinh(u)^4 = (cosh(4*u) - 4*cosh(2*u) + 3) / 8`, `cosh(u)^4 = (cosh(4*u) + 4*cosh(2*u) + 3) / 8`
  2. Add `Expr? _tryTrigOrHypOverLinearPower(Expr left, Expr right, String variable, {required Assumptions assumptions})` in `lib/src/symbolic/calculus/integration/rational.dart`:
     - Match `right` as `linBase` (`k = 1`) or `Pow(linBase, IntegerNumber(asInt: final k?))` (`1 <= k <= 6`), where `linBase.matchLinear(variable)` is `(a: final d, b: final c)`.
     - If `left` is `Pow(Sin|Cos|Sinh|Cosh(u), IntegerNumber(asInt: final n?))` (`2 <= n <= 4`, `u` linear): apply `_reduceTrigPower(left, variable)`, expand, and integrate each term over `right`!
     - If `left` is `Sin(u)`, `Cos(u)`, `Sinh(u)`, or `Cosh(u)` with `u.matchLinear(variable) = (a: final b, b: final a)`:
       - Base case `k == 1`: shift `w = c + d*x`, so `u = alpha + beta*w` where `beta = b / d`, `alpha = a - b * c / d`:
         - `sin(alpha + beta*w) / w`: `(cos(alpha) * SinIntegralSi(beta * w) + sin(alpha) * CosIntegralCi(beta * w)) / d`
         - `cos(alpha + beta*w) / w`: `(cos(alpha) * CosIntegralCi(beta * w) - sin(alpha) * SinIntegralSi(beta * w)) / d`
         - `sinh(alpha + beta*w) / w`: `(cosh(alpha) * SinhIntegralShi(beta * w) + sinh(alpha) * CoshIntegralChi(beta * w)) / d`
         - `cosh(alpha + beta*w) / w`: `(cosh(alpha) * CoshIntegralChi(beta * w) + sinh(alpha) * SinhIntegralShi(beta * w)) / d`
       - Recursive step `k >= 2`: 1-step IBP (`u = left`, `dv = (c + d*x)^(-k) dx`):
         `term1 = -left / (d * (k - 1) * (c + d*x)^(k - 1))`, plus `(1 / (d * (k - 1))) * integral(left' / (c + d*x)^(k - 1))`.
- **Verification:**
  - `dart run bin/cas_runner.dart -s "^rubi_integrate$" -t "t_6_1_1.jsonl#(4|5|6|7|11|12|13|14)$"` passes **8 / 8 (100.0%)**.

---

## [TASK-54] Shifted Exponential Integrals `exp(a + b*x) / (c + d*x)^k` and `exp(a + b*x) / Q(x)` (`P2-Coverage`, ~200+ fixes)

- **Impact:** Fixes `independent/apostol_problems.jsonl#173` (`exp(2*x) / (x^2 - 3*x + 2)`) and unlocks shifted exponential-rational integrals in `rubi_integrate` (`t_2_exponentials`).
- **Files:**
  - `lib/src/symbolic/calculus/integration/rational.dart` (`tryAntiDerivDiv`, `_tryExpOverRational`)
  - `test/symbolic/calculus/integration_test.dart`
- **Problem:**
  `exp(a + b*x) / (c + d*x)^k` and `exp(2*x) / (x^2 - 3*x + 2)` stay unevaluated because there is no rule for shifted exponential integrals (`Ei`) or partial-fraction decomposition of `1 / Q(x)` underneath an exponential factor `exp(a + b*x)`.
- **Specification:**
  Add `Expr? _tryExpOverRational(Expr left, Expr right, String variable, {required Assumptions assumptions})` in `lib/src/symbolic/calculus/integration/rational.dart`:
  1. Match `left` as `scale * Pow(Constant.e, u)` where `!scale.dependsOn(variable)` and `u.matchLinear(variable)` is `(a: final b, b: final a)`.
  2. **Case 1 (`right` is `(c + d*x)^k` with `1 <= k <= 6`):**
     - Base case `k == 1`: substitute `w = c + d*x`, returning `scale * Pow(Constant.e, a - b*c/d) / d * ExpIntegralEi((b / d) * (c + d*x))`.
     - Recursive step `k >= 2`: 1-step IBP (`-left / (d * (k - 1) * (c + d*x)^(k - 1)) + (b / (d * (k - 1))) * integral(left / (c + d*x)^(k - 1))`).
  3. **Case 2 (`right` is a polynomial of degree `2 <= deg <= 4`):**
     - Compute `final pf = (IntegerNumber.one / right).apart(variable);`.
     - If `pf is Add`: multiply each term by `left` and integrate term-by-term via `antiDerivative(..., depth: depth + 1, assumptions: assumptions)`. Return the sum if no unevaluated `Integral` remains.
- **Verification:**
  - `dart run bin/cas_runner.dart -s "^independent_integrate$" -t "apostol_problems.jsonl#173$"` passes.
  - Add unit tests for `exp(2*x) / (x^2 - 3*x + 2)` and `exp(a + b*x) / (c + d*x)^2`.
