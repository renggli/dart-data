import 'dart:async';

import 'ast.dart';

/// Cooperative zone-scoped mathematical domain assumptions for symbolic variables.
///
/// Wrap symbolic operations (such as simplification, equation solving, or
/// complex-part reductions) in [Assumptions.run] to supply domain constraints
/// (`positive`, `real`, `integer`, `complex`) for [Variable] nodes by name
/// without mutating or reconstructing the AST nodes.
///
/// ```dart
/// final expr = Expr.parse('sqrt(x^2) + conj(y)');
/// final simplified = Assumptions.run(
///   () => expr.simplify(),
///   domains: {'x': VariableDomain.positive, 'y': VariableDomain.real},
/// );
/// print(simplified); // x + y
/// ```
abstract final class Assumptions {
  static final Object _assumptionsKey = Object();
  static int _activeZones = 0;

  /// Whether an [Assumptions.run] zone is currently active.
  static bool get isActive => _activeZones > 0;

  /// Executes [body] within a zone that binds variable names in [domains]
  /// (and any unmentioned variables to [defaultDomain], if provided) to their
  /// assumed [VariableDomain].
  ///
  /// When nested inside an outer [Assumptions.run], inner bindings in [domains]
  /// and [defaultDomain] override outer bindings while preserving non-overridden
  /// outer assumptions.
  static R run<R>(
    R Function() body, {
    Map<String, VariableDomain> domains = const {},
    VariableDomain? defaultDomain,
  }) {
    final parent = _activeZones > 0
        ? Zone.current[_assumptionsKey] as _AssumptionsState?
        : null;
    final mergedDomains = <String, VariableDomain>{
      ...?parent?.domains,
      ...domains,
    };
    final state = _AssumptionsState(
      domains: mergedDomains,
      defaultDomain: defaultDomain ?? parent?.defaultDomain,
    );
    _activeZones++;
    try {
      return runZoned(body, zoneValues: {_assumptionsKey: state});
    } finally {
      _activeZones--;
    }
  }

  /// Resolves the assumed [VariableDomain] for a variable [name] in the current
  /// zone, or [VariableDomain.unknown] if no assumption is active.
  static VariableDomain domainOf(
    String name, [
    VariableDomain explicit = VariableDomain.unknown,
  ]) {
    if (_activeZones == 0) return explicit;
    final state = Zone.current[_assumptionsKey] as _AssumptionsState?;
    if (state == null) return explicit;
    final mapped = state.domains[name];
    if (mapped != null) return mapped;
    if (explicit != VariableDomain.unknown) return explicit;
    return state.defaultDomain ?? VariableDomain.unknown;
  }
}

final class _AssumptionsState {
  const new({required this.domains, required this.defaultDomain});

  final Map<String, VariableDomain> domains;
  final VariableDomain? defaultDomain;
}
