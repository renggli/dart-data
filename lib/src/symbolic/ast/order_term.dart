part of '../ast.dart';

/// Asymptotic Landau order term $O((variable - point)^{order})$.
///
/// In mathematical analysis, the big-O notation $O(f(x))$ describes the limiting
/// behavior of a function when the argument tends towards a particular value or
/// infinity. For a formal power series around $x = a$, an order term $O((x - a)^n)$
/// denotes an unspecified remainder function whose absolute value is bounded by
/// $M \cdot |x - a|^n$ in a neighborhood of $a$.
///
/// ```dart
/// final x = Variable('x');
/// final remainder = OrderTerm('x', 3); // O(x^3)
/// final centered = OrderTerm('x', 2, point: RationalNumber(1)); // O((x - 1)^2)
/// ```
final class OrderTerm extends Expr {
  /// Creates an asymptotic Landau order term $O((variable - point)^{order})$.
  const new(this.variable, this.order, {this.point = RationalNumber.zero});

  /// The asymptotic variable symbol name (e.g. `'x'`).
  final String variable;

  /// The asymptotic truncation order $n$.
  final int order;

  /// The expansion point $a$ as $x \to a$ (defaults to [RationalNumber.zero]).
  final Expr point;

  @override
  bool dependsOn(String name) => variable == name || point.dependsOn(name);

  @override
  void collectFreeVariables(Set<String> target) {
    target.add(variable);
    point.collectFreeVariables(target);
  }

  @override
  Expr substitute(String variable, Expr replacement) {
    final newPoint = point.substitute(variable, replacement);
    if (this.variable == variable && replacement is Variable) {
      return OrderTerm(replacement.name, order, point: newPoint);
    }
    return OrderTerm(this.variable, order, point: newPoint);
  }

  @override
  double evaluate(Map<String, double> context) => 0.0;

  @override
  Complex evaluateComplex([Map<String, Complex> context = const {}]) =>
      Complex.zero;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OrderTerm &&
          variable == other.variable &&
          order == other.order &&
          point == other.point;

  @override
  int get hashCode => Object.hash(OrderTerm, variable, order, point);

  @override
  String toString() => formatExpr(this);
}

/// Recursively removes all [OrderTerm] leaves from [expr].
Expr _removeOrder(Expr expr) => switch (expr) {
  OrderTerm() => RationalNumber.zero,
  Add(:final left, :final right) => switch ((
    _removeOrder(left),
    _removeOrder(right),
  )) {
    (final l, RationalNumber(isZero: true)) => l,
    (RationalNumber(isZero: true), final r) => r,
    (final l, final r) => Add(l, r),
  },
  Sub(:final left, :final right) => switch ((
    _removeOrder(left),
    _removeOrder(right),
  )) {
    (final l, RationalNumber(isZero: true)) => l,
    (RationalNumber(isZero: true), final r) => Neg(r),
    (final l, final r) => Sub(l, r),
  },
  Mul(:final left, :final right) => switch ((
    _removeOrder(left),
    _removeOrder(right),
  )) {
    (_, RationalNumber(isZero: true)) ||
    (RationalNumber(isZero: true), _) => RationalNumber.zero,
    (final l, RationalNumber(isOne: true)) => l,
    (RationalNumber(isOne: true), final r) => r,
    (final l, final r) => Mul(l, r),
  },
  Div(:final left, :final right) => switch ((
    _removeOrder(left),
    _removeOrder(right),
  )) {
    (RationalNumber(isZero: true), _) => RationalNumber.zero,
    (final l, RationalNumber(isOne: true)) => l,
    (final l, final r) => Div(l, r),
  },
  Neg(:final expr) => switch (_removeOrder(expr)) {
    RationalNumber(isZero: true) => RationalNumber.zero,
    final e => Neg(e),
  },
  Pow(:final base, :final exponent) => switch ((
    _removeOrder(base),
    _removeOrder(exponent),
  )) {
    (_, RationalNumber(isZero: true)) => RationalNumber.one,
    (final b, RationalNumber(isOne: true)) => b,
    (final b, final e) => Pow(b, e),
  },
  Sin(:final expr) => Sin(_removeOrder(expr)),
  Cos(:final expr) => Cos(_removeOrder(expr)),
  Tan(:final expr) => Tan(_removeOrder(expr)),
  Sinh(:final expr) => Sinh(_removeOrder(expr)),
  Cosh(:final expr) => Cosh(_removeOrder(expr)),
  Tanh(:final expr) => Tanh(_removeOrder(expr)),
  Asin(:final expr) => Asin(_removeOrder(expr)),
  Acos(:final expr) => Acos(_removeOrder(expr)),
  Atan(:final expr) => Atan(_removeOrder(expr)),
  Exp(:final expr) => Exp(_removeOrder(expr)),
  Ln(:final expr) => Ln(_removeOrder(expr)),
  Abs(:final expr) => Abs(_removeOrder(expr)),
  LambertW(:final expr, :final branch) => LambertW(
    _removeOrder(expr),
    branch: branch,
  ),
  Erf(:final expr) => Erf(_removeOrder(expr)),
  Erfc(:final expr) => Erfc(_removeOrder(expr)),
  Gamma(:final expr) => Gamma(_removeOrder(expr)),
  Beta(:final left, :final right) => Beta(
    _removeOrder(left),
    _removeOrder(right),
  ),
  Asinh(:final expr) => Asinh(_removeOrder(expr)),
  Acosh(:final expr) => Acosh(_removeOrder(expr)),
  Atanh(:final expr) => Atanh(_removeOrder(expr)),
  LessThan(:final left, :final right) => LessThan(
    _removeOrder(left),
    _removeOrder(right),
  ),
  LessEqual(:final left, :final right) => LessEqual(
    _removeOrder(left),
    _removeOrder(right),
  ),
  GreaterThan(:final left, :final right) => GreaterThan(
    _removeOrder(left),
    _removeOrder(right),
  ),
  GreaterEqual(:final left, :final right) => GreaterEqual(
    _removeOrder(left),
    _removeOrder(right),
  ),
  Equal(:final left, :final right) => Equal(
    _removeOrder(left),
    _removeOrder(right),
  ),
  Piecewise(:final branches, :final otherwise) => Piecewise(
    branches.map((b) => (_removeOrder(b.$1), _removeOrder(b.$2))).toList(),
    otherwise: otherwise != null ? _removeOrder(otherwise) : null,
  ),
  Number() || Variable() => expr,
};
