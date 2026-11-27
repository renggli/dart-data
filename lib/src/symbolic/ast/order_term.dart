part of '../ast.dart';

/// Landau asymptotic order remainder term: `O((x - a)^n)`.
final class OrderTerm extends Expr {
  /// Creates an asymptotic remainder term `O((x - a)^n)`.
  new(this.variable, this.order, {Expr? point})
    : point = point ?? IntegerNumber.zero;

  /// Variable of expansion `x`.
  final String variable;

  /// Expansion center point `a` (defaults to `0`).
  final Expr point;

  /// Truncation degree `n`.
  final int order;

  @override
  int get flags => kFlagHasVariable | kFlagHasOrder | point.flags;

  @override
  int get nodeCount => 1 + point.nodeCount;

  @override
  int get structuralTag => 100;

  @override
  Set<String> get freeVariables =>
      Set.unmodifiable({variable, ...point.freeVariables});

  @override
  bool dependsOn(String variable) =>
      this.variable == variable || point.dependsOn(variable);

  @override
  Expr substitute(String variable, Expr replacement) {
    if (this.variable == variable) {
      if (replacement == point) {
        return order > 0 ? IntegerNumber.zero : Constant.undefined;
      }
      if (replacement is Variable) {
        if (replacement.name == this.variable) return this;
        if (!point.dependsOn(replacement.name)) {
          return OrderTerm(replacement.name, order, point: point);
        }
        return this;
      }
      if (replacement.freeVariables.length == 1) {
        final newVar = replacement.freeVariables.first;
        if (!point.dependsOn(newVar)) {
          final shifted = (replacement - point).simplify();
          if (shifted.matchLinear(newVar) case (:final a, :final b)) {
            final newPoint = (-b / a).simplify();
            return OrderTerm(newVar, order, point: newPoint);
          }
        }
      }
      if (replacement.freeVariables.isEmpty) {
        return order > 0 ? IntegerNumber.zero : this;
      }
      return this;
    }
    final newPoint = point.substitute(variable, replacement);
    return identical(newPoint, point)
        ? this
        : OrderTerm(this.variable, order, point: newPoint);
  }

  @override
  Expr mapChildren(Expr Function(Expr) transform) {
    final next = transform(point);
    return identical(next, point)
        ? this
        : OrderTerm(variable, order, point: next);
  }

  @override
  bool anyNode(bool Function(Expr) predicate) =>
      predicate(this) || point.anyNode(predicate);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OrderTerm &&
          hashCode == other.hashCode &&
          variable == other.variable &&
          order == other.order &&
          point == other.point);

  @override
  late final int hashCode = Object.hash(OrderTerm, variable, order, point);
}

/// Extension on [Expr] for stripping Landau [OrderTerm] remainders.
extension OrderTermExtension on Expr {
  /// Strips any [OrderTerm] remainder from this expression, returning the pure
  /// polynomial or Laurent approximation.
  Expr removeOrder() => _removeOrder(this);
}

Expr _removeOrder(Expr expr) {
  if (!expr.hasOrder) return expr;
  return switch (expr) {
    OrderTerm() => IntegerNumber.zero,
    Mul(:final factors) when factors.any((f) => f is OrderTerm) =>
      IntegerNumber.zero,
    Add(:final terms) => Add.of([
      for (final term in terms)
        if (term is! OrderTerm) _removeOrder(term),
    ]),
    _ => expr.mapChildren(_removeOrder),
  };
}
