part of '../ast.dart';

/// Direction for computing directional limits of symbolic expressions.
enum LimitDirection {
  /// Two-sided limit $\lim_{x \to a} f(x)$. Requires left and right limits to agree.
  both,

  /// Right-hand limit $\lim_{x \to a^+} f(x)$ (approaching from above).
  fromAbove,

  /// Left-hand limit $\lim_{x \to a^-} f(x)$ (approaching from below).
  fromBelow,
}

/// Symbolic limit node representing an unevaluated limit
/// $\lim_{x \to a} f(x)$.
final class Limit extends Expr {
  /// Creates a symbolic limit of [expr] as [variable] approaches [point] from
  /// [direction].
  new(
    this.expr,
    this.variable,
    this.point, {
    this.direction = LimitDirection.both,
    this.isSimplified = false,
  });

  /// The operand expression $f(x)$.
  final Expr expr;

  /// The bound limit variable $x$.
  final String variable;

  /// The target limit point $a$.
  final Expr point;

  /// The limit direction (two-sided, from above, or from below).
  final LimitDirection direction;

  @override
  final bool isSimplified;

  @override
  late final int hashCode = Object.hash(
    Limit,
    expr,
    variable,
    point,
    direction,
  );

  @override
  void _collectFreeVariables(Set<String> target) {
    final innerVars = <String>{};
    expr._collectFreeVariables(innerVars);
    innerVars.remove(variable);
    target.addAll(innerVars);
    point._collectFreeVariables(target);
  }

  @override
  bool dependsOn(String variable) =>
      (variable != this.variable && expr.dependsOn(variable)) ||
      point.dependsOn(variable);

  @override
  Expr substitute(String variable, Expr replacement) {
    if (variable == this.variable) {
      return Limit(
        expr,
        this.variable,
        point.substitute(variable, replacement),
        direction: direction,
      );
    }
    var boundVar = this.variable;
    var body = expr;
    if (replacement.freeVariables.contains(boundVar)) {
      final used = <String>{
        ...body.freeVariables,
        ...replacement.freeVariables,
        ...point.freeVariables,
      };
      final fresh = _freshBoundVariable(boundVar, used);
      body = body.substitute(boundVar, Variable(fresh));
      boundVar = fresh;
    }
    return Limit(
      body.substitute(variable, replacement),
      boundVar,
      point.substitute(variable, replacement),
      direction: direction,
    );
  }

  @override
  Expr mapChildren(Expr Function(Expr) transform) =>
      Limit(transform(expr), variable, transform(point), direction: direction);

  @override
  bool anyNode(bool Function(Expr) predicate) =>
      predicate(this) || expr.anyNode(predicate) || point.anyNode(predicate);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Limit &&
          hashCode == other.hashCode &&
          direction == other.direction &&
          variable == other.variable &&
          point == other.point &&
          expr == other.expr);
}
