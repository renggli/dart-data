/// Adjusts a negative index to be retrieved from the end.
int adjustIndex(int index, int length) => index < 0 ? index + length : index;

/// Adjusts and checks an `index` to be smaller than `length`, or otherwise
/// throw an [IndexError].
int checkIndex(int index, int length, [String? name, String? message]) {
  final adjustedIndex = adjustIndex(index, length);
  if (0 <= adjustedIndex && adjustedIndex < length) {
    return adjustedIndex;
  }
  throw IndexError.withLength(adjustedIndex, length,
      name: name, message: message);
}

/// Adjusts and checks an `index` to be smaller or equal than `length`,
/// otherwise throws a [RangeError].
int checkStart(int start, int length, [String? name, String? message]) {
  final adjustedStart = adjustIndex(start, length);
  if (0 <= adjustedStart && adjustedStart <= length) {
    return adjustedStart;
  }
  throw RangeError.range(adjustedStart, 0, length, name, message);
}

/// Adjusts and checks an `index` to be larger than start and smaller or equal
/// than `length`, otherwise throw a [RangeError].
int checkEnd(int start, int? end, int length, [String? name, String? message]) {
  final adjustedEnd = adjustIndex(end ?? length, length);
  if (start <= adjustedEnd && adjustedEnd <= length) {
    return adjustedEnd;
  }
  throw RangeError.range(adjustedEnd, start, length, name, message);
}

/// Checks if `value` is positive or zero, otherwise throw a [RangeError].
int checkStep(int value, [String? name, String? message]) {
  if (value > 0) {
    return value;
  }
  throw RangeError.range(value, 0, null, name, message);
}
