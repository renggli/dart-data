part of '../ast.dart';

/// A trigonometric sine function expression node representing $\sin(expr)$.
///
/// ```dart
/// final s = Sin(Variable('x'));
/// ```
final class Sin extends UnaryExpr {
  /// Creates a sine function node representing `sin([expr])`.
  const new(super.expr);

  @override
  Expr substitute(String variable, Expr replacement) =>
      Sin(expr.substitute(variable, replacement));

  @override
  double evaluate(Map<String, double> context) =>
      math.sin(expr.evaluate(context));
}

/// A trigonometric cosine function expression node representing $\cos(expr)$.
///
/// ```dart
/// final c = Cos(Variable('x'));
/// ```
final class Cos extends UnaryExpr {
  /// Creates a cosine function node representing `cos([expr])`.
  const new(super.expr);

  @override
  Expr substitute(String variable, Expr replacement) =>
      Cos(expr.substitute(variable, replacement));

  @override
  double evaluate(Map<String, double> context) =>
      math.cos(expr.evaluate(context));
}

/// An exponential function expression node representing $e^{expr}$.
///
/// ```dart
/// final exp = Exp(Variable('x'));
/// ```
final class Exp extends UnaryExpr {
  /// Creates an exponential function node representing `exp([expr])`.
  const new(super.expr);

  @override
  Expr substitute(String variable, Expr replacement) =>
      Exp(expr.substitute(variable, replacement));

  @override
  double evaluate(Map<String, double> context) =>
      math.exp(expr.evaluate(context));
}

/// A natural logarithm function expression node representing $\ln(expr)$.
///
/// ```dart
/// final l = Ln(Variable('x'));
/// ```
final class Ln extends UnaryExpr {
  /// Creates a natural logarithm function node representing `ln([expr])`.
  const new(super.expr);

  @override
  Expr substitute(String variable, Expr replacement) =>
      Ln(expr.substitute(variable, replacement));

  @override
  double evaluate(Map<String, double> context) =>
      math.log(expr.evaluate(context));
}

/// A trigonometric tangent function expression node representing $\tan(expr)$.
///
/// ```dart
/// final t = Tan(Variable('x'));
/// ```
final class Tan extends UnaryExpr {
  /// Creates a tangent function node representing `tan([expr])`.
  const new(super.expr);

  @override
  Expr substitute(String variable, Expr replacement) =>
      Tan(expr.substitute(variable, replacement));

  @override
  double evaluate(Map<String, double> context) =>
      math.tan(expr.evaluate(context));
}

/// An inverse sine (arcsine) function expression node representing $\arcsin(expr)$.
///
/// ```dart
/// final a = Asin(Variable('x'));
/// ```
final class Asin extends UnaryExpr {
  /// Creates an inverse sine function node representing `asin([expr])`.
  const new(super.expr);

  @override
  Expr substitute(String variable, Expr replacement) =>
      Asin(expr.substitute(variable, replacement));

  @override
  double evaluate(Map<String, double> context) =>
      math.asin(expr.evaluate(context));
}

/// An inverse cosine (arccosine) function expression node representing $\arccos(expr)$.
///
/// ```dart
/// final a = Acos(Variable('x'));
/// ```
final class Acos extends UnaryExpr {
  /// Creates an inverse cosine function node representing `acos([expr])`.
  const new(super.expr);

  @override
  Expr substitute(String variable, Expr replacement) =>
      Acos(expr.substitute(variable, replacement));

  @override
  double evaluate(Map<String, double> context) =>
      math.acos(expr.evaluate(context));
}

/// An inverse tangent (arctangent) function expression node representing $\arctan(expr)$.
///
/// ```dart
/// final a = Atan(Variable('x'));
/// ```
final class Atan extends UnaryExpr {
  /// Creates an inverse tangent function node representing `atan([expr])`.
  const new(super.expr);

  @override
  Expr substitute(String variable, Expr replacement) =>
      Atan(expr.substitute(variable, replacement));

  @override
  double evaluate(Map<String, double> context) =>
      math.atan(expr.evaluate(context));
}

/// A hyperbolic sine function expression node representing $\sinh(expr)$.
///
/// ```dart
/// final s = Sinh(Variable('x'));
/// ```
final class Sinh extends UnaryExpr {
  /// Creates a hyperbolic sine function node representing `sinh([expr])`.
  const new(super.expr);

  @override
  Expr substitute(String variable, Expr replacement) =>
      Sinh(expr.substitute(variable, replacement));

  @override
  double evaluate(Map<String, double> context) {
    final v = expr.evaluate(context);
    return (math.exp(v) - math.exp(-v)) / 2.0;
  }
}

/// A hyperbolic cosine function expression node representing $\cosh(expr)$.
///
/// ```dart
/// final c = Cosh(Variable('x'));
/// ```
final class Cosh extends UnaryExpr {
  /// Creates a hyperbolic cosine function node representing `cosh([expr])`.
  const new(super.expr);

  @override
  Expr substitute(String variable, Expr replacement) =>
      Cosh(expr.substitute(variable, replacement));

  @override
  double evaluate(Map<String, double> context) {
    final v = expr.evaluate(context);
    return (math.exp(v) + math.exp(-v)) / 2.0;
  }
}

/// A hyperbolic tangent function expression node representing $\tanh(expr)$.
///
/// ```dart
/// final t = Tanh(Variable('x'));
/// ```
final class Tanh extends UnaryExpr {
  /// Creates a hyperbolic tangent function node representing `tanh([expr])`.
  const new(super.expr);

  @override
  Expr substitute(String variable, Expr replacement) =>
      Tanh(expr.substitute(variable, replacement));

  @override
  double evaluate(Map<String, double> context) {
    final v = expr.evaluate(context);
    if (v > 20.0) return 1.0;
    if (v < -20.0) return -1.0;
    final e2 = math.exp(2.0 * v);
    return (e2 - 1.0) / (e2 + 1.0);
  }
}

/// An absolute value function expression node representing $|expr|$.
///
/// ```dart
/// final a = Abs(Variable('x'));
/// ```
final class Abs extends UnaryExpr {
  /// Creates an absolute value function node representing `|expr|`.
  const new(super.expr);

  @override
  Expr substitute(String variable, Expr replacement) =>
      Abs(expr.substitute(variable, replacement));

  @override
  double evaluate(Map<String, double> context) => expr.evaluate(context).abs();
}
