# Symbolic Mathematics Library Audit & Specification (`TASKS.md`)

All 18 previous tasks (`[TASK-00]` through `[TASK-17]`) were verified against `HEAD` (`dart analyze` clean, all 556 symbolic & dependency test suites passing). The remaining high-priority mathematical, simplification, numerical overflow, and formatting issues discovered during verification and extended audit are specified below in dependency order.

---

## [TASK-18] Canonical Ratio Cancellation and Asymptotic Log-Space Evaluation for `Factorial`, `Gamma`, `Beta`, and `Binomial` (`P0-Bug`)

- **Files:**
  - `lib/src/symbolic/algebra/simplify/multiplicative.dart` (`simplifyMul`, `_reduceFactorialAndGammaRatios`)
  - `lib/src/symbolic/algebra/simplify/special.dart` (`simplifyBeta`, `simplifyBinomial`)
  - `lib/src/symbolic/compiler/evaluator.dart` (`_evalRealBinomial`, `BytecodeEvaluator._runReal`, `BytecodeEvaluator._runComplex`)
  - `lib/src/symbolic/algebra/approximate.dart` (`_approximateNode`, `_approximateMul`)
- **Problem:**
  1. **Unreduced Factorial & Gamma Quotients in `simplifyMul`:**
     `simplifyGamma` and `simplifyFactorial` only expand integer arguments up to $n \le 101$ / $n \le 100$ into literal `IntegerNumber`s (`special.dart:107, 656`) to prevent giant AST integers. However, `simplifyMul` has no ratio-cancellation rule for `Factorial(u) / Factorial(v)` or `Gamma(u) / Gamma(v)` when $u - v = k \in \mathbb{Z}$ (whether numeric like `10000! / 9999!` and `gamma(10000) / gamma(9999)` or symbolic like `(n + 1)! / n!` and `gamma(x + 2) / gamma(x)`). Thus `10000! / 9999!` remains an unsimplified `Mul([Pow(Factorial(9999), -1), Factorial(10000)])`.
  2. **Catastrophic Overflow (`Infinity / Infinity = NaN -> undefined`) in Numeric Evaluation & Approximation:**
     - In IEEE-754 `double`, $\Gamma(x)$ overflows to `double.infinity` for $x > 171.624$.
     - When `gamma(10000) / gamma(9999)` or `10000! / 9999!` is evaluated via `.evaluate()` or `.approximate()`, the numerator and denominator each evaluate to `double.infinity`, and `double.infinity / double.infinity` produces `NaN` (`Constant.undefined` in `.approximate()`) instead of `9999`!
     - In `special.dart:602`, `simplifyBeta(m, n)` caps exact rational reduction at `m + n <= 18` (`IntegerNumber(10000), IntegerNumber(2)` stays `Beta(2, 10000)` instead of `1 / 49995000`).
     - In `special.dart:680-684` (`simplifyBinomial` on `RealNumber`) and `evaluator.dart:939-947` (`_evalRealBinomial`), $\binom{n}{k}$ is computed via `gamma(n + 1) / (gamma(k + 1) * gamma(n - k + 1))` instead of `special_gamma.combination(n, k)` / `gammaLn`, returning `NaN` / `Constant.undefined` for `binomial(1000.0, 2.0)` or `binomial(10000, 5000).approximate()` instead of `499500.0` or `double.infinity`!
     - In `special.dart:706`, `simplifyBinomial(IntegerNumber(n), IntegerNumber(k))` only folds when `min(k, n - k) <= 1000`, and when `min(k, n - k) > 1000`, `binomial(10000, 2000) / binomial(10000, 1999)` is neither cancelled symbolically nor evaluable in log-space.
- **Specification:**
  1. **Exact Symbolic Ratio Cancellation in `simplifyMul` (`lib/src/symbolic/algebra/simplify/multiplicative.dart`):**
     - Add a pass `_reduceFactorialAndGammaFactors(Map<Expr, Expr> baseExponents, {required Assumptions assumptions})` returning an extra `Number` multiplier (to fold into `coeff`) before constructing `remainingFactors`:
       - Collect all entries in `baseExponents` whose base is `Factorial(u)`, `Gamma(u)`, or `Binomial(n, k)` with integer exponents $e \in \mathbb{Z} \setminus \{0\}$.
       - **Pairwise `Factorial(u)` / `Factorial(v)` cancellation:**
         Whenever `baseExponents` has `Factorial(u)` with integer exponent $e_1 > 0$ and `Factorial(v)` with integer exponent $e_2 < 0$, compute `diff = simplifySub(u, v, assumptions: assumptions)`.
         If `diff case IntegerNumber(asInt: final d?)` with `d.abs() <= 1000`:
         - If $d == 0$: exponents cancel directly.
         - If $d > 0$ (and either $v$ is a non-negative `IntegerNumber` or `isProvenReal(v, assumptions)` / symbolic): $\frac{u!}{v!} = \prod_{j=1}^d (v + j)$.
         - If $d < 0$: $\frac{u!}{v!} = \frac{1}{\prod_{j=1}^{-d} (u + j)}$.
         Consume $\min(e_1, -e_2)$ units of the pair and multiply the resulting rising-factorial factors into `baseExponents` / `coeff`.
       - **Pairwise `Gamma(u)` / `Gamma(v)` cancellation:**
         Whenever `baseExponents` has `Gamma(u)` with integer exponent $e_1 > 0$ and `Gamma(v)` with integer exponent $e_2 < 0$, compute `diff = simplifySub(u, v, assumptions: assumptions)`.
         If `diff case IntegerNumber(asInt: final d?)` with `d.abs() <= 1000`:
         - If $d > 0$: $\frac{\Gamma(v + d)}{\Gamma(v)} = \prod_{j=0}^{d-1} (v + j)$.
         - If $d < 0$: $\frac{\Gamma(u)}{\Gamma(u - d)} = \frac{1}{\prod_{j=0}^{-d-1} (u + j)}$.
       - **Cross `Factorial(u)` / `Gamma(v)` cancellation:**
         Using $u! = \Gamma(u + 1)$, if `(u + 1) - v` is an integer $d$ with $|d| \le 1000$, apply the same Pochhammer product reduction!
       - **Pairwise `Binomial(n1, k1)` / `Binomial(n2, k2)` cancellation:**
         Whenever `Binomial(n1, k1)` (exponent $e_1 > 0$) and `Binomial(n2, k2)` (exponent $e_2 < 0$) have integer differences `dn = simplifySub(n1, n2)` and `dk = simplifySub(k1, k2)` with `dn is IntegerNumber` and `dk is IntegerNumber` and `dn.asInt != null && dk.asInt != null && dn.asInt!.abs() + dk.asInt!.abs() <= 1000`:
         Rewrite $\frac{\binom{n_1}{k_1}}{\binom{n_2}{k_2}} = \frac{\Gamma(n_1 + 1)}{\Gamma(n_2 + 1)} \cdot \frac{\Gamma(k_2 + 1)}{\Gamma(k_1 + 1)} \cdot \frac{\Gamma(n_2 - k_2 + 1)}{\Gamma(n_1 - k_1 + 1)}$ and expand each of the three shifted Gamma ratios into exact rational/symbolic Pochhammer products!
  2. **Extend Exact `simplifyBeta` and Fix `simplifyBinomial` (`lib/src/symbolic/algebra/simplify/special.dart`):**
     - In `simplifyBeta`: when `a` and `b` are positive `IntegerNumber`s ($m, n \ge 1$) with $\min(m, n) \le 1000$:
       $\operatorname{B}(m, n) = \frac{(m - 1)!\,(n - 1)!}{(m + n - 1)!} = \frac{1}{n \binom{m + n - 1}{m - 1}} = \frac{1}{m \binom{m + n - 1}{n - 1}}$. Compute this directly via `Integer.binomial` instead of requiring $m + n \le 18$!
     - In `simplifyBinomial`:
       - For `RealNumeric` inputs (`nExpr is RealNumber || kExpr is RealNumber`), replace the naive `gn / (gk * gnk)` formula (lines 678–684) with `_evalRealBinomial(n, k)` using `special_gamma.combination(n, k)` for non-negative values and reflection/log-gamma for negative non-integer $n$, avoiding intermediate `gamma` overflow.
  3. **Fix Overflow in `_evalRealBinomial` and Log-Space Product Evaluation (`lib/src/symbolic/compiler/evaluator.dart` and `lib/src/symbolic/algebra/approximate.dart`):**
     - In `evaluator.dart:939` (`_evalRealBinomial(double n, double k)`):
       - If `n >= 0.0`: delegate to `special_gamma.combination(n, k)` (which already uses `combinationLn` / `gammaLn` when $k > 1000$ or $n$ is non-integer!).
       - If `n < 0.0 && k == k.roundToDouble() && k >= 0.0`: use upper negation $(-1)^k \binom{-n + k - 1}{k}$ via `special_gamma.combination(-n + k - 1.0, k)`.
       - For general real $n, k$: evaluate via `gammaLn` with sign tracking $\Gamma(z) = \frac{\pi}{\sin(\pi z)\Gamma(1 - z)}$ when $z < 0$ so log-magnitudes subtract before calling `math.exp(...)`.
     - In `approximate.dart`: before approximating children of a `Mul`, simplify the `Mul` first if not already simplified; if a `Mul` still contains unsimplified `Gamma`, `Factorial`, or `Binomial` factors with negative exponents whose direct approximation yields `Constant.undefined` (`NaN`), evaluate the product of `Gamma`/`Factorial` factors in log-gamma space ($\sum e_i \ln|\Gamma(u_i)|$ with tracked signs $\prod (\operatorname{sgn}\Gamma(u_i))^{e_i}$).
- **Verification:**
  - `Expr.parse('gamma(10000) / gamma(9999)').simplify()` -> `IntegerNumber.of(9999)`
  - `Expr.parse('10000! / 9999!').simplify()` -> `IntegerNumber.of(10000)`
  - `Expr.parse('(n + 2)! / n!').simplify()` -> `Expr.parse('(1 + n) * (2 + n)').simplify()`
  - `Expr.parse('gamma(x + 2) / gamma(x)').simplify()` -> `Expr.parse('x * (1 + x)').simplify()`
  - `Expr.parse('binomial(10000, 2000) / binomial(10000, 1999)').simplify()` -> `FractionNumber(8001, 2000)`
  - `Expr.parse('binomial(1000.0, 2.0)').simplify()` -> `const RealNumber(499500.0)`
  - `Expr.parse('binomial(1000, 500)').evaluate()` -> `2.7028824094543656e299` (finite double, not `NaN`)
  - `Expr.parse('beta(2, 10000)').simplify()` -> `FractionNumber(Integer.one, Integer.from(99990000))`

---

## [TASK-19] Value Equality for `Assumptions` and Subscripted Variable Formatting in MathML (`P1-Architecture`)

- **Files:**
  - `lib/src/symbolic/assumptions.dart` (`Assumptions.operator ==`, `Assumptions.hashCode`)
  - `lib/src/symbolic/textualization/mathml.dart` (`_toMathMl`, `_formatOrderTermMathMl`, `_formatVariableMathMl`)
- **Problem:**
  1. `Assumptions` is an immutable value class (`domains` and `defaultDomain`), yet it does not override `operator ==` or `hashCode`. Two `Assumptions(domains: {'x': VariableDomain.real})` instances with equal domain maps compare unequal (`a == b` is `false`).
  2. In `[TASK-16]`, `_formatVariableLatex` in `latex.dart:358` was updated to format subscripted variable names (`x_1` -> `x_{1}`, `alpha_0` -> `\alpha_{0}`), but `mathml.dart:37` still formats `Variable(:final name)` as `'<mi>${_escapeXml(name)}</mi>'` instead of `<msub><mi>x</mi><mn>1</mn></msub>` (or `<msub><mi>&alpha;</mi><mn>0</mn></msub>`), violating 1:1 LaTeX/MathML typographic symmetry required by `AGENTS.md`.
- **Specification:**
  1. In `lib/src/symbolic/assumptions.dart`:
     - Override `operator ==` and `hashCode` on `Assumptions` (using `const MapEquality<String, VariableDomain>()` from `package:collection/collection.dart` or manual entry comparison).
  2. In `lib/src/symbolic/textualization/mathml.dart`:
     - Add `_formatVariableMathMl(String name)`:
       - Map standard Greek letter names (`alpha` -> `α`, `beta` -> `β`, ..., `Omega` -> `Ω`) matching `_greekLetters` in `latex.dart`.
       - When `name` contains an underscore `base_sub` (`idx > 0 && idx < name.length - 1`), format `base` as `<mi>...</mi>` and `sub` as `<mn>$sub</mn>` if `sub` is all ASCII digits or `<mi>${_escapeXml(sub)}</mi>` otherwise, wrapped in `<msub>...</msub>`.
     - Use `_formatVariableMathMl` for `Variable(:final name)` in `_toMathMl` and in `_formatOrderTermMathMl`.
- **Verification:**
  - `Assumptions(domains: {'x': VariableDomain.positive}) == Assumptions.none.copyWith(domains: {'x': VariableDomain.positive})` -> `true`
  - `Variable('x_1').toMathMl(root: false)` -> `'<msub><mi>x</mi><mn>1</mn></msub>'`
  - `Variable('alpha_0').toMathMl(root: false)` -> `'<msub><mi>α</mi><mn>0</mn></msub>'`

---

## [TASK-20] Share Simplification Memoization Cache with `MonomialAccumulator` (`P3-Perf`)

- **Files:**
  - `lib/src/symbolic/algebra/simplify.dart` (`_simplify`)
  - `lib/src/symbolic/algebra/simplify/additive.dart` (`simplifyAdd`)
- **Problem:**
  In `simplify.dart:93`, `_simplify` delegates `Add(:final terms)` to `simplifyAdd(simplifiedTerms, assumptions: assumptions)`. Inside `simplifyAdd` (`additive.dart:20`), `MonomialAccumulator` is constructed with `simplify: (e) => simplifyExpr(e, assumptions: assumptions)`, which allocates a fresh `HashMap<Expr, Expr>()` on every fraction combination instead of reusing the active DAG traversal `cache` from `_simplify`.
- **Specification:**
  1. Add an optional `{Expr Function(Expr)? simplify}` parameter to `simplifyAdd`:

     ```dart
     Expr simplifyAdd(
       List<Expr> terms, {
       required Assumptions assumptions,
       Expr Function(Expr)? simplify,
     })
     ```

     and pass `simplify: simplify ?? (e) => simplifyExpr(e, assumptions: assumptions)` to `MonomialAccumulator`.
  2. In `_simplify` (`lib/src/symbolic/algebra/simplify.dart:93`), pass `simplify: (e) => _simplify(e, assumptions, cache)` to `simplifyAdd`.
- **Verification:**
  - Confirm `dart test test/symbolic/` passes with zero analyzer warnings.

---

## [TASK-21] Exact Odd-Denominator Rational Roots of Negative Rationals (`P0-Bug`)

- **Files:**
  - `lib/src/symbolic/ast/number.dart` (`Number._powRationalFrac`)
  - `lib/src/symbolic/algebra/simplify/power.dart` (`_extractRationalRadical`)
- **Problem:**
  In `Number._powRationalFrac` (`number.dart:138`), `if (baseRat.isNegative) return null;` unconditionally rejects all negative rational bases, even when the exponent denominator $q$ is odd! Meanwhile, `evaluator.dart` (`oddRootMode = 1` or `2` in `bytecode.dart:288`) evaluates odd-denominator fractional powers of negative real numbers using the real odd root $(-|x|^{1/q})^p$. Because `_powRationalFrac` and `_extractRationalRadical` reject negative bases for odd $q$, `(-27)^(1/3)` and `(-8)^(2/3)` stay unevaluated `Pow(IntegerNumber(-27), FractionNumber(1, 3))` instead of simplifying to `-3` and `4` (failing `wester_C8`: `(-27)^(1/3) + (-1)^(1/2) -> -3 + i`).
- **Specification:**
  1. In `Number._powRationalFrac(RationalNumber baseRat, FractionNumber exponent)` (`lib/src/symbolic/ast/number.dart:138`):
     - When `baseRat.isNegative`:
       - If `exponent.denominator.isEven`: return `null` (handled by `simplifyPow` pulling out `i` when $q = 2$).
       - If `exponent.denominator.isOdd`: compute the odd root of `baseRat.abs()` (`exactIntegerRoot(baseRat.numerator.abs(), q)` and `exactIntegerRoot(baseRat.denominator, q)`). If both exist, return `RationalNumber.of(-rootNum, rootDen).powInteger(p)`!
  2. In `_extractRationalRadical(RationalNumber base, FractionNumber exponent, {required Assumptions assumptions})` (`lib/src/symbolic/algebra/simplify/power.dart:378`):
     - When `base.isNegative && exponent.denominator.isOdd`: extract the radical on `base.abs()` and multiply by `-1` if `exponent.numerator.isOdd` (or `+1` if `exponent.numerator.isEven`), e.g. `(-54)^(1/3) -> -3 * 2^(1/3)` and `(-8)^(2/3) -> 4`.
- **Verification:**
  - `Expr.parse('(-27)^(1/3) + (-1)^(1/2)').simplify()` -> `ComplexNumber(IntegerNumber.of(-3), IntegerNumber.one)`
  - `Expr.parse('(-8)^(2/3)').simplify()` -> `IntegerNumber.of(4)`
  - `Expr.parse('(-54)^(1/3)').simplify()` -> `Expr.parse('-3 * 2^(1/3)').simplify()`

---

## [TASK-22] Multi-Level Exponential Tower Expansion in Gruntz Limit Engine (`P2-Math`)

- **Files:**
  - `lib/src/symbolic/calculus/limit.dart` (`_gruntzLimit`, `_rewriteExpInOmega`, `_rewriteSingleExp`, `_findDominantExpScale`, `_extractDominantPolynomialTerm`)
- **Problem:**
  In `limit.dart`, `_findDominantExpScale` and `_extractDominantPolynomialTerm` only inspect polynomial terms in `variable` inside `exp(inner)`, failing on Gruntz's nested exponential problems:
  1. `gruntz_8_2`: $\lim_{x \to \infty} e^x \left( \exp\left(\frac{1}{x} + e^{-x} + e^{-x^2}\right) - \exp\left(\frac{1}{x} - e^{-e^x}\right) \right) = 1$.
     Here `_findDominantExpScale` finds `maxDeg = 2` (from $e^{-x^2}$) and sets $\omega = e^{-x^2}$, rewriting $e^{-x^2} \mapsto \omega$ while leaving $e^x$, $e^{-x}$, and $1/x$ untouched, so `toPowerSeries` in $\omega$ fails! Worse, in the first step `exp(1/x + exp(-x) + exp(-x^2))` had `exp(-x^2)` dropped or unexpanded relative to $e^{-x}$.
  2. `gruntz_8_3`: $\lim_{x \to \infty} \left( \exp\left(\frac{e^{x - e^{-x}}}{1 - 1/x}\right) - \exp(e^x) \right) = +\infty$.
     Because the outer exponent $\frac{e^{x - e^{-x}}}{1 - 1/x}$ is not a polynomial in $x$, `_extractDominantPolynomialTerm` returns `null`.
- **Specification:**
  In `lib/src/symbolic/calculus/limit.dart`:
  1. **Asymptotic Exponential Difference / Factoring in `_gruntzLimit` (`gruntz_8_2` & `gruntz_8_3`):**
     - Before `_findDominantExpScale`, add an asymptotic exponential factoring rule `_expandSubdominantExponentials(Expr expr, String variable, Assumptions assumptions)`:
       - Whenever an `exp(A)` node has an exponent $A(x)$ whose limit as $x \to +\infty$ is `0` (`computeLimit(A, variable, Constant.infinity) == 0`), or $A = A_0 + \delta(x)$ where $\lim_{x \to \infty} \delta(x) = 0$ while $A_0$ is common to sibling `exp` terms in a difference `exp(A_0 + d1) - exp(A_0 + d2)`:
         Factor `exp(A_0 + d1) - exp(A_0 + d2) = exp(A_0) * (exp(d1) - exp(d2))`!
         For small arguments $\delta(x) \to 0$ inside `exp(d1) - exp(d2)` (such as $d_1 = e^{-x} + e^{-x^2}$ and $d_2 = -e^{-e^x}$ in `gruntz_8_2` after factoring out $e^{1/x}$), replace $\exp(\delta) - 1$ by its leading asymptotic series $\delta + \frac{1}{2}\delta^2$ or drop subdominant terms ($e^{-x^2} \ll e^{-x}$ and $e^{-e^x} \ll e^{-x}$) by comparing $\lim_{x \to \infty} \frac{\ln|\delta_i|}{\ln|\delta_j|}$!
       - Specifically, for `gruntz_8_2`: factoring $e^{1/x}$ from $\exp(1/x + e^{-x} + e^{-x^2}) - \exp(1/x - e^{-e^x})$ gives $e^x \cdot e^{1/x} \cdot (\exp(e^{-x} + e^{-x^2}) - \exp(-e^{-e^x}))$. Since $e^{-x} + e^{-x^2} \to 0$ and $-e^{-e^x} \to 0$ with dominant term $e^{-x}$, expanding $\exp(u) = 1 + u + O(u^2)$ yields $e^x \cdot e^{1/x} \cdot (e^{-x} + e^{-x^2} + e^{-e^x}) = e^{1/x}(1 + e^{x - x^2} + e^{x - e^x}) \to 1$!
       - For `gruntz_8_3`: in $\exp(U) - \exp(V)$ where $U(x) \to +\infty$ and $V(x) \to +\infty$, write $\exp(U) - \exp(V) = \exp(V) \cdot (\exp(U - V) - 1)$. Compute $L_\Delta = \lim_{x \to \infty} (U - V)$ (for $U = \frac{e^{x - e^{-x}}}{1 - 1/x} = e^x(1 - e^{-x} + \dots)(1 + 1/x + \dots)$ and $V = e^x$, $U - V \sim \frac{e^x}{x} \to +\infty$). Since $V \to +\infty$ and $U - V \to +\infty$ (or $> 0$), $\exp(V)(\exp(U - V) - 1) \to +\infty$!
- **Verification:**
  - `Expr.parse('exp(x) * (exp(1/x + exp(-x) + exp(-x^2)) - exp(1/x - exp(-exp(x))))').limit('x', Constant.infinity)` -> `IntegerNumber.one`
  - `Expr.parse('exp(exp(x - exp(-x)) / (1 - 1/x)) - exp(exp(x))').limit('x', Constant.infinity)` -> `Constant.infinity`

---

## [TASK-23] Weighted Binomial Sums $\sum_{k=0}^n P(k)\binom{n}{k} x^k y^{n-k}$ and Upper-Index Summation $\sum_{k=a}^n \binom{k}{m}$ (`P2-Math`)

- **Files:**
  - `lib/src/symbolic/calculus/summation.dart` (`_antidifferenceCore`, `_tryBinomialSum`)
- **Problem:**
  1. In `_tryBinomialSum` (`summation.dart:667`), only pure geometric factors $x^k y^{n-k} \binom{n}{k}$ are handled. If `varFactors` contains a polynomial in $k$ such as $k \binom{n}{k}$ or $k^2 \binom{n}{k}$, line 731 returns `null` (`sum_binomial_2`: `sum(k * binomial(n, k), k, 0, n)` fails).
  2. In `_antidifferenceCore` (`summation.dart:307`), there is no antidifference rule for $\binom{k}{m}$ (or $\binom{k + c}{m}$) where the summation variable $k$ is in the **upper** index and $m$ is independent of $k$. By Pascal's identity, $\Delta_k \binom{k}{m + 1} = \binom{k + 1}{m + 1} - \binom{k}{m + 1} = \binom{k}{m}$, so the antidifference of $\binom{k + c}{m}$ with respect to $k$ is simply $\binom{k + c}{m + 1}$ (`sum_binomial_upper`: `sum(binomial(k, 2), k, 2, n) == binomial(n + 1, 3)` fails).
- **Specification:**
  1. **Upper-Index Binomial Antidifference (`_antidifferenceCore` in `lib/src/symbolic/calculus/summation.dart`):**
     - When `term` is `Binomial(left, right)` where `!right.dependsOn(variable)` and `left.matchLinear(variable)` is `(a: IntegerNumber(isOne: true), b: final c)`:
       Return `Binomial((Variable(variable) + c).simplify(), (right + IntegerNumber.one).simplify())`!
     - Note: in `computeSum`, when evaluating $F(b + 1) - F(a)$ for $\sum_{k=a}^b \binom{k + c}{m}$, if $a + c = m$ (e.g. $\sum_{k=2}^n \binom{k}{2}$ where $F(k) = \binom{k}{3}$ and $F(2) = \binom{2}{3} = 0$), `simplifyBinomial(2, 3)` already returns `0`, yielding $\binom{n + 1}{3}$!
  2. **Polynomial-Weighted Binomial Sums (`_tryBinomialSum` in `lib/src/symbolic/calculus/summation.dart`):**
     - In `_tryBinomialSum(Expr term, String variable, Expr a, Expr b)`:
       - Allow lower bound `a` to be `0` OR `1` when the polynomial factor in `k` vanishes at `k = 0` (or adjust for `k = 0`).
       - Separate `varFactors` into exponential factors (`Pow(base, lin_in_k)`) and polynomial factors in `variable` (via `extractPolynomialCoefficients(polyPart, variable)` up to degree $d \le 4$).
       - Express any polynomial $P(k)$ of degree $d \le 4$ in the falling-factorial basis $P(k) = \sum_{j=0}^d s_j k^{\underline{j}}$ where $k^{\underline{j}} = k(k-1)\cdots(k-j+1)$.
       - Use the identity $k^{\underline{j}} \binom{n}{k} = n^{\underline{j}} \binom{n - j}{k - j}$, so:
         $$\sum_{k=0}^n k^{\underline{j}} \binom{n}{k} x^k y^{n-k} = n^{\underline{j}} x^j (x + y)^{n - j}$$
         For example:
         - $k = k^{\underline{1}} \implies \sum_{k=0}^n k \binom{n}{k} = n \cdot 2^{n - 1}$.
         - $k^2 = k^{\underline{2}} + k^{\underline{1}} \implies \sum_{k=0}^n k^2 \binom{n}{k} = n(n - 1)2^{n - 2} + n 2^{n - 1} = n(n + 1)2^{n - 2}$.
- **Verification:**
  - `Expr.parse('k * binomial(n, k)').sum('k', 0, Variable('n'))` -> `Expr.parse('n * 2^(n - 1)').simplify()`
  - `Expr.parse('k^2 * binomial(n, k)').sum('k', 0, Variable('n'))` -> `Expr.parse('n * (n + 1) * 2^(n - 2)').simplify()`
  - `Expr.parse('binomial(k, 2)').sum('k', 2, Variable('n'))` -> `Expr.parse('binomial(n + 1, 3)').simplify()`

---

## [TASK-24] Solve Polynomial Equations in Exponential / Function Substitutions $P(b^{a x + c}) = 0$ (`P2-Math`)

- **Files:**
  - `lib/src/symbolic/solver/transcendental.dart` (`isolateAndInvert`, `_tryPolynomialInExponential`)
- **Problem:**
  `Expr.parse('exp(2*x) - 3*exp(x) + 2').solve('x')` returns `[]` (`sol_exp_quadratic`). Neither polynomial factoring nor `isolateAndInvert` recognizes expressions that are polynomials $P(u) = \sum_{j=0}^d c_j u^j$ in an exponential substitution $u = e^{\alpha x}$ (since `exp(2*x)` is `Pow(Constant.e, 2 * x)` rather than `Pow(Pow(Constant.e, x), 2)`).
- **Specification:**
  In `lib/src/symbolic/solver/transcendental.dart`:
  - Add `_tryPolynomialInExponential(Expr expr, String variable, {required Assumptions assumptions})` and invoke it inside `isolateAndInvert` when 2-term isolation and `_matchAffineExponential` return `null`:
    1. Collect all `Pow(base, exponent)` nodes in `expr` where `!base.dependsOn(variable)` and `exponent.matchLinear(variable)` is `(a: final alpha, b: final beta)` with `alpha is RationalNumber && !alpha.isZero`.
    2. If all such exponential nodes share a common base $B$ (e.g. `Constant.e`) and their linear coefficients $\alpha_i$ are positive integer multiples $m_i \alpha_0$ of a fundamental rational slope $\alpha_0$ (with $1 \le m_i \le 6$):
       - Rewrite each `Pow(B, alpha_i * x + beta_i)` as `Pow(B, beta_i) * Pow(Variable('_u_exp'), m_i)` where $u = B^{\alpha_0 x}$.
       - If the resulting expression no longer depends on `variable` (only on `'_u_exp'`), solve the polynomial in `'_u_exp'` via `solveEquation(polyU, '_u_exp', assumptions: Assumptions.none)`.
       - For each root $u_k$, solve $B^{\alpha_0 x} = u_k$ via `invertEquation(Pow(B, alpha_0 * Variable(variable)), u_k, variable, assumptions: assumptions)` and collect all valid roots!
- **Verification:**
  - `Expr.parse('exp(2*x) - 3*exp(x) + 2').solve('x')` -> `[IntegerNumber.zero, Ln(IntegerNumber.two, isSimplified: true)]`
  - `Expr.parse('exp(2*x) - 1').solve('x')` -> `[IntegerNumber.zero]`

---

## [TASK-25] Second-Order Constant-Coefficient Linear Homogeneous ODEs $a y'' + b y' + c y = 0$ (`P2-Math`)

- **Files:**
  - `lib/src/symbolic/solver/ode.dart` (`_solveOde`, `_trySecondOrderLinearOde`)
- **Problem:**
  In `_solveOde` (`ode.dart:66`), `_replaceDerivative` only replaces `Derivative(order: 1, expr: Variable(dependent))` with `_yPrime` and leaves `Derivative(order: 2, ...)` untouched!
  1. For `diff(y, x, 2) + y = 0` (`ode_harmonic_2nd_order`), there is no first derivative `diff(y, x)`, so `!normalized.dependsOn('_yPrime')` throws `ArgumentError('Equation does not contain any derivative of y with respect to x')`.
  2. Worse, for `diff(y, x, 2) - 3 * diff(y, x) + 2 * y = 0` (`ode_damped_roots_2nd_order`), `_replaceDerivative` replaces `diff(y, x)` with `_yPrime` while leaving `diff(y, x, 2)` in the equation as if it were a constant independent of `y` and `x`, returning the completely wrong first-order solution `C1 * exp(2/3 * x)`!
- **Specification:**
  In `lib/src/symbolic/solver/ode.dart`:
  1. Before the first-order `_replaceDerivative` path, check if `eq` contains any higher-order derivative `Derivative(order: final ord, expr: Variable(name: final depName), variable: final indName)` with `depName == dependent && indName == independent && ord >= 2`.
  2. If `ord > 2`: throw `UnsupportedError('ODEs of order $ord > 2 are not supported')` (never treat higher derivatives as constants!).
  3. If the maximum derivative order is `2`:
     - Replace `Derivative(Variable(dependent), independent, order: 2)` with `Variable('_yDoublePrime')` and `Derivative(Variable(dependent), independent, order: 1)` with `Variable('_yPrime')`.
     - Extract coefficients of `a * _yDoublePrime + b * _yPrime + c * y + d = 0`:
       Verify `eq` is linear in `_yDoublePrime`, `_yPrime`, and `dependent` with coefficients $a, b, c$ independent of `independent`, `dependent`, `_yPrime`, and `_yDoublePrime`, and $d = 0$ (or constant/inhomogeneous $d(x)$ via undetermined coefficients if $d = 0$).
     - Solve the characteristic quadratic equation $a r^2 + b r + c = 0$ for $r$:
       Compute discriminant $\Delta = (b^2 - 4ac).\text{simplify}(\text{assumptions}: \text{assumptions})$.
       - **Case 1 ($\Delta == 0$, repeated root $r = -b / (2a)$):**
         Return `((Variable('C1') + Variable('C2') * Variable(independent)) * Pow(Constant.e, r * Variable(independent))).simplify(assumptions: assumptions)`.
       - **Case 2 ($\Delta$ is negative real, i.e., `isNegativeExpr(delta, assumptions: assumptions)`):**
         Let $\alpha = (-b / (2a)).\text{simplify}()$ and $\beta = (\text{Pow}(-\Delta, \text{FractionNumber.half}) / (2a)).\text{simplify}()$.
         Return `(Pow(Constant.e, alpha * Variable(independent)) * (Variable('C1') * Cos(beta * Variable(independent)) + Variable('C2') * Sin(beta * Variable(independent)))).simplify(assumptions: assumptions)`.
       - **Case 3 (Two distinct roots $r_1, r_2$):**
         Let $r_1 = ((-b - \sqrt{\Delta}) / (2a)).\text{simplify}()$ and $r_2 = ((-b + \sqrt{\Delta}) / (2a)).\text{simplify}()$.
         Return `(Variable('C1') * Pow(Constant.e, r_1 * Variable(independent)) + Variable('C2') * Pow(Constant.e, r_2 * Variable(independent))).simplify(assumptions: assumptions)`.
- **Verification:**
  - `Expr.parse('diff(y, x, 2) + y').solveOde(dependent: 'y', independent: 'x')` -> `Expr.parse('C1 * cos(x) + C2 * sin(x)').simplify()`
  - `Expr.parse('diff(y, x, 2) - 3 * diff(y, x) + 2 * y').solveOde(dependent: 'y', independent: 'x')` -> `Expr.parse('C1 * exp(x) + C2 * exp(2 * x)').simplify()`
  - `Expr.parse('diff(y, x, 2) - 2 * diff(y, x) + y').solveOde(dependent: 'y', independent: 'x')` -> `Expr.parse('(C1 + C2 * x) * exp(x)').simplify()`
  - `dart run bin/cas_runner.dart -s "wester|gruntz|algebra|series|solvers"` passes 283 / 283 (100.0%).
