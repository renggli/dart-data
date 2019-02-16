library data.type.models.number;

/// Encapsulates a mathematical number system.
abstract class System<T> {
  const System();

  /// The additive neutral element.
  T get additiveIdentity;

  /// Computes `-a`.
  T neg(T a);

  /// Computes `a + b`.
  T add(T a, T b);

  /// Computes `a - b`.
  T sub(T a, T b);

  /// The multiplicative neutral element.
  T get multiplicativeIdentity;

  /// Computes `1 / a`.
  T inv(T a);

  /// Computes `a * b`.
  T mul(T a, T b);

  /// Computes `a * f`.
  T scale(T a, num f);

  /// Computes `a / f`.
  T div(T a, T b);

  /// Computes `a % f`.
  T mod(T a, T b);

  /// Computes `a ^^ f`.
  T pow(T a, T b);

  /// Thrown when an operation is not supported.
  T unsupportedOperation(String operation) =>
      throw UnsupportedError('$operation is not supported.');
}
