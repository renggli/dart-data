library data.type.models.equality;

/// Encapsulates equality between and the hash code of objects.
class Equality<T> {
  const Equality();

  /// Returns `true` if [a] and [b] are the same.
  bool isEqual(T a, T b) => a == b;

  /// Return the hash code of [a].
  int hash(T a) => a.hashCode;
}
