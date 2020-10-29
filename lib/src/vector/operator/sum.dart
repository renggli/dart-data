import '../vector.dart';

extension SumExtension<T> on Vector<T> {
  /// Computes the sum of all elements in this [Vector].
  T get sum {
    final add = dataType.field.add;
    var result = dataType.field.additiveIdentity;
    for (var i = 0; i < count; i++) {
      result = add(result, getUnchecked(i));
    }
    return result;
  }
}
