import 'package:collection/collection.dart';

import 'ast.dart';

/// Immutable mathematical domain assumptions for symbolic variables.
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
  /// Creates an [Assumptions] context with per-variable [domains] and a
  /// fallback [defaultDomain] (defaulting to [VariableDomain.unknown]).
  const new({
    this.domains = const {},
    this.defaultDomain = VariableDomain.unknown,
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

  /// Default domain for variables not explicitly listed in [domains].
  final VariableDomain defaultDomain;

  /// Whether this context specifies no domain assumptions (all variables
  /// resolve to [VariableDomain.unknown]).
  bool get isEmpty =>
      defaultDomain == VariableDomain.unknown &&
      domains.values.every((domain) => domain == VariableDomain.unknown);

  /// Resolves the [VariableDomain] of variable [name].
  VariableDomain domainOf(String name) => domains[name] ?? defaultDomain;

  /// Returns a new [Assumptions] that merges [domains] and optionally overrides
  /// [defaultDomain].
  Assumptions copyWith({
    Map<String, VariableDomain>? domains,
    VariableDomain? defaultDomain,
  }) => Assumptions(
    domains: domains == null || domains.isEmpty
        ? this.domains
        : Map<String, VariableDomain>.unmodifiable({
            ...this.domains,
            ...domains,
          }),
    defaultDomain: defaultDomain ?? this.defaultDomain,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Assumptions &&
          defaultDomain == other.defaultDomain &&
          _mapEquality.equals(domains, other.domains);

  @override
  int get hashCode => Object.hash(defaultDomain, _mapEquality.hash(domains));

  static const _mapEquality = MapEquality<String, VariableDomain>();
}
