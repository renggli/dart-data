# Development Charter

## General Instructions

- When generating new Dart code, strictly follow the style conventions defined in [Effective Dart](https://dart.dev/effective-dart).
- Systematically prefer using `const` constructors and literals whenever possible to optimize runtime performance.
- Prefer using the Dart MCP tool instead of running commands manually.
- Provide a single canonical way to perform an operation; avoid redundant convenience aliases, parameter aliases, or duplicate invocation styles. No backward compatibility is needed; update and rewrite existing code directly.

## API Design Principles & Architectural Goals

- **Solution-Oriented Naming**: Public APIs must be named after the mathematical problems or solutions they provide (e.g., `solve`, `integrate`, `derivative`, `gradient`, `hessian`, `jacobian`, `minimize`, `solveOde`, `curveFit`), not internal algorithm or author names (e.g., avoid top-level `brentRoot`, `gaussKronrod`, `rk4`, `levenbergMarquardt`, `nelderMead`). Algorithm techniques should be selected via typed enums (`RootMethod`, `IntegrationMethod`, `OptimizationMethod`, `OdeMethod`) with robust defaults.
- **Symmetry & Decoupling Between Numeric and Symbolic**: Maintain clean, parallel APIs and terminology across `package:data/numeric.dart` and `package:data/symbolic.dart`. The `numeric` subsystem is a foundational mathematical layer that must have zero knowledge of or dependencies on `symbolic` (no circular imports; strictly typed function closures like `double Function(double)`, eliminating runtime `dynamic` dispatch). The `symbolic` subsystem bridges into `numeric` via high-speed compiled evaluation closures (`expr.toFunction1D()`, `expr.toVectorFunction()`).
- **Algebraic Container Integration**: The `symbolic` subsystem integrates natively with foundational algebraic container subsystems (`package:data/type.dart`, `package:data/linear.dart`, `package:data/polynomial.dart`). `symbolic` exports `ExprDataType` and `ExprField` implementing `ExtendedField<Expr>`, enabling first-class `Matrix<Expr>`, `Vector<Expr>`, and multivariate polynomial matrices without compromising numeric decoupling. Multivariable calculus operators (`gradient`, `hessian`, `jacobian`) must return first-class `Vector<Expr>` and `Matrix<Expr>` containers rather than raw lists.
- **Exact Symbolic Numeric Representation & Unified N-ary AST**: In `package:data/symbolic.dart`, atomic numbers form a unified `Number` tower (`IntegerNumber`, `FractionNumber`, `RealNumber`, `ComplexNumber`) backed by a zero-cost `Integer` extension type (`int | BigInt`) that promotes and demotes transparently. `RationalNumber` (`IntegerNumber` and `FractionNumber`) and Gaussian/rational `ComplexNumber(real, imaginary)` (`ComplexNumber.i`) are single atomic AST nodes that auto-demote when the denominator is $1$ or the imaginary part is $0$. Named constants (`Constant.pi`, `Constant.e`, `Constant.infinity`, `Constant.undefined`) are opaque `Constant` expressions (not `Number`s) whose numeric `value` is used only for numeric evaluation, numeric approximation (`approximate()`), and sign queries. Variables (`Variable(name)`) are identified purely by name, while domain assumptions (`VariableDomain`: `unknown`, `complex`, `real`, `positive`, `integer`) are supplied via an immutable chainable `Assumptions` value class (`{Assumptions assumptions = Assumptions.none}`) and respected by simplification (`sqrt(x^2)`, `abs(x)`) and equation solving (`solve`). Arithmetic operators use a unified n-ary AST (`Add(terms)`, `Mul(factors)`, `Pow(base, exponent)`) without separate `Sub`, `Div`, `Neg`, or `Exp` classes: subtraction is `a + (-b)`, negation is `Mul([-1, x])`, division is `a * Pow(b, -1)`, and `exp(x)` is `Pow(Constant.e, x)`. Composite AST nodes cache their structural `hashCode` via `late final int hashCode` for $O(1)$ equality short-circuiting and DAG subexpression deduplication. Symbolic integration (`integrate`) returns an unevaluated `Integral` AST node when no elementary closed-form antiderivative exists rather than throwing exceptions. Construction and parsing preserve input order, while `.simplify()` combines like terms/exponents, extracts integer radicals (`sqrt(12) -> 2 * sqrt(3)`), and sorts additive terms in increasing degree order (`1 + x + x^2 + O(x^3)`). Floating-point numbers (`RealNumber`) are only created when explicitly parsed from a decimal/scientific literal or constructed directly; symbolic transformations never fall back to `RealNumber` unless a `RealNumber` is already present in the input expression or `.approximate()` is invoked.
- **Mathematical Completeness & Ergonomics**: Preserve analytical and numerical capabilities: infinite/semi-infinite integration domains via coordinate substitution ($[-\infty, \infty]$, $[a, \infty)$, $(-\infty, b]$), singular pole partitioning, convergence error/warning contracts, high-order differentiation stencils (orders 1–6, up to 8 points), high-level parametric curve fitting with confidence metrics, coordinate sampling grids (`linearSpaced`, `logarithmicSpaced`, `geometricSpaced`), natural 2D matrix indexing (`matrix[r][c]`), general least-squares matrix solves (`Matrix.solve` for rectangular and matrix RHS), and memory-efficient sparse polynomials.

## Comments, Documentation and Examples
  
- Use triple-slash (`///`) doc comments for all public members.
- Use square brackets (`[Name]`) to link all class, constructor, method, and type references within doc comments (e.g., `[DataFrame]`, `[Vector.filled]`, `[Matrix]`, `[Polynomial.fromCoefficients]`). Ensure all bracketed identifiers resolve cleanly without linter warnings (`comment_references`). Use markdown sparingly.
- Escape square brackets in mathematical formulas and LaTeX expressions (e.g., `$R\[x\]$`, `$[a, b]$`) or enclose in backticks to prevent the Dart analyzer from treating them as in-scope symbol references and triggering `comment_references` warnings.
- Start with a concise, single-sentence summary headline. When further explanation is needed, transition seamlessly into an accessible, intuitive conceptual explanation followed by mathematically rigorous definitions, properties, and formulas.
- Never use condescending audience labels (e.g., do not write "For high school students", "For students", or "For mathematicians"). Present conceptual intuition and mathematical rigor naturally as complementary layers of understanding for all readers.
- Include code examples for non-trivial public APIs. Ensure examples are well-formatted, accurate, and relevant. Verify that examples compile and produce the advertised output.

## Coding Style and Conventions

### Naming

- File names must use snake-case (e.g., `recipe_card.dart`).
- Class names, enums, and extensions must use upper camel-case (e.g., `RecipeCard`).
- Private class members, variables, and functions (visible only within the file) must be prefixed with an underscore `_`.
- Avoid one-letter variables; unless in loops (i, j, k, ...), referring to axis (x, y, z, ...), or ranges/pairs (a, b).

### Ordering

- All public members, methods, functions, variables, and constants must be placed at the top of classes and files.
- Class fields (both public and private) must be placed after constructors (or together with their accessors).
- Private methods, functions, variables, and constants must be placed at the bottom of their respective classes and files.

### Imports

- Adhere to the `directives_ordering` linter rule: `dart:` imports first, then `package:` imports, then relative imports.
- Within `lib/`, prefer relative imports (e.g., `import 'src/utils.dart';`) over package imports.

### Code Quality

- The code must be auto-formatted (run `dart format .`).
- The code must be free of linter warnings (run `dart analyze` and `dart fix --apply`).
- Embrace strict null safety. Avoid using the non-null assertion operator (`!`) or `dynamic` types, if possible.
- Never use positional record field accessors (`.$1`, `.$2`, etc.). Prefer named record fields (or `typedef`s with named fields.

## Logic and Patterns

### Asynchrony

- Prefer `async` / `await` syntax over chaining `Future.then`, `Future.catchError`, ...
- Always return `Future<void>` instead of `void` for asynchronous functions.

### Error Handling

- Throw specific exceptions (e.g., `ArgumentError`, `StateError`, `FormatException`) rather than generic `Exception`.
- Catch specific exceptions. Avoid generic `catch (e)` unless you are logging the error or rethrowing it.

## Architecture

- Keep the root `lib/` directory clean. It should primarily contain the public API exports.
- Place implementation details in `lib/src/`. Users of the package should not import files from `lib/src/` directly.
- Avoid introducing new external dependencies in `pubspec.yaml` unless absolutely necessary and no alternative exists in the SDK. Justify any addition to the user.
- Consult [ARCHITECTURE.md](ARCHITECTURE.md) for detailed technical specifications, subsystem architecture, invariants, and design constraints across all subsystems. Always keep [ARCHITECTURE.md](ARCHITECTURE.md) up-to-date when modifying architecture, introducing new subsystems, or altering invariants and contracts.

## Testing

- All code must be accompanied by unit tests in the `test/` folder.
- Structure the tests following the same folder structure as the code under test (e.g., `lib/src/foo/bar.dart` -> `test/foo/bar_test.dart`). Maintain a strict parallel hierarchy matching `lib/src/`.
- Never create or commit test files with cryptic, chat-specific, milestone, or temporary names (e.g., `complex_challenge_*_test.dart`, `m2_*_test.dart`, `*_stress_test.dart`, `*_challenge_test.dart`). All committed tests, stress cases, and challenge suites must be cleanly integrated into their canonical test files.
- Use the Dart `checks` framework (`package:checks`) to assert expected behavior (e.g., `check(result).equals('expected')`, `check(list).isEmpty()`). Prefer `check(...)` assertions over legacy `expect`.
- Group tests by functionality using `group('description', () { ... })`. Avoid declaring a single top-level group in a file.
