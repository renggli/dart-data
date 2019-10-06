library data.type.models.field;

/// Encapsulates a mathematical field.
abstract class Field<T> {
  const Field();

  /// The additive neutral element.
  T get additiveIdentity;

  /// Computes `-a`, the additive inverse.
  T neg(T a);

  /// Computes `a + b`.
  T add(T a, T b);

  /// Computes `a - b`.
  T sub(T a, T b);

  /// The multiplicative neutral element.
  T get multiplicativeIdentity;

  /// Computes `1 / a`, the multiplicative inverse.
  T inv(T a);

  /// Computes `a * b`.
  T mul(T a, T b);

  /// Computes `a * f`.
  T scale(T a, num f);

  /// Computes `a / b`.
  T div(T a, T b);

  /// Computes `a % b`.
  T mod(T a, T b);

  /// Computes `a ^^ b`.
  T pow(T a, T b);

  /// Thrown when an operation is not supported.
  T unsupportedOperation(String operation) =>
      throw UnsupportedError('$operation is not supported.');
}
