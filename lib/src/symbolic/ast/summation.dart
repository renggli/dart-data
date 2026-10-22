part of '../ast.dart';

/// Base class for bounded indexed expressions over a discrete integer range.
sealed class IteratedExpr extends Expr {
  const new(
    this.expr,
    this.variable,
    this.lower,
    this.upper, {
    this.isSimplified = false,
  });

  /// The inner operand expression $f(k)$.
  final Expr expr;

  /// The bound index variable $k$.
  final String variable;

  /// The lower bound $a$.
  final Expr lower;

  /// The upper bound $b$.
  final Expr upper;

  @override
  final bool isSimplified;

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
  bool anyNode(bool Function(Expr) predicate) =>
      predicate(this) ||
      expr.anyNode(predicate) ||
      lower.anyNode(predicate) ||
      upper.anyNode(predicate);

  /// Factory helper to reconstruct this node with updated children.
  IteratedExpr copyWith({
    Expr? expr,
    String? variable,
    Expr? lower,
    Expr? upper,
    bool? isSimplified,
  });

  @override
  Expr substitute(String variable, Expr replacement) {
    if (variable == this.variable) {
      return copyWith(
        expr: expr,
        lower: lower.substitute(variable, replacement),
        upper: upper.substitute(variable, replacement),
      );
    }
    var boundVar = this.variable;
    var body = expr;
    if (replacement.freeVariables.contains(boundVar)) {
      final used = <String>{
        ...body.freeVariables,
        ...replacement.freeVariables,
        ...lower.freeVariables,
        ...upper.freeVariables,
      };
      final fresh = _freshBoundVariable(boundVar, used);
      body = body.substitute(boundVar, Variable(fresh));
      boundVar = fresh;
    }
    return copyWith(
      expr: body.substitute(variable, replacement),
      variable: boundVar,
      lower: lower.substitute(variable, replacement),
      upper: upper.substitute(variable, replacement),
    );
  }

  @override
  Expr mapChildren(Expr Function(Expr) transform) => copyWith(
    expr: transform(expr),
    lower: transform(lower),
    upper: transform(upper),
  );

  /// Tests equality against another [IteratedExpr] of the same runtime type.
  bool equalsIterated(IteratedExpr other) =>
      variable == other.variable &&
      expr == other.expr &&
      lower == other.lower &&
      upper == other.upper;
}

/// Symbolic summation node representing an unevaluated definite sum
/// $\sum_{k=a}^{b} f(k)$.
final class Sum extends IteratedExpr {
  /// Creates a symbolic sum of [expr] with respect to [variable] from [lower]
  /// to [upper].
  new(
    super.expr,
    super.variable,
    super.lower,
    super.upper, {
    super.isSimplified = false,
  });

  @override
  late final int hashCode = Object.hash(Sum, expr, variable, lower, upper);

  @override
  Sum copyWith({
    Expr? expr,
    String? variable,
    Expr? lower,
    Expr? upper,
    bool? isSimplified,
  }) => Sum(
    expr ?? this.expr,
    variable ?? this.variable,
    lower ?? this.lower,
    upper ?? this.upper,
    isSimplified: isSimplified ?? this.isSimplified,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Sum && hashCode == other.hashCode && equalsIterated(other));
}

/// Symbolic product node representing an unevaluated definite product
/// $\prod_{k=a}^{b} f(k)$.
final class Product extends IteratedExpr {
  /// Creates a symbolic product of [expr] with respect to [variable] from
  /// [lower] to [upper].
  new(
    super.expr,
    super.variable,
    super.lower,
    super.upper, {
    super.isSimplified = false,
  });

  @override
  late final int hashCode = Object.hash(Product, expr, variable, lower, upper);

  @override
  Product copyWith({
    Expr? expr,
    String? variable,
    Expr? lower,
    Expr? upper,
    bool? isSimplified,
  }) => Product(
    expr ?? this.expr,
    variable ?? this.variable,
    lower ?? this.lower,
    upper ?? this.upper,
    isSimplified: isSimplified ?? this.isSimplified,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Product && hashCode == other.hashCode && equalsIterated(other));
}
