@TestOn('vm')
library;

import 'dart:io';

import 'package:more/graph.dart';
import 'package:test/test.dart';

/// Major architectural subsystems in `package:data`.
enum Subsystem {
  type('lib/type.dart', 'lib/src/type/'),
  special('lib/special.dart', 'lib/src/special/'),
  acceleration('lib/acceleration.dart', 'lib/src/acceleration/'),
  tensor('lib/tensor.dart', 'lib/src/tensor/'),
  linear('lib/linear.dart', 'lib/src/linear/'),
  polynomial('lib/polynomial.dart', 'lib/src/polynomial/'),
  numeric('lib/numeric.dart', 'lib/src/numeric/'),
  stats('lib/stats.dart', 'lib/src/stats/'),
  dataframe('lib/dataframe.dart', 'lib/src/dataframe/'),
  symbolic('lib/symbolic.dart', 'lib/src/symbolic/');

  new(this.entrypoint, this.sourceDir);

  final String entrypoint;
  final String sourceDir;

  /// Returns whether [path] belongs to this subsystem.
  bool containsPath(String path) =>
      path == entrypoint || path.startsWith(sourceDir);
}

/// Identifies the subsystem for a given relative [path] under `lib/`.
Subsystem? subsystemForPath(String path) {
  for (final s in Subsystem.values) {
    if (s.containsPath(path)) return s;
  }
  return null;
}

final _importExportRegex = RegExp(
  r"""^\s*(?:import|export)\s+['"]([^'"]+)['"]""",
  multiLine: true,
);

/// Constructs a directed [Graph] of all source file import/export dependencies.
Graph<String, void> loadCodebaseGraph() {
  final graph = Graph<String, void>(isDirected: true);
  final libDir = Directory('lib');

  for (final entity in libDir.listSync(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart')) {
      final currentFile = entity.path;
      graph.addVertex(currentFile);

      final content = entity.readAsStringSync();
      final matches = _importExportRegex.allMatches(content);

      for (final match in matches) {
        final uri = match.group(1)!;
        if (uri.startsWith('dart:')) continue;

        String? resolved;
        if (uri.startsWith('package:data/')) {
          resolved = 'lib/${uri.substring('package:data/'.length)}';
        } else if (!uri.startsWith('package:')) {
          resolved = Uri.parse(currentFile).resolve(uri).path;
        }

        if (resolved != null && resolved.startsWith('lib/')) {
          graph.addEdge(currentFile, resolved);
        }
      }
    }
  }

  return graph;
}

/// Architecture analyzer backed by `package:more/graph.dart`.
final class SubsystemArchitecture {
  new(this.graph);

  final Graph<String, void> graph;

  /// Returns all files reachable from [subsystem]'s entrypoint.
  Iterable<String> reachableFiles(Subsystem subsystem) =>
      graph.breadthFirst(subsystem.entrypoint);

  /// Returns all foreign subsystems reached from [subsystem].
  Set<Subsystem> reachedSubsystems(Subsystem subsystem) {
    final reached = <Subsystem>{};
    for (final file in reachableFiles(subsystem)) {
      final foreign = subsystemForPath(file);
      if (foreign != null && foreign != subsystem) {
        reached.add(foreign);
      }
    }
    return reached;
  }

  /// Finds the shortest import path from [subsystem] to [targetSubsystem].
  Path<String, num>? shortestPathTo(
    Subsystem subsystem,
    Subsystem targetSubsystem,
  ) {
    for (final file in reachableFiles(subsystem)) {
      if (targetSubsystem.containsPath(file)) {
        return graph.shortestPath(subsystem.entrypoint, file);
      }
    }
    return null;
  }
}

void main() {
  late final SubsystemArchitecture architecture;

  setUpAll(() {
    architecture = SubsystemArchitecture(loadCodebaseGraph());
    File('doc/dependencies.dot').writeAsString(architecture.graph.toDot());
  });

  // ---------------------------------------------------------------------------
  // Architectural Expectation Helpers
  // ---------------------------------------------------------------------------

  void expectNoDependencies(Subsystem subsystem) {
    final reached = architecture.reachedSubsystems(subsystem);
    if (reached.isNotEmpty) {
      final details = reached
          .map(
            (s) =>
                '  -> Reached ${s.name} via: ${architecture.shortestPathTo(subsystem, s)?.vertices.join(' -> ')}',
          )
          .join('\n');
      fail(
        'Architectural Violation: ${subsystem.name} must have zero dependencies, '
        'but reaches ${reached.map((s) => s.name).toList()}:\n$details',
      );
    }
  }

  void expectOnlyDependencies(
    Subsystem subsystem, {
    required Set<Subsystem> allowed,
  }) {
    final reached = architecture.reachedSubsystems(subsystem);
    final unexpected = reached.difference(allowed);
    if (unexpected.isNotEmpty) {
      final details = unexpected
          .map(
            (s) =>
                '  -> Reached ${s.name} via: ${architecture.shortestPathTo(subsystem, s)?.vertices.join(' -> ')}',
          )
          .join('\n');
      fail(
        'Architectural Violation: ${subsystem.name} depends on disallowed subsystems '
        '${unexpected.map((s) => s.name).toList()}:\n$details',
      );
    }
  }

  void expectDoesNotDependOn(
    Subsystem subsystem, {
    required Set<Subsystem> forbidden,
  }) {
    final reached = architecture.reachedSubsystems(subsystem);
    final violated = reached.intersection(forbidden);
    if (violated.isNotEmpty) {
      final details = violated
          .map(
            (s) =>
                '  -> Reached ${s.name} via: ${architecture.shortestPathTo(subsystem, s)?.vertices.join(' -> ')}',
          )
          .join('\n');
      fail(
        'Architectural Violation: ${subsystem.name} must not depend on '
        '${violated.map((s) => s.name).toList()}:\n$details',
      );
    }
  }

  group('Subsystem Architectural Decoupling & Boundary Specifications', () {
    group('Foundational Leaf Subsystems', () {
      test('type is completely self-contained', () {
        expectNoDependencies(Subsystem.type);
      });

      test('special functions is completely self-contained', () {
        expectNoDependencies(Subsystem.special);
      });
    });

    group('Hardware Acceleration Subsystem', () {
      test('acceleration depends only on type', () {
        expectOnlyDependencies(
          Subsystem.acceleration,
          allowed: {Subsystem.type},
        );
      });
    });

    group('Tensor Container Subsystem', () {
      test('tensor depends only on type and acceleration', () {
        expectOnlyDependencies(
          Subsystem.tensor,
          allowed: {Subsystem.type, Subsystem.acceleration},
        );
      });
    });

    group('Decoupling from Symbolic CAS', () {
      final nonSymbolicSubsystems = [
        Subsystem.type,
        Subsystem.special,
        Subsystem.acceleration,
        Subsystem.tensor,
        Subsystem.linear,
        Subsystem.polynomial,
        Subsystem.numeric,
        Subsystem.stats,
        Subsystem.dataframe,
      ];

      for (final subsystem in nonSymbolicSubsystems) {
        test('${subsystem.name} never transitively depends on symbolic', () {
          expectDoesNotDependOn(subsystem, forbidden: {Subsystem.symbolic});
        });
      }
    });

    group('Decoupling from DataFrame (Tabular Engine)', () {
      final nonDataFrameSubsystems = [
        Subsystem.type,
        Subsystem.special,
        Subsystem.acceleration,
        Subsystem.tensor,
        Subsystem.linear,
        Subsystem.polynomial,
        Subsystem.numeric,
        Subsystem.stats,
        Subsystem.symbolic,
      ];

      for (final subsystem in nonDataFrameSubsystems) {
        test('${subsystem.name} never transitively depends on dataframe', () {
          expectDoesNotDependOn(subsystem, forbidden: {Subsystem.dataframe});
        });
      }
    });

    group('Decoupling from Statistics', () {
      final nonStatsSubsystems = [
        Subsystem.type,
        Subsystem.special,
        Subsystem.acceleration,
        Subsystem.tensor,
        Subsystem.dataframe,
        Subsystem.symbolic,
      ];

      for (final subsystem in nonStatsSubsystems) {
        test('${subsystem.name} never transitively depends on stats', () {
          expectDoesNotDependOn(subsystem, forbidden: {Subsystem.stats});
        });
      }
    });
  });
}
