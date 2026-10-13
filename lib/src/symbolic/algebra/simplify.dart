import '../ast.dart';
import 'simplify/additive.dart';
import 'simplify/multiplicative.dart';
import 'simplify/power.dart';
import 'simplify/transcendental.dart';

export 'simplify/additive.dart';
export 'simplify/multiplicative.dart';
export 'simplify/power.dart';
export 'simplify/transcendental.dart';

/// Canonical algebraic simplification extension on [Expr].
extension SimplifierExtension on Expr {
  /// Canonically simplifies this expression by performing constant folding,
  /// like-term and like-factor reductions, and algebraic canonicalization.
  ///
  /// Conceptually, this simplifies expressions using algebraic identities such
  /// as $x + x \to 2x$, $x \cdot x \to x^2$, $x + 0 \to x$, $x \cdot 1 \to x$,
  /// evaluates constant sub-expressions such as $2 + 3 \to 5$, and canonicalizes
  /// polynomial terms in descending order of power and degree. Formally, this
  /// executes confluent rewriting rules to reduce algebraic expressions into
  /// canonical normal form.
  ///
  /// ```dart
  /// final x = Variable('x');
  /// final expr = (x + 1) + (x + 2);
  /// final s = expr.simplify(); // 2 * x + 3
  /// ```
  Expr simplify() => simplifyExpr(this);
}

/// Recursively evaluates and canonically simplifies [expr].
Expr simplifyExpr(Expr expr) => switch (expr) {
  Number() || Variable() => expr,
  Add(:final left, :final right) => simplifyAdd(
    simplifyExpr(left),
    simplifyExpr(right),
  ),
  Sub(:final left, :final right) => simplifySub(
    simplifyExpr(left),
    simplifyExpr(right),
  ),
  Mul(:final left, :final right) => simplifyMul(
    simplifyExpr(left),
    simplifyExpr(right),
  ),
  Div(:final left, :final right) => simplifyDiv(
    simplifyExpr(left),
    simplifyExpr(right),
  ),
  Pow(:final base, :final exponent) => simplifyPow(
    simplifyExpr(base),
    simplifyExpr(exponent),
  ),
  Neg(:final expr) => simplifyNeg(simplifyExpr(expr)),
  Sin(:final expr) => simplifySin(simplifyExpr(expr)),
  Cos(:final expr) => simplifyCos(simplifyExpr(expr)),
  Tan(:final expr) => simplifyTan(simplifyExpr(expr)),
  Asin(:final expr) => simplifyAsin(simplifyExpr(expr)),
  Acos(:final expr) => simplifyAcos(simplifyExpr(expr)),
  Atan(:final expr) => simplifyAtan(simplifyExpr(expr)),
  Sinh(:final expr) => simplifySinh(simplifyExpr(expr)),
  Cosh(:final expr) => simplifyCosh(simplifyExpr(expr)),
  Tanh(:final expr) => simplifyTanh(simplifyExpr(expr)),
  Abs(:final expr) => simplifyAbs(simplifyExpr(expr)),
  Exp(:final expr) => simplifyExp(simplifyExpr(expr)),
  Ln(:final expr) => simplifyLn(simplifyExpr(expr)),
};
