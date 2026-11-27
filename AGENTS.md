# Development Charter

## General Instructions

- When generating new Dart code, strictly follow the style conventions defined in [Effective Dart](https://dart.dev/effective-dart).
- Systematically prefer using `const` constructors and literals whenever possible to optimize runtime performance.
- Prefer using the Dart MCP tool instead of running commands manually.
- Provide a single canonical way to perform an operation; avoid redundant convenience aliases, parameter aliases, or duplicate invocation styles. No backward compatibility is needed; update and rewrite existing code directly.

## API Design Principles & Architectural Goals

- **Solution-Oriented Naming**: Public APIs must be named after the mathematical problems or solutions they provide (e.g., `solve`, `solveSystem`, `integrate`, `derivative`, `gradient`, `hessian`, `jacobian`, `minimize`, `solveOde`, `curveFit`, `fitNonlinear`, `sampleCurve`), not internal algorithm or author names (e.g., avoid top-level `brentRoot`, `gaussKronrod`, `rk4`, `levenbergMarquardt`, `nelderMead`). Algorithm techniques should be selected via typed enums (`RootMethod`, `IntegrationMethod`, `OptimizationMethod`, `OdeMethod`, `PolynomialSystemMethod`) with robust defaults.
- **Hardware Acceleration & Portable Fallback Architecture**: The acceleration subsystem is organized into modular sub-packages (`blas`, `lapack`, `fft`, `vforce`, `utils`). Native FFI acceleration routes through leaf `@ffi.Native` direct-address typed array bindings (`Float64List`, `Int32List`), avoiding generic wrappers or marshalling overhead. Cross-platform Fourier transforms support Apple Accelerate vDSP and FFTW3 (Linux, Windows, Android) using interleaved `Float64ComplexList` layouts `[re0, im0, re1, im1, ...]`. Every accelerated routine MUST have an optimized pure Dart fallback in `*_dart.dart` to guarantee 100% portability and identical numerical semantics across Dart VM, Node.js, Web (JS/Wasm), and mobile without crashes. All accelerated operations must be verified across `auto`, `dart`, and `accelerated` modes using the `accelerationTest` test helper. Higher-level algorithms (in `linear`, `numeric`, `stats`, `polynomial`) must call the unified accelerated facades (`Blas`, `Lapack`, `Fft`, `Vforce`) directly without inspecting `AccelerationManager.mode` or `isAccelerated`, and must never duplicate fallback implementations outside the `acceleration` subsystem.
- **Zero-Cost Extension Types & Memory Model**: Generic containers (`Tensor<double>`, `Matrix<double>`, `Vector<double>`) are complemented by zero-cost Dart 3 extension types (`Float64Tensor`, `Float64Matrix`, `Float64Vector`). They expose direct unboxed buffer access (`asTypedList`) and execute inlined contiguous loops directly on `Float64List` buffers, bypassing generic field abstraction and virtual dispatch while subtyping their generic counterparts transparently. All arithmetic operations remain strictly eager; zero-copy views manipulate `Layout` strides and offsets but never wrap deferred computation logic.
- **Columnar DataFrames & Arrow Interoperability**: Columnar tabular data engines rely on Arrow-aligned chunked series. Support both Apache Arrow IPC streaming/file serialization and the standardized Arrow C Data interface using named arguments (`exportTo({required outSchema, required outArray})`, `importFrom({required schema, required array})`) for zero-copy memory exchange across C, Python, DuckDB, and Polars boundaries.
- **Symmetry & Decoupling Between Numeric and Symbolic**: Maintain clean, parallel APIs and terminology across `package:data/numeric.dart` and `package:data/symbolic.dart`. The `numeric` subsystem is a foundational mathematical layer that must have zero knowledge of or dependencies on `symbolic` (no circular imports; strictly typed function closures like `double Function(double)`, eliminating runtime `dynamic` dispatch). The `symbolic` subsystem bridges into `numeric` via high-speed compiled evaluation closures (`expr.toFunction1D()`, `expr.toVectorFunction()`, and bytecode VM evaluation).
- **Algebraic Container Integration**: The `symbolic` subsystem integrates natively with foundational algebraic container subsystems (`package:data/type.dart`, `package:data/linear.dart`, `package:data/polynomial.dart`). `symbolic` exports `ExprDataType` and `ExprField` implementing `ExtendedField<Expr>`, enabling first-class `Matrix<Expr>`, `Vector<Expr>`, and multivariate polynomial matrices without compromising numeric decoupling. Multivariable calculus operators (`gradient`, `hessian`, `jacobian`) must return first-class `Vector<Expr>` and `Matrix<Expr>` containers rather than raw lists.
- **Exact Symbolic Numeric Representation & Unified AST**: In `package:data/symbolic.dart`, atomic numbers form a unified `Number` tower (`IntegerNumber`, `FractionNumber`, `RealNumber`, `ComplexNumber`) backed directly by reduced `BigInt` numerators and denominators (`IntegerNumber`, `FractionNumber`) and Gaussian/rational `ComplexNumber(real, imaginary)` (`ComplexNumber.i`) nodes that auto-demote when the denominator is 1 or the imaginary part is 0. Named constants (`Constant.pi`, `Constant.e`, `Constant.infinity`, `Constant.undefined`) are opaque `Constant` expressions (not `Number`s) whose numeric `value` is used only for numeric evaluation, numeric approximation (`approximate()`), and interval/sign queries. Variables (`Variable(name)`) are identified purely by name, while domain assumptions, bitmask properties, interval bounds (`VariableBounds`), and relations are supplied via an immutable chainable `Assumptions` value class (`{Assumptions assumptions = Assumptions.none}`) and resolved via `DomainOracle` and `RealInterval` (`lib/src/symbolic/oracle/`). Arithmetic operators use a canonical-by-construction n-ary AST (`Add.of(terms)`, `Mul.of(factors)`, `Pow.of(base, exponent)`) without separate `Sub`, `Div`, `Neg`, or `Exp` classes: subtraction is `a + (-b)`, negation is `Mul.of([-1, x])`, division is `a * Pow.of(b, -1)`, and `exp(x)` is `Pow.of(Constant.e, x)`. All elementary, trigonometric, hyperbolic, logarithmic, special, and uninterpreted function applications unify under `Call(FunctionSpec, args)` (canonical factories on `Fn.*` with typed `FunctionId`), relations under `Relational(RelationalOp, left, right)`, and bound operators under `BinderExpr` (`Integral`, `Derivative`, `Limit`, `Sum`, `Product`, `RootSum`). Composite AST nodes precompute structural bitmask `flags`, `nodeCount`, `structuralTag`, and cached `hashCode` for O(1) equality short-circuiting and DAG subexpression deduplication. Symbolic integration (`integrate`) uses Hermite rational reduction (`hermiteReduce`) and returns an unevaluated `Integral` AST node when no elementary closed-form antiderivative exists rather than throwing exceptions. Parsing (`ExprSyntax.standard`, zero built-in aliases with opt-in `aliases`) and construction preserve input order, while `.simplify()` combines like terms/exponents, extracts integer radicals (`sqrt(12) -> 2 * sqrt(3)`), and sorts additive terms in increasing degree order (`1 + x + x^2 + O(x^3)`). Floating-point numbers (`RealNumber`) are strictly numeric values and must never be treated as symbols or inferred as exact expressions: real numbers simplify down to numeric results only, and there must never be automatic inference or guessing of real numbers to rational numbers or exact constants (`sqrt(2)`, `sqrt(3)`, `pi`, `e`). Real-to-rational conversion is supported exclusively as an explicit, separate operation via `.rationalize()`. When algebraic, transcendental, or power operations are applied to `RealNumber` inputs, they evaluate directly to numeric `RealNumber` results rather than constructing symbolic expressions or matching exact angle/radical identities.
- **No String-Based Symbol Assumptions**: Never assume constants, variables, or functions are present or carry mathematical semantics purely by name (e.g., matching `Call.symbolic` or `Variable` by string name in simplification, differentiation, or integration). Every mathematical constant, special function, or operator requires a first-class `FunctionId` / `FunctionSpec` descriptor and `Fn.*` factory with full support across parsing, formatting, simplification, compilation, evaluation, and calculus.
- **Sub-package Modularization**: Decompose functional modules into dedicated sub-packages within `lib/src/<subsystem>/<feature>/` (e.g., `calculus/`, `ode/`, `root_finding/`, `interpolation/`, `hypothesis/`, `resampling/`, `arrow/`, `blas/`, `lapack/`, `fft/`, `vforce/`), and avoid monolithic files.
- **Mathematical Completeness & Ergonomics**: Preserve analytical and numerical capabilities: infinite/semi-infinite integration domains via coordinate substitution ($[-\infty, \infty]$, $[a, \infty)$, $(-\infty, b]$), singular pole partitioning, convergence error/warning contracts, high-order differentiation stencils (orders 1–6, up to 8 points), high-level parametric curve fitting with confidence metrics, coordinate sampling grids (`linearSpaced`, `logarithmicSpaced`, `geometricSpaced`), adaptive curve sampling with discontinuity detection (`sampleCurve`), natural 2D matrix indexing (`matrix[r][c]`), general least-squares matrix solves (`Matrix.solve` for rectangular and matrix RHS), and memory-efficient sparse polynomials.
- **Web Applications & Mathematical Typography**: Mathematical notation rendered in HTML/MathML across web applications and documentation must match LaTeX typesetting standards in visual rigor, elegance, and consistency:
  - **LaTeX Quality Rendering & Label Symmetry**: All UI labels, headers, toggles, and computed telemetry attributes must maintain 1:1 mathematical and typographic consistency with the library's MathML and LaTeX output. Plain-text mathematical approximations (such as `lim x->0`, `sum`, or raw prime notation) are prohibited where MathML or proper typography applies.
  - **Operator Limit Placement**:
    - *Slanted operators* such as integrals ($\int$) must always place integration limits to the top-right and bottom-right ($\int_a^b$) using subscript/superscript layouts (`<msubsup>`), never stacking numbers vertically directly over/under the slanted glyph.
    - *Iterated operators* ($\sum$, $\prod$) must place index boundaries directly above and below the big Greek glyph ($\sum_{k=1}^n$, $\prod_{k=1}^n$) using `<munderover><mo movablelimits="false">...`.
    - *Limit operators* ($\lim$) must place limit conditions directly underneath the operator name ($\lim_{x \to x_0}$) using `<munder><mo movablelimits="false">lim</mo>...`.
  - **Differentiation Notation**: Differentiation must consistently use Leibniz notation ($\frac{df}{dx}$, $\frac{d^2f}{dx^2}$, $\frac{d^3f}{dx^3}$) across all labels, equation roots, extrema, and evaluated expressions, strictly avoiding inconsistent prime notation ($f'(x)$, $f''(x)$).
  - **Inline & Compact UI Metrics**: In compact telemetry rows and tables, math elements must have uniform sizing, baseline alignment, and non-clipping line heights (`line-height: normal; vertical-align: middle;`) matching adjacent descriptive labels.

## Comments, Documentation and Examples

- Use triple-slash (`///`) doc comments for all public members.
- Use square brackets (`[Name]`) to link all class, constructor, method, and type references within doc comments (e.g., `[DataFrame]`, `[Vector.filled]`, `[Matrix]`, `[Polynomial.fromCoefficients]`). Use markdown sparingly.
- Escape square brackets in mathematical formulas (e.g., `R\[x\]`, `\[a, b\]`) or enclose them in backticks so all bracketed references resolve cleanly without triggering `comment_references` analyzer warnings.
- Do not use LaTeX statements (`$...$` or `$$...$$`) in markdown or Dartdoc documentation; LaTeX syntax is not supported by Dart markdown documentation. Use plain Unicode mathematical notation or code spans instead.
- Start with a concise, single-sentence summary headline. When further explanation is needed, follow with a blank line and transition seamlessly into an accessible, intuitive conceptual explanation alongside mathematically rigorous definitions, properties, formulas, edge cases, parameters, and error handling.
- Never use condescending audience labels (e.g., do not write "For high school students", "For students", or "For mathematicians"). Present conceptual intuition and mathematical rigor naturally as complementary layers of understanding for all readers.
- Include code examples for non-trivial public APIs. Ensure examples are well-formatted, accurate, and relevant, and verify that they compile and produce the advertised output.

## Coding Style and Conventions

### Naming

- File names must use snake-case (e.g., `recipe_card.dart`).
- Class names, enums, and extensions must use upper camel-case (e.g., `RecipeCard`).
- Private class members, variables, and functions (visible only within the file) must be prefixed with an underscore `_`.
- Use descriptive, intention-revealing names that communicate purpose. Avoid single-letter variables except for standard loop counters (`i`, `j`, `k`, ...), axes (`x`, `y`, `z`, ...), or ranges/pairs (`a`, `b`).

### Ordering

- All public members, methods, functions, variables, and constants must be placed at the top of classes and files.
- Class fields (both public and private) must be placed after constructors (or together with their accessors).
- Private methods, functions, variables, and constants must be placed at the bottom of their respective classes and files.

### Imports

- Adhere to the `directives_ordering` linter rule: `dart:` imports first, then `package:` imports, then relative imports.
- Within `lib/`, prefer relative imports (e.g., `import 'src/utils.dart';`) over package imports.
- All imports must be in a single block, not split into multiple import blocks.

### Code Quality

- The code must be auto-formatted (run `dart format .`).
- The code must be free of linter warnings (run `dart analyze` and `dart fix --apply`).
- Embrace strict null safety. Avoid using the non-null assertion operator (`!`) or `dynamic` types, if possible.
- Never use positional record field accessors (`.$1`, `.$2`, etc.). Prefer named record fields or `typedef`s with named fields.

## Logic and Patterns

### Asynchrony

- Prefer `async` / `await` syntax over chaining `Future.then`, `Future.catchError`, etc.
- Always return `Future<void>` instead of `void` for asynchronous functions.

### Error Handling

- **Throw Specific Exceptions**: Never throw generic `Exception` or `String` objects. Always throw specialized exceptions (e.g., `ArgumentError`, `StateError`, `FormatException`) to provide clear context.
- **Catch Narrowly**: Avoid catching generic `Error` or `Exception` types, and never use blank catch blocks (`catch (_)`) or try-catch blocks without rethrowing, as they swallow critical failures.
- **Prevent, Don't Catch**: Do not use exception handling for predictable control flow. If a framework or class provides a non-throwing alternative (e.g., `int.tryParse()` vs `int.parse()`), always prefer the safe method.

## Architecture

- Keep the root `lib/` directory clean. Root files (`lib/*.dart`) are pure public API export facades and the umbrella `lib/data.dart`. Do not put implementation logic in root `lib/*.dart`.
- Place implementation details in `lib/src/<library>/`. Users of the package should not import files from `lib/src/` directly.
- Exports are only allowed in `lib/*.dart`—intermediate internal barrel files inside `lib/src/` are prohibited, and root `lib/<subsystem>.dart` files must export public declarations directly (conditional platform export selectors such as `library_loader.dart` and `arrow_c_data.dart` are allowed exceptions).
- Nothing must depend on the umbrella library `lib/data.dart`.
- The sub-library dependency graph (the dependencies between `lib/src/<library>/` directories) must form a strict Directed Acyclic Graph (DAG) with zero cycles.
- Place cross-cutting utilities without domain coupling in `lib/src/shared/` to prevent circular dependencies between sub-libraries.
- Avoid hyper-fragmenting tightly coupled classes into single-class micro-files (e.g., base classes and private or factory subclasses should be co-located in the same file).
- Verify dependency structure by running `dart test test/deps_test.dart`.
- Avoid introducing new external dependencies in `pubspec.yaml` unless absolutely necessary and no alternative exists in the SDK. Justify any addition to the user.
- Consult [ARCHITECTURE.md](ARCHITECTURE.md) for detailed technical specifications, subsystem architecture, invariants, and design constraints across all subsystems. Always keep [ARCHITECTURE.md](ARCHITECTURE.md) up-to-date when modifying architecture, introducing new subsystems, or altering invariants and contracts.

## Testing

- All code must be accompanied by unit tests in the `test/` folder, aiming for meaningful unit test coverage near 100%.
- Structure tests to strictly mirror `lib/src/` 1:1 (e.g., `lib/src/foo/bar.dart` -> `test/foo/bar_test.dart`).
- Never create or commit test files with cryptic, chat-specific, milestone, or temporary names (e.g., `complex_challenge_*_test.dart`, `m2_*_test.dart`, `*_stress_test.dart`, `*_challenge_test.dart`). All committed tests, stress cases, and challenge suites must be cleanly integrated into their canonical test files.
- Use the Dart `checks` framework (`package:checks` and `package:test/scaffolding.dart`; avoid `package:test/expect.dart`) to assert expected behavior (e.g., `check(result).equals('expected')`, `check(list).isEmpty()`).
- Create reusable domain-specific checks where it makes sense.
- Group tests by functionality using `group('description', () { ... })`. Avoid declaring a single top-level group in a file.
- Avoid groups with a single monolithic test that bundles multiple disparate checks (e.g., combining sampling, fitting, constructor validation, errors, equality, and formatting). Split tests into short, descriptive cases with a couple of related assertions each (e.g., separate tests for moments/bounds, probability density/mass, cumulative distribution/survival, quantiles, sampling, fitting, error validation, equality/hashCode, and string conversion) so failures isolate the exact issue without terminating unrelated assertions.
- **Performance Benchmark Suite (`bin/benchmark_runner.dart`)**: Use `dart run bin/benchmark_runner.dart` (with suite definitions in `bin/benchmark_suites/`) to measure execution times and native hardware acceleration speedups across numeric routines (`numeric`) and symbolic computer algebra workloads (`symbolic`), reporting median durations and empirical 95% bootstrap confidence intervals. Filter suites with `-s <pattern>`, filter workloads with `-t <pattern>`, and print summary markdown tables with `-q`.
- **Symbolic CAS Benchmark Suite (`bin/cas_runner.dart`)**: Use `dart run bin/cas_runner.dart` (with suite definitions in `bin/cas_suites/`) to benchmark and diagnose `package:data/symbolic.dart` against external Computer Algebra System corpora (Wester's 1999 CAS benchmark suite, Gruntz's 1996 limit suite, SymPy algebra/series/summation/product/solver suites, and the external `integration-test-suites` `<name>_integrate` and `<name>_differentiate` corpora cloned via `--update`). Filter suites with `-s <pattern>` (e.g., `dart run bin/cas_runner.dart -s "wester|gruntz|algebra|series|solvers"`, `dart run bin/cas_runner.dart -s "_integrate"`, or `dart run bin/cas_runner.dart -s "_differentiate"`), filter individual cases with `-t <pattern>`, and summarize pass rates with `-q`. Continuously strive to increase the pass rate across all CAS benchmark suites without regressing mathematical rigor or execution speed.
