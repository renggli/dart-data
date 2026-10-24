@TestOn('vm')
library;

import 'dart:io';

import 'package:checks/checks.dart';
import 'package:more/collection.dart';
import 'package:more/graph.dart';
import 'package:test/scaffolding.dart';

/// Major architectural subsystems in `package:data`.
enum Subsystem {
  type('#e8f4f8'),
  special('#fef3e2'),
  acceleration('#eafaf1'),
  tensor('#f4ecf7'),
  linear('#fdedec'),
  polynomial('#fcf3cf'),
  numeric('#e8f8f5'),
  stats('#ebf5fb'),
  dataframe('#f5eef8'),
  symbolic('#fbeee6');

  new(this.color);

  final String color;

  String get entrypoint => 'lib/$name.dart';
  String get sourceDir => 'lib/src/$name/';

  static Subsystem? byNameOrNull(String? name) {
    for (final s in values) {
      if (s.name == name) return s;
    }
    return null;
  }

  bool containsPath(String path) =>
      path == entrypoint || path.startsWith(sourceDir);
}

void main() {
  late final filesGraph = createFilesGraph();
  late final libsGraph = createLibsGraph(filesGraph);

  setUpAll(() {
    final filesDot = filesGraph.toDot(
      graphAttributes: const {'rankdir': 'LR', 'concentrate': 'true'},
      subgraph: subLibraryOf,
      subgraphName: (subgraph) => 'cluster_$subgraph',
      subgraphLabel: (subgraph) => subgraph,
      subgraphAttributes: (subgraph) => {
        'style': 'rounded,filled',
        'fillcolor': Subsystem.byNameOrNull(subgraph)?.color ?? '#f8f9fa',
      },
      vertexLabel: vertexLabel,
      vertexAttributes: (vertex) => {
        'shape': 'box',
        'style': 'rounded,filled',
        'fillcolor': '#ffffff',
      },
      edgeAttributes: (edge) => const {'color': '#888888', 'arrowsize': '0.7'},
    );
    final filesDotFile = File('doc/files_deps.dot');
    filesDotFile.parent.createSync(recursive: true);
    filesDotFile.writeAsStringSync(filesDot);

    final libsDot = libsGraph.toDot(
      graphAttributes: const {'rankdir': 'LR'},
      vertexAttributes: (vertex) => {
        'shape': 'box',
        'style': 'rounded,filled',
        'fillcolor': Subsystem.byNameOrNull(vertex)?.color ?? '#f0f4f8',
      },
      edgeAttributes: (edge) => const {'arrowsize': '0.8'},
    );
    final libsDotFile = File('doc/libs_deps.dot');
    libsDotFile.parent.createSync(recursive: true);
    libsDotFile.writeAsStringSync(libsDot);
  });

  group('umbrella', () {
    test('no incoming dependencies', () {
      check(filesGraph.predecessorsOf('lib/data.dart')).isEmpty();
    });

    test('exports all public sub-libraries', () {
      check(filesGraph.successorsOf('lib/data.dart'))
          .unorderedEquals(Subsystem.values.map((s) => s.entrypoint).toList());
    });
  });

  group('dependencies', () {
    test('no top-level imports', () {
      final badEdges = filesGraph.edges
          .where(
            (edge) =>
                edge.source != 'lib/data.dart' &&
                !edge.target.startsWith('lib/src/'),
          )
          .map((edge) => '${edge.source} -> ${edge.target}')
          .toList();
      check(badEdges).isEmpty();
    });

    test('no cycles between sub-libraries', () {
      check(
        libsGraph.stronglyConnected().where(
          (scc) =>
              scc.length > 1 || libsGraph.getEdge(scc.first, scc.first) != null,
        ),
      ).isEmpty();
    });
  });

  group('reachability', () {
    test('no orphan files', () {
      check(
        filesGraph.vertices
            .where((file) => file.startsWith('lib/src/'))
            .where((file) => filesGraph.predecessorsOf(file).isEmpty),
      ).isEmpty();
    });

    test('all files reachable from root', () {
      final roots = filesGraph.vertices.where(
        (file) => !file.startsWith('lib/src/'),
      );
      final reachable = <String>{...roots.expand(filesGraph.depthFirst)};
      check(filesGraph.vertices.where((file) => !reachable.contains(file)))
          .isEmpty();
    });
  });

  group('architectural decoupling', () {
    Set<Subsystem> reachedSubsystems(Subsystem subsystem) {
      final reachable = filesGraph.breadthFirst(subsystem.entrypoint);
      final reached = <Subsystem>{};
      for (final file in reachable) {
        for (final other in Subsystem.values) {
          if (other != subsystem && other.containsPath(file)) {
            reached.add(other);
          }
        }
      }
      return reached;
    }

    test('type is completely self-contained', () {
      check(reachedSubsystems(Subsystem.type)).isEmpty();
    });

    test('special is completely self-contained', () {
      check(reachedSubsystems(Subsystem.special)).isEmpty();
    });

    test('acceleration depends only on type', () {
      check(reachedSubsystems(Subsystem.acceleration))
          .unorderedEquals([Subsystem.type]);
    });

    test('tensor depends only on type and acceleration', () {
      check(reachedSubsystems(Subsystem.tensor))
          .unorderedEquals([Subsystem.type, Subsystem.acceleration]);
    });

    group('decoupling from symbolic CAS', () {
      final nonSymbolic = Subsystem.values.where(
        (s) => s != Subsystem.symbolic,
      );
      for (final s in nonSymbolic) {
        test('${s.name} never transitively depends on symbolic', () {
          check(reachedSubsystems(s))
              .not((sub) => sub.contains(Subsystem.symbolic));
        });
      }
    });

    group('decoupling from dataframe', () {
      final nonDataFrame = Subsystem.values.where(
        (s) => s != Subsystem.dataframe,
      );
      for (final s in nonDataFrame) {
        test('${s.name} never transitively depends on dataframe', () {
          check(reachedSubsystems(s))
              .not((sub) => sub.contains(Subsystem.dataframe));
        });
      }
    });

    group('decoupling from stats', () {
      const nonStats = [
        Subsystem.type,
        Subsystem.special,
        Subsystem.acceleration,
        Subsystem.tensor,
        Subsystem.dataframe,
        Subsystem.symbolic,
      ];
      for (final s in nonStats) {
        test('${s.name} never transitively depends on stats', () {
          check(reachedSubsystems(s))
              .not((sub) => sub.contains(Subsystem.stats));
        });
      }
    });
  });
}

/// Creates a dependency graph of all Dart files in the `lib` directory.
Graph<String, void> createFilesGraph() {
  final filesGraph = Graph<String, void>(isDirected: true);
  final files = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'));
  final directivePattern = RegExp(
    r'''^\s*(?:import|export|part)\b[^;]+;''',
    multiLine: true,
  );
  final stringPattern = RegExp(r'''['"]([^'"]+)['"]''');
  for (final file in files) {
    final source = file.path.replaceAll(r'\', '/');
    filesGraph.addVertex(source);
    final content = file.readAsStringSync();
    for (final match in directivePattern.allMatches(content)) {
      final directive = match.group(0)!;
      if (directive.trimLeft().startsWith('part of')) continue;
      for (final stringMatch in stringPattern.allMatches(directive)) {
        final uri = stringMatch.group(1)!;
        if (uri.startsWith('dart:') ||
            (uri.startsWith('package:') && !uri.startsWith('package:data/'))) {
          continue;
        }
        final target = uri.startsWith('package:data/')
            ? 'lib/${uri.removePrefix('package:data/')}'
            : Uri.file(source).resolve(uri).toFilePath().replaceAll(r'\', '/');
        filesGraph.addEdge(source, target);
      }
    }
  }
  return filesGraph;
}

/// Creates a coarse dependency graph between sub-libraries.
Graph<String, void> createLibsGraph(Graph<String, void> filesGraph) {
  final libsGraph = Graph<String, void>(isDirected: true);
  for (final edge in filesGraph.edges) {
    final sourceLib = subLibraryOf(edge.source);
    final targetLib = subLibraryOf(edge.target);
    if (sourceLib != null && targetLib != null && sourceLib != targetLib) {
      libsGraph.addEdge(sourceLib, targetLib);
    }
  }
  return libsGraph;
}

/// Identifies the sub-library name for a given file path.
String? subLibraryOf(String path) {
  if (path.startsWith('lib/src/')) {
    return path.removePrefix('lib/src/').takeTo('/');
  } else if (path.startsWith('lib/') && path != 'lib/data.dart') {
    return path.removePrefix('lib/').removeSuffix('.dart');
  }
  return null;
}

/// Returns the short label for a given file path.
String vertexLabel(String vertex) {
  if (vertex.startsWith('lib/src/')) {
    final rest = vertex.removePrefix('lib/src/');
    return rest.contains('/') ? rest.skipTo('/') : rest;
  }
  return vertex.removePrefix('lib/');
}
