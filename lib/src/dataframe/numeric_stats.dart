/// Computes the arithmetic mean of non-null values yielded by [getAt] over
/// `0 .. count - 1`.
///
/// Returns `null` if no non-null values exist, propagates `NaN` (and `+∞ + -∞`),
/// and falls back to `maxAbs`-scaled summation if direct summation overflows on
/// all-finite values.
double? computeNumericMean(int count, double? Function(int i) getAt) {
  var validCount = 0;
  var sum = 0.0;
  var maxAbs = 0.0;
  var hasPosInf = false;
  var hasNegInf = false;

  for (var i = 0; i < count; i++) {
    final val = getAt(i);
    if (val == null) continue;
    if (val.isNaN) return double.nan;
    validCount++;
    if (val.isInfinite) {
      if (val > 0) {
        hasPosInf = true;
      } else {
        hasNegInf = true;
      }
      continue;
    }
    final absVal = val.abs();
    if (absVal > maxAbs) maxAbs = absVal;
    sum += val;
  }

  if (validCount == 0) return null;
  if (hasPosInf && hasNegInf) return double.nan;
  if (hasPosInf) return double.infinity;
  if (hasNegInf) return double.negativeInfinity;

  if (!sum.isFinite && maxAbs > 0.0) {
    var scaledSum = 0.0;
    for (var i = 0; i < count; i++) {
      final val = getAt(i);
      if (val != null) {
        scaledSum += val / maxAbs;
      }
    }
    return scaledSum * (maxAbs / validCount);
  }

  return sum / validCount;
}

/// Computes the sample ([population] = `false`) or population
/// ([population] = `true`) variance of non-null values yielded by [getAt] over
/// `0 .. count - 1`.
///
/// Returns `null` if fewer than 2 non-null values exist (or fewer than 1 when
/// [population] is `true`). Returns [double.nan] if any value is non-finite.
/// Falls back to two-pass shifted/scaled summation if single-pass Welford
/// overflows on finite inputs.
double? computeNumericVariance(
  int count,
  double? Function(int i) getAt, {
  required bool population,
}) {
  var validCount = 0;
  var mean = 0.0;
  var m2 = 0.0;
  var hasNonFinite = false;

  for (var i = 0; i < count; i++) {
    final val = getAt(i);
    if (val == null) continue;
    if (val.isNaN) return double.nan;
    if (!val.isFinite) {
      hasNonFinite = true;
      validCount++;
      continue;
    }
    validCount++;
    final delta = val - mean;
    mean += delta / validCount;
    final delta2 = val - mean;
    m2 += delta * delta2;
  }

  final divisor = population ? validCount : validCount - 1;
  if (divisor <= 0) return null;
  if (hasNonFinite) return double.nan;

  if (m2.isFinite) {
    final v = m2 / divisor;
    return v < 0.0 ? 0.0 : v;
  }

  final mu = computeNumericMean(count, getAt);
  if (mu == null || mu.isNaN) return double.nan;
  var maxDev = 0.0;
  for (var i = 0; i < count; i++) {
    final val = getAt(i);
    if (val == null) continue;
    final dev = (val - mu).abs();
    if (dev > maxDev) maxDev = dev;
  }
  if (maxDev == 0.0) return 0.0;
  if (!maxDev.isFinite) return double.infinity;

  var scaledSq = 0.0;
  for (var i = 0; i < count; i++) {
    final val = getAt(i);
    if (val == null) continue;
    final normDev = (val - mu) / maxDev;
    scaledSq += normDev * normDev;
  }
  final v = maxDev * (maxDev / divisor) * scaledSq;
  return v < 0.0 ? 0.0 : v;
}

/// Linearly interpolates between sorted endpoints [a] and [b] at fraction
/// [frac] in `[0.0, 1.0]` without overflow when `b - a` is non-finite.
double interpolateQuantile(double a, double b, double frac) {
  if (a == b || frac == 0.0) return a;
  if (frac == 1.0) return b;
  final diff = b - a;
  return diff.isFinite ? a + frac * diff : a * (1.0 - frac) + b * frac;
}

/// Partitions [list] in-place around the element at rank [k] within `[left, right]`
/// using 3-way Dutch National Flag quickselect.
void quickselect(List<double> list, int k, [int left = 0, int? right]) {
  var l = left;
  var r = right ?? list.length - 1;
  while (l < r) {
    final mid = l + (r - l) ~/ 2;
    if (list[l] > list[mid]) _swap(list, l, mid);
    if (list[l] > list[r]) _swap(list, l, r);
    if (list[mid] > list[r]) _swap(list, mid, r);
    final pivot = list[mid];

    var i = l;
    var lt = l;
    var gt = r;
    while (i <= gt) {
      if (list[i] < pivot) {
        _swap(list, lt, i);
        lt++;
        i++;
      } else if (list[i] > pivot) {
        _swap(list, i, gt);
        gt--;
      } else {
        i++;
      }
    }

    if (k < lt) {
      r = lt - 1;
    } else if (k > gt) {
      l = gt + 1;
    } else {
      return;
    }
  }
}

/// Computes the empirical quantile at fraction [p] in `[0.0, 1.0]` using
/// [scratch] in-place via [quickselect].
///
/// Mutates the order of elements in [scratch]. Returns `null` if [scratch] is
/// empty, [double.nan] if any element is `NaN`, or throws [RangeError] if [p]
/// is outside `[0.0, 1.0]`.
double? computeQuantileInPlace(List<double> scratch, double p) {
  if (p < 0.0 || p > 1.0 || p.isNaN) {
    throw RangeError.value(p, 'p', 'Must be between 0.0 and 1.0');
  }
  final n = scratch.length;
  if (n == 0) return null;
  for (var i = 0; i < n; i++) {
    if (scratch[i].isNaN) return double.nan;
  }
  final idx = p * (n - 1);
  final low = idx.floor();
  final frac = idx - low;
  quickselect(scratch, low);
  if (frac > 0.0 && low + 1 < n) {
    quickselect(scratch, low + 1, low + 1, n - 1);
    return interpolateQuantile(scratch[low], scratch[low + 1], frac);
  }
  return scratch[low];
}

void _swap(List<double> list, int i, int j) {
  final temp = list[i];
  list[i] = list[j];
  list[j] = temp;
}
