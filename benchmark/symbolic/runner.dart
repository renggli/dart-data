/// Minimal `Stopwatch`-based micro-benchmark runner without external
/// dependencies.
library;

/// The result of measuring a single benchmark.
class BenchmarkResult {
  /// Creates a benchmark result.
  const new(this.name, this.runs, this.samples);

  /// The name of the benchmark.
  final String name;

  /// The number of measured runs.
  final int runs;

  /// The sorted per-run durations in microseconds.
  final List<int> samples;

  /// The median duration in microseconds.
  double get median {
    final middle = samples.length ~/ 2;
    return samples.length.isOdd
        ? samples[middle].toDouble()
        : (samples[middle - 1] + samples[middle]) / 2;
  }

  /// The minimum duration in microseconds.
  int get min => samples.first;

  /// The maximum duration in microseconds.
  int get max => samples.last;

  @override
  String toString() =>
      '${name.padRight(40)} '
      'median ${median.toStringAsFixed(0).padLeft(10)} us   '
      'min ${'$min'.padLeft(10)} us   '
      'max ${'$max'.padLeft(10)} us   '
      'runs $runs';
}

/// Sink to prevent the compiler from eliminating benchmark bodies.
Object? blackHole;

/// Measures [body] by running it [warmup] times untimed, followed by [runs]
/// timed samples, and returns the per-run statistics.
///
/// Each sample executes [body] [inner] times and records the average duration
/// of a single execution, which reduces timer noise for very fast workloads.
BenchmarkResult measure(
  String name,
  Object? Function() body, {
  int warmup = 3,
  int runs = 15,
  int inner = 1,
}) {
  for (var i = 0; i < warmup * inner; i++) {
    blackHole = body();
  }
  final samples = <int>[];
  final stopwatch = Stopwatch();
  for (var i = 0; i < runs; i++) {
    stopwatch
      ..reset()
      ..start();
    for (var j = 0; j < inner; j++) {
      blackHole = body();
    }
    stopwatch.stop();
    samples.add(stopwatch.elapsedMicroseconds ~/ inner);
  }
  samples.sort();
  return BenchmarkResult(name, runs, samples);
}
