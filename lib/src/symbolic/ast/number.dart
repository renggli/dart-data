part of '../ast.dart';

/// Sealed base class representing a numeric value node in an expression AST.
///
/// Subtypes include exact rational numbers ([RationalNumber]), floating-point
/// approximations ([RealNumber]), recognized transcendental constants
/// ([ConstantNumber]), and complex numbers ([ComplexNumber]).
sealed class Number extends Expr {
  /// Abstract const constructor for numeric nodes.
  const new();

  /// Floating-point double precision numeric value of this number.
  ///
  /// Throws an [UnsupportedError] if called on complex numbers with non-zero
  /// imaginary parts.
  double get value;

  /// Whether this number equals zero.
  bool get isZero;

  /// Whether this number has no imaginary part.
  bool get isReal => true;

  /// Converts this number to a [Complex] value.
  Complex get complexValue => Complex(value, 0);

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
  bool get isZero => value == 0.0;

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
  /// Creates a named mathematical constant with [name] and optional numeric [value].
  const new(this.name, [double value = double.nan]) : _value = value;

  /// Mathematical constant $\pi \approx 3.141592653589793$.
  static const pi = ConstantNumber('pi', math.pi);

  /// Mathematical constant $e \approx 2.718281828459045$.
  static const e = ConstantNumber('e', math.e);

  /// Positive infinity constant $\infty$.
  static const infinity = ConstantNumber('oo', double.infinity);

  /// Imaginary unit constant $i = \sqrt{-1}$.
  static const i = ComplexNumber.i;

  /// The symbolic name of this constant (e.g. `'pi'`, `'e'`).
  final String name;

  final double _value;

  @override
  double get value => _value;

  @override
  bool get isZero => _value == 0.0;

  @override
  bool get isReal => true;

  @override
  Complex get complexValue => Complex(_value, 0);

  @override
  String toString() => name;

  @override
  bool operator ==(Object other) =>
      other is ConstantNumber && other.name == name;

  @override
  int get hashCode => name.hashCode;
}

/// A complex number leaf node ($a + bi \in \mathbb{C}$).
final class ComplexNumber extends Number implements ConstantNumber {
  /// Creates a complex number node with [real] and [imaginary] components.
  const new(this.real, this.imaginary);

  /// Creates a purely imaginary complex number node ($0.0 + bi$).
  const new imaginary(double imaginary) : this(0.0, imaginary);

  /// Creates a [ComplexNumber] from a [Complex] instance.
  factory fromComplex(Complex complex) =>
      ComplexNumber(complex.a.toDouble(), complex.b.toDouble());

  /// Standard imaginary unit ($i = \sqrt{-1}$).
  static const i = ComplexNumber(0.0, 1.0);

  /// The real scalar component.
  final double real;

  /// The imaginary scalar component.
  final double imaginary;

  @override
  String get name => real == 0.0 && imaginary == 1.0
      ? 'i'
      : real == 0.0 && imaginary == -1.0
      ? '-i'
      : toString();

  @override
  double get _value => imaginary == 0.0 ? real : double.nan;

  @override
  double get value => imaginary == 0.0
      ? real
      : throw UnsupportedError(
          'Complex number has non-zero imaginary component: $this',
        );

  @override
  bool get isReal => imaginary == 0.0;

  @override
  bool get isZero => real == 0.0 && imaginary == 0.0;

  @override
  Complex get complexValue => Complex(real, imaginary);

  @override
  bool operator ==(Object other) =>
      other is ComplexNumber &&
      other.real == real &&
      other.imaginary == imaginary;

  @override
  int get hashCode => Object.hash(ComplexNumber, real, imaginary);

  @override
  String toString() {
    if (imaginary == 0.0) return '$real';
    if (real == 0.0 && imaginary == 1.0) return 'i';
    if (real == 0.0 && imaginary == -1.0) return '-i';
    if (real == 0.0) return '${imaginary}i';
    return imaginary < 0 ? '$real - ${-imaginary}i' : '$real + ${imaginary}i';
  }
}
