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
  bool dependsOn(String variable) {
    if (isDefinite) {
      return (variable != this.variable && integrand.dependsOn(variable)) ||
          lower!.dependsOn(variable) ||
          upper!.dependsOn(variable);
    }
    return variable == this.variable || integrand.dependsOn(variable);
  }

  @override
  Expr substitute(String variable, Expr replacement) {
    if (isDefinite) {
      if (variable == this.variable) {
        // Dummy integration variable is bound; only substitute in bounds
        return Integral(
          integrand,
          this.variable,
          lower: lower!.substitute(variable, replacement),
          upper: upper!.substitute(variable, replacement),
        );
      }
      var boundVar = this.variable;
      var body = integrand;
      if (replacement.freeVariables.contains(boundVar)) {
        final used = <String>{
          ...body.freeVariables,
          ...replacement.freeVariables,
          if (lower != null) ...lower!.freeVariables,
          if (upper != null) ...upper!.freeVariables,
        };
        final fresh = _freshBoundVariable(boundVar, used);
        body = body.substitute(boundVar, Variable(fresh));
        boundVar = fresh;
      }
      return Integral(
        body.substitute(variable, replacement),
        boundVar,
        lower: lower!.substitute(variable, replacement),
        upper: upper!.substitute(variable, replacement),
      );
    }
    if (variable == this.variable) {
      if (replacement is Variable) {
        var boundVar = this.variable;
        var body = integrand;
        if (replacement.name != boundVar &&
            body.freeVariables.contains(replacement.name)) {
          final used = <String>{
            ...body.freeVariables,
            ...replacement.freeVariables,
          };
          final fresh = _freshBoundVariable(boundVar, used);
          body = body.substitute(boundVar, Variable(fresh));
          boundVar = fresh;
        }
        return Integral(
          body.substitute(boundVar, replacement),
          replacement.name,
        );
      }
      return Integral(integrand, this.variable);
    }
    var boundVar = this.variable;
    var body = integrand;
    if (replacement.freeVariables.contains(boundVar)) {
      final used = <String>{
        ...body.freeVariables,
        ...replacement.freeVariables,
      };
      final fresh = _freshBoundVariable(boundVar, used);
      body = body.substitute(boundVar, Variable(fresh));
      boundVar = fresh;
    }
    return Integral(body.substitute(variable, replacement), boundVar);
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
