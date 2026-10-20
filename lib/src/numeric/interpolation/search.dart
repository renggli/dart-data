import 'dart:math' as math;

/// Finds the interval index $i$ such that $x_i \le x < x_{i+1}$ for strictly
/// increasing [xs].
int binarySearchInterval(List<double> xs, double x) {
  if (x <= xs.first) return 0;
  if (x >= xs.last) return xs.length - 2;
  var low = 0;
  var high = xs.length - 1;
  while (low <= high) {
    final mid = (low + high) >> 1;
    if (xs[mid] <= x) {
      if (mid + 1 < xs.length && x < xs[mid + 1]) {
        return mid;
      }
      low = mid + 1;
    } else {
      high = mid - 1;
    }
  }
  return math.max(0, math.min(xs.length - 2, low - 1));
}
