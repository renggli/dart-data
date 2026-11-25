import 'dart:math';

/// Shared default pseudo-random number generator for distribution sampling.
final Random defaultRandom = Random();

/// Evaluates `exp(x) - 1.0` without catastrophic cancellation near zero.
double expm1(double x) {
  if (x.isNaN) return double.nan;
  if (x == 0.0) return 0.0;
  if (x.abs() < 1e-4) {
    return x * (1.0 + x * (0.5 + x * (1.0 / 6.0 + x / 24.0)));
  }
  return exp(x) - 1.0;
}

/// Draws a pseudo-random value strictly in the open interval `(0.0, 1.0)`.
double nextOpenUnit(Random random) {
  var u = random.nextDouble();
  while (u == 0.0) {
    u = random.nextDouble();
  }
  return u;
}

/// Computes count, sample mean, and unbiased sample variance in a single pass
/// using Welford's online algorithm.
///
/// Validates finiteness and optional [isValid] predicate for every element and
/// throws [ArgumentError] if fewer than [minCount] elements are provided.
({int count, double mean, double variance}) welfordSampleStats(
  Iterable<num> samples, {
  bool Function(double value)? isValid,
  String invalidMessage = 'Samples must be finite',
  int minCount = 1,
}) {
  var count = 0;
  var mean = 0.0;
  var m2 = 0.0;
  for (final sample in samples) {
    final value = sample.toDouble();
    if (!value.isFinite || (isValid != null && !isValid(value))) {
      throw ArgumentError.value(sample, 'samples', invalidMessage);
    }
    count++;
    final delta = value - mean;
    mean += delta / count;
    final delta2 = value - mean;
    m2 += delta * delta2;
  }
  if (count < minCount) {
    throw ArgumentError.value(
      samples,
      'samples',
      minCount == 1
          ? 'Cannot fit empty samples'
          : 'At least $minCount samples required',
    );
  }
  return (
    count: count,
    mean: mean,
    variance: count > 1 ? m2 / (count - 1) : 0.0,
  );
}
