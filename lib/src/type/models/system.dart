library data.type.models.number;

/// Encapsulates a mathematical number system.
abstract class System<T> {
  const System();

  T get additiveIdentity;

  T neg(T a);

  T add(T a, T b);

  T sub(T a, T b);

  T get multiplicativeIdentity;

  T inv(T a);

  T mul(T a, T b);

  T scale(T a, num f);

  T div(T a, T b);

  T mod(T a, T b);

  T pow(T a, T b);
}
