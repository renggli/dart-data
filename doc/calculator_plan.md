# Symbolic Calculator & Web Suite — Actionable Implementation Plan

Target: `web/calculator/`, `web/shared/`, `web/expressions/`, `web/distributions/`, `test/web/calculator/`, and [doc/calculator_design.md](calculator_design.md)

---

## Guiding Principles, UX Bar & Per-Task Commit Protocol

1. **UX Excellence Standard**:
   - **High Usability & Zero Clutter**: Every control, chip, menu, and panel must have an obvious purpose, clear visual hierarchy, and immediate feedback.
   - **Clean, Modern & Consistent Visuals**: Strictly adhere to the dark-glass design tokens (`web/shared/style.css`), typography, spacing, and active/hover/disabled states across all views.
   - **Seamless Desktop & Mobile Responsiveness**: Every interaction must work effortlessly on both desktop (`1200×800`, full keyboard + mouse) and narrow mobile (`320×600` and `375×667`, touch targets, zero horizontal overflow, no clipped popovers or menus).
2. **Shared, Simple & Reusable CSS Across All Web Applications**:
   - Reuse and consolidate common styles (cards, buttons, chips, badges, inputs, popovers, chart containers, sliders, and layout primitives) in `web/shared/style.css` so `web/calculator/`, `web/expressions/`, `web/distributions/`, and `web/` share one simple, clean, consistent stylesheet foundation.
   - Eliminate duplicate or ad-hoc CSS rules across individual app stylesheets (`web/*/style.css`); keep app-specific stylesheets minimal and strictly scoped to unique layout needs.
3. **Zero Backward Compatibility / Single Canonical Way**:
   - Remove duplicate state containers, legacy 4-letter HP48 command aliases (`SIMP`, `EXPA`, `TAYL`, `CPOL`, `EGVL`, `CHS`, `PURG`, `CLVA`, `→NUM`, `→Q`), dead code (`web/calculator/src/ui/soft_keys.dart`), hardcoded command switch tables, and blocking modal dialogs (`MatrixEditorModal`).
4. **Unified Mode Architecture**:
   - Scroll mode and RPN mode are two complementary views and interaction styles over a single shared computation state (`Environment`, `Session`, `RpnStack`).
5. **Whole-Session Transactional Undo/Redo**:
   - Every mutating operation across both Scroll and RPN modes is undoable and redoable via a single snapshot ring in `WorkerDispatcher`.
6. **Strict Per-Task Quality Loop & Separate Commits**:
   - **Each task (Tasks 1–9) MUST be executed, verified, and committed separately.** Never combine multiple tasks into a single commit.
   - Before committing each individual task, complete all 5 steps:
     1. **Unit Tests**: Add/update unit tests in `test/web/calculator/` (`model_test.dart`, `language_test.dart`, `engine_test.dart`, `worker_test.dart`) using `package:checks`.
     2. **Documentation Sync**: Update the corresponding sections of [doc/calculator_design.md](calculator_design.md) so the architecture and UX specifications stay 100% synchronized.
     3. **Browser UX Audit (Desktop & Mobile)**: Inspect and interactively test the live UI via Chrome DevTools MCP at both desktop (`1200×800`) and mobile (`320×600` / `375×667`) viewports to verify clean layout, alignment, spacing, and responsiveness.
     4. **Static Analysis & Formatting**: Run `dart test`, `dart analyze`, `dart fix --apply`, and `dart format .` with zero warnings or errors.
     5. **Separate Git Commit**: Stage and commit the task (`git commit -m "..."`) before starting the next task.

---

## Task 1: Decompose Monolithic `commands.dart`, Declarative Command Dispatch & Remove Legacy Aliases

### Objective
Split the 2,014-line monolithic `commands.dart` into modular category files, replace hardcoded command switch tables with declarative parameter descriptors, delete dead soft-key code and cryptic 4-letter HP48 aliases, and hide stack-only operations in Scroll mode.

### Files to Modify / Delete / Create
- Delete `web/calculator/src/ui/soft_keys.dart`
- Modify `web/calculator/src/engine/commands.dart` (convert to registry + shared types)
- Create `web/calculator/src/engine/commands/algebra.dart`
- Create `web/calculator/src/engine/commands/calculus.dart`
- Create `web/calculator/src/engine/commands/linear.dart`
- Create `web/calculator/src/engine/commands/complex.dart`
- Create `web/calculator/src/engine/commands/numbers.dart`
- Create `web/calculator/src/engine/commands/numeric.dart`
- Create `web/calculator/src/engine/commands/plot.dart`
- Create `web/calculator/src/engine/commands/session.dart`
- Modify `web/calculator/src/engine/evaluator.dart`
- Modify `web/calculator/src/engine/rpn.dart`
- Modify `web/calculator/src/ui/keypad.dart`
- Modify `web/calculator/src/ui/palette.dart`
- Modify `web/calculator/src/ui/app.dart`
- Modify `web/calculator/style.css`
- Modify `test/web/calculator/engine_test.dart`
- Modify `test/web/calculator/worker_test.dart`
- Modify `doc/calculator_design.md`

### Implementation Steps
1. **Decompose `commands.dart` into Modular Sub-Files**:
   - Split command definitions by category into `web/calculator/src/engine/commands/*.dart`.
   - Add declarative parameter metadata (`ParamSpec`: `expr`, `symbol`, `equation`, `optionalExpr`, `optionalInt`) and `(minArity, maxArity)` to `Command` so `CalcEvaluator._evalCall` no longer needs a hardcoded `varAtSecondArg` set.
2. **Delete Dead Code & Legacy RPN Aliases**:
   - Delete `web/calculator/src/ui/soft_keys.dart` and remove `.calc-softkey-*` rules from `web/calculator/style.css`.
   - Delete `_legacyRpnAliases` (`SIMP`, `EXPA`, `FACT`, `SOLV`, `SUBS`, `APRT`, `TGTH`, `CANC`, `COLL`, `NUMR`, `DENM`, `TEXP`, `TSMP`, `TAYL`, `SERI`, `LIM`, `GRAD`, `HESS`, `JACO`, `TRN`, `TRAC`, `CPOL`, `NULL`, `EGVL`, `EGVC`, `IDN`, `ZERO`, `CROS`, `POLR`, `PRIM?`, `COMB`, `FLR`, `RND`, `NSOL`, `NDER`, `PURG`, `CLVA`) and legacy switch branches (`CHS`, `→NUM`, `→Q`, `PURGE`, `CLVAR`) from `web/calculator/src/engine/rpn.dart`.
3. **Hide Stack Operations in Scroll Mode**:
   - In `VirtualKeypad.render({required CalcMode mode})` (`web/calculator/src/ui/keypad.dart`), only show the `'Stack'` tab when `mode == CalcMode.rpn`. Reset `_activeTab = 'Numbers'` if switching to Scroll mode while on `'Stack'`.
   - Pass `required CalcMode mode` to `CommandPaletteModal.open(...)` (`web/calculator/src/ui/palette.dart`) so stack manipulation commands appear only in RPN mode.

### Task 1 Verification & Separate Commit
- **Unit Tests**: Update `test/web/calculator/engine_test.dart` and `test/web/calculator/worker_test.dart` to use canonical command names exclusively.
- **Design Doc**: Update `doc/calculator_design.md` §3.3, §3.5 (`R6`, `R9`), §3.7, §4.1, and §5.4 to reflect the modular `commands/` directory, declarative parameter metadata, and removal of `soft_keys.dart` and 4-letter aliases.
- **UX & Browser Audit**: Verify in Chrome DevTools at `1200×800` and `320×600` that the `Stack` keypad tab and stack palette entries are hidden in Scroll mode and present in RPN mode.
- **Quality Loop & Commit**: Run `dart test`, `dart analyze`, `dart format .`, and create a dedicated commit for Task 1.

---

## Task 2: Unified RPN Execution Model, Smart 1-Argument Inference & Level-1 Action Chips

### Objective
Fix the inconsistency where keypad and palette commands insert broken Scroll function syntax (`solve(, x)`) in RPN mode; make every command button act directly on the stack in RPN mode; support 1-argument auto-variable inference (`solve(x^2 - 4)`, `diff(sin(t))`, `integrate(x^2)`, `taylor(cos(x))`, `plot(sin(x))`) in both Scroll and RPN modes; and show context-aware action chips on RPN stack level `1:`.

### Files to Modify
- Modify `web/calculator/src/engine/commands.dart` and `web/calculator/src/engine/commands/*.dart`
- Modify `web/calculator/src/engine/rpn.dart`
- Modify `web/calculator/src/ui/keypad.dart`
- Modify `web/calculator/src/ui/palette.dart`
- Modify `web/calculator/src/ui/rpn_view.dart`
- Modify `web/calculator/src/ui/app.dart`
- Modify `web/calculator/style.css`
- Modify `test/web/calculator/engine_test.dart`
- Modify `doc/calculator_design.md`

### Implementation Steps
1. **Smart Variable Inference & Flexible Arities (1-Arg Ergonomics)**:
   - Add `String inferPrimaryVariable(CalcValue value, {String fallback = 'x'})` on `EvaluatorContext` that returns the single free variable of an `ExprValue`, `VectorValue`, or `MatrixValue` (or `fallback` if none/multiple).
   - Allow `diff`, `integrate`, `solve`, `apart`, `collect`, `charpoly`, `taylor`, `series`, `limit`, and `plot` to be called with **1 argument** in both Scroll mode (`solve(x^2 - 4)`, `diff(sin(t))`, `integrate(x^2)`, `taylor(cos(x))`) and RPN mode (`'x^2 - 4' solve`, `'sin(t)' diff`, `'x^2' integrate`, `'cos(x)' taylor`).
2. **Context-Aware Stack Arity Inspection in `RpnInterpreter`**:
   - Before popping arguments for a command in `RpnInterpreter._runRegistryCommand`:
     - For `solve`, `diff`, `integrate`, `apart`, `collect`, `charpoly`: if stack depth ≥ 2 and level `1:` is a bare `Variable` (`'t'`) while level `2:` is an expression/matrix, pop **2** items (`expr`, `var`); if `integrate` is called with definite bounds (`4: expr, 3: 'x', 2: a, 1: b` or `3: expr, 2: a, 1: b`), pop 4 or 3 items; otherwise pop **1** item (`level 1:`) and infer its variable automatically.
     - For `taylor` and `series`: support 1 item (`1: expr` → var inferred, around `0`, order `5`), 2 items (`2: expr, 1: order` → var inferred, around `0`), 3 items (`3: expr, 2: 'x', 1: order`), and 4 items (`4: expr, 3: 'x', 2: point, 1: order`).
3. **Keypad & Palette Execute Directly on Stack in RPN Mode**:
   - In `VirtualKeypad` (`web/calculator/src/ui/keypad.dart`), distinguish Scroll mode vs RPN mode for all operator and command keys (`simplify`, `expand`, `factor`, `solve`, `d/dx`, `∫ dx`, `taylor`, `series`, `limit`, `sin`, `cos`, `tan`, `asin`, `acos`, `atan`, `ln`, `exp`, `det`, `inv`, `trace`, `rref`, `rank`, `eigenvals`, `eigenvects`, `plot`, etc.):
     - In **Scroll mode**: insert prefix call template `solve(, x)` as before.
     - In **RPN mode**: unless the input bar cursor is actively inside an unclosed quote (`'...'`) or bracket (`[...]`), push any pending text in the input bar onto the stack and immediately execute the RPN command (`onExecuteRpn(cmdName)`).
   - In `CommandPaletteModal` (`web/calculator/src/ui/palette.dart`), when `mode == CalcMode.rpn`, selecting a command executes it immediately on the stack (`executeImmediately: true`).
4. **Context-Aware Action Chips on RPN Stack Level `1:`**:
   - In `RpnStackView.render` (`web/calculator/src/ui/rpn_view.dart`), beneath level `1:`, render the applicable action chips from `CommandRegistry.chipsFor(stackItem.value)` so clicking `Factor`, `Roots`, `d/dx`, `∫ dx`, `Plot`, `det`, `inv`, or `≈` directly transforms level `1:`.

### Task 2 Verification & Separate Commit
- **Unit Tests**: Add unit tests in `test/web/calculator/engine_test.dart` for 1-argument Scroll calls (`solve(x^2 - 9)`, `diff(sin(t))`, `integrate(3 * x^2)`, `taylor(exp(x))`) and 1-item RPN stack execution (`'x^2 - 9' solve`, `'sin(t)' diff`, `'3 * x^2' integrate`, `'exp(x)' taylor`).
- **Design Doc**: Update `doc/calculator_design.md` §3.3, §3.5 (`R5`), §3.6 (`D1`, `D3`), and §3.8 to document 1-argument variable inference, RPN direct keypad/palette execution, and level-1 action chips.
- **UX & Browser Audit**: Verify in Chrome DevTools at `1200×800` and `320×600` that in RPN mode, typing `x^2 - 4` and clicking `solve` (or `∫ dx`, `d/dx`) on the keypad immediately pushes `x^2 - 4` and computes `[-2, 2]` on the stack without polluting the input box.
- **Quality Loop & Commit**: Run `dart test`, `dart analyze`, `dart format .`, and create a dedicated commit for Task 2.

---

## Task 3: Fix 3-Dot Overflow Menu Clipping in Scroll & RPN Modes

### Objective
Prevent the `⋯` action chip overflow menu from clipping above the top edge of the scroll/stack container or viewport on desktop and mobile.

### Files to Modify
- Modify `web/calculator/src/ui/chips.dart`
- Modify `web/calculator/style.css`
- Modify `doc/calculator_design.md`

### Implementation Steps
1. **Dynamic Viewport / Container Collision Detection**:
   - In `ActionChips.build` (`web/calculator/src/ui/chips.dart`), when `moreBtn` is clicked:
     - Close any other open `.calc-chip-dropdown` elements in `web.document`.
     - Measure `moreBtn.getBoundingClientRect()` and the closest `.calc-scroll-view` or `.calc-rpn-registers` bounding rect (falling back to viewport top `0`).
     - If `btnRect.top - containerTop < 220` (not enough room above), toggle class `open-down` on `menu`; otherwise remove `open-down`.
2. **Outside-Click Dismissal**:
   - Register a document click listener so clicking outside any `.calc-chip-more-wrap` closes open `.calc-chip-dropdown` menus cleanly.
3. **CSS Positioning & Scrollable Max-Height**:
   - In `web/calculator/style.css`, update `.calc-chip-dropdown`:
     - Default upward: `bottom: calc(100% + 4px); top: auto;`
     - Downward override (`.calc-chip-dropdown.open-down`): `top: calc(100% + 4px); bottom: auto;`
     - Constrain height and ensure horizontal fit on mobile: `max-height: 220px; overflow-y: auto; z-index: 150;`

### Task 3 Verification & Separate Commit
- **Design Doc**: Update `doc/calculator_design.md` §3.6 (`D3`) to document collision-aware overflow menu positioning.
- **UX & Browser Audit**: In Chrome DevTools at `1200×800` and `320×600`, evaluate `[[1, 2], [3, 4]]` as the top cell `r[1]`, click `⋯`, and verify the menu opens downward inside the frame with every item visible, well-spaced, and clickable.
- **Quality Loop & Commit**: Run `dart test`, `dart analyze`, `dart format .`, and create a dedicated commit for Task 3.

---

## Task 4: Connect Scroll and RPN Modes via Synchronized State

### Objective
Synchronize `Session` and `RpnStack` so results computed in Scroll mode are immediately available on the RPN stack, edits/deletions stay in sync, RPN operations produce clean worksheet cells without intermediate literal clutter, and Scroll cells offer a 1-click `⤓ Stack` action.

### Files to Modify
- Modify `web/calculator/src/model/stack.dart`
- Modify `web/calculator/src/model/session.dart`
- Modify `web/calculator/src/engine/evaluator.dart`
- Modify `web/calculator/src/engine/rpn.dart`
- Modify `web/calculator/src/worker/protocol.dart`
- Modify `web/calculator/src/worker/engine_client.dart`
- Modify `web/calculator/src/ui/chips.dart`
- Modify `web/calculator/src/ui/scroll_view.dart`
- Modify `web/calculator/src/ui/app.dart`
- Modify `test/web/calculator/model_test.dart`
- Modify `test/web/calculator/engine_test.dart`
- Modify `test/web/calculator/worker_test.dart`
- Modify `doc/calculator_design.md`

### Implementation Steps
1. **Stack Synchronization Helpers on `RpnStack` and `Session`**:
   - Add `bool isLiteralPush` (default `false`) to `StackItem` (`web/calculator/src/model/stack.dart`), persisted in `toJson`/`fromJson`.
   - Add `void updateResultValue(int resultId, CalcValue newValue)` and `void removeResultId(int resultId)` on `RpnStack`.
   - Add `bool isResultReferenced(int id)` and `void removeUnreferencedCell(int id)` on `Session` (`web/calculator/src/model/session.dart`).
2. **Scroll → RPN Automatic Synchronization**:
   - When `CalcEvaluator.evaluateScroll` creates a cell whose value is not `ErrorValue` or `InfoValue`, push `StackItem(resultId: cell.id, value: cell.value)` onto `RpnStack`.
   - When `CalcEvaluator.updateScrollCell` updates `cellId` (and during `recomputeStaleCells`), call `stack.updateResultValue(cell.id, cell.value)`.
   - When `deleteCell` deletes `cellId`, call `stack.removeResultId(cellId)`.
3. **Clean RPN → Scroll Synchronization**:
   - In `RpnInterpreter._executeToken` (`web/calculator/src/engine/rpn.dart`), when pushing a literal/symbol (`RpnPushNodeToken`), pass `isLiteralPush: true` to `_pushResult`.
   - When an RPN operator or command pops arguments via `stack.popArgs(k)`, for each popped `StackItem` with `isLiteralPush == true`, call `session.removeUnreferencedCell(item.resultId)` before creating the compound result cell (`in[n]: 12 + 4` or `in[n]: factor(x^2 - 1)`).
4. **Explicit `⤓ Stack` Chip on Scroll Cells**:
   - Add `void Function(int cellId)? onPushToStack` callback to `ScrollWorksheetView` and `ActionChips.build`.
   - Render a secondary chip `⤓ Stack` on non-error, non-plot Scroll cells that pushes `r[cellId]` to level `1:` of `RpnStack` and switches to RPN mode with a confirmation toast.

### Task 4 Verification & Separate Commit
- **Unit Tests**: Add unit tests in `test/web/calculator/engine_test.dart` and `test/web/calculator/worker_test.dart` verifying bidirectional synchronization between Scroll and RPN modes.
- **Design Doc**: Update `doc/calculator_design.md` §3.4 and §3.5 (`R8`) to specify the bidirectional Scroll ↔ RPN synchronization model.
- **UX & Browser Audit**: Verify in Chrome DevTools at `1200×800` and `320×600` that switching between Scroll and RPN feels seamless, `⤓ Stack` chip is cleanly styled and functional, and RPN evaluations appear as clean cells in Scroll mode.
- **Quality Loop & Commit**: Run `dart test`, `dart analyze`, `dart format .`, and create a dedicated commit for Task 4.

---

## Task 5: RPN Empty Intro State with Interactive Quick-Start Cards

### Objective
Replace the plain-text empty stack message in RPN mode with a clean, modern interactive onboarding view featuring clickable RPN quick-start cards matching Scroll mode.

### Files to Modify
- Modify `web/calculator/src/ui/rpn_view.dart`
- Modify `web/calculator/src/ui/app.dart`
- Modify `web/calculator/style.css`
- Modify `doc/calculator_design.md`

### Implementation Steps
1. **Interactive Empty State in `RpnStackView`**:
   - Add `required this.onQuickStartSelect` callback (`void Function(String rpnLine)`) to `RpnStackView` (`web/calculator/src/ui/rpn_view.dart`).
   - When `stack.items.isEmpty`, render a `.calc-empty-state` container matching Scroll mode's visual layout and typography:
     - Heading: `'RPN Stack Workbench'`
     - Subtitle: `'Push numbers or quoted symbolic expressions (\'x^2 - 1\'), then apply postfix operators or commands to stack levels.'`
     - A `.calc-quickstart-grid` with 4 `.calc-quickstart-card` buttons:
       1. **Postfix Arithmetic**: `'12 4 + 3 *'` — `'Push 12 and 4, add, then multiply by 3'`
       2. **Symbolic Factoring**: `"'x^3 - x' factor"` — `'Push symbolic polynomial and factor'`
       3. **Symbolic Calculus**: `"'sin(x)^2' diff"` — `'Differentiate sin²(x) with respect to x'`
       4. **Matrix Eigenvalues**: `'[[2, 1], [1, 2]] eigenvals'` — `'Compute exact eigenvalues of a 2×2 matrix'`
   - Clicking any card invokes `onQuickStartSelect(card.code)`.

### Task 5 Verification & Separate Commit
- **Design Doc**: Update `doc/calculator_design.md` §3.5 and §3.6 to document the RPN empty intro state and quick-start cards.
- **UX & Browser Audit**: Verify in Chrome DevTools at `1200×800` and `320×600` that the RPN empty state looks modern, balanced, and responsive, and clicking any quick-start card immediately populates the stack.
- **Quality Loop & Commit**: Run `dart test`, `dart analyze`, `dart format .`, and create a dedicated commit for Task 5.

---

## Task 6: Unified Whole-Session Undo / Redo Across Scroll & RPN Modes

### Objective
Replace `RpnStack`'s isolated undo stack (and fix the `EngineClient` sync bug that wiped it) with a single whole-session transactional undo/redo manager in `WorkerDispatcher` supporting both Scroll and RPN modes via header buttons and `⌘Z` / `⇧⌘Z` (`Ctrl+Z` / `Ctrl+Y`).

### Files to Modify
- Modify `web/calculator/src/model/stack.dart`
- Modify `web/calculator/src/engine/rpn.dart`
- Modify `web/calculator/src/worker/protocol.dart`
- Modify `web/calculator/src/worker/engine_client.dart`
- Modify `web/calculator/index.html`
- Modify `web/calculator/src/ui/app.dart`
- Modify `web/calculator/src/ui/keypad.dart`
- Modify `web/calculator/src/ui/shortcuts.dart`
- Modify `web/calculator/style.css`
- Modify `test/web/calculator/model_test.dart`
- Modify `test/web/calculator/worker_test.dart`
- Modify `doc/calculator_design.md`

### Implementation Steps
1. **Clean Up `RpnStack`**:
   - Remove `_undoStack`, `_redoStack`, `_lastArgs`, `canUndo`, `canRedo`, `snapshot()`, `undo()`, `redo()`, and `recallLastArgs()` from `RpnStack` (`web/calculator/src/model/stack.dart`). Keep `checkpoint()` and `restoreCheckpoint()` for atomic rollback on mid-line error.
2. **Whole-Session Undo/Redo Ring in `WorkerDispatcher`**:
   - In `WorkerDispatcher` (`web/calculator/src/worker/protocol.dart`), maintain `_undoStack = <Map<String, Object?>>[]` and `_redoStack = <Map<String, Object?>>[]` (max 64 snapshots of `_exportCoreState()`).
   - Before any mutating operation (`evalScroll`, `updateScrollCell`, `recomputeStale`, `deleteCell`, `pushCellToStack`, `evalRpnLine`, `execRpnCommand`, `reset`), capture `before = _exportCoreState()`. If the operation succeeds without returning an RPN `ErrorValue`, push `before` onto `_undoStack` and clear `_redoStack`.
   - Implement worker operations `'undo'` and `'redo'` (and support `'UNDO'` / `'REDO'` in `execRpnCommand`).
   - Include `'canUndo': _undoStack.isNotEmpty` and `'canRedo': _redoStack.isNotEmpty` in `exportStateJson()`.
3. **Fix `EngineClient` Local-Mirror Overwrite Bug**:
   - In `EngineClient` (`web/calculator/src/worker/engine_client.dart`), track `_canUndo` and `_canRedo` from worker responses, and only call `_fallbackDispatcher.importStateJson(stateMap)` in `_syncFromWorkerResult` when `_workerAvailable` is `true` (preventing local-mirror execution from wiping `_fallbackDispatcher`).
   - Add `Future<bool> undo()` and `Future<bool> redo()` methods on `EngineClient`.
4. **Header Undo/Redo Controls & Global Shortcuts**:
   - Add `<button id="btn-undo" type="button" class="calc-header-btn" title="Undo (Ctrl/Cmd+Z)" disabled>↶</button>` and `<button id="btn-redo" type="button" class="calc-header-btn" title="Redo (Ctrl+Y / Cmd+Shift+Z)" disabled>↷</button>` to `.calc-header-right` in `web/calculator/index.html`.
   - Style disabled header buttons cleanly (`opacity: 0.38; cursor: default; pointer-events: none;`) and ensure header layout fits `320px` screens without wrapping or overflow.
   - Remove `Undo`, `Redo`, and `Last Args` keys from `VirtualKeypad`'s `'Stack'` tab (`web/calculator/src/ui/keypad.dart`).
   - In `GlobalShortcuts.register` (`web/calculator/src/ui/shortcuts.dart`), bind `Ctrl/Cmd+Z` to `onUndo` and `Ctrl+Y` / `Cmd+Shift+Z` to `onRedo` when the formula input is empty or not focused.

### Task 6 Verification & Separate Commit
- **Unit Tests**: Update `test/web/calculator/model_test.dart` and `test/web/calculator/worker_test.dart` to test multi-step undo/redo across Scroll cell creation, cell editing, cell deletion, RPN line execution, stack manipulation, and variable assignment.
- **Design Doc**: Update `doc/calculator_design.md` §3.4, §3.5 (`R4`), §3.7, §4.1, and §5.4 to describe the unified session-wide undo/redo architecture and header controls.
- **UX & Browser Audit**: Verify in Chrome DevTools at `1200×800` and `320×600` that header `↶` / `↷` buttons have crisp active/disabled states, fit cleanly on narrow mobile headers, and undo/redo operations in both Scroll and RPN modes.
- **Quality Loop & Commit**: Run `dart test`, `dart analyze`, `dart format .`, and create a dedicated commit for Task 6.

---

## Task 7: Docked Vector / Matrix Builder Panel (Replacing Modal Dialog)

### Objective
Replace the blocking `MatrixEditorModal` with a collapsible, modern docked `MatrixBuilderPanel` below the formula input bar (matching `VirtualKeypad`), toggled by the `⊞` button.

### Files to Modify
- Modify `web/calculator/src/ui/matrix_editor.dart`
- Modify `web/calculator/src/ui/input_bar.dart`
- Modify `web/calculator/src/ui/keypad.dart`
- Modify `web/calculator/src/ui/app.dart`
- Modify `web/calculator/style.css`
- Modify `doc/calculator_design.md`

### Implementation Steps
1. **Rewrite `MatrixEditorModal` as Docked `MatrixBuilderPanel`**:
   - In `web/calculator/src/ui/matrix_editor.dart`, replace `MatrixEditorModal` with `final class MatrixBuilderPanel`:
     - Exposes `late final web.HTMLDivElement element` (`className = 'calc-matrix-panel hidden'`).
     - Includes a compact top bar with dimension badge (`2 × 2`), steppers (`+ Row`, `− Row`, `+ Col`, `− Col`), presets (`Identity`, `Zeros`), and action buttons (`Insert Vector [...]`, `Insert Matrix [[...]]`, and `✕` close).
     - Exposes `bool get isVisible`, `void setVisible(bool visible)`, and `void toggle()`.
2. **Mount in `CalculatorApp` & Wire Formula Bar / Keypad**:
   - In `CalculatorApp._mountMainViews()` (`web/calculator/src/ui/app.dart`), instantiate `_matrixPanel = MatrixBuilderPanel(onInsert: (text) => _inputBar.insertAtCursor(text))` and append `_matrixPanel.element` to `#calc-workspace` right above `_keypad.element`.
   - Pass `onToggleMatrixBuilder: () => _matrixPanel.toggle()` to `FormulaInputBar` (`web/calculator/src/ui/input_bar.dart`) and `VirtualKeypad` (`web/calculator/src/ui/keypad.dart`), highlighting the `⊞` button when open.
3. **CSS Styling for `.calc-matrix-panel`**:
   - Replace `.calc-matrix-dialog` modal styles in `web/calculator/style.css` with `.calc-matrix-panel` docked panel styling consistent with `.calc-keypad`, responsive down to `320px` width.

### Task 7 Verification & Separate Commit
- **Design Doc**: Update `doc/calculator_design.md` §3.8, §4.1, and §5.4 to describe the docked `MatrixBuilderPanel`.
- **UX & Browser Audit**: Verify in Chrome DevTools at `1200×800` and `320×600` that clicking `⊞` smoothly toggles the docked matrix panel without blocking the worksheet/stack or formula input bar, and inserting a matrix/vector works cleanly on both mobile and desktop.
- **Quality Loop & Commit**: Run `dart test`, `dart analyze`, `dart format .`, and create a dedicated commit for Task 7.

---

## Task 8: High-Usability Mathematical Workbench Features (`+ Plot` Overlay, Parameter Sliders, `analyze`, ODE & Parametric Plots)

### Objective
Add high-leverage mathematical capabilities that make the calculator uniquely powerful: unboxed `Float64List` plot segments, 1-click `+ Plot` curve overlay, interactive 60fps parameter sliders on symbolic plots, comprehensive function analysis (`analyze`), and parametric/polar/ODE trajectory plotting.

### Files to Modify
- Modify `web/calculator/src/model/value.dart`
- Modify `web/calculator/src/engine/sampling.dart`
- Modify `web/calculator/src/engine/commands/plot.dart`
- Modify `web/calculator/src/engine/commands/calculus.dart`
- Modify `web/calculator/src/ui/plot_view.dart`
- Modify `web/calculator/src/ui/chips.dart`
- Modify `web/calculator/src/ui/scroll_view.dart`
- Modify `web/calculator/style.css`
- Modify `test/web/calculator/engine_test.dart`
- Modify `doc/calculator_design.md`

### Implementation Steps
1. **Unboxed `Float64List` Plot Buffers**:
   - Store `Float64List` directly in `PlotSegmentData` (`web/calculator/src/model/value.dart` and `web/calculator/src/engine/sampling.dart`) instead of allocating boxed `List<double>`.
2. **`+ Plot` ("Overlay on Last Plot") Action Chip**:
   - When the session contains an existing `PlotValue` cell, show a `+ Plot` chip on univariate `ExprValue` or `SeriesValue` cells that appends the expression to the most recent plot cell (`plot([existing..., r[id]], x, minX, maxX)`) so $f(x)$, $f'(x)$, and Taylor expansions can be visually compared on one graph.
3. **Interactive Parameter Sliders on Symbolic Plots**:
   - When `plot` receives an expression containing unassigned free parameters in addition to the plot variable (e.g., `plot(sin(a * x + b), x)` where `a, b` are free symbols), detect the parameter set `params` and render compact range sliders (`[-5, 5]`, default `1.0`) beneath the plot canvas in `PlotView` (`web/calculator/src/ui/plot_view.dart`) that re-sample the compiled expression closure in real time at 60 fps.
4. **Function Analysis Command (`analyze(expr[, var])`) & Chip**:
   - Add `analyze` command in `web/calculator/src/engine/commands/calculus.dart` (and an `Analyze` chip in the overflow menu for univariate expressions) that computes Parity (even/odd), Exact Roots (`solve`), Critical Points & Local Extrema ($f'(x) = 0$), Inflection Points ($f''(x) = 0$), and Y-intercept $f(0)$ as a structured `MatrixValue` / `ListValue` summary.
5. **Parametric, Polar & Numerical ODE Plotting (`parametric`, `polarplot`, `ode`)**:
   - Support 2D parametric curves `plot([x(t), y(t)], t, tMin, tMax)` and `ode(rhs, y0, [t0, t1])` (bridging to `solveOde` in `package:data/numeric.dart`).

### Task 8 Verification & Separate Commit
- **Unit Tests**: Add unit tests in `test/web/calculator/engine_test.dart` covering `analyze`, parametric `plot([cos(t), sin(t)], t, 0, 6.28)`, `ode`, and parameterized `PlotValue`.
- **Design Doc**: Update `doc/calculator_design.md` §3.3 and §3.9 to document `+ Plot`, interactive parameter sliders, `analyze`, parametric plots, and `ode`.
- **UX & Browser Audit**: Verify in Chrome DevTools at `1200×800` and `320×600` that parameter sliders smoothly animate curves, `+ Plot` overlays curves cleanly, and `analyze` renders clearly.
- **Quality Loop & Commit**: Run `dart test`, `dart analyze`, `dart format .`, and create a dedicated commit for Task 8.

---

## Task 9: Shared WebGL2 2D/3D Rendering Engine (`plot3d` & GPU Graphs Across All Web Apps)

### Objective
Build a shared zero-dependency WebGL2 + Canvas2D HUD rendering engine in `web/shared/` using `package:web` `WebGL2RenderingContext`, upgrade 2D graphs across `web/calculator/`, `web/expressions/`, and `web/distributions/` to GPU-accelerated rendering, and add interactive 3D surface rendering (`plot3d` for multivariable expressions $z = f(x, y)$).

### Files to Create / Modify
- Create `web/shared/webgl_chart.dart` (dual-layer WebGL2 2D curve/fill/heatmap renderer + Canvas2D crisp HUD overlay)
- Create `web/shared/webgl_surface.dart` (WebGL2 3D surface mesh renderer with Blinn–Phong lighting, Viridis/Plasma/Cool-Warm colormaps, screen-space `fwidth` contour lines, and turntable orbit camera)
- Modify `web/shared/chart.dart` (integrate WebGL2 backing layer into shared chart primitives)
- Modify `web/calculator/src/model/value.dart` (add `Surface3dValue` or 3D mode on `PlotValue`)
- Modify `web/calculator/src/engine/sampling.dart` (add 2D grid sampling via `expr.toVectorFunction([xVar, yVar])`)
- Modify `web/calculator/src/engine/commands/plot.dart` (add `plot3d(expr, [x, minX, maxX], [y, minY, maxY])` command and `Plot 3D` action chip for 2-variable expressions)
- Modify `web/calculator/src/ui/plot_view.dart` (render 3D interactive WebGL2 surface cards for 2-variable plots and GPU-accelerated 2D plots)
- Modify `web/expressions/main.dart` and `web/expressions/index.html` (render 2D curves with WebGL2 and automatically switch to interactive 3D surface rendering for 2-variable expressions such as `x * exp(-x^2 - y^2)`)
- Modify `web/distributions/main.dart` (use WebGL2 GPU-accelerated curve/area rendering)
- Modify `test/web/calculator/engine_test.dart` and `test/web/calculator/model_test.dart`
- Modify `doc/calculator_design.md`

### Implementation Steps
1. **Shared WebGL2 2D + Canvas2D HUD Renderer (`web/shared/webgl_chart.dart`)**:
   - Create a dual-canvas container (bottom `<canvas>` with `WebGL2RenderingContext` for GPU-accelerated anti-aliased triangle-strip polylines and gradient fills; top `<canvas>` with `CanvasRenderingContext2D` for crisp axes ticks, grid labels, legends, and crosshair tooltips).
   - Provide graceful automatic fallback to Canvas2D if WebGL2 context creation is unavailable in headless environments.
2. **Shared WebGL2 3D Surface Renderer (`web/shared/webgl_surface.dart`)**:
   - Sample $z = f(x, y)$ over an $N \times N$ grid ($72 \times 72$ default) using `expr.toVectorFunction([xVar, yVar])` into a `Float32List` vertex position + analytical/central-difference normal buffer.
   - Compile GLSL ES 3.00 vertex and fragment shaders implementing:
     - Normalized 3D bounding box projection with perspective/orthographic matrix.
     - Smooth height-based scientific colormap (Viridis / Cool-Warm) + directional Blinn–Phong specular/diffuse lighting.
     - Anti-aliased screen-space parameter grid lines (`x = const`, `y = const`) and topographic elevation isolines (`z = const`) using `fwidth()`.
   - Attach pointer/touch/wheel listeners for smooth 3D turntable orbit (drag to rotate azimuth/elevation, wheel/pinch to zoom, double-click to reset camera, hover readout of $(x, y, z)$).
3. **`plot3d` Command & Automatic `Plot 3D` Chip in Calculator**:
   - Add `plot3d(expr, [xVar, minX, maxX, yVar, minY, maxY])` in `web/calculator/src/engine/commands/plot.dart` (inferring the 2 free variables and default domain `[-4, 4] × [-4, 4]` when called with 1 argument: `plot3d(sin(sqrt(x^2 + y^2)))` or `'x^2 - y^2' plot3d`).
   - Automatically surface a **`Plot 3D`** action chip on any `ExprValue` with 2 free variables.
4. **Upgrade `web/expressions` & `web/distributions`**:
   - In `web/expressions/main.dart`, render univariate expressions with the WebGL2 2D renderer and automatically render 2-variable expressions (`x * exp(-x^2 - y^2)`, etc.) using the interactive WebGL2 3D surface renderer alongside their partial derivatives.
   - In `web/distributions/main.dart`, upgrade the PDF/CDF/PMF charts to use the shared WebGL2 renderer.

### Task 9 Verification & Separate Commit
- **Unit Tests**: Add unit tests in `test/web/calculator/engine_test.dart` and `test/web/calculator/model_test.dart` for `plot3d` 1-argument variable inference, 2D grid sampling, and serialization round-tripping.
- **Design Doc**: Update `doc/calculator_design.md` §1.2, §3.3, §3.9, and §5.1 to document WebGL2 2D/3D rendering and `plot3d`, and mark the design doc status as `Implemented`.
- **UX & Browser Audit**: Verify in Chrome DevTools at `1200×800` and `320×600` across `/calculator/`, `/expressions/`, and `/distributions/` that WebGL2 2D charts and 3D surfaces render at 60 fps with crisp HUD overlays and smooth orbit/zoom interactions.
- **Quality Loop & Commit**: Run `dart test`, `dart analyze`, `dart format .`, and create a dedicated commit for Task 9.
