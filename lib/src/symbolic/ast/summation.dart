part of '../ast.dart';

/// Symbolic summation node representing an unevaluated definite sum
/// $\sum_{k=a}^{b} f(k)$.
final class Sum extends Expr {
  /// Creates a symbolic sum of [expr] with respect to [variable] from [lower]
  /// to [upper].
  new(
    this.expr,
    this.variable,
    this.lower,
    this.upper, {
    this.isSimplified = false,
  });

  /// The summand expression $f(k)$.
  final Expr expr;

  /// The bound summation index variable $k$.
  final String variable;

  /// The lower summation bound $a$.
  final Expr lower;

  /// The upper summation bound $b$.
  final Expr upper;

  @override
  final bool isSimplified;

  @override
  late final int hashCode = Object.hash(Sum, expr, variable, lower, upper);

  @override
  void _collectFreeVariables(Set<String> target) {
    final innerVars = <String>{};
    expr._collectFreeVariables(innerVars);
    innerVars.remove(variable);
    target.addAll(innerVars);
    lower._collectFreeVariables(target);
    upper._collectFreeVariables(target);
  }

  @override
  bool dependsOn(String variable) =>
      (variable != this.variable && expr.dependsOn(variable)) ||
      lower.dependsOn(variable) ||
      upper.dependsOn(variable);

  @override
  Expr substitute(String variable, Expr replacement) => Sum(
    variable == this.variable ? expr : expr.substitute(variable, replacement),
    this.variable,
    lower.substitute(variable, replacement),
    upper.substitute(variable, replacement),
  );

  @override
  Expr mapChildren(Expr Function(Expr) transform) =>
      Sum(transform(expr), variable, transform(lower), transform(upper));

  @override
  bool anyNode(bool Function(Expr) predicate) =>
      predicate(this) ||
      expr.anyNode(predicate) ||
      lower.anyNode(predicate) ||
      upper.anyNode(predicate);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Sum &&
          hashCode == other.hashCode &&
          variable == other.variable &&
          expr == other.expr &&
          lower == other.lower &&
          upper == other.upper);
}

/// Symbolic product node representing an unevaluated definite product
/// $\prod_{k=a}^{b} f(k)$.
final class Product extends Expr {
  /// Creates a symbolic product of [expr] with respect to [variable] from
  /// [lower] to [upper].
  new(
    this.expr,
    this.variable,
    this.lower,
    this.upper, {
    this.isSimplified = false,
  });

  /// The factor expression $f(k)$.
  final Expr expr;

  /// The bound product index variable $k$.
  final String variable;

  /// The lower product bound $a$.
  final Expr lower;

  /// The upper product bound $b$.
  final Expr upper;

  @override
  final bool isSimplified;

  @override
  late final int hashCode = Object.hash(Product, expr, variable, lower, upper);

  @override
  void _collectFreeVariables(Set<String> target) {
    final innerVars = <String>{};
    expr._collectFreeVariables(innerVars);
    innerVars.remove(variable);
    target.addAll(innerVars);
    lower._collectFreeVariables(target);
    upper._collectFreeVariables(target);
  }

  @override
  bool dependsOn(String variable) =>
      (variable != this.variable && expr.dependsOn(variable)) ||
      lower.dependsOn(variable) ||
      upper.dependsOn(variable);

  @override
  Expr substitute(String variable, Expr replacement) => Product(
    variable == this.variable ? expr : expr.substitute(variable, replacement),
    this.variable,
    lower.substitute(variable, replacement),
    upper.substitute(variable, replacement),
  );

  @override
  Expr mapChildren(Expr Function(Expr) transform) =>
      Product(transform(expr), variable, transform(lower), transform(upper));

  @override
  bool anyNode(bool Function(Expr) predicate) =>
      predicate(this) ||
      expr.anyNode(predicate) ||
      lower.anyNode(predicate) ||
      upper.anyNode(predicate);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Product &&
          hashCode == other.hashCode &&
          variable == other.variable &&
          expr == other.expr &&
          lower == other.lower &&
          upper == other.upper);
}
