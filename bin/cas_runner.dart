/// Standalone CLI runner for the Computer Algebra System (CAS) benchmark suites.
///
/// This diagnostic benchmark tool evaluates `package:data/symbolic.dart`
/// across simplification, expansion, factoring, rational functions,
/// trigonometry, limits, series, summations, products, differentiation,
/// integration, equation solvers, ODEs, and symbolic linear algebra.
library;

import 'dart:async';
import 'dart:io';
import 'dart:isolate';

// ignore: depend_on_referenced_packages internal tool
import 'package:args/args.dart';

import 'cas_suites/algebra_suite.dart';
import 'cas_suites/cas_test_case.dart';
import 'cas_suites/gruntz_limits_suite.dart';
import 'cas_suites/series_sums_products_suite.dart';
import 'cas_suites/solvers_linear_suite.dart';
import 'cas_suites/sympy_integration_suite.dart';
import 'cas_suites/wester_suite.dart';

/// All registered CAS benchmark suites.
final List<CasTestSuite> allCasSuites = [
  westerSuite,
  gruntzLimitsSuite,
  algebraSuite,
  seriesSumsProductsSuite,
  solversLinearSuite,
  ...sympyIntegrationSuites,
];

/// Standard CLI [ArgParser] for `bin/cas_runner.dart`.
final ArgParser parser = ArgParser()
  ..addFlag(
    'help',
    abbr: 'h',
    negatable: false,
    help: 'Show this usage information and exit.',
  )
  ..addFlag(
    'update',
    abbr: 'u',
    negatable: false,
    help: 'Update or clone external benchmark repositories before running.',
  )
  ..addMultiOption(
    'suite',
    abbr: 's',
    valueHelp: 'pattern',
    help: 'Filter test suites by pattern.',
  )
  ..addMultiOption(
    'test',
    abbr: 't',
    valueHelp: 'pattern',
    help: 'Filter test cases by pattern.',
  )
  ..addFlag(
    'all',
    abbr: 'a',
    negatable: false,
    help: 'Show all tests, including passes (defaults to failures & errors).',
  )
  ..addFlag(
    'errors-only',
    abbr: 'e',
    negatable: false,
    help: 'Show only errors (hide assertion failures and passes).',
  )
  ..addFlag(
    'quiet',
    abbr: 'q',
    negatable: false,
    help: 'Suppress test output and print only summary.',
  )
  ..addFlag(
    'time',
    defaultsTo: true,
    help: 'Display elapsed duration per test.',
  )
  ..addOption(
    'max-errors',
    abbr: 'm',
    valueHelp: 'count',
    help: 'Halt execution after reaching this number of failures/errors.',
  )
  ..addOption(
    'timeout',
    defaultsTo: '500',
    valueHelp: 'ms',
    help: 'Per-case timeout in milliseconds.',
  );

enum _Verbosity { all, failures, errors, quiet }

typedef _CaseIndexRequest = ({int suiteIndex, int caseIndex});

Future<void> main(List<String> arguments) async {
  final ArgResults argResults;
  try {
    argResults = parser.parse(arguments);
  } on FormatException catch (e) {
    stderr.writeln('Error: ${e.message}\n\n${parser.usage}');
    exit(64);
  }

  if (argResults.flag('help')) {
    stdout.writeln(
      'Usage: dart run bin/cas_runner.dart [options] [patterns]\n\n'
      'Positional arguments are treated as test case filters.\n\n'
      'Available suites:\n'
      '${allCasSuites.map((s) => '  - ${s.name.padRight(32)} ${s.description}').join('\n')}\n\n'
      '${parser.usage}',
    );
    return;
  }

  final forceUpdate = argResults.flag('update');
  final suitePatterns = argResults
      .multiOption('suite')
      .map(RegExp.new)
      .toList();
  final testPatterns = [
    ...argResults.multiOption('test'),
    ...argResults.rest,
  ].map(RegExp.new).toList();

  final verbosity = switch ((
    argResults.flag('quiet'),
    argResults.flag('errors-only'),
    argResults.flag('all'),
  )) {
    (true, _, _) => _Verbosity.quiet,
    (_, true, _) => _Verbosity.errors,
    (_, _, true) => _Verbosity.all,
    _ => _Verbosity.failures,
  };

  final maxErrorsStr = argResults.option('max-errors');
  final maxErrors = maxErrorsStr != null ? int.tryParse(maxErrorsStr) : null;
  if (maxErrorsStr != null && maxErrors == null) {
    stderr.writeln('Error: --max-errors must be an integer.');
    exit(64);
  }

  final timeoutMs = int.tryParse(argResults.option('timeout')!) ?? -1;
  if (timeoutMs <= 0) {
    stderr.writeln('Error: --timeout must be a positive integer.');
    exit(64);
  }

  final showTime = argResults.flag('time');

  // Run setUp only on suites that match the active suite filter before spawning the worker.
  for (final suite in allCasSuites) {
    if (suitePatterns.isNotEmpty &&
        !suitePatterns.any((p) => p.hasMatch(suite.name))) {
      continue;
    }
    suite.setUp?.call(forceUpdate: forceUpdate);
  }

  var suiteCount = 0;
  var totalCount = 0;
  var passCount = 0;
  var failCount = 0;
  var errorCount = 0;

  final worker = await _Worker.spawn();
  try {
    outer:
    for (var sIdx = 0; sIdx < allCasSuites.length; sIdx++) {
      final suite = allCasSuites[sIdx];
      if (suitePatterns.isNotEmpty &&
          !suitePatterns.any((p) => p.hasMatch(suite.name))) {
        continue;
      }

      var matchedSuite = false;
      var printedHeader = false;
      final cases = suite.cases;

      for (var cIdx = 0; cIdx < cases.length; cIdx++) {
        final testCase = cases[cIdx];
        final fullName = '${suite.name}/${testCase.name}';
        if (testPatterns.isNotEmpty &&
            !testPatterns.any(
              (p) =>
                  p.hasMatch(fullName) ||
                  p.hasMatch(testCase.name) ||
                  p.hasMatch(testCase.description),
            )) {
          continue;
        }

        if (!matchedSuite) {
          suiteCount++;
          matchedSuite = true;
        }

        final result = await worker.run(
          (suiteIndex: sIdx, caseIndex: cIdx),
          caseLabel: '${testCase.name}: ${testCase.description}',
          timeoutMs: timeoutMs,
        );
        totalCount++;
        switch (result.status) {
          case CasStatus.pass:
            passCount++;
          case CasStatus.fail:
            failCount++;
          case CasStatus.error:
            errorCount++;
        }

        final shouldPrint = switch (verbosity) {
          _Verbosity.quiet => false,
          _Verbosity.all => true,
          _Verbosity.failures => result.status != CasStatus.pass,
          _Verbosity.errors => result.status == CasStatus.error,
        };

        if (shouldPrint) {
          if (!printedHeader) {
            stdout.writeln(suite.name);
            printedHeader = true;
          }
          final badge = switch (result.status) {
            CasStatus.pass => 'PASS',
            CasStatus.fail => 'FAIL',
            CasStatus.error => 'ERROR',
          };
          final buffer = StringBuffer('  [$badge] ${testCase.name}');
          if (showTime) {
            buffer.write(' (${_formatDuration(result.elapsedUs)})');
          }
          if (result.detail != null && result.detail!.isNotEmpty) {
            buffer.write(': ${result.detail}');
          }
          stdout.writeln(buffer.toString());
        }

        if (maxErrors != null && failCount + errorCount >= maxErrors) {
          break outer;
        }
      }
    }
  } finally {
    worker.dispose();
  }

  stdout.writeln();
  for (final (label, count, total) in [
    ('Suites', suiteCount, -1),
    ('Total', totalCount, -1),
    ('Passed', passCount, totalCount),
    ('Failed', failCount, totalCount),
    ('Errors', errorCount, totalCount),
  ]) {
    stdout.writeln(
      [
        '$label:'.padRight(10),
        count.toString().padLeft(10),
        if (total > 0)
          '${(100 * count / total).toStringAsFixed(1)}%'.padLeft(10),
      ].join(''),
    );
  }

  if (failCount + errorCount > 0) {
    exitCode = 1;
  }
}

String _formatDuration(int us) =>
    us >= 1000 ? '${(us / 1000).toStringAsFixed(1)}ms' : '${us}us';

class _Worker {
  new _(this._isolate, this._sendPort, this._responses, this._exitPort);

  Isolate _isolate;
  SendPort _sendPort;
  StreamIterator<Object?> _responses;
  ReceivePort _exitPort;

  static Future<_Worker> spawn() async {
    final receive = ReceivePort();
    final exitPort = ReceivePort();
    final isolate = await Isolate.spawn(
      (SendPort mainPort) {
        final port = ReceivePort();
        mainPort.send(port.sendPort);
        port.listen((msg) {
          final req = msg! as _CaseIndexRequest;
          mainPort.send(_evaluateCase(req));
        });
      },
      receive.sendPort,
      onExit: exitPort.sendPort,
    );
    final iter = StreamIterator<Object?>(receive);
    await iter.moveNext();
    return _Worker._(isolate, iter.current! as SendPort, iter, exitPort);
  }

  Future<CasCaseResult> run(
    _CaseIndexRequest req, {
    required String caseLabel,
    required int timeoutMs,
  }) async {
    _sendPort.send(req);
    try {
      final hasNext = await _responses.moveNext().timeout(
        Duration(milliseconds: timeoutMs),
      );
      if (hasNext) return _responses.current! as CasCaseResult;
    } on TimeoutException {
      // Respawn below after killing the timed-out isolate.
    }
    dispose();
    final fresh = await _Worker.spawn();
    _isolate = fresh._isolate;
    _sendPort = fresh._sendPort;
    _responses = fresh._responses;
    _exitPort = fresh._exitPort;
    return (
      status: CasStatus.error,
      detail: 'Timeout after ${timeoutMs}ms ($caseLabel)',
      elapsedUs: timeoutMs * 1000,
    );
  }

  void dispose() {
    _isolate.kill(priority: Isolate.immediate);
    _exitPort.close();
    _responses.cancel();
  }
}

CasCaseResult _evaluateCase(_CaseIndexRequest req) {
  final sw = Stopwatch()..start();
  final testCase = allCasSuites[req.suiteIndex].cases[req.caseIndex];
  try {
    final (:ok, :detail) = testCase.run();
    sw.stop();
    return (
      status: ok ? CasStatus.pass : CasStatus.fail,
      detail: detail,
      elapsedUs: sw.elapsedMicroseconds,
    );
  } on Object catch (error) {
    sw.stop();
    return (
      status: CasStatus.error,
      detail: '$error',
      elapsedUs: sw.elapsedMicroseconds,
    );
  }
}
