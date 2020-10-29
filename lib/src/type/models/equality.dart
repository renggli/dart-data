import 'package:meta/meta.dart';

/// Encapsulates equality between and the hash code of objects.
@immutable
class Equality<T> {
  const Equality();

  /// Returns `true`, if [a] and [b] are the same.
  bool isEqual(T a, T b) => a == b;

  /// Returns `true`, if [a] and [b] are within range of [epsilon].
  bool isClose(T a, T b, double epsilon) => isEqual(a, b);

  /// Return the hash code of [a].
  int hash(T a) => a.hashCode;
}
