part of '../ast.dart';

/// Symbolic derivative node representing an unevaluated derivative
/// $\frac{d^n}{dx^n} f(x)$ or evaluated at a point $\left.\frac{d^n}{dx^n} f(x)\right|_{x=a}$.
final class Derivative extends Expr {
  /// Creates a symbolic derivative of [expr] with respect to [variable] of
  /// order [order], optionally evaluated at [point].
  new(
    this.expr,
    this.variable, {
    this.order = 1,
    this.point,
    this.isSimplified = false,
  }) : assert(order >= 1, 'Derivative order must be at least 1.');

  /// The differentiated operand expression $f(x)$.
  final Expr expr;

  /// The variable of differentiation $x$.
  final String variable;

  /// The order of differentiation $n \ge 1$.
  final int order;

  /// Optional evaluation point $a$ for $\left.\frac{d^n}{dx^n} f(x)\right|_{x=a}$.
  final Expr? point;

  @override
  final bool isSimplified;

  @override
  late final int hashCode = Object.hash(
    Derivative,
    expr,
    variable,
    order,
    point,
  );

  @override
  void _collectFreeVariables(Set<String> target) {
    if (point case final pt?) {
      final innerVars = <String>{};
      expr._collectFreeVariables(innerVars);
      innerVars.remove(variable);
      target.addAll(innerVars);
      pt._collectFreeVariables(target);
    } else {
      expr._collectFreeVariables(target);
      target.add(variable);
    }
  }

  @override
  bool dependsOn(String variable) {
    if (point case final pt?) {
      return pt.dependsOn(variable) ||
          (variable != this.variable && expr.dependsOn(variable));
    }
    return variable == this.variable || expr.dependsOn(variable);
  }

  @override
  Expr substitute(String variable, Expr replacement) {
    if (point case final pt?) {
      if (variable == this.variable) {
        // Bound variable: only substitute in evaluation point
        return Derivative(
          expr,
          this.variable,
          order: order,
          point: pt.substitute(variable, replacement),
        );
      }
      var boundVar = this.variable;
      var body = expr;
      if (replacement.freeVariables.contains(boundVar)) {
        final used = <String>{
          ...body.freeVariables,
          ...replacement.freeVariables,
          ...pt.freeVariables,
        };
        final fresh = _freshBoundVariable(boundVar, used);
        body = body.substitute(boundVar, Variable(fresh));
        boundVar = fresh;
      }
      return Derivative(
        body.substitute(variable, replacement),
        boundVar,
        order: order,
        point: pt.substitute(variable, replacement),
      );
    }

    if (variable == this.variable) {
      if (replacement is Variable) {
        final targetName = replacement.name;
        var body = expr;
        if (targetName != this.variable &&
            body.freeVariables.contains(targetName)) {
          final used = <String>{
            ...body.freeVariables,
            ...replacement.freeVariables,
          };
          final fresh = _freshBoundVariable(targetName, used);
          body = body.substitute(targetName, Variable(fresh));
        }
        return Derivative(
          body.substitute(this.variable, replacement),
          targetName,
          order: order,
        );
      }
      final derived = expr.derivative(variable, order: order);
      if (!derived.anyNode(
        (node) =>
            node is Derivative &&
            node.variable == variable &&
            node.point == null,
      )) {
        return derived.substitute(variable, replacement);
      }
      return Derivative(expr, variable, order: order, point: replacement);
    }

    var boundVar = this.variable;
    var body = expr;
    if (replacement.freeVariables.contains(boundVar)) {
      final used = <String>{
        ...body.freeVariables,
        ...replacement.freeVariables,
      };
      final fresh = _freshBoundVariable(boundVar, used);
      body = body.substitute(boundVar, Variable(fresh));
      boundVar = fresh;
    }
    return Derivative(
      body.substitute(variable, replacement),
      boundVar,
      order: order,
    );
  }

  @override
  Expr mapChildren(Expr Function(Expr) transform) => Derivative(
    transform(expr),
    variable,
    order: order,
    point: point != null ? transform(point!) : null,
  );

  @override
  bool anyNode(bool Function(Expr) predicate) =>
      predicate(this) ||
      expr.anyNode(predicate) ||
      (point?.anyNode(predicate) ?? false);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Derivative &&
          hashCode == other.hashCode &&
          order == other.order &&
          variable == other.variable &&
          expr == other.expr &&
          point == other.point);
}
