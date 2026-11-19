# Symbolic Mathematics Library Audit & Specification (`TASKS.md`)

All previous tasks (`[TASK-00]` through `[TASK-31]`) were verified against `HEAD` (`145bd4ca`): `dart analyze` clean, 570 / 570 symbolic & dependency unit tests passing, 283 / 283 (100.0%) on the built-in CAS suites (`wester|gruntz|algebra|series|solvers`), `mit_bee_integrate` at 200 / 322 (62.1%), and `mit_bee_differentiate|mit_bee_official_differentiate` at 585 / 598 (97.8%, zero timeouts). The tasks below cover defects found while verifying `[TASK-26]`–`[TASK-31]` and the highest-leverage failure clusters in `mit_bee_integrate`, in dependency order.

---

## [TASK-32] Verification Defects in `[TASK-27]`, `[TASK-28]`, and `[TASK-30]` (`P0-Bug`)

- **Files:**
  - `lib/src/symbolic/solver/ode.dart` (`OdeExtension.solveOde`, `_solveOde`, `_trySecondOrderLinearOde`)
  - `lib/src/symbolic/solver/transcendental.dart` (`isolateAndInvert`, `_solveAddTranscendental`)
  - `lib/src/symbolic/algebra/term_accumulator.dart` (`MonomialAccumulator._doCombineFractions`, `_hasHighDegreePowerOfAdd`)
- **Problem:**
  1. **Second-order initial conditions are silently ignored:** `_solveOde` returns from `_trySecondOrderLinearOde` (`ode.dart:87-95`) before the initial-value block. `Expr.parse('diff(y, x, 2) + y').solveOde(dependent: 'y', independent: 'x', at: 0, initialValue: 1)` returns `C1 * cos(x) + C2 * sin(x)` without any error. The API also cannot express the second condition `y'(x0)`.
  2. **`a*sin(u) + b*cos(u) = c` returns `[]`:** `Expr.parse('sin(x) + cos(x) - 1').solve('x')` returns `[]` (expected `[0, pi/2]`). The same happens for `sin(x) - cos(x)` (expected `[pi/4, 5*pi/4]`). This predates `[TASK-28]`, but `[]` claims there are no solutions, which is wrong.
  3. **Fraction numerators are never collected when a high-degree power is present:** `_hasHighDegreePowerOfAdd` turns off `.expand()` for the whole combined numerator. For `mit_bee_official#394` the derivative now finishes in about 24 ms, but it stays as `(2023 * exp(x) * (-1/4090506 + 1/2022 * exp(x)) + 1/2022 * exp(x) * (1 - exp(x))) / (1 - exp(x))^2024` instead of `exp(2*x) / (1 - exp(x))^2024`.
  4. **Large affine powers are integrated by full expansion:** `x*(1 - x)^99` is expanded through `_antiDerivPow` (`integration.dart:972`) and `_antiDerivMul` step 6 (`integration.dart:1197`) into a 101-term polynomial with huge coefficients. Checking that result numerically loses precision to cancellation, so `mit_bee#63`, `#104` (`(1-x)^2014`) and `#226` (`(1-x)^2020`) fail.
- **Specification:**
  1. Replace `initialValue` with `initialValues: List<Object>` in `solveOde`, holding `[y(at)]` or `[y(at), y'(at)]`. Throw `ArgumentError` if `initialValues.length` is greater than the ODE order. Apply the conditions after both the first-order and second-order paths: substitute `at` into `ySol` (and into `ySol.derivative(independent)`), then solve the linear system for `C1`/`C2` with `List<Expr>.solve([...])`. Update `bin/cas_suites/` callers and the doc comments.
  2. In `_solveAddTranscendental` (or a new `_tryHarmonicAddition` called before `_tryMultipleAngleTrig`), match `a*sin(u) + b*cos(u) + k` where `u` is linear in `variable` and `a`, `b`, `k` are constants. Rewrite it as `R*sin(u + phi) = -k` with `R = sqrt(a^2 + b^2)` and `phi = atan2(b, a)` (exact for rational multiples of `pi`), then invert through the existing `Sin` branch. Return `const []` only when `|k| > R` has been proven numerically.
  3. In `_doCombineFractions`, do not skip expansion entirely. Replace each high-degree `Pow(Add, n)` (`|n| > 16`) with an opaque placeholder `Variable('_hp_i')`, expand and simplify, then substitute back. Apply the same treatment in `_isAlgebraicallyZero`.
  4. In `_antiDerivPow` and `_antiDerivMul`, when an integrand is `P(x) * (a*x + b)^n` with integer `n > 8` and `deg(P) <= 8`, try `trySymbolicBinomialAffine` (`substitution.dart:194`) before any `.expand()`. Its exponent handling already works for integer `n`.
- **Verification:**
  - `Expr.parse('diff(y, x, 2) + y').solveOde(dependent: 'y', independent: 'x', at: 0, initialValues: [1, 0])` -> `cos(x)`
  - `Expr.parse('sin(x) + cos(x) - 1').solve('x')` -> `[0, pi/2]`
  - `Expr.parse('1/(2023*(1 - exp(x))^2023) - 1/(2022*(1 - exp(x))^2022)').derivative('x')` -> `Expr.parse('exp(2*x) / (1 - exp(x))^2024').simplify()`
  - `Expr.parse('x*(1 - x)^99').integrate('x')` -> `Expr.parse('(1 - x)^101/101 - (1 - x)^100/100').simplify()`. `mit_bee#63`, `#104`, and `#226` pass.

---

## [TASK-33] Inhomogeneous ODE Forcing Terms `P(x)*exp(αx)`, `P(x)*sin/cos(ωx)`, and n-th Order Constant-Coefficient ODEs (`P2-Math`)

- **Files:**
  - `lib/src/symbolic/solver/ode.dart` (`_trySecondOrderLinearOde`, particular-solution helpers)
- **Problem:**
  1. `Expr.parse('diff(y, x, 2) - y - x*exp(2*x)').solveOde(...)` throws `UnsupportedError: Unsupported inhomogeneous term ... exp(2 * x) * x`. Only the pure polynomial, pure exponential, and pure sinusoid cases were implemented.
  2. `diff(y, x, 3) - y` throws `ODEs of order 3 > 2 are not supported`. The characteristic-polynomial method generalizes directly to any order `n`.
- **Specification:**
  1. Generalize the characteristic polynomial to `p(r) = sum_{j=0}^{n} a_j r^j` for any order `n <= 6`. Find its roots with `solveEquation(p, '_r')` and record multiplicities with `factor`. Build the homogeneous basis: `x^k e^{rx}` for real roots, and `x^k e^{αx} cos(βx)`, `x^k e^{αx} sin(βx)` for conjugate pairs `α ± iβ`. Name the constants `C1..Cn`.
  2. Undetermined coefficients for forcing `Q(x) e^{αx}` and `Q(x) e^{αx} {cos, sin}(βx)` with `deg(Q) = m <= 4`: let `s` be the multiplicity of `α + iβ` as a root of `p`. Use the ansatz `x^s e^{αx} (A(x) cos(βx) + B(x) sin(βx))` with unknown coefficients for `A` and `B` of degree `m`. Substitute into the ODE, collect the coefficients of `x^k e^{αx} cos/sin(βx)`, and solve the linear system with `List<Expr>.solve`.
- **Verification:**
  - `diff(y, x, 2) - y - x*exp(2*x)` -> `C1*exp(-x) + C2*exp(x) + (x/3 - 4/9)*exp(2*x)`
  - `diff(y, x, 3) - y` -> `C1*exp(x) + exp(-x/2)*(C2*cos(sqrt(3)/2*x) + C3*sin(sqrt(3)/2*x))`
  - `diff(y, x, 2) + y - x*sin(x)` -> `C1*cos(x) + C2*sin(x) - x^2/4*cos(x) + x/4*sin(x)`

---

## [TASK-34] Integrate Logarithms of Non-Linear Arguments via Generalized Integration by Parts (`P2-Math`)

- **Files:**
  - `lib/src/symbolic/calculus/integration/integration.dart` (`_antiDerivLn`)
  - `lib/src/symbolic/calculus/integration/parts.dart` (`tryIntegrationByParts`)
- **Problem:** `_antiDerivLn` (`integration.dart:506`) only handles linear arguments, and the IBP rule from `[TASK-31]` requires a polynomial cofactor. All of the following stay unevaluated:
  - `ln(x^2 + 1)` (`mit_bee#220`) and `ln((x + 1)/(1 - x))` (`#216`): `u = ln(g)`, `dv = dx`
  - `ln(x + 1)/x^2` (`#248`): rational cofactor `dv = x^-2 dx`
  - `sin(x)*ln(sin(x))` (`#92`) and `ln(cos(x))/cos(x)^2` (`#302`): trigonometric cofactor with an elementary antiderivative
- **Specification:**
  1. In `_antiDerivLn`, when `inner` is not linear but `inner.derivative(variable) / inner` simplifies to a rational function of `variable`, return `x*ln(inner) - integrate(x * inner' / inner)`. Reject the result if the remainder is unevaluated.
  2. In `tryIntegrationByParts`, add a general log rule. When `vExpr` is `Ln(g)` (or `Pow(Ln(g), k)` with `1 <= k <= 3`) and `pExpr` is anything whose `antiDerivative(pExpr, depth: 2)` is fully evaluated, return `V*vExpr - integrate(V * vExpr')`. Accept it only if the remainder is evaluated. Keep the `depth` guard against recursion.
- **Verification:** `mit_bee#92`, `#216`, `#220`, `#248`, and `#302` pass. `Expr.parse('ln(x^2 + 1)').integrate('x')` -> `x*ln(x^2 + 1) - 2*x + 2*atan(x)`.

---

## [TASK-35] Rational Function Integration Robustness: Square-Free Denominators, Nested Fractions, and `u = x^k` (`P2-Math`)

- **Files:**
  - `lib/src/symbolic/calculus/integration/rational.dart` (`integrateRationalFunction`)
  - `lib/src/symbolic/calculus/integration/integration.dart` (`antiDerivative`, `tryAntiDerivDiv`)
- **Problem:**
  1. `1/(x^2 + 1)^2` integrates, but its expanded form `1/(x^4 + 2*x^2 + 1)` (`mit_bee#33`) does not. Repeated irreducible factors are not detected in expanded denominators.
  2. `1/(x + 1/x)^2` (`#165`) is not normalized with `together()` before rational integration.
  3. `x^9/(x^20 - 48*x^10 + 575)` (`#320`) and `(2*x^2022 + 1)/(x^2023 + x)` (`#290`) need the substitution `u = x^k`. Without it they exceed the degree limits.
- **Specification:**
  1. Before partial fractions, run square-free factorization (Yun's algorithm via `gcd(D, D')`) on the denominator and use Hermite reduction for factors of multiplicity `> 1`. Pass the factored form to the existing per-factor quadratic and linear routines.
  2. In `antiDerivative`, when `node` is a rational function of `variable` with nested fractions (`_isRationalIn` true, but the numerator or denominator contains a negative power of a variable-dependent `Add` or `Variable`), retry on `node.together()`.
  3. For a rational integrand `N(x)/D(x)` (after `together`): let `k = gcd` of the exponents of `D`. If `x*N(x)` only has exponents that are multiples of `k`, with `k >= 2`, substitute `u = x^k`, `dx/x = du/(k*u)`, integrate in `u`, and substitute back.
- **Verification:** `mit_bee#33`, `#165`, `#290`, and `#320` pass.

---

## [TASK-36] Special-Function Antiderivatives (`li`, `Ei`, `erf`) and Cancellation Across Additive Terms (`P2-Math`)

- **Files:**
  - `lib/src/symbolic/calculus/integration/integration.dart` (`_antiDerivPow`, `antiDerivative`)
  - `lib/src/symbolic/calculus/integration/substitution.dart` (`tryUSubstitution`, `tryGaussianAntiderivative`)
- **Problem:** Several integrands have antiderivatives built from special functions, or are sums whose non-elementary parts cancel. They currently stay unevaluated, and `antiDerivative` integrates `Add` term by term (`integration.dart:157`), so the cancelling pieces never meet:
  - `1/ln(x) - 1/ln(x)^2` (`#22`) = `x/ln(x)`, but `1/ln(x)^2` has no rule
  - `1/ln(x) + ln(ln(x))` (`#39`), `cos(x)*ln(x) + sin(x)/x` (`#60`), `(1 + ln(x))*ln(ln(x))` (`#244`), `(cos(x)*ln(x) - sin(x)/x)/ln(x)^2` (`#76`), `(cos(x) + sin(x))/x^2 + (sin(x) - cos(x))/x` (`#149`)
  - `(x^7 - 1)/ln(x)` (`#72`), `exp(exp(x))` and `x*exp(exp(x^2))` (`#46`, `#239`), `x^5*exp(-x^4)` (`#230`), `2^ln(x)` (`#197`)
- **Specification:**
  1. Reduction rules that end in special functions:
     - `ln(ax+b)^(-k)`, `k >= 1`: `∫ ln(u)^(-k) = -u/((k-1) ln(u)^(k-1)) + 1/(k-1) ∫ ln(u)^(-(k-1))`, with base case `li(u)/a`.
     - `x^n / ln(x)`: `Ei((n+1) ln(x))`.
     - `ln(ln(x))`: `x*ln(ln(x)) - li(x)`.
     - `cos(x)*ln(x)` and `sin(x)*ln(x)`: IBP to `sin(x)*ln(x) - Si(x)` and `-cos(x)*ln(x) + Ci(x)`.
     - `sin(x)/x^k` and `cos(x)/x^k`, `k >= 2`: reduce to `Si`/`Ci`.
     - `exp(exp(u))*u'`: `Ei(exp(u))`.
     - `b^ln(x)`: rewrite as `x^ln(b)`.
  2. In `tryUSubstitution`, add the candidate `u = x^m` for integrands `x^(m-1) * f(x^m)` with even `m` (`x^5*exp(-x^4)` -> `u = x^2`, a Gaussian moment).
  3. Additive cancellation: after the term-by-term `Add` integration, pass the combined result through `simplify`. With rule 1 in place the `li`/`Si`/`Ci`/`Ei` terms cancel. If unevaluated `Integral` nodes remain, retry the whole `Add` once with IBP pairing (`u*v' + u'*v` recognition: test `integrand == d/dx(f*g)` for candidate pairs `f`, `g` drawn from the terms' factors).
- **Verification:** `mit_bee#22`, `#39`, `#46`, `#60`, `#72`, `#76`, `#149`, `#197`, `#230`, `#239`, and `#244` pass. Each special-function result must still pass `verifyDerivative`.

---

## [TASK-37] Trigonometric, Hyperbolic, and Radical Integration Gaps (`P2-Math`)

- **Files:**
  - `lib/src/symbolic/calculus/integration/trigonometric.dart` (`tryRationalTrigSubstitution`, `tryHyperbolicRationalSubstitution`, `_collectAffineHypInner`, `_collectAffineTrigInner`)
  - `lib/src/symbolic/calculus/integration/parts.dart` (`tryIntegrationByParts`)
  - `lib/src/symbolic/calculus/integration/radical.dart` (`tryFractionalLinearRadical`, `tryAffineRadicalSubstitution`)
- **Problem:**
  - Multiple angles stop the trig collectors, because `_collectAffineTrigInner` needs a single common argument: `sin(4*x)/sin(x)` (`#64`), `sin(23*x)/sin(x)` (`#304`), `cos(x)/(1 - cos(2*x))` (`#183`)
  - Mixed exponential/hyperbolic/trig forms: `tanh(x)/exp(x)` (`#168`, `exp(x)` rejected by `_collectAffineHypInner`), `cos(x)*cosh(x) + sin(x)*sinh(x)` (`#179`), `exp(x)*(cos(x)^2 + cos(x)*sin(x) - sin(x)^2)` (`#207`)
  - IBP for polynomial times non-standard `dv`: `x*sec(4*x)^2` (`#112`), `x*cosh(x)/sinh(x)^2` (`#70`)
  - Radicals: `sqrt(1 + 1/x)` (`#311`), `1/(5 + 4*sqrt(x) + x)` (`#123`), `x/(sqrt(x - 1) + sqrt(x + 1))` (`#234`), `sqrt(1 + sin(x))` (`#169`)
- **Specification:**
  1. In `tryRationalTrigSubstitution`, if `_collectAffineTrigInner` fails only because the arguments are distinct integer multiples `k_i*u` of a common `u` (with `k_i <= 24`), apply `expandTrig()` first and retry.
  2. In `_collectAffineHypInner` and `_replaceHypWithExp`, accept `Pow(Constant.e, k*inner)` with integer `k` as `w^k`. Rewrite `sinh`/`cosh` in products with `sin`/`cos` as exponentials, then distribute so cyclic IBP (`parts.dart:73`) applies per term. Before cyclic IBP, distribute `exp(ax)*Add` and reduce trig powers.
  3. In `tryIntegrationByParts`, add a fallback for polynomial `pExpr` of degree 1–3 with any `vExpr` whose `antiDerivative(vExpr, depth: 2)` is evaluated. Use `u = pExpr`, `dv = vExpr`, and require the remainder `∫ p' V` to be evaluated.
  4. Radicals:
     - Normalize radicands with `together()` so `sqrt(1 + 1/x)` becomes `sqrt((x+1)/x)` and goes through `tryFractionalLinearRadical`.
     - Find out why `tryAffineRadicalSubstitution` fails on `1/(5 + 4*sqrt(x) + x)`. The transformed integrand `2u/(u^2 + 4u + 5)` is elementary.
     - Rationalize `1/(sqrt(A) + sqrt(B))` denominators by multiplying by the conjugate when `A - B` is free of radicals.
     - Use the half-angle identity `1 + sin(x) = (sin(x/2) + cos(x/2))^2` for `sqrt(1 ± sin(x))` and `sqrt(1 ± cos(x))`.
- **Verification:** `mit_bee#64`, `#70`, `#112`, `#123`, `#168`, `#169`, `#179`, `#183`, `#207`, `#234`, `#304`, and `#311` pass. Target `mit_bee_integrate` at 75% or above (≥ 242 / 322) with no regressions in the built-in suites.
