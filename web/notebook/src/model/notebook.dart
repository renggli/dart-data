import '../language/markdown.dart';
import 'environment.dart';
import 'serialization.dart';
import 'value.dart';

/// Base class for ordered cells in a [NotebookDocument].
sealed class NotebookCell {
  new({required this.uid, required this.source});

  final String uid;
  String source;

  Map<String, Object?> toJson();
}

/// Prose Markdown cell with live `$...$` MathML and `{{...}}` interpolations.
final class MarkdownCell extends NotebookCell {
  new({
    required super.uid,
    required super.source,
    this.referencedResults = const {},
    this.referencedSymbols = const {},
    this.stale = false,
  });

  factory fromJson(Map<String, Object?> json) => MarkdownCell(
    uid: json['uid']! as String,
    source: json['source']! as String,
    referencedResults: {
      for (final r in json['referencedResults'] as List<Object?>? ?? const [])
        (r! as num).toInt(),
    },
    referencedSymbols: {
      for (final s in json['referencedSymbols'] as List<Object?>? ?? const [])
        s! as String,
    },
    stale: json['stale'] as bool? ?? false,
  );

  Set<int> referencedResults;
  Set<String> referencedSymbols;
  bool stale;

  void refreshReferences() {
    final refs = MarkdownParser.extractReferences(source);
    referencedResults = refs.results;
    referencedSymbols = refs.symbols;
  }

  @override
  Map<String, Object?> toJson() => {
    'kind': 'markdown',
    'uid': uid,
    'source': source,
    'referencedResults': referencedResults.toList(),
    'referencedSymbols': referencedSymbols.toList(),
    'stale': stale,
  };
}

/// Executable symbolic math cell with monotonic `r[id]` result binding.
final class MathCell extends NotebookCell {
  new({
    required super.uid,
    required super.source,
    required this.id,
    this.value,
    this.assignedSymbol,
    this.definedFunction,
    this.referencedResults = const {},
    this.referencedSymbols = const {},
    this.stale = false,
    this.collapsed = false,
    this.preserveForm = false,
  });

  factory fromJson(Map<String, Object?> json) {
    final rawVal = json['value'] as Map<String, Object?>?;
    return MathCell(
      uid: json['uid']! as String,
      source: json['source']! as String,
      id: (json['id']! as num).toInt(),
      value: rawVal == null ? null : valueFromJson(rawVal),
      assignedSymbol: json['assignedSymbol'] as String?,
      definedFunction: json['definedFunction'] as String?,
      referencedResults: {
        for (final r in json['referencedResults'] as List<Object?>? ?? const [])
          (r! as num).toInt(),
      },
      referencedSymbols: {
        for (final s in json['referencedSymbols'] as List<Object?>? ?? const [])
          s! as String,
      },
      stale: json['stale'] as bool? ?? false,
      collapsed: json['collapsed'] as bool? ?? false,
      preserveForm: json['preserveForm'] as bool? ?? false,
    );
  }

  final int id;
  CalcValue? value;
  String? assignedSymbol;
  String? definedFunction;
  Set<int> referencedResults;
  Set<String> referencedSymbols;
  bool stale;
  bool collapsed;
  bool preserveForm;

  @override
  Map<String, Object?> toJson() => {
    'kind': 'math',
    'uid': uid,
    'id': id,
    'source': source,
    if (value != null) 'value': valueToJson(value!),
    if (assignedSymbol != null) 'assignedSymbol': assignedSymbol,
    if (definedFunction != null) 'definedFunction': definedFunction,
    'referencedResults': referencedResults.toList(),
    'referencedSymbols': referencedSymbols.toList(),
    'stale': stale,
    'collapsed': collapsed,
    'preserveForm': preserveForm,
  };
}

/// Ordered heterogeneous notebook document managing cells, result IDs,
/// dependency staleness, and JSON/Markdown serialization.
final class NotebookDocument {
  new({
    List<NotebookCell>? cells,
    Environment? env,
    this._nextMathId = 1,
    this._nextUid = 1,
    Map<int, CalcValue>? tombstones,
  }) : cells = cells ?? [],
       env = env ?? Environment(),
       _tombstones = tombstones ?? {};

  final List<NotebookCell> cells;
  final Environment env;
  int _nextMathId;
  int _nextUid;
  final Map<int, CalcValue> _tombstones;

  int get nextMathId => _nextMathId;

  String _allocUid() => 'cell-${_nextUid++}';

  int _allocMathId() => _nextMathId++;

  NotebookCell? cellByUid(String uid) {
    for (final c in cells) {
      if (c.uid == uid) return c;
    }
    return null;
  }

  MathCell? mathCellById(int id) {
    for (final c in cells) {
      if (c is MathCell && c.id == id) return c;
    }
    return null;
  }

  int indexOfUid(String uid) => cells.indexWhere((c) => c.uid == uid);

  /// Looks up a result value for `r[id]` from live [MathCell]s or tombstones.
  CalcValue? lookupResult(int id) => mathCellById(id)?.value ?? _tombstones[id];

  MathCell insertMathCell(String source, {int? index}) {
    final cell = MathCell(uid: _allocUid(), source: source, id: _allocMathId());
    final at = index == null ? cells.length : index.clamp(0, cells.length);
    cells.insert(at, cell);
    return cell;
  }

  MarkdownCell insertMarkdownCell(String source, {int? index}) {
    final cell = MarkdownCell(uid: _allocUid(), source: source)
      ..refreshReferences();
    final at = index == null ? cells.length : index.clamp(0, cells.length);
    cells.insert(at, cell);
    return cell;
  }

  bool moveCell(String uid, int newIndex) {
    final oldIndex = indexOfUid(uid);
    if (oldIndex < 0) return false;
    final target = newIndex.clamp(0, cells.length - 1);
    if (oldIndex == target) return false;
    final cell = cells.removeAt(oldIndex);
    cells.insert(target, cell);
    return true;
  }

  bool deleteCell(String uid) {
    final idx = indexOfUid(uid);
    if (idx < 0) return false;
    final removed = cells.removeAt(idx);
    if (removed is MathCell) {
      final isReferenced = cells.any(
        (c) => switch (c) {
          MathCell(:final referencedResults) => referencedResults.contains(
            removed.id,
          ),
          MarkdownCell(:final referencedResults) => referencedResults.contains(
            removed.id,
          ),
        },
      );
      if (isReferenced && removed.value != null) {
        _tombstones[removed.id] = removed.value!;
      }
      markDependentsStale(
        changedResultId: removed.id,
        changedSymbol: removed.assignedSymbol ?? removed.definedFunction,
      );
    }
    return true;
  }

  NotebookCell? convertCellType(String uid) {
    final idx = indexOfUid(uid);
    if (idx < 0) return null;
    final current = cells[idx];
    final replacement = switch (current) {
      MathCell(:final source, :final uid) => MarkdownCell(
        uid: uid,
        source: source,
      )..refreshReferences(),
      MarkdownCell(:final source, :final uid) => MathCell(
        uid: uid,
        source: source,
        id: _allocMathId(),
      ),
    };
    cells[idx] = replacement;
    return replacement;
  }

  /// Marks downstream [MathCell]s and [MarkdownCell]s stale when a result ID or
  /// symbol changes.
  void markDependentsStale({int? changedResultId, String? changedSymbol}) {
    if (changedResultId == null && changedSymbol == null) return;
    final dirtyResults = <int>{?changedResultId};
    final dirtySymbols = <String>{?changedSymbol};

    var changed = true;
    while (changed) {
      changed = false;
      for (final cell in cells) {
        if (cell is MathCell && !cell.stale) {
          final hit =
              cell.referencedResults.any(dirtyResults.contains) ||
              cell.referencedSymbols.any(dirtySymbols.contains);
          if (hit) {
            cell.stale = true;
            dirtyResults.add(cell.id);
            if (cell.assignedSymbol != null) {
              dirtySymbols.add(cell.assignedSymbol!);
            }
            if (cell.definedFunction != null) {
              dirtySymbols.add(cell.definedFunction!);
            }
            changed = true;
          }
        } else if (cell is MarkdownCell && !cell.stale) {
          final hit =
              cell.referencedResults.any(dirtyResults.contains) ||
              cell.referencedSymbols.any(dirtySymbols.contains);
          if (hit) {
            cell.stale = true;
            changed = true;
          }
        }
      }
    }
  }

  /// Exports the notebook as portable Markdown with fenced ```` ```math ````
  /// blocks.
  String toMarkdown() {
    final parts = <String>[];
    for (final cell in cells) {
      switch (cell) {
        case MarkdownCell(:final source):
          final trimmed = source.trim();
          if (trimmed.isNotEmpty) parts.add(trimmed);
        case MathCell(:final source):
          parts.add('```math\n${source.trim()}\n```');
      }
    }
    return parts.join('\n\n');
  }

  /// Replaces the document's cells by parsing portable Markdown with fenced
  /// ```` ```math ```` blocks.
  void loadFromMarkdown(String markdown) {
    cells.clear();
    _tombstones.clear();
    _nextMathId = 1;
    _nextUid = 1;

    final lines = markdown.replaceAll('\r\n', '\n').split('\n');
    final mdBuf = <String>[];

    void flushMarkdown() {
      final text = mdBuf.join('\n').trim();
      mdBuf.clear();
      if (text.isNotEmpty) {
        insertMarkdownCell(text);
      }
    }

    var i = 0;
    while (i < lines.length) {
      final trimmed = lines[i].trim();
      if (trimmed == '```math') {
        flushMarkdown();
        i++;
        final mathLines = <String>[];
        while (i < lines.length && lines[i].trim() != '```') {
          mathLines.add(lines[i]);
          i++;
        }
        if (i < lines.length) i++; // consume closing ```
        final code = mathLines.join('\n').trim();
        if (code.isNotEmpty) {
          insertMathCell(code);
        }
        continue;
      }
      mdBuf.add(lines[i]);
      i++;
    }
    flushMarkdown();
  }

  Map<String, Object?> toJson() => {
    'version': 1,
    'nextMathId': _nextMathId,
    'nextUid': _nextUid,
    'cells': [for (final c in cells) c.toJson()],
    'tombstones': {
      for (final entry in _tombstones.entries)
        entry.key.toString(): valueToJson(entry.value),
    },
    'env': env.toJson(),
  };

  void loadFromJson(Map<String, Object?> json) {
    cells.clear();
    _tombstones.clear();
    _nextMathId = (json['nextMathId'] as num?)?.toInt() ?? 1;
    _nextUid = (json['nextUid'] as num?)?.toInt() ?? 1;

    final rawCells = json['cells'] as List<Object?>? ?? const [];
    for (final raw in rawCells) {
      final map = raw! as Map<String, Object?>;
      final kind = map['kind'] as String?;
      if (kind == 'markdown') {
        cells.add(MarkdownCell.fromJson(map));
      } else {
        cells.add(MathCell.fromJson(map));
      }
    }

    final rawTombs = json['tombstones'] as Map<String, Object?>? ?? const {};
    for (final entry in rawTombs.entries) {
      _tombstones[int.parse(entry.key)] = valueFromJson(
        entry.value! as Map<String, Object?>,
      );
    }

    final rawEnv = json['env'] as Map<String, Object?>?;
    if (rawEnv != null) {
      final loaded = Environment.fromJson(rawEnv);
      env.variables
        ..clear()
        ..addAll(loaded.variables);
      env.functions
        ..clear()
        ..addAll(loaded.functions);
      env.settings = loaded.settings;
    }
  }
}
