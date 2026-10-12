import 'dart:math' as math;

import 'package:more/number.dart' show Fraction;

import 'parser.dart';
import 'textualization/string.dart';

/// Mathematical constant $\pi \approx 3.141592653589793$ as a symbolic [Expr].
const pi = ConstantNumber.pi;

/// Mathematical constant $e \approx 2.718281828459045$ as a symbolic [Expr].
const e = ConstantNumber.e;

/// Sealed base class representing an algebraic expression abstract syntax tree
/// (AST) node.
///
/// In algebra and calculus, an expression combines constants, variables,
/// operators, and mathematical functions (such as $2x + 1$ or $\sin(x)$).
/// Expressions can be constructed and evaluated numerically for specific
/// variable assignments, or manipulated symbolically for exact differentiation,
/// indefinite integration, equation solving, simplification, and JIT
/// compilation.
///
/// ```dart
/// final x = Variable('x');
/// final expr = x * x + 2 * x + 1;
/// final val = expr.evaluate({'x': 3.0}); // 3^2 + 2(3) + 1 = 16.0
/// ```
sealed class Expr {
  /// Abstract const constructor for expression nodes.
  const new();

  /// Parses a mathematical expression from [input] into an [Expr] tree.
  ///
  /// Supports numbers (integers, floating-point, scientific notation), mathematical
  /// constants ([pi], [e]), variables, basic arithmetic (`+`, `-`, `*`, `/`, `^`),
  /// unary operators (`+`, `-`), functions ([Sin], [Cos], [Exp], [Ln], `log`, `sqrt`),
  /// and parentheses.
  ///
  /// Throws a [FormatException] if [input] cannot be parsed.
  ///
  /// ```dart
  /// final f = Expr.parse('sin(pi * x) + 2 * x');
  /// print(f.evaluate({'x': 0.5}));
  /// ```
  static Expr parse(String input, {int maxDenominator = 64}) =>
      parseExpression(input, maxDenominator: maxDenominator);

  /// Tries to parse a mathematical expression from [input], returning `null` on
  /// syntax error.
  ///
  /// ```dart
  /// final expr = Expr.tryParse('2 * x + 1');
  /// ```
  static Expr? tryParse(String input, {int maxDenominator = 64}) =>
      tryParseExpression(input, maxDenominator: maxDenominator);

  /// Whether this expression depends on [name].
  bool dependsOn(String name);

  /// Populates [target] with all unique variable names appearing in this expression.
  void collectFreeVariables(Set<String> target);

  /// All unique variable names appearing in this expression.
  Set<String> get freeVariables {
    final result = <String>{};
    collectFreeVariables(result);
    return result;
  }

  /// Substitutes occurrences of [variable] with [replacement].
  Expr substitute(String variable, Expr replacement);

  /// Evaluates this expression using the variable values in [context].
  double evaluate(Map<String, double> context);

  /// Adds this expression to [other].
  Expr operator +(Object other) => Add(this, _wrap(other));

  /// Subtracts [other] from this expression.
  Expr operator -(Object other) => Sub(this, _wrap(other));

  /// Multiplies this expression by [other].
  Expr operator *(Object other) => Mul(this, _wrap(other));

  /// Divides this expression by [other].
  Expr operator /(Object other) => Div(this, _wrap(other));

  /// Negates this expression.
  Expr operator -() => Neg(this);

  /// Raises this expression to the power of [exponent].
  Expr pow(Object exponent) => Pow(this, _wrap(exponent));

  @override
  String toString() => formatExpr(this);

  static Expr _wrap(Object value, {int maxDenominator = 64}) {
    if (value is Expr) return value;
    if (value is int) return RationalNumber(value);
    if (value is Fraction) return RationalNumber.fraction(value);
    if (value is num) {
      if (maxDenominator > 0) {
        final frac = Fraction.fromDouble(value, maxDenominator: maxDenominator);
        if (frac.denominator <= maxDenominator &&
            (value.toDouble() - frac.toDouble()).abs() < 1e-12) {
          return RationalNumber(frac.numerator, frac.denominator);
        }
      }
      return RealNumber(value.toDouble());
    }
    throw ArgumentError.value(
      value,
      'value',
      'Cannot convert to symbolic Expr',
    );
  }
}

/// A named symbolic variable in an algebraic expression.
///
/// Variables act as placeholders for unknown quantities or coordinates (e.g.
/// `'x'`, `'y'`). During evaluation, their values are supplied via a context map.
///
/// ```dart
/// final x = Variable('x');
/// final expr = x * x + 1;
/// print(expr.evaluate({'x': 3.0})); // 10.0
/// ```
final class Variable extends Expr {
  /// Creates a variable node with the given [name].
  const new(this.name);

  /// The symbol name of this variable (e.g. `'x'`).
  final String name;

  @override
  bool dependsOn(String name) => this.name == name;

  @override
  void collectFreeVariables(Set<String> target) => target.add(name);

  @override
  Set<String> get freeVariables => {name};

  @override
  Expr substitute(String variable, Expr replacement) =>
      name == variable ? replacement : this;

  @override
  double evaluate(Map<String, double> context) {
    final val = context[name];
    if (val == null) {
      throw ArgumentError('Variable "$name" not provided in context');
    }
    return val;
  }

  @override
  String toString() => name;

  @override
  bool operator ==(Object other) => other is Variable && other.name == name;

  @override
  int get hashCode => name.hashCode;
}

/// Sealed base class representing a numeric value node in an expression AST.
///
/// Subtypes include exact rational numbers ([RationalNumber]), floating-point
/// approximations ([RealNumber]), and recognized transcendental constants
/// ([ConstantNumber]).
sealed class Number extends Expr {
  /// Abstract const constructor for numeric nodes.
  const new();

  /// Floating-point double precision numeric value of this number.
  double get value;

  @override
  bool dependsOn(String name) => false;

  @override
  void collectFreeVariables(Set<String> target) {}

  @override
  Set<String> get freeVariables => const {};

  @override
  Expr substitute(String variable, Expr replacement) => this;

  @override
  double evaluate(Map<String, double> context) => value;
}

/// An exact rational number ($\mathbb{Q}$) represented by an integer [numerator] and [denominator].
///
/// Canonical rational numbers are in lowest reduced terms with
/// $\gcd(|numerator|, denominator) = 1$ and a strictly positive denominator.
///
/// ```dart
/// final half = RationalNumber(1, 2);
/// print(half.toDouble()); // 0.5
/// ```
final class RationalNumber extends Number {
  /// Creates an exact rational number node with [numerator] and optional [denominator].
  const new(this.numerator, [this.denominator = 1])
    : assert(denominator > 0, 'Denominator must be strictly positive');

  /// Creates a [RationalNumber] from a [Fraction].
  factory fraction(Fraction fraction) =>
      RationalNumber(fraction.numerator, fraction.denominator);

  /// Creates a [RationalNumber] from a numeric [value] using continued fraction expansion.
  factory fromDouble(num value, {int maxDenominator = 64}) =>
      RationalNumber.fraction(
        Fraction.fromDouble(value, maxDenominator: maxDenominator),
      );

  /// The additive neutral element `0`.
  static const zero = RationalNumber(0);

  /// The multiplicative neutral element `1`.
  static const one = RationalNumber(1);

  /// The negative unit element `-1`.
  static const negativeOne = RationalNumber(-1);

  /// The integer numerator of this rational number.
  final int numerator;

  /// The positive integer denominator of this rational number.
  final int denominator;

  @override
  double get value => numerator / denominator;

  /// Whether this rational number is an integer ($denominator = 1$).
  bool get isInteger => denominator == 1;

  /// Whether this rational number equals zero.
  bool get isZero => numerator == 0;

  /// Whether this rational number equals one.
  bool get isOne => numerator == 1 && denominator == 1;

  /// Whether this rational number equals negative one.
  bool get isNegativeOne => numerator == -1 && denominator == 1;

  /// Whether this rational number is strictly negative.
  bool get isNegative => numerator < 0;

  /// Converts this rational number to a [Fraction].
  Fraction toFraction() => Fraction(numerator, denominator);

  /// Converts this rational number to an [int] (truncated).
  int toInt() => numerator ~/ denominator;

  /// Converts this rational number to a [double].
  double toDouble() => numerator / denominator;

  @override
  String toString() => isInteger ? '$numerator' : '$numerator/$denominator';

  @override
  bool operator ==(Object other) =>
      other is RationalNumber &&
      other.numerator == numerator &&
      other.denominator == denominator;

  @override
  int get hashCode => Object.hash(numerator, denominator);
}

/// A real floating-point numeric value node ($\mathbb{R}$).
///
/// Used for numbers that cannot be represented as exact rational fractions
/// within the configured denominator bound.
///
/// ```dart
/// final r = RealNumber(1.2345);
/// print(r.value); // 1.2345
/// ```
final class RealNumber extends Number {
  /// Creates a real/floating-point number node with the given [value].
  const new(this.value);

  @override
  final double value;

  @override
  String toString() => value.toString();

  @override
  bool operator ==(Object other) => other is RealNumber && other.value == value;

  @override
  int get hashCode => value.hashCode;
}

/// A recognized transcendental mathematical constant (such as [pi] or [e]).
///
/// Preserves symbolic identity during algebraic manipulations and LaTeX
/// typesetting without premature floating-point loss of precision.
///
/// ```dart
/// final c = ConstantNumber.pi;
/// print(c.name); // 'pi'
/// print(c.value); // 3.141592653589793
/// ```
final class ConstantNumber extends Number {
  /// Creates a named transcendental constant with [name] and numeric [value].
  const new(this.name, this.value);

  /// Mathematical constant $\pi \approx 3.141592653589793$.
  static const pi = ConstantNumber('pi', math.pi);

  /// Mathematical constant $e \approx 2.718281828459045$.
  static const e = ConstantNumber('e', math.e);

  /// The symbolic name of this constant (e.g. `'pi'`, `'e'`).
  final String name;

  @override
  final double value;

  @override
  String toString() => name;

  @override
  bool operator ==(Object other) =>
      other is ConstantNumber && other.name == name;

  @override
  int get hashCode => name.hashCode;
}

/// Sealed base class representing a unary operation AST node with a single operand.
///
/// Encapsulates common structural traversal, variable dependency collection,
/// and value hashing across unary expressions such as negation ([Neg]) and
/// transcendental functions ([Sin], [Cos], [Exp], [Ln]).
sealed class UnaryExpr extends Expr {
  /// Abstract const constructor for unary expression nodes.
  const new(this.expr);

  /// The sub-expression argument of this unary operation.
  final Expr expr;

  @override
  bool dependsOn(String name) => expr.dependsOn(name);

  @override
  void collectFreeVariables(Set<String> target) =>
      expr.collectFreeVariables(target);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UnaryExpr &&
          other.runtimeType == runtimeType &&
          other.expr == expr);

  @override
  int get hashCode => Object.hash(runtimeType, expr);
}

/// Sealed base class representing a binary operation AST node with two operands.
///
/// Encapsulates common structural traversal, variable dependency collection,
/// and value hashing across binary expressions such as arithmetic operations
/// ([Add], [Sub], [Mul], [Div]) and exponentiation ([Pow]).
sealed class BinaryExpr extends Expr {
  /// Abstract const constructor for binary expression nodes.
  const new(this.left, this.right);

  /// The left operand.
  final Expr left;

  /// The right operand.
  final Expr right;

  @override
  bool dependsOn(String name) => left.dependsOn(name) || right.dependsOn(name);

  @override
  void collectFreeVariables(Set<String> target) {
    left.collectFreeVariables(target);
    right.collectFreeVariables(target);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BinaryExpr &&
          other.runtimeType == runtimeType &&
          other.left == left &&
          other.right == right);

  @override
  int get hashCode => Object.hash(runtimeType, left, right);
}

/// An addition binary expression node representing $left + right$.
///
/// ```dart
/// final sum = Add(Variable('x'), RationalNumber(1));
/// ```
final class Add extends BinaryExpr {
  /// Creates an addition node representing `[left] + [right]`.
  const new(super.left, super.right);

  @override
  Expr substitute(String variable, Expr replacement) => Add(
    left.substitute(variable, replacement),
    right.substitute(variable, replacement),
  );

  @override
  double evaluate(Map<String, double> context) =>
      left.evaluate(context) + right.evaluate(context);
}

/// A subtraction binary expression node representing $left - right$.
///
/// ```dart
/// final diff = Sub(Variable('x'), RationalNumber(1));
/// ```
final class Sub extends BinaryExpr {
  /// Creates a subtraction node representing `[left] - [right]`.
  const new(super.left, super.right);

  @override
  Expr substitute(String variable, Expr replacement) => Sub(
    left.substitute(variable, replacement),
    right.substitute(variable, replacement),
  );

  @override
  double evaluate(Map<String, double> context) =>
      left.evaluate(context) - right.evaluate(context);
}

/// A multiplication binary expression node representing $left \times right$.
///
/// ```dart
/// final product = Mul(RationalNumber(2), Variable('x'));
/// ```
final class Mul extends BinaryExpr {
  /// Creates a multiplication node representing `[left] * [right]`.
  const new(super.left, super.right);

  @override
  Expr substitute(String variable, Expr replacement) => Mul(
    left.substitute(variable, replacement),
    right.substitute(variable, replacement),
  );

  @override
  double evaluate(Map<String, double> context) =>
      left.evaluate(context) * right.evaluate(context);
}

/// A division binary expression node representing $left / right$.
///
/// ```dart
/// final quotient = Div(Variable('x'), RationalNumber(2));
/// ```
final class Div extends BinaryExpr {
  /// Creates a division node representing `[left] / [right]`.
  const new(super.left, super.right);

  @override
  Expr substitute(String variable, Expr replacement) => Div(
    left.substitute(variable, replacement),
    right.substitute(variable, replacement),
  );

  @override
  double evaluate(Map<String, double> context) =>
      left.evaluate(context) / right.evaluate(context);
}

/// An exponentiation binary expression node representing $base^{exponent}$.
///
/// ```dart
/// final power = Pow(Variable('x'), RationalNumber(2));
/// ```
final class Pow extends BinaryExpr {
  /// Creates an exponentiation node representing `[base] ^ [exponent]`.
  const new(super.left, super.right);

  /// The base expression.
  Expr get base => left;

  /// The exponent expression.
  Expr get exponent => right;

  @override
  Expr substitute(String variable, Expr replacement) => Pow(
    left.substitute(variable, replacement),
    right.substitute(variable, replacement),
  );

  @override
  double evaluate(Map<String, double> context) =>
      math.pow(left.evaluate(context), right.evaluate(context)).toDouble();
}

/// A unary negation expression node representing $-expr$.
///
/// ```dart
/// final neg = Neg(Variable('x'));
/// ```
final class Neg extends UnaryExpr {
  /// Creates a unary negation node representing `-[expr]`.
  const new(super.expr);

  @override
  Expr substitute(String variable, Expr replacement) =>
      Neg(expr.substitute(variable, replacement));

  @override
  double evaluate(Map<String, double> context) => -expr.evaluate(context);
}

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

/// A square root function expression node representing $\sqrt{expr}$.
///
/// ```dart
/// final s = Sqrt(Variable('x'));
/// ```
final class Sqrt extends UnaryExpr {
  /// Creates a square root function node representing `sqrt([expr])`.
  const new(super.expr);

  @override
  Expr substitute(String variable, Expr replacement) =>
      Sqrt(expr.substitute(variable, replacement));

  @override
  double evaluate(Map<String, double> context) =>
      math.sqrt(expr.evaluate(context));
}

/// A logarithm function expression node representing $\log_{base}(expr)$ with arbitrary base.
///
/// ```dart
/// final l = Log(RationalNumber(10), Variable('x'));
/// ```
final class Log extends BinaryExpr {
  /// Creates a logarithm function node with [base] and argument [expr].
  const new(super.left, super.right);

  /// The logarithmic base expression.
  Expr get base => left;

  /// The argument expression.
  Expr get expr => right;

  @override
  Expr substitute(String variable, Expr replacement) => Log(
    left.substitute(variable, replacement),
    right.substitute(variable, replacement),
  );

  @override
  double evaluate(Map<String, double> context) =>
      math.log(right.evaluate(context)) / math.log(left.evaluate(context));
}
