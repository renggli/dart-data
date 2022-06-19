import 'package:meta/meta.dart';

/// Encapsulates a mathematical field.
@immutable
abstract class Field<T> {
  const Field();

  /// The additive neutral element.
  T get additiveIdentity;

  /// Computes the additive inverse: `-a`.
  T neg(T a) => sub(additiveIdentity, a);

  /// Computes the addition: `a + b`.
  T add(T a, T b);

  /// Computes the subtraction: `a - b`.
  T sub(T a, T b);

  /// The multiplicative neutral element.
  T get multiplicativeIdentity;

  /// Computes the multiplicative inverse: `1 / a`.
  T inv(T a) => div(multiplicativeIdentity, a);

  /// Computes the multiplication: `a * b`.
  T mul(T a, T b);

  /// Computes the multiplicative scaling: `a * f`.
  T scale(T a, num f);

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

  /// Not a number.
  T get nan => div(additiveIdentity, additiveIdentity);

  /// Positive infinity.
  T get infinity => div(multiplicativeIdentity, additiveIdentity);

  /// Negative infinity.
  T get negativeInfinity => neg(infinity);

  /// Thrown when an operation is not supported.
  T unsupportedOperation(String operation) =>
      throw UnsupportedError('$operation is not supported.');
}
