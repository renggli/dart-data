/// Benchmark runner, statistics computation, and reporting utilities.
library;

// ignore_for_file: avoid_print

import 'dart:math' as math;

import 'package:data/acceleration.dart';
import 'package:data/stats.dart';

/// The result of measuring a single benchmark workload.
class BenchmarkResult {
  /// Creates a benchmark result.
  const new({
    required this.name,
    required this.runs,
    required this.samples,
    this.confidenceInterval,
    this.standardError,
  });

  /// The name of the benchmark.
  final String name;

  /// The number of measured runs.
  final int runs;

  /// The sorted per-run durations in microseconds.
  final List<double> samples;

  /// Empirical 95% bootstrap confidence interval `(lower, upper)`.
  final (double, double)? confidenceInterval;

  /// Empirical standard error of the estimate.
  final double? standardError;

  /// The median duration in microseconds.
  double get median {
    final middle = samples.length ~/ 2;
    return samples.length.isOdd
        ? samples[middle]
        : (samples[middle - 1] + samples[middle]) / 2;
  }

  /// The minimum duration in microseconds.
  double get min => samples.first;

  /// The maximum duration in microseconds.
  double get max => samples.last;

  /// The lower bound of the 95% confidence interval, if available.
  double? get ciLower => confidenceInterval?.$1;

  /// The upper bound of the 95% confidence interval, if available.
  double? get ciUpper => confidenceInterval?.$2;

  @override
  String toString() {
    final medStr = formatDuration(median).padLeft(8);
    final minStr = formatDuration(min).padLeft(8);
    final maxStr = formatDuration(max).padLeft(8);
    final ciStr = confidenceInterval != null
        ? '95% CI [${formatDuration(ciLower!)}, ${formatDuration(ciUpper!)}]'
              .padLeft(24)
        : '';
    return '${name.padRight(36)} '
        'median $medStr us   '
        'min $minStr us   '
        'max $maxStr us   '
        '$ciStr   '
        'runs $runs';
  }
}

/// A comparison between pure Dart execution and native hardware acceleration.
class ModeComparison {
  /// Creates a comparison between Dart and native runs.
  const new({
    required this.name,
    required this.dartResult,
    this.nativeResult,
    this.note,
  });

  /// The name of the benchmark.
  final String name;

  /// The benchmark result under pure Dart execution.
  final BenchmarkResult dartResult;

  /// The benchmark result under native accelerated execution, if available.
  final BenchmarkResult? nativeResult;

  /// Optional note (e.g. why native execution was skipped or unavailable).
  final String? note;

  /// Speedup factor of native over pure Dart (`dartMedian / nativeMedian`).
  double? get speedup => nativeResult != null && nativeResult!.median > 0
      ? dartResult.median / nativeResult!.median
      : null;
}

/// Specification of a single benchmark workload.
class BenchmarkSpec {
  /// Creates a benchmark specification.
  const new({
    required this.name,
    this.category = '',
    required this.action,
    this.runs = 15,
    this.warmup = 3,
    this.inner = 1,
    this.isNativeSupported,
  });

  /// Unique name of the benchmark workload.
  final String name;

  /// High-level mathematical category or subsystem group.
  final String category;

  /// The closure to measure.
  final Object? Function() action;

  /// Number of timed sample runs.
  final int runs;

  /// Number of untimed warmup iterations.
  final int warmup;

  /// Repetitions executed per sample run to reduce timer quantization noise.
  final int inner;

  /// Optional availability check for native acceleration.
  final bool Function()? isNativeSupported;
}

/// Suite of benchmark specifications with command-line execution and reporting.
class BenchmarkSuite {
  /// Creates a benchmark suite.
  const new({required this.name, this.description = '', required this.specs});

  /// Human-readable title of the benchmark suite.
  final String name;

  /// Optional subtitle or platform notes.
  final String description;

  /// The registered benchmark workloads in this suite.
  final List<BenchmarkSpec> specs;

  /// Executes the suite with the given CLI [arguments].
  ///
  /// When [compareModes] is `true`, every workload is evaluated under both pure
  /// Dart and native acceleration modes, reporting speedup factors.
  void run(List<String> arguments, {bool compareModes = false}) {
    _printHeader(compareModes);

    final filtered = _filterSpecs(arguments);
    if (filtered.isEmpty) {
      print('No benchmarks matched filters: ${arguments.join(', ')}');
      return;
    }

    if (compareModes) {
      _runComparison(filtered);
    } else {
      _runStandard(filtered);
    }
  }

  void _printHeader(bool compareModes) {
    print('=' * 72);
    print(name);
    if (description.isNotEmpty) {
      print(description);
    }
    print('=' * 72);
    if (compareModes) {
      print('Platform hardware acceleration status:');
      print('  BLAS available:    ${AccelerationManager.isBlasAvailable}');
      print('  vDSP available:    ${AccelerationManager.isVdspAvailable}');
      print('  FFT available:     ${AccelerationManager.isFftAvailable}');
      print('  vForce available:  ${AccelerationManager.isVForceAvailable}');
      print('-' * 72);
    }
    print('');
  }

  List<BenchmarkSpec> _filterSpecs(List<String> arguments) {
    if (arguments.isEmpty) return specs;
    return specs.where((spec) {
      final query = '${spec.name} ${spec.category}'.toLowerCase();
      return arguments.any((arg) => query.contains(arg.toLowerCase()));
    }).toList();
  }

  void _runStandard(List<BenchmarkSpec> filtered) {
    final results = <(BenchmarkSpec, BenchmarkResult)>[];
    var currentCategory = '';

    for (final spec in filtered) {
      if (spec.category.isNotEmpty && spec.category != currentCategory) {
        currentCategory = spec.category;
        print('\n### $currentCategory\n');
      }

      final result = measure(
        spec.name,
        spec.action,
        warmup: spec.warmup,
        runs: spec.runs,
        inner: spec.inner,
      );
      results.add((spec, result));

      final med = '${formatDuration(result.median)} us'.padLeft(11);
      final ci = result.confidenceInterval != null
          ? '[${formatDuration(result.ciLower!)}, ${formatDuration(result.ciUpper!)}]'
                .padLeft(18)
          : '-'.padLeft(18);
      final range =
          '${formatDuration(result.min)}–${formatDuration(result.max)} us'
              .padLeft(18);

      print(
        '${spec.name.padRight(36)} '
        'median $med  '
        '95% CI $ci  '
        'min–max $range',
      );
    }

    print('\n\n## Benchmark Summary Table\n');
    final hasCategories = results.any((pair) => pair.$1.category.isNotEmpty);
    if (hasCategories) {
      print(
        '| Benchmark | Category | Median (µs) | 95% CI (µs) | Min–Max (µs) |',
      );
      print('| --- | --- | ---: | ---: | ---: |');
      for (final (spec, res) in results) {
        final med = formatDuration(res.median);
        final ci = res.confidenceInterval != null
            ? '[${formatDuration(res.ciLower!)}, ${formatDuration(res.ciUpper!)}]'
            : '—';
        final range = '${formatDuration(res.min)}–${formatDuration(res.max)}';
        print('| `${spec.name}` | ${spec.category} | $med | $ci | $range |');
      }
    } else {
      print('| Benchmark | Median (µs) | 95% CI (µs) | Min–Max (µs) |');
      print('| --- | ---: | ---: | ---: |');
      for (final (spec, res) in results) {
        final med = formatDuration(res.median);
        final ci = res.confidenceInterval != null
            ? '[${formatDuration(res.ciLower!)}, ${formatDuration(res.ciUpper!)}]'
            : '—';
        final range = '${formatDuration(res.min)}–${formatDuration(res.max)}';
        print('| `${spec.name}` | $med | $ci | $range |');
      }
    }
  }

  void _runComparison(List<BenchmarkSpec> filtered) {
    final comparisons = <(BenchmarkSpec, ModeComparison)>[];
    var currentCategory = '';

    for (final spec in filtered) {
      if (spec.category.isNotEmpty && spec.category != currentCategory) {
        currentCategory = spec.category;
        print('\n### $currentCategory\n');
      }

      // 1. Pure Dart execution
      AccelerationManager.mode = AccelerationMode.dart;
      final dartRes = measure(
        spec.name,
        spec.action,
        warmup: spec.warmup,
        runs: spec.runs,
        inner: spec.inner,
      );

      // 2. Native hardware acceleration
      BenchmarkResult? nativeRes;
      String? note;
      final isSupported = spec.isNativeSupported?.call() ?? true;

      if (isSupported) {
        AccelerationManager.mode = AccelerationMode.accelerated;
        try {
          nativeRes = measure(
            spec.name,
            spec.action,
            warmup: spec.warmup,
            runs: spec.runs,
            inner: spec.inner,
          );
        } catch (error) {
          note = 'Failed: $error';
        }
      } else {
        note = 'Native unavailable';
      }

      final comparison = ModeComparison(
        name: spec.name,
        dartResult: dartRes,
        nativeResult: nativeRes,
        note: note,
      );
      comparisons.add((spec, comparison));

      final speedupStr = comparison.speedup != null
          ? '${comparison.speedup!.toStringAsFixed(1)}x'.padLeft(7)
          : (comparison.note ?? 'N/A').padLeft(7);
      final dartMed = '${formatDuration(comparison.dartResult.median)} us'
          .padLeft(11);
      final nativeMed = comparison.nativeResult != null
          ? '${formatDuration(comparison.nativeResult!.median)} us'.padLeft(11)
          : '-'.padLeft(11);

      print(
        '${spec.name.padRight(36)} '
        'Dart: $dartMed  '
        'Native: $nativeMed  '
        'Speedup: $speedupStr',
      );
    }

    // Restore default mode
    AccelerationManager.mode = AccelerationMode.auto;

    print('\n\n## Benchmark Summary Table\n');
    print(
      '| Benchmark | Category | Pure Dart (µs) | Dart 95% CI | Native (µs) | Native 95% CI | Speedup |',
    );
    print('| --- | --- | ---: | ---: | ---: | ---: | ---: |');
    for (final (spec, c) in comparisons) {
      final dartMed = formatDuration(c.dartResult.median);
      final dartCi = c.dartResult.confidenceInterval != null
          ? '[${formatDuration(c.dartResult.ciLower!)}, ${formatDuration(c.dartResult.ciUpper!)}]'
          : '—';
      final nativeMed = c.nativeResult != null
          ? formatDuration(c.nativeResult!.median)
          : (c.note ?? 'N/A');
      final nativeCi = c.nativeResult?.confidenceInterval != null
          ? '[${formatDuration(c.nativeResult!.ciLower!)}, ${formatDuration(c.nativeResult!.ciUpper!)}]'
          : '—';
      final speedupStr = c.speedup != null
          ? '**${c.speedup!.toStringAsFixed(1)}×**'
          : '—';
      print(
        '| `${c.name}` | ${spec.category} | $dartMed | $dartCi | $nativeMed | $nativeCi | $speedupStr |',
      );
    }
  }
}

/// Sink to prevent the compiler from eliminating benchmark bodies.
Object? blackHole;

/// Measures [body] by running it [warmup] times untimed, followed by [runs]
/// timed samples, and returns the per-run statistics with bootstrap 95% CI.
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
  final samples = <double>[];
  final stopwatch = Stopwatch();
  for (var i = 0; i < runs; i++) {
    stopwatch
      ..reset()
      ..start();
    for (var j = 0; j < inner; j++) {
      blackHole = body();
    }
    stopwatch.stop();
    samples.add(stopwatch.elapsedMicroseconds / inner);
  }
  samples.sort();

  (double, double)? ci;
  double? se;
  if (samples.length >= 3) {
    try {
      final boot = bootstrap<double>(
        samples,
        _sampleMedian,
        resamples: 1000,
        random: math.Random(42),
      );
      ci = boot.percentileInterval;
      se = boot.standardError;
    } catch (_) {
      // Degenerate inputs fallback cleanly
    }
  }

  return BenchmarkResult(
    name: name,
    runs: runs,
    samples: samples,
    confidenceInterval: ci,
    standardError: se,
  );
}

double _sampleMedian(List<double> list) {
  final sorted = list.toList()..sort();
  final middle = sorted.length ~/ 2;
  return sorted.length.isOdd
      ? sorted[middle]
      : (sorted[middle - 1] + sorted[middle]) / 2;
}

/// Formats microsecond durations into human-readable strings with thousand
/// separators or decimal places as appropriate.
String formatDuration(double microseconds) {
  if (microseconds >= 1000000) {
    return '${(microseconds / 1000000).toStringAsFixed(2)} s';
  } else if (microseconds >= 100) {
    return _formatWithCommas(microseconds.round());
  } else if (microseconds >= 10) {
    return microseconds.toStringAsFixed(1);
  } else {
    return microseconds.toStringAsFixed(2);
  }
}

String _formatWithCommas(int value) {
  final digits = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) {
      buffer.write(',');
    }
    buffer.write(digits[i]);
  }
  return buffer.toString();
}
