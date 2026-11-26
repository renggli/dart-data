part of '../ast.dart';

/// Sine function node: `sin(x)`.
final class Sin extends UnaryExpr {
  /// Creates a sine node `sin(expr)`.
  new(super.expr, {super.isSimplified = false});

  @override
  Expr _withExpr(Expr expr) => Sin(expr);
}

/// Cosine function node: `cos(x)`.
final class Cos extends UnaryExpr {
  /// Creates a cosine node `cos(expr)`.
  new(super.expr, {super.isSimplified = false});

  @override
  Expr _withExpr(Expr expr) => Cos(expr);
}

/// Tangent function node: `tan(x)`.
final class Tan extends UnaryExpr {
  /// Creates a tangent node `tan(expr)`.
  new(super.expr, {super.isSimplified = false});

  @override
  Expr _withExpr(Expr expr) => Tan(expr);
}

/// Inverse sine (arcsine) function node: `asin(x)`.
final class Asin extends UnaryExpr {
  /// Creates an arcsine node `asin(expr)`.
  new(super.expr, {super.isSimplified = false});

  @override
  Expr _withExpr(Expr expr) => Asin(expr);
}

/// Inverse cosine (arccosine) function node: `acos(x)`.
final class Acos extends UnaryExpr {
  /// Creates an arccosine node `acos(expr)`.
  new(super.expr, {super.isSimplified = false});

  @override
  Expr _withExpr(Expr expr) => Acos(expr);
}

/// Inverse tangent (arctangent) function node: `atan(x)`.
final class Atan extends UnaryExpr {
  /// Creates an arctangent node `atan(expr)`.
  new(super.expr, {super.isSimplified = false});

  @override
  Expr _withExpr(Expr expr) => Atan(expr);
}

/// Two-argument arctangent function node: `atan2(y, x)`.
final class Atan2 extends BinaryExpr {
  /// Creates a two-argument arctangent node `atan2(left, right)`.
  new(super.left, super.right, {super.isSimplified = false});

  /// The `y`-coordinate operand.
  Expr get y => left;

  /// The `x`-coordinate operand.
  Expr get x => right;

  @override
  Expr _withOperands(Expr left, Expr right) => Atan2(left, right);
}

/// Hyperbolic sine function node: `sinh(x)`.
final class Sinh extends UnaryExpr {
  /// Creates a hyperbolic sine node `sinh(expr)`.
  new(super.expr, {super.isSimplified = false});

  @override
  Expr _withExpr(Expr expr) => Sinh(expr);
}

/// Hyperbolic cosine function node: `cosh(x)`.
final class Cosh extends UnaryExpr {
  /// Creates a hyperbolic cosine node `cosh(expr)`.
  new(super.expr, {super.isSimplified = false});

  @override
  Expr _withExpr(Expr expr) => Cosh(expr);
}

/// Hyperbolic tangent function node: `tanh(x)`.
final class Tanh extends UnaryExpr {
  /// Creates a hyperbolic tangent node `tanh(expr)`.
  new(super.expr, {super.isSimplified = false});

  @override
  Expr _withExpr(Expr expr) => Tanh(expr);
}

/// Inverse hyperbolic sine function node: `asinh(x) = ln(x + sqrt(x^2 + 1))`.
final class Asinh extends UnaryExpr {
  /// Creates an inverse hyperbolic sine node `asinh(expr)`.
  new(super.expr, {super.isSimplified = false});

  @override
  Expr _withExpr(Expr expr) => Asinh(expr);
}

/// Inverse hyperbolic cosine function node: `acosh(x) = ln(x + sqrt(x^2 - 1))`.
final class Acosh extends UnaryExpr {
  /// Creates an inverse hyperbolic cosine node `acosh(expr)`.
  new(super.expr, {super.isSimplified = false});

  @override
  Expr _withExpr(Expr expr) => Acosh(expr);
}

/// Inverse hyperbolic tangent function node: `atanh(x) = (1)/(2)ln((1+x)/(1-x))`.
final class Atanh extends UnaryExpr {
  /// Creates an inverse hyperbolic tangent node `atanh(expr)`.
  new(super.expr, {super.isSimplified = false});

  @override
  Expr _withExpr(Expr expr) => Atanh(expr);
}

/// Absolute value function node: `|x|`.
final class Abs extends UnaryExpr {
  /// Creates an absolute value node `|expr|`.
  new(super.expr, {super.isSimplified = false});

  @override
  bool get isReal => true;

  @override
  Expr _withExpr(Expr expr) => Abs(expr);
}

/// Natural logarithm function node: `ln(x)`.
final class Ln extends UnaryExpr {
  /// Creates a natural logarithm node `ln(expr)`.
  new(super.expr, {super.isSimplified = false});

  @override
  Expr _withExpr(Expr expr) => Ln(expr);
}

/// Real part function node: `Re(z)`.
final class Re extends UnaryExpr {
  /// Creates a real-part node `Re(expr)`.
  new(super.expr, {super.isSimplified = false});

  @override
  bool get isReal => true;

  @override
  Expr _withExpr(Expr expr) => Re(expr);
}

/// Imaginary part function node: `Im(z)`.
final class Im extends UnaryExpr {
  /// Creates an imaginary-part node `Im(expr)`.
  new(super.expr, {super.isSimplified = false});

  @override
  bool get isReal => true;

  @override
  Expr _withExpr(Expr expr) => Im(expr);
}

/// Complex argument (phase angle) function node: `arg(z) in (-pi, pi]`.
final class Arg extends UnaryExpr {
  /// Creates a complex argument node `arg(expr)`.
  new(super.expr, {super.isSimplified = false});

  @override
  bool get isReal => true;

  @override
  Expr _withExpr(Expr expr) => Arg(expr);
}

/// Complex conjugate function node: `conj(z)`.
final class Conjugate extends UnaryExpr {
  /// Creates a complex conjugate node `conj(expr)`.
  new(super.expr, {super.isSimplified = false});

  @override
  Expr _withExpr(Expr expr) => Conjugate(expr);
}
