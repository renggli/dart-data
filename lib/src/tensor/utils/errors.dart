int checkPositive(int value, [String? name, String? message]) {
  if (value > 0) return value;
  throw RangeError.range(value, 0, null, name ?? "index", message);
}
