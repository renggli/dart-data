/// SymPy `integration-test-suites` Corpus Suites (`integrate` and `differentiate`).
///
/// Attribution:
/// - SymPy `integration-test-suites` repository
///   (https://github.com/sympy/integration-test-suites.git, MIT License),
///   aggregating indefinite and definite integration corpora from Albert Rich's
///   Rubi test suite, Manuel Bronstein, Waldek Hebisch, Joel Moses,
///   Tom Apostol, A. F. Timofeev, and Anthony Hearn.
library;

import 'dart:convert';
import 'dart:io';

import 'cas_test_case.dart';

const _repoUrl = 'https://github.com/sympy/integration-test-suites.git';
const _checkoutDir = '.dart_tool/integration-test-suites';

const _corpusNames = <String>[
  'blake',
  'hebisch',
  'independent',
  'mit_bee',
  'mit_bee_official',
  'rubi',
];

var _ensuredInProcess = false;

/// All integration and differentiation [CasTestSuite]s from
/// `sympy/integration-test-suites`.
///
/// Each suite declares [CasTestSuite.setUp] to automatically clone
/// `.dart_tool/integration-test-suites` if not yet present on disk (or pull
/// updates when `--update` is passed), and loads its cases lazily on demand.
final List<CasTestSuite> sympyIntegrationSuites = [
  for (final corpus in _corpusNames) ...[
    CasTestSuite(
      name: '${corpus}_integrate',
      description:
          'SymPy integration-test-suites/$corpus (integrate, MIT License)',
      setUp: _ensureIntegrationRepo,
      buildCases: () => _loadCorpusCases(corpus, differentiate: false),
    ),
    CasTestSuite(
      name: '${corpus}_differentiate',
      description:
          'SymPy integration-test-suites/$corpus (differentiate, MIT License)',
      setUp: _ensureIntegrationRepo,
      buildCases: () => _loadCorpusCases(corpus, differentiate: true),
    ),
  ],
];

void _ensureIntegrationRepo({bool forceUpdate = false}) {
  final dir = Directory(_checkoutDir);
  if (dir.existsSync()) {
    if (!forceUpdate || _ensuredInProcess) return;
    _ensuredInProcess = true;
    stdout.writeln('Updating ${dir.path} ...');
    final res = Process.runSync('git', ['-C', dir.path, 'pull', '--ff-only']);
    if (res.exitCode != 0) {
      stderr.writeln(res.stderr);
      exit(res.exitCode);
    }
  } else {
    _ensuredInProcess = true;
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

List<CasTestCase> _loadCorpusCases(
  String rawName, {
  required bool differentiate,
}) {
  _ensureIntegrationRepo();
  final dataDir = Directory('$_checkoutDir/data');
  final suiteDir = Directory('${dataDir.path}/$rawName');
  if (!suiteDir.existsSync()) return const [];

  final files =
      suiteDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.jsonl'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  final renameE = rawName == 'blake' || rawName == 'rubi';
  final renameI = rawName == 'rubi';
  final cases = <CasTestCase>[];

  for (final file in files) {
    final relPath = file.path.substring('${dataDir.path}/'.length);
    for (final line in file.readAsLinesSync()) {
      if (line.trim().isEmpty) continue;
      final obj = jsonDecode(line) as Map<String, Object?>;
      final idx = obj['index'];
      final caseName = '$relPath#$idx';
      final integrandRaw = obj['integrand']! as String;
      final variable = obj['variable']! as String;
      final expected = (obj['value'] ?? obj['integral']) as String?;
      final lower = obj['lower'] as String?;
      final upper = obj['upper'] as String?;
      final isDefinite = obj.containsKey('lower') || obj.containsKey('upper');

      final useE0 =
          renameE ||
          (rawName == 'independent' &&
              ((relPath.endsWith('hearn_problems.jsonl') &&
                      idx is int &&
                      idx >= 208 &&
                      idx <= 211) ||
                  (relPath.endsWith('moses_problems.jsonl') &&
                      const {101, 103, 105, 107, 109, 110}.contains(idx))));

      if (differentiate) {
        if (isDefinite || expected == null) continue;
        cases.add(
          differentiateCase(
            caseName,
            expected,
            variable,
            integrandRaw,
            renameE: useE0,
            renameI: renameI,
          ),
        );
      } else {
        cases.add(
          integrateCase(
            caseName,
            integrandRaw,
            variable,
            expected: expected,
            lower: lower,
            upper: upper,
            renameE: useE0,
            renameI: renameI,
          ),
        );
      }
    }
  }

  return cases;
}
