library data.vector.operator.compare;

import '../vector.dart';

extension CompareExtension<T> on Vector<T> {
  /// Compares this [Vector] and with [other].
  bool compare(Vector<T> other, {bool Function(T a, T b) equals}) {
    if (equals == null && identical(this, other)) {
      return true;
    }
    if (count != other.count) {
      return false;
    }
    equals ??= dataType.equality.isEqual;
    for (var i = 0; i < count; i++) {
      if (!equals(getUnchecked(i), other.getUnchecked(i))) {
        return false;
      }
    }
    return true;
  }
}
