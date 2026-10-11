import 'dart:math' as math;

import 'ast.dart';

/// Canonical algebraic simplification extension on [Expr].
extension SimplifierExtension on Expr {
  /// Canonically simplifies this expression by performing constant folding and
  /// identity reductions.
  ///
  /// Conceptually, this simplifies expressions using algebraic identities such
  /// as $x + 0 \to x$, $x \cdot 1 \to x$, $0 \cdot x \to 0$, and evaluates
  /// constant sub-expressions like $2 + 3 \to 5$. Formally, this executes
  /// confluent rewriting rules to reduce algebraic expressions into canonical
  /// normal form over additive and multiplicative identities, annihilators, and
  /// constants.
  ///
  /// ```dart
  /// final x = Variable('x');
  /// final expr = (x + 0) * 1 + (const Constant(2.0) + const Constant(3.0));
  /// final s = expr.simplify(); // x + 5
  /// ```
  Expr simplify() => _simplify(this);
}

Expr _simplify(Expr expr) => switch (expr) {
  Constant() || Variable() => expr,
  Add(:final left, :final right) => _simplifyAdd(
    _simplify(left),
    _simplify(right),
  ),
  Sub(:final left, :final right) => _simplifySub(
    _simplify(left),
    _simplify(right),
  ),
  Mul(:final left, :final right) => _simplifyMul(
    _simplify(left),
    _simplify(right),
  ),
  Div(:final left, :final right) => _simplifyDiv(
    _simplify(left),
    _simplify(right),
  ),
  Pow(:final base, :final exponent) => _simplifyPow(
    _simplify(base),
    _simplify(exponent),
  ),
  Neg(:final expr) => _simplifyNeg(_simplify(expr)),
  Sin(:final expr) => _simplifySin(_simplify(expr)),
  Cos(:final expr) => _simplifyCos(_simplify(expr)),
  Exp(:final expr) => _simplifyExp(_simplify(expr)),
  Ln(:final expr) => _simplifyLn(_simplify(expr)),
};

Expr _simplifyAdd(Expr left, Expr right) => switch ((left, right)) {
  (Constant(value: final l), Constant(value: final r)) => Constant(l + r),
  (Constant(value: 0.0), final r) => r,
  (final l, Constant(value: 0.0)) => l,
  _ => Add(left, right),
};

Expr _simplifySub(Expr left, Expr right) => switch ((left, right)) {
  (Constant(value: final l), Constant(value: final r)) => Constant(l - r),
  (final l, Constant(value: 0.0)) => l,
  _ when left == right => const Constant(0.0),
  _ => Sub(left, right),
};

Expr _simplifyMul(Expr left, Expr right) => switch ((left, right)) {
  (Constant(value: final l), Constant(value: final r)) => Constant(l * r),
  (Constant(value: 0.0), _) || (_, Constant(value: 0.0)) => const Constant(0.0),
  (Constant(value: 1.0), final r) => r,
  (final l, Constant(value: 1.0)) => l,
  (Constant(value: -1.0), final r) => Neg(r),
  (final l, Constant(value: -1.0)) => Neg(l),
  _ => Mul(left, right),
};

Expr _simplifyDiv(Expr left, Expr right) => switch ((left, right)) {
  (_, Constant(value: 0.0)) => throw UnsupportedError(
    'Division by zero in simplification',
  ),
  (Constant(value: final l), Constant(value: final r)) => Constant(l / r),
  (Constant(value: 0.0), _) => const Constant(0.0),
  (final l, Constant(value: 1.0)) => l,
  (final l, Constant(value: -1.0)) => Neg(l),
  _ when left == right => const Constant(1.0),
  _ => Div(left, right),
};

Expr _simplifyPow(Expr base, Expr exponent) => switch ((base, exponent)) {
  (Constant(value: final b), Constant(value: final e)) => Constant(
    math.pow(b, e).toDouble(),
  ),
  (_, Constant(value: 0.0)) => const Constant(1.0),
  (final b, Constant(value: 1.0)) => b,
  (Constant(value: 0.0), _) => const Constant(0.0),
  (Constant(value: 1.0), _) => const Constant(1.0),
  _ => Pow(base, exponent),
};

Expr _simplifyNeg(Expr expr) => switch (expr) {
  Constant(:final value) => Constant(-value),
  Neg(:final expr) => expr,
  _ => Neg(expr),
};

Expr _simplifySin(Expr expr) => switch (expr) {
  Constant(:final value) => Constant(math.sin(value)),
  _ => Sin(expr),
};

Expr _simplifyCos(Expr expr) => switch (expr) {
  Constant(:final value) => Constant(math.cos(value)),
  _ => Cos(expr),
};

Expr _simplifyExp(Expr expr) => switch (expr) {
  Constant(:final value) => Constant(math.exp(value)),
  _ => Exp(expr),
};

Expr _simplifyLn(Expr expr) => switch (expr) {
  Constant(:final value) when value <= 0.0 => throw ArgumentError(
    'Natural logarithm domain error: $value <= 0',
  ),
  Constant(:final value) => Constant(math.log(value)),
  _ => Ln(expr),
};
