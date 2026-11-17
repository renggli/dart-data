# Symbolic Subsystem (`lib/src/symbolic`) Task Specification

Execute tasks in order; later tasks assume earlier ones are merged. After every task: `dart format .`, `dart analyze`, `dart test test/symbolic`, `dart test test/deps_test.dart`. Add every **Verification** case as a `check(...)` test in the mirrored file under `test/symbolic/` (e.g. `lib/src/symbolic/algebra/simplify/power.dart` → `test/symbolic/algebra/simplify/power_test.dart`). Line numbers are approximate; locate code by the named symbol.

Priorities: `P0-Bug` (wrong result), `P1-Architecture`, `P2-Math` (missing capability), `P3-Perf`.

---

## [TASK-01] Total order in `compareStructural` and `RealNumeric.compareTo` (`P0-Bug`)

- **Files:** `lib/src/symbolic/algebra/structural_order.dart` (`compareStructural`), `lib/src/symbolic/ast/number.dart` (`RealNumeric.compareTo`)
- **Problem:**
  1. The `(Integral, Integral)` arm returns `0` when both `lower` are `null` without comparing `upper`, and mishandles mixed `null`/non-null bounds; violates `compareStructural(a, b) == 0 ⇔ a == b`.
  2. `RationalNumber` vs `RealNumber` compares via `toDouble()`, which is `±infinity` for magnitudes > 1.8e308.
- **Specification:**
  1. In the `(final Integral ia, final Integral ib)` arm, after comparing `variable` and `integrand`, return:

     ```dart
     final cmpLow = _compareNullable(ia.lower, ib.lower);
     return cmpLow != 0 ? cmpLow : _compareNullable(ia.upper, ib.upper);
     ```

     Add at the bottom of the file:

     ```dart
     int _compareNullable(Expr? a, Expr? b) => switch ((a, b)) {
       (null, null) => 0,
       (null, _) => -1,
       (_, null) => 1,
       (final xa?, final xb?) => compareStructural(xa, xb),
     };
     ```

  2. In the mixed branch of `RealNumeric.compareTo`: let `d = rational.toDouble()`; if `!d.isFinite` return `rational.sign` when `this` is the rational, else `-rational.sign`.
- **Verification:**
  - `compareStructural(Integral(x, 'x', lower: 0, upper: 1), Integral(x, 'x', lower: 0, upper: 2)) < 0`
  - `compareStructural(Integral(x, 'x'), Integral(x, 'x', lower: 0, upper: 1)) < 0`
  - `IntegerNumber(Integer.two.pow(1024)).compareTo(RealNumber(1e300)) > 0`

---

## [TASK-02] Cache `freeVariables` on `IteratedExpr`; allocation-free `OrderTerm.dependsOn` (`P3-Perf`)

- **Files:** `lib/src/symbolic/ast/summation.dart` (`IteratedExpr`), `lib/src/symbolic/ast/order_term.dart` (`OrderTerm`)
- **Problem:** `Sum`/`Product`/`OrderTerm` build a new `Set<String>` on every `freeVariables`/`dependsOn` call → O(n²) allocations in recursive traversals.
- **Specification:**
  1. `IteratedExpr`: drop `const` from the constructor; replace the getter with

     ```dart
     @override
     late final Set<String> freeVariables = Set.unmodifiable(
       {...expr.freeVariables}
         ..remove(variable)
         ..addAll(lower.freeVariables)
         ..addAll(upper.freeVariables),
     );
     ```

  2. `OrderTerm`: add

     ```dart
     @override
     bool dependsOn(String variable) =>
         this.variable == variable || point.dependsOn(variable);
     ```

- **Verification:**
  - `final s = Sum(k * x, 'k', 1, n); identical(s.freeVariables, s.freeVariables)`
  - `OrderTerm('x', 3).dependsOn('x') == true`, `OrderTerm('x', 3).dependsOn('y') == false`

---

## [TASK-03] Simplification memoization and assumption propagation (`P3-Perf`)

- **Files:** `lib/src/symbolic/algebra/simplify.dart` (`simplifyExpr`), `lib/src/symbolic/algebra/simplify/transcendental.dart` (`simplifyAsin`, `simplifyAcos`, `simplifyAtan`, `simplifySinh`, `simplifyCosh`, `simplifyTanh`, `simplifyAsinh`, `simplifyAcosh`, `simplifyAtanh`)
- **Problem:**
  1. With non-empty `assumptions`, the `isSimplified` short-circuit is disabled, so every call re-simplifies the whole tree; shared subtrees (DAGs) are re-simplified once per occurrence. `VariableFunction` and `OrderTerm` are rebuilt even when unchanged.
  2. Inverse trig and hyperbolic simplifiers do not receive `assumptions`, so no domain-dependent rule (e.g. `asin(sin(x))`, `acosh(cosh(x))` for `x ≥ 0`) can fire.
- **Specification:**
  1. Rename the recursive body of `simplifyExpr` to `Expr _simplify(Expr expr, Assumptions assumptions, Map<Expr, Expr> cache)`. Public `simplifyExpr` keeps its fast path (`assumptions.isEmpty && expr.isSimplified`) and then calls `_simplify(expr, assumptions, HashMap<Expr, Expr>())`.
  2. In `_simplify`: `final cached = cache[expr]; if (cached != null) return cached;` … compute … `cache[expr] = result;`. All recursive child calls in the dispatch switch use `_simplify(child, assumptions, cache)`. Leaves (`Number`, `Constant`, `Variable`) bypass the cache.
  3. For `VariableFunction` and `OrderTerm`: if every simplified child is `identical` to the original, return `expr` unchanged.
  4. Add `{Assumptions assumptions = Assumptions.none}` to the nine functions listed under **Files** and pass it from the dispatch switch. Add rules:
     - `simplifyAsin(Sin(u))` → `u` when `u` is real with static value in `[-π/2, π/2]` (`tryStaticRealValue`).
     - `simplifyAtan(Tan(u))` → `u` when static value in `(-π/2, π/2)`.
     - `simplifyAcos(Cos(u))` → `u` when static value in `[0, π]`.
     - `simplifyAsinh(Sinh(u))` → `u` and `simplifyAtanh(Tanh(u))` → `u` when `isProvenReal(u)`.
     - `simplifyAcosh(Cosh(u))` → `u` when `isNonNegativeExpr(u)`; → `Abs(u)` when `isProvenReal(u)`.
- **Verification:**
  - `Expr.parse('asinh(sinh(x))').simplify(assumptions: Assumptions.real) == x`
  - `Expr.parse('acosh(cosh(x))').simplify(assumptions: Assumptions.real) == Expr.parse('abs(x)')`
  - `Expr.parse('asin(sin(x))').simplify() == Expr.parse('asin(sin(x))')` (unchanged without assumptions)
  - Simplifying `e = (sin(x) + 1)^2 * (sin(x) + 1)^3` under `Assumptions.real` gives the same result as before (regression).

---

## [TASK-04] Sound domain predicates (`P0-Bug`)

- **Files:** `lib/src/symbolic/algebra/simplify/domain.dart` (`isProvenReal`, `isPositiveExpr`, `isNonNegativeExpr`)
- **Problem:**
  1. `isNonNegativeExpr(Pow(b, e))` is `true` when `b ≥ 0` even for complex `e` (`2^i`).
  2. `isProvenReal(EllipticK(x))`/`EllipticE(x)` is `true` for any real `x`; `K(x)` is complex for `|x| ≥ 1`, `E(x)` for `|x| > 1`.
  3. `Add` and `Cosh` are missing from `isPositiveExpr`/`isNonNegativeExpr`, so `abs(x^2 + 1)` and `sqrt((x^2+1)^2)` do not simplify for real `x`.
- **Specification:**
  1. `isNonNegativeExpr`, `Pow` arm:

     ```dart
     Pow(:final base, :final exponent) =>
       (isNonNegativeExpr(base, assumptions: assumptions) &&
           isProvenReal(exponent, assumptions)) ||
       (isProvenReal(base, assumptions) &&
           exponent is IntegerNumber && exponent.value.isEven),
     ```

  2. `isPositiveExpr`: add

     ```dart
     Cosh(:final expr) => isProvenReal(expr, assumptions),
     Add(:final terms) =>
       terms.every((t) => isNonNegativeExpr(t, assumptions: assumptions)) &&
       terms.any((t) => isPositiveExpr(t, assumptions: assumptions)),
     ```

  3. `isNonNegativeExpr`: add `Cosh(:final expr) => isProvenReal(expr, assumptions),` and `Add(:final terms) => terms.every((t) => isNonNegativeExpr(t, assumptions: assumptions)),`.
  4. `isProvenReal`: `EllipticK(:final expr)` → real and static value `v` exists with `v.abs() < 1`; `EllipticE(:final expr)` → real and `v.abs() <= 1`. No static value → `false`.
- **Verification:**
  - `isNonNegativeExpr(Pow(IntegerNumber.two, ComplexNumber.i)) == false`
  - `isPositiveExpr(Expr.parse('x^2 + 1'), assumptions: Assumptions.real) == true`
  - `Expr.parse('abs(x^2 + 1)').simplify(assumptions: Assumptions.real) == Expr.parse('1 + x^2').simplify()`
  - `Expr.parse('sqrt((x^2 + 1)^2)').simplify(assumptions: Assumptions.real) == Expr.parse('1 + x^2').simplify()`
  - `isProvenReal(EllipticK(x), Assumptions.real) == false`

---

## [TASK-05] Canonical rational radicals; power and inverse-composition rules (`P0-Bug`)

- **Files:** `lib/src/symbolic/ast/number.dart` (`_exactIntegerRoot`), `lib/src/symbolic/algebra/simplify/power.dart` (`_extractRationalRadical`, `_extractQthPower`), `lib/src/symbolic/algebra/simplify/multiplicative.dart` (`simplifyMul`), `lib/src/symbolic/algebra/simplify/transcendental.dart` (`simplifySin`, `simplifyCos`, `simplifySinh`, `simplifyCosh`, `simplifyTanh`)
- **Problem:**
  1. No normal form for rational radicals: `1/sqrt(2)` → `2^(-1/2)`, `sqrt(1/2)` → `(1/2)^(1/2)`, `sqrt(2)/2` → `1/2 * 2^(1/2)`; their differences do not cancel.
  2. `_extractQthPower` uses `1 << count2` (wraps on JS for ≥ 31), ignores `BigInt`, and never tests the cofactor left after trial division to 997 (`sqrt(2 * 1009^2)` not reduced).
  3. `simplifyMul` cancels `∞^1 * ∞^(-1)` → `1`.
  4. Missing compositions: `sin(acos u)`, `sin(atan u)`, `cos(asin u)`, `cos(atan u)`, `sinh(asinh u)`, `cosh(acosh u)`, `cosh(asinh u)`, `tanh(atanh u)`.
- **Specification:**
  1. Make `_exactIntegerRoot` a public static `Number.exactIntegerRoot(Integer n, int q) → Integer?`.
  2. Normal form for `RationalNumber b > 0` raised to `FractionNumber p/q` (`q > 1`):
     - `b = u/v`, `v ≠ 1` → `simplifyMul([u^(p/q) (omit if u == 1), v^(-p/q)])`, each recursively simplified.
     - `b` integer > 1: `m = floorDiv(p, q)`, `r = p - m*q ∈ [1, q-1]`; if `m ≠ 0` return `simplifyMul([IntegerNumber(b^m) as RationalNumber, b^(r/q)])`. Thus integer radicals only carry exponents in `(0, 1)` and rational coefficients absorb denominators (`2^(-1/2)` → `1/2 * 2^(1/2)`).
  3. `_extractQthPower(Integer n, int q)`: use `Integer` arithmetic throughout (no `<<`, no `asInt`); after trial division, if `unfactored > 1` and `Number.exactIntegerRoot(unfactored, q)` returns `r`, multiply `root` by `r` and set `unfactored = 1`.
  4. `simplifyMul`: when merged exponent of base `Constant.infinity` is zero, return `Constant.undefined`.
  5. Transcendental compositions (`s(u) := simplify`):
     - `sin(acos u)`, `cos(asin u)` → `(1 - u^2)^(1/2)`
     - `sin(atan u)` → `u * (1 + u^2)^(-1/2)`; `cos(atan u)` → `(1 + u^2)^(-1/2)`
     - `sinh(asinh u)`, `cosh(acosh u)`, `tanh(atanh u)` → `u`
     - `cosh(asinh u)` → `(1 + u^2)^(1/2)`
- **Verification:**
  - `(Expr.parse('sin(pi/4)') - Expr.parse('1/sqrt(2)')).simplify() == IntegerNumber.zero`
  - `(Expr.parse('sqrt(1/2)') - Expr.parse('sqrt(2)/2')).simplify() == IntegerNumber.zero`
  - `(Expr.parse('tan(pi/6)') - Expr.parse('1/sqrt(3)')).simplify() == IntegerNumber.zero`
  - `Expr.parse('2^(5/2)').simplify() == Expr.parse('4 * sqrt(2)').simplify()`
  - `Pow(IntegerNumber.of(2 * 1009 * 1009), FractionNumber.half).simplify() == Expr.parse('1009 * sqrt(2)').simplify()`
  - `(Constant.infinity / Constant.infinity).simplify() == Constant.undefined`
  - `Expr.parse('sin(acos(x))').simplify() == Expr.parse('sqrt(1 - x^2)').simplify()`
  - `Expr.parse('sinh(asinh(x))').simplify() == x`

---

## [TASK-06] Exact special-function evaluation gaps (`P0-Bug`)

- **Files:** `lib/src/symbolic/algebra/simplify/special.dart` (`simplifyGamma`, `simplifyFactorial`, `simplifyPolygamma`, `simplifyBinomial`)
- **Problem:**
  1. `gamma(n)` for `IntegerNumber n ≤ 0` stays symbolic (pole; `RealNumber` path already returns `undefined`). `(-1)!` likewise.
  2. Thresholds disagree: `gamma(n)` is evaluated only for `n ≤ 18`, `n!` for `n ≤ 100`, so `gamma(20) - 19!` does not cancel.
  3. Half-integer gamma uses `Integer.from(1 << (2 * n))`, which wraps on JS for `n ≥ 16`; negative half-integers (`gamma(-1/2) = -2·sqrt(π)`) are missing.
  4. `simplifyPolygamma` truncates a non-integer `RealNumber` order via `toInt()` (`polygamma(1.5, 2.0)` silently computes order 1).
  5. `binomial(n, k)` for negative integer `n` and non-negative integer `k` stays symbolic; the identity `binomial(-n, k) = (-1)^k · binomial(n + k - 1, k)` applies.
- **Specification:**
  1. `simplifyGamma`: `IntegerNumber n ≤ 0` → `Constant.undefined`; `1 ≤ n ≤ 101` → `(n-1)!`. `simplifyFactorial`: negative `IntegerNumber` → `Constant.undefined`; keep `0..100`.
  2. Half-integer `x = n + 1/2` with `|n| ≤ 50`: for `n ≥ 0`, coefficient `(2n)! / (4^n · n!)` using `Integer.from(4).pow(n)`; for `n < 0` with `m = -n`, coefficient `(-4)^m · m! / (2m)!`. Return `simplifyMul([coeff, sqrt(π)])`.
  3. `simplifyPolygamma`: if `m` is not integral (`m.toDouble() != m.toDouble().roundToDouble()`) return `Polygamma(m, x, isSimplified: true)` unevaluated.
  4. `simplifyBinomial`: `n` negative `IntegerNumber`, `k` non-negative `IntegerNumber` with `k ≤ 1000` → `(-1)^k * binomial(-n + k - 1, k)` exactly.
- **Verification:**
  - `Expr.parse('gamma(0)').simplify() == Constant.undefined`, `Expr.parse('(-1)!').simplify() == Constant.undefined`
  - `(Expr.parse('gamma(20)') - Expr.parse('19!')).simplify() == IntegerNumber.zero`
  - `Expr.parse('gamma(-1/2)').simplify() == Expr.parse('-2 * sqrt(pi)').simplify()`
  - `Expr.parse('gamma(41/2)').simplify()` equals `(38! / (4^19 * 19!)) * sqrt(pi)` (exact, no overflow)
  - `Expr.parse('binomial(-1, 3)').simplify() == IntegerNumber.negativeOne`
  - `Polygamma(RealNumber(1.5), RealNumber(2.0)).simplify() is Polygamma`

---

## [TASK-07] Complete Pythagorean and logarithm reductions in `MonomialAccumulator` (`P2-Math`)

- **Files:** `lib/src/symbolic/algebra/term_accumulator.dart` (`_reducePythagorean`, `_reduceHyperbolicPythagorean`, `_reduceLogarithms`)
- **Problem:**
  1. `a·sin²u + b·cos²u` folds only for `a, b > 0`; `c - c·sin²u` folds only for `c = 1`.
  2. Hyperbolic fold requires `coshCoeff ≥ 0`; constant folds only for `±1`.
  3. `Ln` terms combine only with coefficients `±1` (`2ln2 + 2ln3 - 2ln6` stays).
- **Specification:**
  1. `_reducePythagorean`: replace the `!sinCoeff.isNegative && !cosCoeff.isNegative` guard with `sinCoeff.sign == cosCoeff.sign`; let `m` be the coefficient of smaller absolute value; subtract `m` from both and add `m` to `constant`. Replace `constant == IntegerNumber.one` with any non-zero rational `c`: if a `sin²u` (resp. `cos²u`) term has coefficient `-c`, remove it, zero the constant, add `c` to `cos²u` (resp. `sin²u`).
  2. `_reduceHyperbolicPythagorean`: guard becomes `coshCoeff == sinhCoeff.neg()`. For any non-zero rational constant `c`: `c + c·sinh²u → c·cosh²u`; `c - c·cosh²u → -c·sinh²u`.
  3. `_reduceLogarithms`: collect entries with key `Ln(arg)`, `IntegerNumber` coefficient, `isPositiveExpr(arg)`. If ≥ 2: `g = gcd(|coeffs|)`, `s_i = coeff_i / g`; if all `|s_i| ≤ 8`, form `num = ∏_{s_i>0} arg_i^{s_i}`, `den = ∏_{s_i<0} arg_i^{-s_i}`, replace entries by `g · simplifyLn(num / den)`.
- **Verification:**
  - `Expr.parse('-cosh(x)^2 + sinh(x)^2').simplify() == IntegerNumber.negativeOne`
  - `Expr.parse('-3*sin(x)^2 - 2*cos(x)^2').simplify() == Expr.parse('-2 - sin(x)^2').simplify()`
  - `Expr.parse('2 - 2*sin(x)^2').simplify() == Expr.parse('2*cos(x)^2').simplify()`
  - `Expr.parse('3 + 3*sinh(x)^2').simplify() == Expr.parse('3*cosh(x)^2').simplify()`
  - `Expr.parse('2*ln(2) + 2*ln(3) - 2*ln(6)').simplify() == IntegerNumber.zero`

---

## [TASK-08] Unsorted monomials in `expand()` (`P0-Bug`)

- **Files:** `lib/src/symbolic/algebra/expand.dart` (`_parsePolyMonomial`, `_mergePolyFactors`)
- **Problem:** `_mergePolyFactors` assumes factors sorted by variable name and unique, but `_parsePolyMonomial` accepts unsimplified `Mul` (`(y*x + 1)*(x*y + 1)`), producing `Mul([x, y, x, y], isSimplified: true)`.
- **Specification:** Guard the `Mul` arm of `_parsePolyMonomial` with `isSimplified: true`; unsimplified products fall through to the existing `simplifyMul` fallback.
- **Verification:**
  - `((y*x + 1) * (x*y + 1)).expand() == Expr.parse('1 + 2*x*y + x^2*y^2').simplify()`

---

## [TASK-09] Symbolic common factors and large-coefficient divisors in `factor` (`P0-Bug`)

- **Files:** `lib/src/symbolic/algebra/factor/multivariate.dart` (`extractMonomialGcd`, `divideMonomial`, `collectVariablePowers`), `lib/src/symbolic/algebra/factor/univariate.dart` (`divisors`)
- **Problem:**
  1. Monomial GCD tracks only `Variable` powers (`Map<String, int>`), so `x·sin(y) + 2·sin(y)` and `x·e^x + e^x` are not factored; `(c.numerator * (lcmDen ~/ c.denominator)).abs()` is computed twice.
  2. `divisors(n)` returns `[1, n]` when `bitLength > 30`, disabling rational-root search for large coefficients with small prime factors.
- **Specification:**
  1. Replace `Map<String, int>` with `Map<Expr, int>` keyed by the non-numeric base of each factor (`Pow(b, k)` with positive integer `k` → `(b, k)`; any other non-numeric factor `f` → `(f, 1)`). GCD = intersection of keys with minimum exponent. `divideMonomial` subtracts exponents per key and rebuilds via `simplifyMul`. Compute the scaled numerator once into a local.
  2. `divisors`: trial-divide by primes up to `min(10^5, isqrt(n))` (use `Integer` arithmetic); if the remaining cofactor > 1 treat it as one prime. Generate all divisors from the factorization; if the count would exceed 4096, return `[1, n]`.
- **Verification:**
  - `Expr.parse('x*sin(y) + 2*sin(y)').factor() == Expr.parse('(2 + x)*sin(y)').simplify()`
  - `Expr.parse('x*exp(x) + exp(x)').factor() == Expr.parse('(1 + x)*exp(x)').simplify()`
  - `Expr.parse('x^2 - 3*2^31*x + 2^63').factor()` yields `(x - 2^31)*(x - 2^32)` (canonical order)

---

## [TASK-10] Definite integrals across antiderivative discontinuities; consistent log antiderivatives (`P0-Bug`)

- **Files:** `lib/src/symbolic/calculus/integration/definite.dart` (`evaluateDefiniteIntegral`, `_hasInteriorPole`), `lib/src/symbolic/calculus/integration/integration.dart` (`_antiDerivPow`, `_antiDerivTan`), `lib/src/symbolic/calculus/integration/rational.dart` (`tryAntiDerivDiv`), `lib/src/symbolic/calculus/integration/substitution.dart` (`_tryChainRulePower`)
- **Problem:**
  1. Weierstrass (`t = tan(x/2)`) and `t = tan(x)` substitutions yield antiderivatives that jump at `tan` poles although the integrand is smooth; `_hasInteriorPole` only inspects the integrand, so `∫_0^{2π} 1/(2 + cos x) dx` returns `0` (correct: `2π/√3`) and `∫_0^π 1/(1 + sin²x) dx` returns `0` (correct: `π/√2`).
  2. Log antiderivatives are inconsistent: some paths return `Ln(Abs(u))`, others bare `Ln(u)` (`∫(ax+b)^(-1)`, `∫tan`, `∫c/(ax+b)`, `∫u'/u`, chain-rule power).
- **Specification:**
  1. Add to `definite.dart`:
     `List<double> _antiderivativeJumps(Expr antiDeriv, String variable, double low, double high)`: for every `Tan(arg)` node in `antiDeriv` with `arg.matchLinear(variable) = (a, b)` (`a ≠ 0`), collect `x_k = ((k + 1/2)π - b)/a` lying in `(low + 1e-9, high - 1e-9)`; return them sorted, at most 16 (more → return `null`/abort and keep unevaluated `Integral`).
  2. In `evaluateDefiniteIntegral`, when the integrand has no interior pole but `_antiderivativeJumps` is non-empty with split points `p_1 < … < p_m`, return `Σ_i [F(p_{i+1}^-) - F(p_i^+)]` with `p_0 = low`, `p_{m+1} = high`, using the existing one-sided `limit` machinery; simplify the sum.
  3. Add in `integration.dart` `Expr logAntiderivative(Expr u, Assumptions assumptions) => isPositiveExpr(u, assumptions: assumptions) ? Ln(u) : Ln(Abs(u));` and route every log-producing rule listed under **Files** through it. Update affected test expectations in `test/symbolic/calculus/integration/` to `ln(abs(...))`.
- **Verification:**
  - `Expr.parse('1/(2 + cos(x))').integrate('x', from: 0, to: 2*pi) == Expr.parse('2*pi/sqrt(3)').simplify()`
  - `Expr.parse('1/(1 + sin(x)^2)').integrate('x', from: 0, to: pi) == Expr.parse('pi/sqrt(2)').simplify()`
  - `Expr.parse('1/x').integrate('x') == Expr.parse('ln(abs(x))')`
  - `Expr.parse('1/x').integrate('x', assumptions: Assumptions.none.assume('x', VariableDomain.positive)) == Expr.parse('ln(x)')`
  - `Expr.parse('tan(x)').integrate('x') == Expr.parse('-ln(abs(cos(x)))').simplify()`

---

## [TASK-11] Modulus derivatives of incomplete elliptic integrals (`P2-Math`)

- **Files:** `lib/src/symbolic/calculus/differentiation.dart` (`_differentiate`, `EllipticF`/`EllipticEIncomplete` arms)
- **Problem:** `EllipticF(φ, k)` and `EllipticEIncomplete(φ, k)` differentiate only when `k` is independent of the variable; otherwise an unevaluated `Derivative` is returned.
- **Specification:** Total derivative = `∂_φ · φ' + ∂_k · k'` with
  - `∂_φ F = (1 - k²sin²φ)^(-1/2)`, `∂_φ E = (1 - k²sin²φ)^(1/2)` (existing),
  - `∂_k F = [E(φ,k) - (1 - k²)F(φ,k) - k²·sinφ·cosφ·(1 - k²sin²φ)^(-1/2)] / (k(1 - k²))`,
  - `∂_k E = [E(φ,k) - F(φ,k)] / k`.
  Omit terms whose inner derivative is zero.
- **Verification:**
  - `EllipticEIncomplete(pi/4, k).derivative('k') == ((EllipticEIncomplete(pi/4, k) - EllipticF(pi/4, k)) / k).simplify()`
  - Numeric: `EllipticF(pi/3, k).derivative('k')` at `k = 0.5` matches central difference `(F(π/3, 0.5+h) - F(π/3, 0.5-h))/(2h)`, `h = 1e-6`, to `1e-6`.

---

## [TASK-12] Limit sign at infinity, oscillation, continuity fast path (`P0-Bug`)

- **Files:** `lib/src/symbolic/calculus/limit.dart` (`computeLimit`, `_asymptoticSignAtInfinity`, `_isEverywhereContinuous`)
- **Problem:**
  1. `_asymptoticSignAtInfinity` samples `x = 100` and returns immediately if finite non-zero: `ln(x) - 5` → `-1` (correct `+1`), so `1/(ln(x) - 5)` and `abs(ln(x) - 5)` limits get wrong signs.
  2. `lim (-1 + 1/x)^x` is rewritten via `exp(x·ln(base))` with `ln(-1) = iπ` instead of reporting oscillation.
  3. `_isEverywhereContinuous` lacks `Tanh`, `Atan`, `Asinh`, `Erf`, `Erfc`, `Erfi`, `FresnelS`, `FresnelC`, `SinIntegralSi`, `SinhIntegralShi`, `Abs`, forcing series expansion for trivial substitutions.
- **Specification:**
  1. `_asymptoticSignAtInfinity`: first try `computeLimit(expr, variable, Constant.infinity)` (catch `UnsupportedError`): `+∞` → `1`, `-∞` → `-1`, finite variable-free non-zero → its sign. Only on failure sample `x ∈ {1e4, 1e8, 1e16}`, require all finite non-zero samples to agree, else return `0` (unknown) and let callers keep the `Limit` unevaluated.
  2. In the `Pow` path of `computeLimit`: if `baseLim` is a negative `RealNumeric` and `expLim` is `±∞`, throw `UnsupportedError('Limit does not exist due to oscillation')`.
  3. Add the listed functions to `_isEverywhereContinuous` as `=> _isEverywhereContinuous(expr, variable)`.
- **Verification:**
  - `Expr.parse('abs(ln(x) - 5)/ln(x)').limit('x', Constant.infinity) == IntegerNumber.one`
  - `Expr.parse('1/(ln(x) - 5)').limit('x', Constant.infinity) == IntegerNumber.zero`
  - `Expr.parse('5 - ln(x)').limit('x', Constant.infinity)` equals `-∞`
  - `Expr.parse('(-1 + 1/x)^x').limit('x', Constant.infinity)` throws `UnsupportedError`
  - `Expr.parse('atan(x) + erf(x)').limit('x', 1) == Expr.parse('pi/4 + erf(1)').simplify()`

---

## [TASK-13] Series: `LambertW` off-origin, branch points (`P0-Bug`)

- **Files:** `lib/src/symbolic/calculus/series.dart` (`_expandLambertW`, `_expandAsin`, `_expandAtanh`, `_expandAcosh`)
- **Problem:**
  1. `_expandLambertW` throws for `u₀ ≠ 0` although `W` is analytic for `u₀ > -1/e`; its loop runs to `order` even when `u` has valuation `m > 1` (wasted O(N) Cauchy products).
  2. At `u₀ = ±1` (`asin`, `atanh`) and `u₀ = 1` (`acosh`), `(1 - u²)^(-1/2)` fails with an opaque error.
- **Specification:**
  1. `_expandLambertW`: if `u.constantTerm` simplifies to `-1/e` → throw `UnsupportedError('LambertW branch point at -1/e')`; if non-zero → `return _expandTaylorSeries(LambertW(inner), variable, point, order);`. If zero: empty `u` → empty series; else loop `for (var k = 1; k * u.valuation < order; k++)`.
  2. In `_expandAsin`, `_expandAtanh`, `_expandAcosh`: if `(1 - u²)` (resp. `u² - 1`) has zero constant term, throw `UnsupportedError('Branch point singularity')`.
- **Verification:**
  - `LambertW(x).series('x', point: Constant.e, order: 3) == Expr.parse('1 + (x - e)/(2*e) - 3*(x - e)^2/(16*e^2) + O((x - e)^3)').simplify()`
  - `Expr.parse('asin(x)').series('x', point: 1, order: 3)` throws `UnsupportedError`

---

## [TASK-14] Summation: integer-index assumptions and convergence guard (`P0-Bug`)

- **Files:** `lib/src/symbolic/calculus/summation.dart` (`computeSum`), `lib/src/symbolic/calculus/product.dart` (`computeProduct`)
- **Problem:**
  1. The summand is simplified without assuming the index is an integer, so `Σ sin(πk)`, `Σ (-1)^(2k)·x`, `Σ cos(πk)` are not reduced.
  2. Infinite sums are evaluated as `lim_{N→∞}` of the finite closed form even when it contains `b^N` with symbolic `b`; the result is unconditional although convergence requires `|b| < 1` (e.g. `Σ_{k≥0} x^k`).
- **Specification:**
  1. In `computeSum`/`computeProduct`, compute `final indexAssumptions = assumptions.assume(variable, VariableDomain.integer);` and use it for simplifying the summand and per-term substitutions (not for the final result, where `variable` is bound).
  2. Before the limit step: if `finite` contains `Pow(base, e)` with `e.dependsOn(limitVarName)` and `base` has free variables, skip the limit and return `Piecewise([(closedForm, LessThan(Abs(base), 1))], otherwise: Sum(...unevaluated))` where `closedForm` is the limit computed treating `|base| < 1` (i.e. replace `base^e` by `0`).
- **Verification:**
  - `Sum(Expr.parse('sin(pi*k)'), 'k', 1, n).simplify() == IntegerNumber.zero`
  - `Sum(Expr.parse('(-1)^(2*k)'), 'k', 1, n).simplify() == n`
  - `Sum(Expr.parse('x^k'), 'k', 0, Constant.infinity).simplify()` is a `Piecewise` with branch `1/(1 - x)` under `abs(x) < 1`
  - `Sum(Expr.parse('(1/2)^k'), 'k', 0, Constant.infinity).simplify() == IntegerNumber.two`

---

## [TASK-15] Solver: extraneous roots, radical and logarithmic equations (`P0-Bug`)

- **Files:** `lib/src/symbolic/solver/univariate.dart` (`solveEquation`, `_solveUnfiltered`), `lib/src/symbolic/solver/transcendental.dart` (`isolateAndInvert`, `_solveProductTranscendental`)
- **Problem:**
  1. Candidate roots are never substituted back; non-equivalent transformations leak extraneous roots.
  2. `√f(x) + g(x) = 0` with polynomial `f, g` returns `[]` (`√(x+2) - x`).
  3. Sums of logs (`ln(x-1) + ln(x+1) - ln 3`) are not combined before isolation.
  4. `ln(x)/x = c` is not solved (`expr / b` depends on `x`); correct solution `x = exp(-W(-c))`.
- **Specification:**
  1. Add `bool _isValidRoot(Expr original, String variable, Expr root, Assumptions assumptions)`: `v = original.substitute(variable, root).simplify(assumptions)`; reject if `v` contains `Constant.undefined`/`Constant.infinity`, or is a numeric constant with `|v| > 1e-9` (use `approximate()` for exact non-zero detection when `v` is not syntactically zero). Apply it to every root returned from `solveEquation`, skipping roots containing free symbolic parameters.
  2. Radical isolation in `isolateAndInvert` for `Add`: if exactly one term is `c·Pow(base, p/q)` (`2 ≤ q ≤ 4`, `base.dependsOn(variable)`) and the rest `R` is radical-free: solve `(c^q · base^p - (-R)^q).expand().simplify() = 0`, then filter with `_isValidRoot` against the original.
  3. Log combination: if `expr` has ≥ 2 `Ln` terms with rational coefficients, rewrite `Σ a_i ln(u_i) + C` as `ln(∏ u_i^{a_i}) + C` before isolation; filter roots requiring each original `u_i` to simplify to a positive value.
  4. `_solveProductTranscendental`: add case `Pow(arg, -1) · Ln(arg)` with `arg` = the variable-dependent inner: solutions `arg = exp(-W_k(-c))` for `k ∈ {0, -1}` when `-1/e ≤ -c < 0`, `k = 0` only when `-c ≥ 0`.
- **Verification:**
  - `Expr.parse('sqrt(x + 2) - x').solve('x') == [IntegerNumber.two]`
  - `Expr.parse('sqrt(x) + 1').solve('x').isEmpty`
  - `Expr.parse('ln(x - 1) + ln(x + 1) - ln(3)').solve('x') == [IntegerNumber.two]`
  - `Expr.parse('ln(x)/x - 1/(2*e)').solve('x')` contains `exp(-LambertW(-1/(2*e)))` (2 real roots)

---

## [TASK-16] Bareiss redundant work; polynomial system root loss (`P2-Math`)

- **Files:** `lib/src/symbolic/linear/bareiss.dart` (`_exactDivide`, `_divideByVariable`), `lib/src/symbolic/solver/polynomial_system.dart` (`_backSubstitute`), `lib/src/symbolic/algebra/term_accumulator.dart` (`extractPolynomialCoefficients`)
- **Problem:**
  1. `_backSubstitute` verifies with `.simplify()` only; `(1 + √2)² - 2(1 + √2) - 1` is not recognized as `0`, so valid radical roots are dropped.
  2. `_divideByVariable` calls `.expand().simplify()` and then `extractPolynomialCoefficients`, which expands again; `_exactDivide` attempts `(num/den).simplify()` before polynomial division and then falls back to full `factor()` of both operands per matrix entry.
- **Specification:**
  1. `_backSubstitute`: replace both verification `simplify()` calls with `.expand().simplify()`.
  2. `extractPolynomialCoefficients(expr, v)`: skip `expand().simplify()` when `expr.isSimplified && !_needsExpansion(expr)`, with private `_needsExpansion` = any `Mul` containing an `Add` factor, or `Pow` with `Add` base and positive integer exponent (recursive via `anyNode`).
  3. `_exactDivide`: order attempts as (a) `den` is a `Number` → direct division, (b) `_polynomialLongDivide`, (c) factor-cancel fallback; remove the leading `(num/den).simplify()` attempt.
- **Verification:**
  - `[Expr.parse('x^2 - 2*x - 1'), Expr.parse('y - x^2')]` solved for `['x', 'y']` returns both `{x: 1 - sqrt(2), y: 3 - 2*sqrt(2)}` and `{x: 1 + sqrt(2), y: 3 + 2*sqrt(2)}`
  - Existing `test/symbolic/linear/` suite passes unchanged.

---

## [TASK-17] String formatter: `-(x * y)` (`P0-Bug`)

- **Files:** `lib/src/symbolic/textualization/string.dart` (`_formatMulNumerator`)
- **Problem:** `Mul([-1, x, y])` is formatted as `-(x * y)` because the operand `Mul(rest)` (precedence 2) is formatted with parent precedence 4. Also `-x * z / y` prints `-(x * z) / y`.
- **Specification:** In the `[IntegerNumber(isNegativeOne: true), ...final rest]` case:
  - `rest.length == 1` → `'-${_formatExpr(rest.single, 3, decimalPlaces)}'`.
  - `rest.length > 1` → `'-${_formatExpr(rest.first, 3, decimalPlaces)} * ${_formatMulNumerator(rest.sublist(1), 2, decimalPlaces)}'`.
  Wrap in parentheses iff `3 < parentPrec` (unchanged).
- **Verification:**
  - `Mul([IntegerNumber.negativeOne, x, y]).toString() == '-x * y'`
  - `Expr.parse('-x * z / y').toString() == '-x * z / y'`
  - `Expr.parse('-(a + b)').toString() == '-(a + b)'`
  - Round-trip: `Expr.parse(e.toString()) == e` for each of the above.

---

## [TASK-18] LaTeX/MathML: integrand grouping and bound-variable names (`P0-Bug`)

- **Files:** `lib/src/symbolic/textualization/latex.dart` (`Integral`, `Derivative`, `Limit`, `Sum`, `Product` arms), `lib/src/symbolic/textualization/mathml.dart` (same arms)
- **Problem:**
  1. `Integral(x + 1, 'x')` renders `\int x + 1 \, dx` (reads as `(\int x) + 1`).
  2. Bound variables are interpolated raw (`d$variable`, `\frac{d}{d$variable}`, `\lim_{$variable ...}`), so `theta` renders `dtheta` instead of `d\theta`, and multi-letter names are not upright/grouped, inconsistent with how `Variable` nodes render.
- **Specification:**
  1. Format the integrand via `_formatMulRight` (as Derivative/Limit already do) so `Add`/relational integrands are parenthesized.
  2. Render every bound-variable name through the same function used for `Variable` nodes (`_toLatex(Variable(variable), decimalPlaces)` / `_toMathMl(Variable(variable), …)`); differential is `\, \mathrm{d}<var>` in LaTeX and `<mo>&#x2146;</mo><var>` (or existing `d` convention, applied consistently) in MathML.
- **Verification:**
  - `Integral(x + 1, 'x').toLatex() == r'\int \left(x + 1\right) \, \mathrm{d}x'` (adapt parenthesis macro to the one `_formatMulRight` emits)
  - `Integral(Variable('theta'), 'theta').toLatex()` contains `\mathrm{d}\theta`
  - `Derivative(Variable('theta'), 'theta').toLatex()` contains `\frac{d}{d\theta}`

---

## [TASK-19] Bytecode compiler/evaluator correctness and caching (`P1-Architecture`)

- **Files:** `lib/src/symbolic/compiler/bytecode.dart` (`_computeMaxStack`), `lib/src/symbolic/compiler/evaluator.dart` (`BytecodeEvaluator._runReal`, `_runComplex`, `_evalNodeReal`), `lib/src/symbolic/compiler.dart` (`CompilerExtension.evaluate`, `evaluateComplex`)
- **Problem:**
  1. `_computeMaxStack` walks instructions linearly ignoring jumps; each `Piecewise` branch adds `+1`, overestimating depth (and corrupting depth for following code).
  2. `abs(sqrt(x))` at `x = -4` returns `NaN` (correct `2`): the real path never retries in complex mode unless `Re`/`Im`/`Arg`/`Conjugate` are present, and those branches inside `_runReal` are dead code (their presence forces complex mode).
  3. `Op.lt/le/gt/ge` in `_runComplex` compare real parts only, ignoring non-zero imaginary parts and `NaN`.
  4. `_evalNodeReal` recompiles inner bytecode for `Integral`, `Sum`, `Product` on every evaluation; `expr.evaluate(...)` builds a fresh `BytecodeEvaluator` per call.
- **Specification:**
  1. `_computeMaxStack`: keep `List<int?> depthAt` of length `instructions.length + 1`. On `jumpIfFalse(t)`: pop, set `depthAt[t] = current`. On `jump(t)`: set `depthAt[t] = current`; the next instruction starts from `depthAt[pc]` if recorded. At each `pc`, if `depthAt[pc] != null`, `current = depthAt[pc]!`.
  2. `_runReal`: before returning, if `stack[0].isNaN` and no variable input was `NaN`, rerun `_runComplex`; return its real part when `|im| ≤ 1e-15·(|re| + 1)`, else `NaN`. Delete the unreachable `isNaN` fallbacks in `Op.re/im/arg` cases.
  3. `_runComplex` comparisons: if either operand is `NaN` or has `|im| > 1e-15·(|re| + 1)`, push `Complex.nan`; else compare real parts.
  4. Cache inner programs per evaluator: `final _innerPrograms = HashMap<Expr, BytecodeEvaluator>();` filled lazily in `_evalNodeReal`/complex counterpart. Cache top-level evaluators in `CompilerExtension` via `static final Expando<BytecodeEvaluator> _cache` keyed on the `Expr` instance.
- **Verification:**
  - `Expr.parse('abs(sqrt(x))').toFunction1D('x')(-4.0) == 2.0`
  - `Expr.parse('sqrt(x)').toFunction1D('x')(-4.0).isNaN`
  - Max stack of `Piecewise` with 4 branches each a single constant equals 1 (plus condition depth), not 4.
  - `Expr.parse('sum(k*x, k, 1, 100)')` evaluated at 1000 points compiles the inner summand once (expose `@visibleForTesting int get innerCompileCount`).
