/// Standalone CLI runner for the performance benchmark suites.
///
/// Evaluates `package:data` performance across numeric routines, linear algebra,
/// hardware acceleration (BLAS, LAPACK, vDSP FFT, vForce), and symbolic
/// computer algebra workloads, reporting median execution times and empirical
/// 95% bootstrap confidence intervals.
library;

import 'dart:io';

import 'package:args/args.dart';

import 'benchmark_suites/benchmark_suite.dart';
import 'benchmark_suites/numeric_suite.dart';
import 'benchmark_suites/symbolic_suite.dart';

/// All registered performance benchmark suites.
final List<BenchmarkSuite> allBenchmarkSuites = [numericSuite, symbolicSuite];

/// Standard CLI [ArgParser] for `bin/benchmark_runner.dart`.
final ArgParser parser = ArgParser()
  ..addFlag(
    'help',
    abbr: 'h',
    negatable: false,
    help: 'Show this usage information and exit.',
  )
  ..addMultiOption(
    'suite',
    abbr: 's',
    valueHelp: 'pattern',
    help: 'Filter benchmark suites by pattern.',
  )
  ..addMultiOption(
    'test',
    abbr: 't',
    valueHelp: 'pattern',
    help: 'Filter benchmark workloads by pattern.',
  )
  ..addFlag(
    'compare',
    abbr: 'c',
    defaultsTo: null,
    help:
        'Compare pure Dart against native hardware acceleration '
        '(defaults to each suite\'s default mode).',
  )
  ..addFlag(
    'quiet',
    abbr: 'q',
    negatable: false,
    help: 'Suppress live progress output and print only summary tables.',
  );

void main(List<String> arguments) {
  final ArgResults argResults;
  try {
    argResults = parser.parse(arguments);
  } on FormatException catch (e) {
    stderr.writeln('Error: ${e.message}\n\n${parser.usage}');
    exit(64);
  }

  if (argResults.flag('help')) {
    stdout.writeln(
      'Usage: dart run bin/benchmark_runner.dart [options] [patterns]\n\n'
      'Positional arguments are treated as benchmark workload filters.\n\n'
      'Available suites:\n'
      '${allBenchmarkSuites.map((s) => '  - ${s.name.padRight(16)} ${s.description}').join('\n')}\n\n'
      '${parser.usage}',
    );
    return;
  }

  final suitePatterns = argResults
      .multiOption('suite')
      .map((p) => RegExp(p, caseSensitive: false))
      .toList();
  final testPatterns = [
    ...argResults.multiOption('test'),
    ...argResults.rest,
  ].map((p) => RegExp(p, caseSensitive: false)).toList();

  final compareOverride = argResults.wasParsed('compare')
      ? argResults.flag('compare')
      : null;
  final quiet = argResults.flag('quiet');

  var matchedAny = false;
  for (final suite in allBenchmarkSuites) {
    if (suitePatterns.isNotEmpty &&
        !suitePatterns.any(
          (p) => p.hasMatch(suite.name) || p.hasMatch(suite.title),
        )) {
      continue;
    }

    final filtered = testPatterns.isEmpty
        ? suite.specs
        : suite.specs
              .where(
                (spec) => testPatterns.any(
                  (p) =>
                      p.hasMatch('${suite.name}/${spec.name}') ||
                      p.hasMatch(spec.name) ||
                      p.hasMatch(spec.category),
                ),
              )
              .toList();
    if (filtered.isEmpty) continue;

    if (matchedAny) stdout.writeln();
    matchedAny = true;
    suite.run(
      filtered,
      compare: compareOverride ?? suite.compareModes,
      quiet: quiet,
    );
  }

  if (!matchedAny) {
    stderr.writeln('No benchmarks matched the specified filters.');
    exitCode = 1;
  }
}
