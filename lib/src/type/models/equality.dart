import 'package:meta/meta.dart';

/// Encapsulates equality between and the hash code of objects.
@immutable
abstract class Equality<T> {
  const Equality();

  /// Returns `true`, if [a] and [b] are the same.
  bool isEqual(T a, T b);

  /// Returns `true`, if [a] and [b] are within range of [epsilon].
  bool isClose(T a, T b, double epsilon);

  /// Return the hash code of [a].
  int hash(T a);
}

/// The natural and canonical equality of objects.
class NaturalEquality<T> extends Equality<T> {
  const NaturalEquality();

  @override
  bool isEqual(T a, T b) => a == b;

  @override
  bool isClose(T a, T b, double epsilon) => isEqual(a, b);

  @override
  int hash(T a) => a.hashCode;
}
