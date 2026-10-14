part of '../ast.dart';

/// Sealed base class representing a numeric value node in an expression AST.
///
/// Subtypes include exact rational numbers ([RationalNumber]), floating-point
/// approximations ([RealNumber]), and recognized mathematical constants
/// ([ConstantNumber]).
sealed class Number extends Expr {
  /// Abstract const constructor for numeric nodes.
  const new();

  /// Whether this number equals zero.
  bool get isZero;

  /// Whether this number has no imaginary part.
  bool get isReal => true;

  /// Converts this number to a floating-point [double].
  ///
  /// Throws an [UnsupportedError] if called on a non-real constant such as
  /// [ConstantNumber.i].
  double toDouble();

  /// Converts this number to a [Complex] value.
  Complex get complexValue => Complex(toDouble(), 0);

  @override
  bool dependsOn(String name) => false;

  @override
  void collectFreeVariables(Set<String> target) {}

  @override
  Set<String> get freeVariables => const {};

  @override
  Expr substitute(String variable, Expr replacement) => this;

  @override
  double evaluate(Map<String, double> context) => toDouble();
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

  /// Whether this rational number is an integer ($denominator = 1$).
  bool get isInteger => denominator == 1;

  /// Whether this rational number equals zero.
  @override
  bool get isZero => numerator == 0;

  /// Whether this rational number equals one.
  bool get isOne => numerator == 1 && denominator == 1;

  /// Whether this rational number equals negative one.
  bool get isNegativeOne => numerator == -1 && denominator == 1;

  /// Whether this rational number is strictly negative.
  bool get isNegative => numerator < 0;

  /// Converts this rational number to a [Fraction].
  Fraction toFraction() => Fraction(numerator, denominator);

  /// Returns this rational number reduced to lowest terms.
  RationalNumber get normalized {
    if (denominator == 1) return this;
    if (numerator == 0) return zero;
    final g = numerator.abs().gcd(denominator);
    if (g <= 1) return this;
    return RationalNumber(numerator ~/ g, denominator ~/ g);
  }

  /// Converts this rational number to an [int] (truncated).
  int toInt() => numerator ~/ denominator;

  @override
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

  /// The floating-point numeric value of this node.
  final double value;

  @override
  bool get isZero => value == 0.0;

  @override
  double toDouble() => value;

  @override
  String toString() => value.toString();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RealNumber &&
          (other.value == value || (value.isNaN && other.value.isNaN)));

  @override
  int get hashCode => value.isNaN ? double.nan.hashCode : value.hashCode;
}

/// A recognized mathematical constant (such as [pi], [e], [infinity], or [i]).
///
/// Preserves symbolic identity during algebraic manipulations and LaTeX
/// typesetting without premature floating-point loss of precision.
///
/// ```dart
/// final c = ConstantNumber.pi;
/// print(c.name); // 'pi'
/// print(c.toDouble()); // 3.141592653589793
/// ```
final class ConstantNumber extends Number {
  /// Creates a named mathematical constant with [name] and [value].
  const new(this.name, this.value);

  /// Mathematical constant $\pi \approx 3.141592653589793$.
  static const pi = ConstantNumber('pi', RealNumber(math.pi));

  /// Mathematical constant $e \approx 2.718281828459045$.
  static const e = ConstantNumber('e', RealNumber(math.e));

  /// Positive infinity constant $\infty$.
  static const infinity = ConstantNumber('∞', RealNumber(double.infinity));

  /// Imaginary unit constant $i = \sqrt{-1}$.
  static const i = ConstantNumber(
    'i',
    Pow(RationalNumber.negativeOne, RationalNumber(1, 2)),
  );

  /// The symbolic name of this constant (e.g. `'pi'`, `'e'`, `'∞'`, `'i'`).
  final String name;

  /// The expression representing the value of this constant.
  final Expr value;

  @override
  double toDouble() => isReal
      ? value.evaluate(const {})
      : throw UnsupportedError(
          'Constant "$name" has no real floating-point value',
        );

  @override
  bool get isZero => value is Number && (value as Number).isZero;

  @override
  bool get isReal => value.evaluateComplex().b == 0.0;

  @override
  Complex get complexValue => value.evaluateComplex();

  @override
  String toString() => name;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ConstantNumber && other.name == name && other.value == value);

  @override
  int get hashCode => Object.hash(name, value);
}
