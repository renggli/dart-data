# Tasks (`TASKS.md`)

All tasks (`[TASK-91]`–`[TASK-97]`) have been addressed and verified:

- `[TASK-91]` (`1d8631f6`): Fixed sign preservation, branch-cut selection, and complex logarithm `Abs` handling in symbolic integration.
- `[TASK-92]` (`a55923de`): Preserved `Acosh` branch cuts in symbolic differentiation.
- `[TASK-93]` (`9f89023d`): Added integration step/time budget, memoization, and AST size guards to prevent timeouts.
- `[TASK-94]` (`d5818b2a` + special-function fixes & tests): Added first-class `Hypergeometric`, `ExpIntegralE`, Hurwitz `Zeta`, `Min`, and `Max` support, fixed `expIntegralE` continued-fraction stability, `hurwitzZeta` non-positive `a` values, `hypergeometricPFQ` `0F0`/`1F0`/termination handling, and added dedicated `test/special/` unit tests.
- `[TASK-95]` (`56d16698`): Added `Hypergeometric` Chebyshev binomial, `ExpIntegralE`, and shifted trig-integral antiderivatives.
- `[TASK-96]` (`28656485`): Renamed symbolic special integral AST classes (`ExpIntegral`, `LogIntegral`, `SinIntegral`, `CosIntegral`, `SinhIntegral`, `CoshIntegral`) and unified `EllipticE(k, {phi})`.
- `[TASK-97]` (`8b465de5`): Modularized large symbolic modules and consolidated shared algebra helpers.

No open tasks remain.
