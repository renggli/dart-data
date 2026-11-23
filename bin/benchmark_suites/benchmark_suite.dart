/// Shared benchmark suite definitions, statistical measurement, and formatting
/// utilities for `bin/benchmark_runner.dart`.
library;

import 'dart:io';
import 'dart:math' as math;

import 'package:data/acceleration.dart';
import 'package:data/stats.dart';
import 'package:more/printer.dart';

/// Printer formatting microsecond durations with adaptive precision and
/// thousand separators.
final Printer<num> durationUsPrinter = Printer<num>.switcher({
  (us) => us >= 100: FixedNumberPrinter<num>(separator: ','),
  (us) => us >= 10: FixedNumberPrinter<num>(precision: 1),
}, otherwise: FixedNumberPrinter<num>(precision: 2));

/// Printer formatting speedup ratios with one decimal place.
final Printer<num> speedupPrinter = FixedNumberPrinter<num>(precision: 1);

/// Sink to prevent the compiler from eliminating benchmark bodies.
Object? blackHole;

/// The result of measuring a single benchmark workload.
final class BenchmarkResult with ToStringPrinter {
  /// Creates a benchmark result backed by a non-parametric [bootstrap] of the
  /// sample median.
  const new({required this.name, required this.bootstrap});

  /// The name of the benchmark.
  final String name;

  /// The bootstrap resampling distribution of the median duration (µs).
  final Bootstrap<double> bootstrap;

  /// The number of measured runs.
  int get runs => bootstrap.samples.length;

  /// The sorted per-run durations in microseconds.
  List<double> get samples => bootstrap.samples;

  /// The median duration in microseconds.
  double get median => bootstrap.estimate;

  /// The minimum duration in microseconds.
  double get min => samples.first;

  /// The maximum duration in microseconds.
  double get max => samples.last;

  /// Empirical 95% bootstrap percentile confidence interval `(lower, upper)`.
  ({double lower, double upper}) get confidenceInterval =>
      bootstrap.percentileInterval;

  /// Empirical standard error of the median estimate.
  double get standardError => bootstrap.standardError;

  /// Formatted median duration in microseconds.
  String get formattedMedian => durationUsPrinter(median);

  /// Formatted `min–max` range in microseconds.
  String get formattedRange =>
      '${durationUsPrinter(min)}–${durationUsPrinter(max)}';

  /// Formatted 95% confidence interval `[lower, upper]` in microseconds.
  String get formattedConfidenceInterval =>
      '[${durationUsPrinter(confidenceInterval.lower)}, '
      '${durationUsPrinter(confidenceInterval.upper)}]';

  @override
  ObjectPrinter get toStringPrinter => super.toStringPrinter
    ..addValue(name, name: 'name')
    ..addValue(formattedMedian, name: 'medianUs')
    ..addValue(formattedConfidenceInterval, name: 'ci95Us')
    ..addValue(formattedRange, name: 'rangeUs')
    ..addValue(runs, name: 'runs');
}

/// A comparison between pure Dart execution and native hardware acceleration.
final class ModeComparison {
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
final class BenchmarkSpec {
  /// Creates a benchmark specification.
  const new({
    required this.name,
    this.category = '',
    required this.action,
    this.runs = 15,
    this.warmup = 3,
    this.inner = 1,
    this.isNativeSupported,
  }) : assert(runs >= 2, 'At least 2 runs are required for bootstrap CI');

  /// Unique name of the benchmark workload.
  final String name;

  /// High-level mathematical category or subsystem group.
  final String category;

  /// The closure to measure.
  final Object? Function() action;

  /// Number of timed sample runs (must be at least 2).
  final int runs;

  /// Number of untimed warmup iterations.
  final int warmup;

  /// Repetitions executed per sample run to reduce timer quantization noise.
  final int inner;

  /// Optional availability check for native acceleration.
  final bool Function()? isNativeSupported;
}

/// Suite of benchmark specifications with command-line execution and reporting.
final class BenchmarkSuite {
  /// Creates a benchmark suite.
  new({
    required this.name,
    required this.title,
    this.description = '',
    this.compareModes = false,
    required this.buildSpecs,
  });

  /// Short identifier used for `--suite` filtering (e.g. `numeric`, `symbolic`).
  final String name;

  /// Human-readable title of the benchmark suite.
  final String title;

  /// Optional subtitle or platform notes.
  final String description;

  /// Whether this suite compares pure Dart vs native acceleration by default.
  final bool compareModes;

  /// Callback building the ordered benchmark specifications in this suite.
  final List<BenchmarkSpec> Function() buildSpecs;

  /// Ordered benchmark workloads in this suite, built on first access.
  late final List<BenchmarkSpec> specs = buildSpecs();

  /// Executes [filtered] workloads from this suite.
  void run(
    List<BenchmarkSpec> filtered, {
    required bool compare,
    required bool quiet,
  }) {
    if (!quiet) {
      _printHeader(compare);
    }
    if (compare) {
      _runComparison(filtered, quiet: quiet);
    } else {
      _runStandard(filtered, quiet: quiet);
    }
  }

  void _printHeader(bool compare) {
    stdout.writeln('=' * 72);
    stdout.writeln('$title ($name)');
    if (description.isNotEmpty) {
      stdout.writeln(description);
    }
    stdout.writeln('=' * 72);
    if (compare) {
      stdout.writeln('Platform hardware acceleration status:');
      stdout.writeln('  BLAS available:    ${Blas.isAvailable}');
      stdout.writeln(
        '  vDSP available:    ${Fft.isAvailable || Vforce.isAvailable}',
      );
      stdout.writeln('  FFT available:     ${Fft.isAvailable}');
      stdout.writeln('  vForce available:  ${Vforce.isAvailable}');
      stdout.writeln('-' * 72);
    }
    stdout.writeln();
  }

  void _runStandard(List<BenchmarkSpec> filtered, {required bool quiet}) {
    final results = <({BenchmarkSpec spec, BenchmarkResult result})>[];
    var currentCategory = '';

    for (final spec in filtered) {
      if (!quiet &&
          spec.category.isNotEmpty &&
          spec.category != currentCategory) {
        currentCategory = spec.category;
        stdout.writeln('\n### $currentCategory\n');
      }

      final result = measure(
        spec.name,
        spec.action,
        warmup: spec.warmup,
        runs: spec.runs,
        inner: spec.inner,
      );
      results.add((spec: spec, result: result));

      if (!quiet) {
        final med = '${result.formattedMedian} us'.padLeft(11);
        final ci = result.formattedConfidenceInterval.padLeft(18);
        final range = '${result.formattedRange} us'.padLeft(18);
        stdout.writeln(
          '${spec.name.padRight(36)} '
          'median $med  '
          '95% CI $ci  '
          'min–max $range',
        );
      }
    }

    stdout.writeln('\n## $title Summary\n');
    final hasCategories = results.any((pair) => pair.spec.category.isNotEmpty);
    if (hasCategories) {
      stdout.writeln(
        '| Benchmark | Category | Median (µs) | 95% CI (µs) | Min–Max (µs) |',
      );
      stdout.writeln('| --- | --- | ---: | ---: | ---: |');
      for (final (:spec, :result) in results) {
        stdout.writeln(
          '| `${spec.name}` | ${spec.category} | ${result.formattedMedian} | '
          '${result.formattedConfidenceInterval} | ${result.formattedRange} |',
        );
      }
    } else {
      stdout.writeln(
        '| Benchmark | Median (µs) | 95% CI (µs) | Min–Max (µs) |',
      );
      stdout.writeln('| --- | ---: | ---: | ---: |');
      for (final (:spec, :result) in results) {
        stdout.writeln(
          '| `${spec.name}` | ${result.formattedMedian} | '
          '${result.formattedConfidenceInterval} | ${result.formattedRange} |',
        );
      }
    }
  }

  void _runComparison(List<BenchmarkSpec> filtered, {required bool quiet}) {
    final comparisons = <({BenchmarkSpec spec, ModeComparison comparison})>[];
    var currentCategory = '';

    for (final spec in filtered) {
      if (!quiet &&
          spec.category.isNotEmpty &&
          spec.category != currentCategory) {
        currentCategory = spec.category;
        stdout.writeln('\n### $currentCategory\n');
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
        } on Object catch (error) {
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
      comparisons.add((spec: spec, comparison: comparison));

      if (!quiet) {
        final speedupStr = comparison.speedup != null
            ? '${speedupPrinter(comparison.speedup!)}x'.padLeft(7)
            : (comparison.note ?? 'N/A').padLeft(7);
        final dartMed = '${comparison.dartResult.formattedMedian} us'.padLeft(
          11,
        );
        final nativeMed = comparison.nativeResult != null
            ? '${comparison.nativeResult!.formattedMedian} us'.padLeft(11)
            : '-'.padLeft(11);

        stdout.writeln(
          '${spec.name.padRight(36)} '
          'Dart: $dartMed  '
          'Native: $nativeMed  '
          'Speedup: $speedupStr',
        );
      }
    }

    // Restore default mode
    AccelerationManager.mode = AccelerationMode.auto;

    stdout.writeln('\n## $title Summary\n');
    stdout.writeln(
      '| Benchmark | Category | Pure Dart (µs) | Dart 95% CI | Native (µs) | Native 95% CI | Speedup |',
    );
    stdout.writeln('| --- | --- | ---: | ---: | ---: | ---: | ---: |');
    for (final (:spec, comparison: c) in comparisons) {
      final dartMed = c.dartResult.formattedMedian;
      final dartCi = c.dartResult.formattedConfidenceInterval;
      final nativeMed = c.nativeResult != null
          ? c.nativeResult!.formattedMedian
          : (c.note ?? 'N/A');
      final nativeCi = c.nativeResult != null
          ? c.nativeResult!.formattedConfidenceInterval
          : '—';
      final speedupStr = c.speedup != null
          ? '**${speedupPrinter(c.speedup!)}×**'
          : '—';
      stdout.writeln(
        '| `${c.name}` | ${spec.category} | $dartMed | $dartCi | $nativeMed | $nativeCi | $speedupStr |',
      );
    }
  }
}

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

  return BenchmarkResult(
    name: name,
    bootstrap: Bootstrap<double>(
      samples,
      median,
      resamples: 1000,
      random: math.Random(42),
    ),
  );
}
