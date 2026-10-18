part of '../ast.dart';

/// Sine function node: $\sin(x)$.
final class Sin extends UnaryExpr {
  /// Creates a sine node $\sin(\text{expr})$.
  new(super.expr, {super.isSimplified = false});

  @override
  Expr substitute(String variable, Expr replacement) =>
      Sin(expr.substitute(variable, replacement));

  @override
  Expr mapChildren(Expr Function(Expr) transform) => Sin(transform(expr));
}

/// Cosine function node: $\cos(x)$.
final class Cos extends UnaryExpr {
  /// Creates a cosine node $\cos(\text{expr})$.
  new(super.expr, {super.isSimplified = false});

  @override
  Expr substitute(String variable, Expr replacement) =>
      Cos(expr.substitute(variable, replacement));

  @override
  Expr mapChildren(Expr Function(Expr) transform) => Cos(transform(expr));
}

/// Tangent function node: $\tan(x)$.
final class Tan extends UnaryExpr {
  /// Creates a tangent node $\tan(\text{expr})$.
  new(super.expr, {super.isSimplified = false});

  @override
  Expr substitute(String variable, Expr replacement) =>
      Tan(expr.substitute(variable, replacement));

  @override
  Expr mapChildren(Expr Function(Expr) transform) => Tan(transform(expr));
}

/// Inverse sine (arcsine) function node: $\arcsin(x)$.
final class Asin extends UnaryExpr {
  /// Creates an arcsine node $\arcsin(\text{expr})$.
  new(super.expr, {super.isSimplified = false});

  @override
  Expr substitute(String variable, Expr replacement) =>
      Asin(expr.substitute(variable, replacement));

  @override
  Expr mapChildren(Expr Function(Expr) transform) => Asin(transform(expr));
}

/// Inverse cosine (arccosine) function node: $\arccos(x)$.
final class Acos extends UnaryExpr {
  /// Creates an arccosine node $\arccos(\text{expr})$.
  new(super.expr, {super.isSimplified = false});

  @override
  Expr substitute(String variable, Expr replacement) =>
      Acos(expr.substitute(variable, replacement));

  @override
  Expr mapChildren(Expr Function(Expr) transform) => Acos(transform(expr));
}

/// Inverse tangent (arctangent) function node: $\arctan(x)$.
final class Atan extends UnaryExpr {
  /// Creates an arctangent node $\arctan(\text{expr})$.
  new(super.expr, {super.isSimplified = false});

  @override
  Expr substitute(String variable, Expr replacement) =>
      Atan(expr.substitute(variable, replacement));

  @override
  Expr mapChildren(Expr Function(Expr) transform) => Atan(transform(expr));
}

/// Hyperbolic sine function node: $\sinh(x)$.
final class Sinh extends UnaryExpr {
  /// Creates a hyperbolic sine node $\sinh(\text{expr})$.
  new(super.expr, {super.isSimplified = false});

  @override
  Expr substitute(String variable, Expr replacement) =>
      Sinh(expr.substitute(variable, replacement));

  @override
  Expr mapChildren(Expr Function(Expr) transform) => Sinh(transform(expr));
}

/// Hyperbolic cosine function node: $\cosh(x)$.
final class Cosh extends UnaryExpr {
  /// Creates a hyperbolic cosine node $\cosh(\text{expr})$.
  new(super.expr, {super.isSimplified = false});

  @override
  Expr substitute(String variable, Expr replacement) =>
      Cosh(expr.substitute(variable, replacement));

  @override
  Expr mapChildren(Expr Function(Expr) transform) => Cosh(transform(expr));
}

/// Hyperbolic tangent function node: $\tanh(x)$.
final class Tanh extends UnaryExpr {
  /// Creates a hyperbolic tangent node $\tanh(\text{expr})$.
  new(super.expr, {super.isSimplified = false});

  @override
  Expr substitute(String variable, Expr replacement) =>
      Tanh(expr.substitute(variable, replacement));

  @override
  Expr mapChildren(Expr Function(Expr) transform) => Tanh(transform(expr));
}

/// Inverse hyperbolic sine function node: $\operatorname{asinh}(x) = \ln(x + \sqrt{x^2 + 1})$.
final class Asinh extends UnaryExpr {
  /// Creates an inverse hyperbolic sine node $\operatorname{asinh}(\text{expr})$.
  new(super.expr, {super.isSimplified = false});

  @override
  Expr substitute(String variable, Expr replacement) =>
      Asinh(expr.substitute(variable, replacement));

  @override
  Expr mapChildren(Expr Function(Expr) transform) => Asinh(transform(expr));
}

/// Inverse hyperbolic cosine function node: $\operatorname{acosh}(x) = \ln(x + \sqrt{x^2 - 1})$.
final class Acosh extends UnaryExpr {
  /// Creates an inverse hyperbolic cosine node $\operatorname{acosh}(\text{expr})$.
  new(super.expr, {super.isSimplified = false});

  @override
  Expr substitute(String variable, Expr replacement) =>
      Acosh(expr.substitute(variable, replacement));

  @override
  Expr mapChildren(Expr Function(Expr) transform) => Acosh(transform(expr));
}

/// Inverse hyperbolic tangent function node: $\operatorname{atanh}(x) = \frac{1}{2}\ln\left(\frac{1+x}{1-x}\right)$.
final class Atanh extends UnaryExpr {
  /// Creates an inverse hyperbolic tangent node $\operatorname{atanh}(\text{expr})$.
  new(super.expr, {super.isSimplified = false});

  @override
  Expr substitute(String variable, Expr replacement) =>
      Atanh(expr.substitute(variable, replacement));

  @override
  Expr mapChildren(Expr Function(Expr) transform) => Atanh(transform(expr));
}

/// Absolute value function node: $|x|$.
final class Abs extends UnaryExpr {
  /// Creates an absolute value node $|\text{expr}|$.
  new(super.expr, {super.isSimplified = false});

  @override
  bool get isReal => true;

  @override
  Expr substitute(String variable, Expr replacement) =>
      Abs(expr.substitute(variable, replacement));

  @override
  Expr mapChildren(Expr Function(Expr) transform) => Abs(transform(expr));
}

/// Natural logarithm function node: $\ln(x)$.
final class Ln extends UnaryExpr {
  /// Creates a natural logarithm node $\ln(\text{expr})$.
  new(super.expr, {super.isSimplified = false});

  @override
  Expr substitute(String variable, Expr replacement) =>
      Ln(expr.substitute(variable, replacement));

  @override
  Expr mapChildren(Expr Function(Expr) transform) => Ln(transform(expr));
}

/// Real part function node: $\Re(z)$.
final class Re extends UnaryExpr {
  /// Creates a real-part node $\Re(\text{expr})$.
  new(super.expr, {super.isSimplified = false});

  @override
  bool get isReal => true;

  @override
  Expr substitute(String variable, Expr replacement) =>
      Re(expr.substitute(variable, replacement));

  @override
  Expr mapChildren(Expr Function(Expr) transform) => Re(transform(expr));
}

/// Imaginary part function node: $\Im(z)$.
final class Im extends UnaryExpr {
  /// Creates an imaginary-part node $\Im(\text{expr})$.
  new(super.expr, {super.isSimplified = false});

  @override
  bool get isReal => true;

  @override
  Expr substitute(String variable, Expr replacement) =>
      Im(expr.substitute(variable, replacement));

  @override
  Expr mapChildren(Expr Function(Expr) transform) => Im(transform(expr));
}

/// Complex argument (phase angle) function node: $\arg(z) \in (-\pi, \pi]$.
final class Arg extends UnaryExpr {
  /// Creates a complex argument node $\arg(\text{expr})$.
  new(super.expr, {super.isSimplified = false});

  @override
  bool get isReal => true;

  @override
  Expr substitute(String variable, Expr replacement) =>
      Arg(expr.substitute(variable, replacement));

  @override
  Expr mapChildren(Expr Function(Expr) transform) => Arg(transform(expr));
}

/// Complex conjugate function node: $\overline{z}$.
final class Conjugate extends UnaryExpr {
  /// Creates a complex conjugate node $\overline{\text{expr}}$.
  new(super.expr, {super.isSimplified = false});

  @override
  Expr substitute(String variable, Expr replacement) =>
      Conjugate(expr.substitute(variable, replacement));

  @override
  Expr mapChildren(Expr Function(Expr) transform) => Conjugate(transform(expr));
}
