import 'package:meta/meta.dart';

/// Encapsulates a mathematical field.
@immutable
abstract interface class Field<T> {
  /// The additive neutral element.
  T get additiveIdentity;

  /// Computes the additive inverse: `-a`.
  T neg(T a);

  /// Computes the addition: `a + b`.
  T add(T a, T b);

  /// Computes the subtraction: `a - b`.
  T sub(T a, T b);

  /// The multiplicative neutral element.
  T get multiplicativeIdentity;

  /// Computes the multiplicative inverse: `1 / a`.
  T inv(T a);

  /// Computes the multiplication: `a * b`.
  T mul(T a, T b);

  /// Computes the multiplicative scaling: `a * factor`.
  T scale(T a, num factor);

  /// Computes the division: `a / b`.
  T div(T a, T b);

  /// Computes the remainder of the Euclidean division `a % b`.
  T mod(T a, T b);

  /// Computes a truncating division: `a ~/ b`.
  T division(T a, T b);

  /// Computes the remainder of the truncating division.
  T remainder(T a, T b);

  /// Computes [base] to the power of [exponent].
  T pow(T base, T exponent);

  /// Computes [base] to the power of [exponent] modulo [modulus].
  T modPow(T base, T exponent, T modulus);

  /// Computes the modular multiplicative inverse of [base] modulo [modulus].
  T modInverse(T base, T modulus);

  /// Computes the greatest common divisor: `gcd(a, b)`.
  T gcd(T a, T b);

  /// Computes the absolute value: `|a|`.
  T abs(T a);

  /// Computes the Euclidean norm: `||a||`.
  double norm(T a);

  /// Computes the square root: `sqrt(a)`.
  T sqrt(T a);

  /// Computes the exponential function: `exp(a)`.
  T exp(T a);

  /// Computes the natural logarithm: `ln(a)`.
  T log(T a);

  /// Computes the complex conjugate: `a*` (identity for real types).
  T conjugate(T a);

  /// Not a number.
  T get nan;

  /// Positive infinity.
  T get infinity;

  /// Negative infinity.
  T get negativeInfinity;
}

/// An algebraic field extended with norm, square root, power, and
/// transcendental functions.
abstract interface class ExtendedField<T> implements Field<T>;

/// Thrown when an operation is not supported.
Never unsupportedOperation(String operation) =>
    throw UnsupportedError('$operation is not supported.');
