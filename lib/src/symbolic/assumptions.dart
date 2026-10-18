import 'ast.dart';

/// Immutable, chainable mathematical domain assumptions for symbolic variables.
///
/// Pass an [Assumptions] instance to symbolic transformation, calculus, or
/// equation-solving methods to supply domain constraints (`positive`, `real`,
/// `integer`, `complex`) for [Variable] nodes by name without mutating or
/// reconstructing the AST nodes.
///
/// ```dart
/// final expr = Expr.parse('sqrt(x^2) + conj(y)');
/// final simplified = expr.simplify(
///   assumptions: const Assumptions(
///     domains: {'x': VariableDomain.positive, 'y': VariableDomain.real},
///   ),
/// );
/// print(simplified); // x + y
/// ```
final class Assumptions {
  /// Creates an [Assumptions] context with per-variable [domains], a fallback
  /// [defaultDomain] (defaulting to [VariableDomain.unknown]), and an optional
  /// [parent] context for hierarchical lookup.
  const new({
    this.domains = const {},
    this.defaultDomain = VariableDomain.unknown,
    this.parent,
  });

  /// Empty assumptions where all unspecified variables default to
  /// [VariableDomain.unknown].
  static const Assumptions none = Assumptions();

  /// Assumptions where all unspecified variables default to
  /// [VariableDomain.real].
  static const Assumptions real = Assumptions(
    defaultDomain: VariableDomain.real,
  );

  /// Assumptions where all unspecified variables default to
  /// [VariableDomain.positive].
  static const Assumptions positive = Assumptions(
    defaultDomain: VariableDomain.positive,
  );

  /// Assumptions where all unspecified variables default to
  /// [VariableDomain.complex].
  static const Assumptions complex = Assumptions(
    defaultDomain: VariableDomain.complex,
  );

  /// Explicit domain assignments by variable name.
  final Map<String, VariableDomain> domains;

  /// Default domain for variables not explicitly listed in [domains] or [parent].
  final VariableDomain defaultDomain;

  /// Optional parent assumptions consulted before falling back to [defaultDomain].
  final Assumptions? parent;

  /// Whether this context specifies no domain assumptions (all variables
  /// resolve to [VariableDomain.unknown]).
  bool get isEmpty =>
      defaultDomain == VariableDomain.unknown &&
      domains.isEmpty &&
      (parent == null || parent!.isEmpty);

  /// Resolves the [VariableDomain] of variable [name] by walking the
  /// assumption chain from this context through [parent]s.
  VariableDomain domainOf(String name) =>
      domains[name] ?? parent?.domainOf(name) ?? defaultDomain;

  /// Returns a child [Assumptions] that overrides specific [domains] or
  /// [defaultDomain] while chaining to `this` as [parent].
  Assumptions copyWith({
    Map<String, VariableDomain> domains = const {},
    VariableDomain? defaultDomain,
  }) => Assumptions(
    domains: domains,
    defaultDomain: defaultDomain ?? this.defaultDomain,
    parent: this,
  );
}
