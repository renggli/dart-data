part of '../ast.dart';

/// Symbolic integral node representing an unevaluated indefinite integral
/// $\int f(x) \, dx$ or definite integral $\int_{a}^{b} f(x) \, dx$.
final class Integral extends Expr {
  /// Creates a symbolic integral of [integrand] with respect to [variable],
  /// optionally bounded from [lower] to [upper].
  new(
    this.integrand,
    this.variable, {
    this.lower,
    this.upper,
    this.isSimplified = false,
  }) : assert(
         (lower == null) == (upper == null),
         'Both lower and upper bounds must be provided for definite integrals, '
         'or neither for indefinite integrals.',
       );

  /// The integrand expression $f(x)$.
  final Expr integrand;

  /// The variable of integration $x$.
  final String variable;

  /// Optional lower bound $a$ for a definite integral.
  final Expr? lower;

  /// Optional upper bound $b$ for a definite integral.
  final Expr? upper;

  /// Whether this represents a definite integral with [lower] and [upper] bounds.
  bool get isDefinite => lower != null && upper != null;

  @override
  final bool isSimplified;

  @override
  late final int hashCode = Object.hash(
    Integral,
    integrand,
    variable,
    lower,
    upper,
  );

  @override
  void _collectFreeVariables(Set<String> target) {
    if (isDefinite) {
      final innerVars = <String>{};
      integrand._collectFreeVariables(innerVars);
      innerVars.remove(variable);
      target.addAll(innerVars);
      lower!._collectFreeVariables(target);
      upper!._collectFreeVariables(target);
    } else {
      integrand._collectFreeVariables(target);
      target.add(variable);
    }
  }

  @override
  bool dependsOn(String v) {
    if (isDefinite) {
      return (v != variable && integrand.dependsOn(v)) ||
          lower!.dependsOn(v) ||
          upper!.dependsOn(v);
    }
    return v == variable || integrand.dependsOn(v);
  }

  @override
  Expr substitute(String v, Expr replacement) {
    if (isDefinite) {
      return Integral(
        v == variable ? integrand : integrand.substitute(v, replacement),
        variable,
        lower: lower!.substitute(v, replacement),
        upper: upper!.substitute(v, replacement),
      );
    }
    return Integral(integrand.substitute(v, replacement), variable);
  }

  @override
  Expr mapChildren(Expr Function(Expr) transform) => Integral(
    transform(integrand),
    variable,
    lower: lower != null ? transform(lower!) : null,
    upper: upper != null ? transform(upper!) : null,
  );

  @override
  bool anyNode(bool Function(Expr) predicate) =>
      predicate(this) ||
      integrand.anyNode(predicate) ||
      (lower?.anyNode(predicate) ?? false) ||
      (upper?.anyNode(predicate) ?? false);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Integral &&
          hashCode == other.hashCode &&
          variable == other.variable &&
          integrand == other.integrand &&
          lower == other.lower &&
          upper == other.upper);
}
