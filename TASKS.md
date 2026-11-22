# Tasks (`TASKS.md`)

All tasks (`[TASK-71]`–`[TASK-81]`) have been addressed and verified against `HEAD` (`1238ab64`):

- `[TASK-71]` (`fa14bc01`, `e44063f6`, `1238ab64`): Refactored `package:data/special.dart` to canonical names, paired `<name>` / `<name>Complex` exports, top-of-file public layout, and numerical edge-case fixes.
- `[TASK-72]` (`17bd0eb9`): Added complex gamma, incomplete gamma, beta, digamma, polygamma, and zeta functions.
- `[TASK-73]` (`c28f01a8`): Added complex elliptic integrals (`K`, `F`, `E`, `Pi`) and real `ellipticPi`.
- `[TASK-74]` (`529ae5a1`): Added complex error, Fresnel, integral, Bessel, Lambert W, and hypergeometric functions.
- `[TASK-75]` (`ab2c2de7`): Wired `evaluator.dart`, `approximate.dart`, and `simplify/special.dart` onto `<name>Complex`.
- `[TASK-76]` (`1c76c8fa`): Added first-class `EllipticPi` and `Atan2` AST nodes with parsing, calculus, and evaluation.
- `[TASK-77]` (`4209fa64`): Simplified exponentials of inverse hyperbolic functions `exp(atanh|asinh|acosh(u))`.
- `[TASK-78]` (`96fb9a19`): Implemented square-root radical denesting `sqrt(a ± b*sqrt(c))`.
- `[TASK-79]` (`a54958be`): Added solver for homogeneous and constant-shifted quadratic trigonometric equations.
- `[TASK-80]` (`9b61b8cf`): Added Stirling asymptotic limits, special-function Maclaurin series tests, and alternating/two-pole `Digamma` infinite sums.
- `[TASK-81]` (`80a1ab35`): Fixed quadratic radical integration sign bugs, symbolic-exponent `x^m * P(x)` expansion, and Ostrogradsky reduction.

No open tasks remain.
