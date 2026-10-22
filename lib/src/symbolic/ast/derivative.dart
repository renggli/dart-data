part of '../ast.dart';

/// Symbolic derivative node representing an unevaluated derivative
/// $\frac{d^n}{dx^n} f(x)$.
final class Derivative extends Expr {
  /// Creates a symbolic derivative of [expr] with respect to [variable] of
  /// order [order].
  new(this.expr, this.variable, {this.order = 1, this.isSimplified = false})
    : assert(order >= 1, 'Derivative order must be at least 1.');

  /// The differentiated operand expression $f(x)$.
  final Expr expr;

  /// The variable of differentiation $x$.
  final String variable;

  /// The order of differentiation $n \ge 1$.
  final int order;

  @override
  final bool isSimplified;

  @override
  late final int hashCode = Object.hash(Derivative, expr, variable, order);

  @override
  void _collectFreeVariables(Set<String> target) {
    expr._collectFreeVariables(target);
    target.add(variable);
  }

  @override
  bool dependsOn(String variable) =>
      variable == this.variable || expr.dependsOn(variable);

  @override
  Expr substitute(String variable, Expr replacement) {
    if (variable == this.variable) {
      if (replacement is Variable) {
        return Derivative(
          expr.substitute(variable, replacement),
          replacement.name,
          order: order,
        );
      }
      return Derivative(expr, this.variable, order: order);
    }
    return Derivative(
      expr.substitute(variable, replacement),
      this.variable,
      order: order,
    );
  }

  @override
  Expr mapChildren(Expr Function(Expr) transform) =>
      Derivative(transform(expr), variable, order: order);

  @override
  bool anyNode(bool Function(Expr) predicate) =>
      predicate(this) || expr.anyNode(predicate);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Derivative &&
          hashCode == other.hashCode &&
          order == other.order &&
          variable == other.variable &&
          expr == other.expr);
}
