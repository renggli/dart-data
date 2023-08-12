/// Throws a [RangeError] if is negative.
int checkPositive(int value, [String? name, String? message]) {
  if (value > 0) return value;
  throw RangeError.range(value, 0, null, name, message);
}

/// Adjusts an index to be positive.
int adjustIndex(int index, int length) => index < 0 ? index + length : index;

/// Adjusts `value` to be positive, throws a [RangeError] if the `value` is
/// not smaller than length.
int checkIndex(int index, int length, [String? name, String? message]) {
  final adjustedIndex = adjustIndex(index, length);
  if (adjustedIndex < length) return adjustedIndex;
  throw RangeError.range(adjustedIndex, 0, length, name, message);
}
