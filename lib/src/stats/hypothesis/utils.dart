/// Validates that significance threshold [alpha] is finite in `(0, 1)`.
void validateAlpha(double alpha) {
  if (!(alpha.isFinite && alpha > 0.0 && alpha < 1.0)) {
    throw ArgumentError.value(
      alpha,
      'alpha',
      'Significance level alpha must be in (0, 1)',
    );
  }
}

/// Computes 1-based fractional ranks for finite/comparable [values] together
/// with the standard tie-correction sum `sum(t^3 - t)` and tie indicator in
/// a single sort pass without allocating a hash map.
({List<double> ranks, double tieCorrectionSum, bool hasTies}) rankDataWithTies(
  List<double> values,
) {
  final n = values.length;
  final indices = List<int>.generate(n, (i) => i)
    ..sort((a, b) => values[a].compareTo(values[b]));
  final ranks = List<double>.filled(n, 0.0);
  var tieSum = 0.0;
  var hasTies = false;
  var i = 0;
  while (i < n) {
    var j = i;
    while (j + 1 < n && values[indices[j + 1]] == values[indices[i]]) {
      j++;
    }
    final avgRank = 1.0 + 0.5 * (i + j);
    for (var k = i; k <= j; k++) {
      ranks[indices[k]] = avgRank;
    }
    final count = j - i + 1;
    if (count > 1) {
      hasTies = true;
      final c = count.toDouble();
      tieSum += c * c * c - c;
    }
    i = j + 1;
  }
  return (ranks: ranks, tieCorrectionSum: tieSum, hasTies: hasTies);
}
