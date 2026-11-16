/// Runner of the SymPy `integration-test-suites` corpus.
///
/// This test-suite is not meant to replace unit-tests. It is purely used to
/// identify gaps and discrepancies of `package:data/symbolic.dart`.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;

// ignore: depend_on_referenced_packages internal tool
import 'package:args/args.dart';
import 'package:data/symbolic.dart';
import 'package:more/number.dart' show Complex;

const _repoUrl = 'https://github.com/sympy/integration-test-suites.git';
const _checkoutDir = '.dart_tool/integration-test-suites';

final parser = ArgParser()
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
    help: 'Update or clone the integration-test-suites repository.',
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
  )
  ..addOption(
    'mode',
    allowed: ['integrate', 'differentiate'],
    defaultsTo: 'integrate',
    help: 'Verification mode: integrate or differentiate.',
  );

enum _Verbosity { all, failures, errors, quiet }

enum _Status { pass, fail, error }

typedef _CaseRequest = ({
  String mode,
  bool isDefinite,
  bool renameE,
  bool renameI,
  String variable,
  String integrand,
  String? expected,
  String? lower,
  String? upper,
});

typedef _CaseResult = ({_Status status, String? detail, int elapsedUs});

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
      'Usage: dart run bin/sympy_integration_tests.dart [options] [patterns]\n\n'
      'Positional arguments are treated as test case filters.\n\n'
      '${parser.usage}',
    );
    return;
  }

  final repoDir = Directory(_checkoutDir);
  if (!repoDir.existsSync() || argResults.flag('update')) {
    _cloneOrUpdate(repoDir);
  }

  final dataDir = Directory('${repoDir.path}/data');
  if (!dataDir.existsSync()) {
    stderr.writeln('Error: Data directory not found at ${dataDir.path}');
    stderr.writeln('Run with --update to clone the test suite.');
    exit(1);
  }

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
  final mode = argResults.option('mode')!;

  final suites = dataDir.listSync().whereType<Directory>().where((dir) {
    if (suitePatterns.isEmpty) return true;
    final name = _basename(dir.path);
    return suitePatterns.any((p) => p.hasMatch(name));
  }).toList()..sort((a, b) => a.path.compareTo(b.path));

  var suiteCount = 0;
  var totalCount = 0;
  var passCount = 0;
  var failCount = 0;
  var errorCount = 0;

  final worker = await _Worker.spawn();
  try {
    outer:
    for (final suiteDir in suites) {
      final suiteName = _basename(suiteDir.path);
      final files =
          suiteDir
              .listSync(recursive: true)
              .whereType<File>()
              .where((f) => f.path.endsWith('.jsonl'))
              .toList()
            ..sort((a, b) => a.path.compareTo(b.path));

      suiteCount++;
      var printedHeader = false;
      final renameE = suiteName == 'blake' || suiteName == 'rubi';
      final renameI = suiteName == 'rubi';

      for (final file in files) {
        final relPath = file.path.substring('${dataDir.path}/'.length);
        for (final line in file.readAsLinesSync()) {
          if (line.trim().isEmpty) continue;
          final obj = jsonDecode(line) as Map<String, Object?>;
          final idx = obj['index'];
          final caseName = '$relPath#$idx';
          final integrandRaw = obj['integrand']! as String;

          if (testPatterns.isNotEmpty &&
              !testPatterns.any(
                (p) => p.hasMatch(caseName) || p.hasMatch(integrandRaw),
              )) {
            continue;
          }

          final useE0 =
              renameE ||
              (suiteName == 'independent' &&
                  ((relPath.endsWith('hearn_problems.jsonl') &&
                          idx is int &&
                          idx >= 208 &&
                          idx <= 211) ||
                      (relPath.endsWith('moses_problems.jsonl') &&
                          const {101, 103, 105, 107, 109, 110}.contains(idx))));

          final req = (
            mode: mode,
            isDefinite: obj.containsKey('lower') || obj.containsKey('upper'),
            renameE: useE0,
            renameI: renameI,
            variable: obj['variable']! as String,
            integrand: integrandRaw,
            expected: (obj['value'] ?? obj['integral']) as String?,
            lower: obj['lower'] as String?,
            upper: obj['upper'] as String?,
          );

          final result = await worker.run(req, timeoutMs: timeoutMs);
          totalCount++;
          switch (result.status) {
            case _Status.pass:
              passCount++;
            case _Status.fail:
              failCount++;
            case _Status.error:
              errorCount++;
          }

          final shouldPrint = switch (verbosity) {
            _Verbosity.quiet => false,
            _Verbosity.all => true,
            _Verbosity.failures => result.status != _Status.pass,
            _Verbosity.errors => result.status == _Status.error,
          };

          if (shouldPrint) {
            if (!printedHeader) {
              stdout.writeln(suiteName);
              printedHeader = true;
            }
            final badge = switch (result.status) {
              _Status.pass => 'PASS',
              _Status.fail => 'FAIL',
              _Status.error => 'ERROR',
            };
            final buffer = StringBuffer('  [$badge] $caseName');
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

void _cloneOrUpdate(Directory dir) {
  if (dir.existsSync()) {
    stdout.writeln('Updating ${dir.path} ...');
    final res = Process.runSync('git', ['-C', dir.path, 'pull', '--ff-only']);
    if (res.exitCode != 0) {
      stderr.writeln(res.stderr);
      exit(res.exitCode);
    }
  } else {
    stdout.writeln('Cloning $_repoUrl into ${dir.path} ...');
    dir.parent.createSync(recursive: true);
    final res = Process.runSync('git', [
      'clone',
      '--depth',
      '1',
      _repoUrl,
      dir.path,
    ]);
    if (res.exitCode != 0) {
      stderr.writeln(res.stderr);
      exit(res.exitCode);
    }
  }
}

String _basename(String path) =>
    path.split('/').where((s) => s.isNotEmpty).last;

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
        port.listen(
          (msg) => mainPort.send(_evaluateCase(msg! as _CaseRequest)),
        );
      },
      receive.sendPort,
      onExit: exitPort.sendPort,
    );
    final iter = StreamIterator<Object?>(receive);
    await iter.moveNext();
    return _Worker._(isolate, iter.current! as SendPort, iter, exitPort);
  }

  Future<_CaseResult> run(_CaseRequest req, {required int timeoutMs}) async {
    _sendPort.send(req);
    try {
      final hasNext = await _responses.moveNext().timeout(
        Duration(milliseconds: timeoutMs),
      );
      if (hasNext) return _responses.current! as _CaseResult;
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
      status: _Status.error,
      detail: 'Timeout after ${timeoutMs}ms (${req.integrand})',
      elapsedUs: timeoutMs * 1000,
    );
  }

  void dispose() {
    _isolate.kill(priority: Isolate.immediate);
    _exitPort.close();
    _responses.cancel();
  }
}

final _sympySyntaxDefault = _buildSympySyntax();
final _sympySyntaxRenameE = _buildSympySyntax(renameE: true);
final _sympySyntaxRenameEI = _buildSympySyntax(renameE: true, renameI: true);

ExprSyntax _buildSympySyntax({bool renameE = false, bool renameI = false}) =>
    ExprSyntax(
      constants: {
        'E': Constant.e,
        'I': ComplexNumber.i,
        'oo': Constant.infinity,
        if (renameE) 'e': const Variable('e'),
        if (renameI) 'i': const Variable('i'),
      },
      unaryFunctions: {'Abs': Abs.new, 'ceiling': Ceil.new},
      binaryFunctions: {
        'Max': (a, b) => VariableFunction('Max', [a, b]),
        'Min': (a, b) => VariableFunction('Min', [a, b]),
        'Mod': Mod.new,
        'Rational': (a, b) => a / b,
      },
      variadicFunctions: {
        'Derivative': ExprSyntax.standardVariadicFunctions['diff']!,
      },
    );

_CaseResult _evaluateCase(_CaseRequest req) {
  final sw = Stopwatch()..start();
  final syntax = switch ((req.renameE, req.renameI)) {
    (_, true) => _sympySyntaxRenameEI,
    (true, false) => _sympySyntaxRenameE,
    _ => _sympySyntaxDefault,
  };

  Expr? parseOpt(String? raw) =>
      raw == null ? null : syntax.parse(_rewriteSpecialForms(raw));

  late final Expr integrand;
  late final Expr? expected, lower, upper;
  try {
    integrand = parseOpt(req.integrand)!;
    expected = parseOpt(req.expected);
    lower = parseOpt(req.lower);
    upper = parseOpt(req.upper);
  } on Object catch (error) {
    sw.stop();
    return (
      status: _Status.error,
      detail: 'Parse error: $error',
      elapsedUs: sw.elapsedMicroseconds,
    );
  }

  final unknownFn =
      _findUnknownFunction(integrand) ??
      _findUnknownFunction(expected) ??
      _findUnknownFunction(lower) ??
      _findUnknownFunction(upper);
  if (unknownFn != null) {
    sw.stop();
    return (
      status: _Status.error,
      detail: 'Unknown function: $unknownFn',
      elapsedUs: sw.elapsedMicroseconds,
    );
  }

  if (req.mode == 'differentiate') {
    if (req.isDefinite || expected == null) {
      sw.stop();
      return (
        status: _Status.pass,
        detail: null,
        elapsedUs: sw.elapsedMicroseconds,
      );
    }
    try {
      final ok = _verifyDerivative(integrand, expected, req.variable);
      sw.stop();
      return (
        status: ok ? _Status.pass : _Status.fail,
        detail: ok ? null : 'd/d${req.variable}($expected) != $integrand',
        elapsedUs: sw.elapsedMicroseconds,
      );
    } on Object catch (error) {
      sw.stop();
      return (
        status: _Status.error,
        detail: '$error',
        elapsedUs: sw.elapsedMicroseconds,
      );
    }
  }

  if (req.isDefinite && (lower == null || upper == null)) {
    sw.stop();
    return (
      status: _Status.fail,
      detail: 'Missing definite bounds',
      elapsedUs: sw.elapsedMicroseconds,
    );
  }

  late final Expr actual;
  try {
    actual = req.isDefinite
        ? integrand.integrate(req.variable, from: lower, to: upper)
        : integrand.integrate(req.variable);
  } on Object catch (error) {
    sw.stop();
    return (
      status: _Status.error,
      detail: '$error',
      elapsedUs: sw.elapsedMicroseconds,
    );
  }

  sw.stop();
  final ok = req.isDefinite
      ? (expected != null && _verifyEqual(actual, expected))
      : ((expected != null && actual == expected) ||
            (_isSolved(actual) &&
                _verifyDerivative(integrand, actual, req.variable)));

  return (
    status: ok ? _Status.pass : _Status.fail,
    detail: ok
        ? null
        : 'int($integrand, ${req.variable}) = $actual (expected: $expected)',
    elapsedUs: sw.elapsedMicroseconds,
  );
}

bool _isSolved(Expr expr) {
  if (expr is Integral) return false;
  var solved = true;
  expr.mapChildren((child) {
    if (solved && !_isSolved(child)) solved = false;
    return child;
  });
  return solved;
}

String? _findUnknownFunction(Expr? expr) {
  if (expr == null) return null;
  if (expr is VariableFunction) return expr.name;
  String? found;
  expr.mapChildren((child) {
    found ??= _findUnknownFunction(child);
    return child;
  });
  return found;
}

bool _verifyDerivative(Expr integrand, Expr antideriv, String variable) {
  try {
    final diff = (antideriv.derivative(variable) - integrand).simplify();
    if (diff is Number && diff.isZero) return true;
  } on Object {
    // Fall back to numerical derivative check.
  }
  final Expr deriv;
  try {
    deriv = antideriv.derivative(variable);
  } on Object {
    return false;
  }
  final freeVars = <String>{...integrand.freeVariables, ...deriv.freeVariables}
    ..remove(variable);
  try {
    final env = <String, double>{};
    var seed = 1.37;
    for (final v in freeVars) {
      env[v] = seed;
      seed += 0.41;
    }
    var checked = 0;
    for (final pt in const [0.37, 0.73, 1.19, 1.63, 2.11]) {
      env[variable] = pt;
      final lhs = deriv.evaluate(env);
      final rhs = integrand.evaluate(env);
      if (!lhs.isFinite || !rhs.isFinite) continue;
      if ((lhs - rhs).abs() > 1e-6 * math.max(1.0, rhs.abs())) return false;
      checked++;
    }
    if (checked > 0) return true;
  } on Object {
    // Fall back to complex evaluation when real evaluation fails.
  }
  try {
    final complexEnv = <String, Complex>{};
    var seed = const Complex(0.63, 0.19);
    for (final v in freeVars) {
      complexEnv[v] = seed;
      seed += const Complex(0.31, -0.07);
    }
    var checked = 0;
    for (final pt in const [
      Complex(0.37, 0.29),
      Complex(1.19, -0.41),
      Complex(-0.73, 0.53),
      Complex(2.63, 0.17),
      Complex(5.41, -0.31),
    ]) {
      complexEnv[variable] = pt;
      final lhs = deriv.evaluateComplex(complexEnv);
      final rhs = integrand.evaluateComplex(complexEnv);
      if (!lhs.a.isFinite ||
          !lhs.b.isFinite ||
          !rhs.a.isFinite ||
          !rhs.b.isFinite) {
        continue;
      }
      if ((lhs - rhs).abs() > 1e-6 * math.max(1.0, rhs.abs())) return false;
      checked++;
    }
    return checked > 0;
  } on Object {
    return false;
  }
}

bool _verifyEqual(Expr actual, Expr expected) {
  if (actual == expected) return true;
  try {
    final diff = (actual - expected).simplify();
    if (diff is Number && diff.isZero) return true;
  } on Object {
    // Ignore simplification failures.
  }
  try {
    final a = actual.evaluate({});
    final b = expected.evaluate({});
    if (a.isFinite && b.isFinite) {
      return (a - b).abs() <= 1e-6 * math.max(1.0, b.abs());
    }
  } on Object {
    // Fall back to complex evaluation.
  }
  try {
    final a = actual.evaluateComplex({});
    final b = expected.evaluateComplex({});
    if (a.a.isFinite && a.b.isFinite && b.a.isFinite && b.b.isFinite) {
      return (a - b).abs() <= 1e-6 * math.max(1.0, b.abs());
    }
  } on Object {
    // Ignore evaluation failures.
  }
  return false;
}

String _rewriteSpecialForms(String s) {
  if (s.contains('Matrix(')) {
    s = s.replaceAllMapped(
      RegExp(r'Matrix\(\[(.*?)\]\)\.det\(\)'),
      (m) =>
          'det(${m[1]!.replaceAllMapped(RegExp(r'\[([^\[\]]+)\]'), (r) => 'row(${r[1]})')})',
    );
  }
  for (final pair in const [
    ('Sum', 'sum'),
    ('Product', 'product'),
    ('Integral', 'integrate'),
  ]) {
    if (s.contains('${pair.$1}(')) s = _rewriteTupleBounds(s, pair.$1, pair.$2);
  }
  if (s.contains('hyper(')) s = _rewriteHyper(s);
  return s;
}

int _matchingParen(String s, int openIdx) {
  var depth = 0;
  for (var i = openIdx; i < s.length; i++) {
    if (s[i] == '(') depth++;
    if (s[i] == ')' && --depth == 0) return i;
  }
  return s.length - 1;
}

List<String> _splitArgs(String inner) {
  final args = <String>[];
  var depth = 0;
  var start = 0;
  for (var i = 0; i < inner.length; i++) {
    final ch = inner[i];
    if (ch == '(' || ch == '[') depth++;
    if (ch == ')' || ch == ']') depth--;
    if (ch == ',' && depth == 0) {
      args.add(inner.substring(start, i).trim());
      start = i + 1;
    }
  }
  return [...args, inner.substring(start).trim()];
}

String _rewriteTupleBounds(String s, String symName, String targetName) {
  final token = '$symName(';
  final buf = StringBuffer();
  var idx = 0;
  while (true) {
    final pos = s.indexOf(token, idx);
    if (pos == -1) {
      buf.write(s.substring(idx));
      return buf.toString();
    }
    if (pos > 0 && RegExp(r'[A-Za-z0-9_]').hasMatch(s[pos - 1])) {
      buf.write(s.substring(idx, pos + token.length));
      idx = pos + token.length;
      continue;
    }
    buf.write(s.substring(idx, pos));
    final closeIdx = _matchingParen(s, pos + symName.length);
    final inner = _rewriteTupleBounds(
      s.substring(pos + token.length, closeIdx),
      symName,
      targetName,
    );
    final args = _splitArgs(inner);
    if (args.length == 2 && args[1].startsWith('(') && args[1].endsWith(')')) {
      final bounds = _splitArgs(args[1].substring(1, args[1].length - 1));
      buf.write('$targetName(${args[0]}, ${bounds.join(', ')})');
    } else {
      buf.write('$targetName($inner)');
    }
    idx = closeIdx + 1;
  }
}

String _rewriteHyper(String s) {
  final buf = StringBuffer();
  var idx = 0;
  while (true) {
    final pos = s.indexOf('hyper(', idx);
    if (pos == -1) {
      buf.write(s.substring(idx));
      return buf.toString();
    }
    buf.write(s.substring(idx, pos + 6));
    var cur = pos + 6;
    for (var arg = 0; arg < 2; arg++) {
      while (cur < s.length && s[cur] == ' ') {
        buf.write(' ');
        cur++;
      }
      if (cur < s.length && s[cur] == '(') {
        final closeIdx = _matchingParen(s, cur);
        var inner = s.substring(cur + 1, closeIdx).trimRight();
        if (inner.endsWith(',')) {
          inner = inner.substring(0, inner.length - 1).trimRight();
        }
        buf.write('tuple($inner)');
        cur = closeIdx + 1;
        while (cur < s.length && (s[cur] == ',' || s[cur] == ' ')) {
          buf.write(s[cur++]);
        }
      }
    }
    idx = cur;
  }
}
