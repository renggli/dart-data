import '../../type.dart';
import '../../vector.dart';

/// Asserts a number of properties on x- and y-coordinate data:
///
/// - Check that x- and y-coordinates have the same size.
/// - Check that there are at least [min] elements.
/// - Check that the x-coordinates are [ordered] and/or [unique].
///
/// The code is only run when assertions are enabled.
void checkPoints<T>(
  DataType<T> dataType, {
  required Vector<T> xs,
  required Vector<T> ys,
  int min = 0,
  bool ordered = false,
  bool unique = false,
}) {
  if (xs.count != ys.count) {
    throw ArgumentError(
      'The x- and y-coordinates must have the same number '
      'of elements, but got ${xs.count} and ${ys.count}.',
    );
  }
  if (xs.count < min) {
    throw ArgumentError(
      'The x- and y-coordinates must have at least $min '
      'elements, but only got ${xs.count}.',
    );
  }
  if (ordered) {
    if (unique) {
      if (!dataType.comparator.isStrictlyOrdered(xs.iterable)) {
        throw ArgumentError(
          'The x-coordinates are expected to be strictly '
          'ordered, but found duplicates in $xs.',
        );
      }
    } else {
      if (!dataType.comparator.isOrdered(xs.iterable)) {
        throw ArgumentError(
          'The x-coordinates are expected to be ordered, but '
          'got $xs.',
        );
      }
    }
  } else {
    if (unique) {
      if (xs.count != Set.of(xs.iterable).length) {
        throw ArgumentError(
          'The x-coordinates are expected to be unique, but '
          'found duplicates in $xs.',
        );
      }
    }
  }
}
