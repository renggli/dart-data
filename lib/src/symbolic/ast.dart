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

  /// All unique variable names appearing in this expression.
  Set<String> get freeVariables;

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

/// [Variable] node representing a named symbol.
final class Variable extends Expr {
  /// Creates a variable node with the given [name].
  const new(this.name);

  /// The symbol name of this variable (e.g. `'x'`).
  final String name;

  @override
  bool dependsOn(String name) => this.name == name;

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

/// Sealed base class representing a numeric value node.
sealed class Number extends Expr {
  /// Abstract const constructor for numeric nodes.
  const new();

  /// Floating-point double precision numeric value of this number.
  double get value;

  @override
  bool dependsOn(String name) => false;

  @override
  Set<String> get freeVariables => const {};

  @override
  Expr substitute(String variable, Expr replacement) => this;

  @override
  double evaluate(Map<String, double> context) => value;
}

/// [RationalNumber] numeric value node representing an exact rational number ($\mathbb{Q}$).
///
/// An exact rational number is represented by an integer [numerator] and a
/// positive integer [denominator]. Canonical rational numbers are in lowest reduced terms
/// with $\gcd(|numerator|, denominator) = 1$.
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

/// [RealNumber] numeric value node representing an unreduced or floating-point number ($\mathbb{R}$).
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

/// [ConstantNumber] representing a recognized transcendental mathematical constant.
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

/// [Add] expression node: left + right.
final class Add extends Expr {
  /// Creates an addition node representing `[left] + [right]`.
  const new(this.left, this.right);

  /// The left operand.
  final Expr left;

  /// The right operand.
  final Expr right;

  @override
  bool dependsOn(String name) => left.dependsOn(name) || right.dependsOn(name);

  @override
  Set<String> get freeVariables => {
    ...left.freeVariables,
    ...right.freeVariables,
  };

  @override
  Expr substitute(String variable, Expr replacement) => Add(
    left.substitute(variable, replacement),
    right.substitute(variable, replacement),
  );

  @override
  double evaluate(Map<String, double> context) =>
      left.evaluate(context) + right.evaluate(context);

  @override
  bool operator ==(Object other) =>
      other is Add && other.left == left && other.right == right;

  @override
  int get hashCode => Object.hash(left, right);
}

/// [Sub] expression node: left - right.
final class Sub extends Expr {
  /// Creates a subtraction node representing `[left] - [right]`.
  const new(this.left, this.right);

  /// The left operand.
  final Expr left;

  /// The right operand.
  final Expr right;

  @override
  bool dependsOn(String name) => left.dependsOn(name) || right.dependsOn(name);

  @override
  Set<String> get freeVariables => {
    ...left.freeVariables,
    ...right.freeVariables,
  };

  @override
  Expr substitute(String variable, Expr replacement) => Sub(
    left.substitute(variable, replacement),
    right.substitute(variable, replacement),
  );

  @override
  double evaluate(Map<String, double> context) =>
      left.evaluate(context) - right.evaluate(context);

  @override
  bool operator ==(Object other) =>
      other is Sub && other.left == left && other.right == right;

  @override
  int get hashCode => Object.hash(left, right);
}

/// [Mul] expression node: left * right.
final class Mul extends Expr {
  /// Creates a multiplication node representing `[left] * [right]`.
  const new(this.left, this.right);

  /// The left operand.
  final Expr left;

  /// The right operand.
  final Expr right;

  @override
  bool dependsOn(String name) => left.dependsOn(name) || right.dependsOn(name);

  @override
  Set<String> get freeVariables => {
    ...left.freeVariables,
    ...right.freeVariables,
  };

  @override
  Expr substitute(String variable, Expr replacement) => Mul(
    left.substitute(variable, replacement),
    right.substitute(variable, replacement),
  );

  @override
  double evaluate(Map<String, double> context) =>
      left.evaluate(context) * right.evaluate(context);

  @override
  bool operator ==(Object other) =>
      other is Mul && other.left == left && other.right == right;

  @override
  int get hashCode => Object.hash(left, right);
}

/// [Div] expression node: left / right.
final class Div extends Expr {
  /// Creates a division node representing `[left] / [right]`.
  const new(this.left, this.right);

  /// The numerator operand.
  final Expr left;

  /// The denominator operand.
  final Expr right;

  @override
  bool dependsOn(String name) => left.dependsOn(name) || right.dependsOn(name);

  @override
  Set<String> get freeVariables => {
    ...left.freeVariables,
    ...right.freeVariables,
  };

  @override
  Expr substitute(String variable, Expr replacement) => Div(
    left.substitute(variable, replacement),
    right.substitute(variable, replacement),
  );

  @override
  double evaluate(Map<String, double> context) =>
      left.evaluate(context) / right.evaluate(context);

  @override
  bool operator ==(Object other) =>
      other is Div && other.left == left && other.right == right;

  @override
  int get hashCode => Object.hash(left, right);
}

/// [Pow] expression node: base ^ exponent.
final class Pow extends Expr {
  /// Creates an exponentiation node representing `[base] ^ [exponent]`.
  const new(this.base, this.exponent);

  /// The base expression.
  final Expr base;

  /// The exponent expression.
  final Expr exponent;

  @override
  bool dependsOn(String name) =>
      base.dependsOn(name) || exponent.dependsOn(name);

  @override
  Set<String> get freeVariables => {
    ...base.freeVariables,
    ...exponent.freeVariables,
  };

  @override
  Expr substitute(String variable, Expr replacement) => Pow(
    base.substitute(variable, replacement),
    exponent.substitute(variable, replacement),
  );

  @override
  double evaluate(Map<String, double> context) =>
      math.pow(base.evaluate(context), exponent.evaluate(context)).toDouble();

  @override
  bool operator ==(Object other) =>
      other is Pow && other.base == base && other.exponent == exponent;

  @override
  int get hashCode => Object.hash(base, exponent);
}

/// [Neg] unary negation node: -expr.
final class Neg extends Expr {
  /// Creates a unary negation node representing `-[expr]`.
  const new(this.expr);

  /// The negated sub-expression.
  final Expr expr;

  @override
  bool dependsOn(String name) => expr.dependsOn(name);

  @override
  Set<String> get freeVariables => expr.freeVariables;

  @override
  Expr substitute(String variable, Expr replacement) =>
      Neg(expr.substitute(variable, replacement));

  @override
  double evaluate(Map<String, double> context) => -expr.evaluate(context);

  @override
  bool operator ==(Object other) => other is Neg && other.expr == expr;

  @override
  int get hashCode => expr.hashCode;
}

/// [Sin] function node: sin(expr).
final class Sin extends Expr {
  /// Creates a sine function node representing `sin([expr])`.
  const new(this.expr);

  /// The argument sub-expression.
  final Expr expr;

  @override
  bool dependsOn(String name) => expr.dependsOn(name);

  @override
  Set<String> get freeVariables => expr.freeVariables;

  @override
  Expr substitute(String variable, Expr replacement) =>
      Sin(expr.substitute(variable, replacement));

  @override
  double evaluate(Map<String, double> context) =>
      math.sin(expr.evaluate(context));

  @override
  bool operator ==(Object other) => other is Sin && other.expr == expr;

  @override
  int get hashCode => expr.hashCode;
}

/// [Cos] function node: cos(expr).
final class Cos extends Expr {
  /// Creates a cosine function node representing `cos([expr])`.
  const new(this.expr);

  /// The argument sub-expression.
  final Expr expr;

  @override
  bool dependsOn(String name) => expr.dependsOn(name);

  @override
  Set<String> get freeVariables => expr.freeVariables;

  @override
  Expr substitute(String variable, Expr replacement) =>
      Cos(expr.substitute(variable, replacement));

  @override
  double evaluate(Map<String, double> context) =>
      math.cos(expr.evaluate(context));

  @override
  bool operator ==(Object other) => other is Cos && other.expr == expr;

  @override
  int get hashCode => expr.hashCode;
}

/// [Exp] function node: exp(expr).
final class Exp extends Expr {
  /// Creates an exponential function node representing `exp([expr])`.
  const new(this.expr);

  /// The exponent sub-expression.
  final Expr expr;

  @override
  bool dependsOn(String name) => expr.dependsOn(name);

  @override
  Set<String> get freeVariables => expr.freeVariables;

  @override
  Expr substitute(String variable, Expr replacement) =>
      Exp(expr.substitute(variable, replacement));

  @override
  double evaluate(Map<String, double> context) =>
      math.exp(expr.evaluate(context));

  @override
  bool operator ==(Object other) => other is Exp && other.expr == expr;

  @override
  int get hashCode => expr.hashCode;
}

/// [Ln] function node: ln(expr).
final class Ln extends Expr {
  /// Creates a natural logarithm function node representing `ln([expr])`.
  const new(this.expr);

  /// The argument sub-expression.
  final Expr expr;

  @override
  bool dependsOn(String name) => expr.dependsOn(name);

  @override
  Set<String> get freeVariables => expr.freeVariables;

  @override
  Expr substitute(String variable, Expr replacement) =>
      Ln(expr.substitute(variable, replacement));

  @override
  double evaluate(Map<String, double> context) =>
      math.log(expr.evaluate(context));

  @override
  bool operator ==(Object other) => other is Ln && other.expr == expr;

  @override
  int get hashCode => expr.hashCode;
}
