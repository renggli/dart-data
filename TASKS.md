# Tasks (`TASKS.md`)

All tasks (`[TASK-88]`–`[TASK-90]`) have been addressed and verified:

- `[TASK-88]` (`8d35ae69` + `Abs` limit composition & infinite endpoint subtraction fixes): Fixed multi-second freeze on `radical_conjugate_limit` (`(sqrt(x + 4) - 2) / x`) — total pipeline dropped from 3,619 ms → 6 ms, `int[0, 5] = 2 + 4*ln(4/5)`, `int[0, ∞] = infinity`.
- `[TASK-89]` (`81c3a32e`): Curated, reorganized, and expanded `web/expressions/presets.dart` across 8 categories.
- `[TASK-90]` (`7b7b06c6`): Expanded `test/web_examples_test.dart` to cover full demo pipeline, curve sampling, and latency budgets.

No open tasks remain.
