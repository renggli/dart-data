import '../polynomial.dart';

extension ComparePolynomialExtension<T> on Polynomial<T> {
  /// Compares this [Polynomial] and with [other].
  bool compare(Polynomial<T> other, {bool Function(T a, T b)? equals}) {
    if (equals == null && identical(this, other)) {
      return true;
    }
    if (degree != other.degree) {
      return false;
    }
    equals ??= dataType.equality.isEqual;
    for (var i = degree; i >= 0; i--) {
      if (!equals(getUnchecked(i), other.getUnchecked(i))) {
        return false;
      }
    }
    return true;
  }
}
