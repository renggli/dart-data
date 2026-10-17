part of '../ast.dart';

/// Landau asymptotic order remainder term: $O((x - a)^n)$.
///
/// Represents truncated higher-order terms in a Taylor or Laurent series
/// expansion around [point] $a$ of degree [order] $n$ in [variable] $x$.
final class OrderTerm extends Expr {
  /// Creates an asymptotic remainder term $O((x - a)^n)$.
  const new(this.variable, this.order, {this.point = IntegerNumber.zero});

  /// Variable of expansion $x$.
  final String variable;

  /// Expansion center point $a$ (defaults to $0$).
  final Expr point;

  /// Truncation degree $n$.
  final int order;

  @override
  bool get isSimplified => point.isSimplified;

  @override
  double evaluate([Map<String, double> context = const {}]) => 0.0;

  @override
  void _collectFreeVariables(Set<String> target) {
    target.add(variable);
    point._collectFreeVariables(target);
  }

  @override
  bool dependsOn(String variable) =>
      this.variable == variable || point.dependsOn(variable);

  @override
  Expr substitute(String variable, Expr replacement) {
    final newPoint = point.substitute(variable, replacement);
    if (this.variable == variable && replacement is Variable) {
      return OrderTerm(replacement.name, order, point: newPoint);
    }
    return OrderTerm(this.variable, order, point: newPoint);
  }

  @override
  Expr mapChildren(Expr Function(Expr) transform) =>
      OrderTerm(variable, order, point: transform(point));

  @override
  bool anyNode(bool Function(Expr) predicate) =>
      predicate(this) || point.anyNode(predicate);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OrderTerm &&
          variable == other.variable &&
          order == other.order &&
          point == other.point);

  @override
  int get hashCode => Object.hash(OrderTerm, variable, order, point);
}

/// Extension on [Expr] for inspecting and stripping Landau [OrderTerm] remainders.
extension OrderTermExtension on Expr {
  /// Strips any [OrderTerm] remainder from this expression, returning the pure
  /// polynomial or Laurent approximation.
  Expr removeOrder() => _removeOrder(this);
}

Expr _removeOrder(Expr expr) => switch (expr) {
  OrderTerm() => IntegerNumber.zero,
  Add(:final terms) => switch ([
    for (final term in terms)
      if (term is! OrderTerm)
        switch (_removeOrder(term)) {
          OrderTerm() || Number(isZero: true) => null,
          final cleaned => cleaned,
        },
  ].nonNulls.toList()) {
    [] => IntegerNumber.zero,
    [final single] => single,
    final filtered => Add(filtered),
  },
  _ => expr.mapChildren(_removeOrder),
};
