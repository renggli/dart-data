import '../engine/evaluator.dart';
import '../model/environment.dart';
import '../model/notebook.dart';
import '../model/value.dart';

/// Pure-Dart request/response dispatcher for the notebook worker and tests.
final class WorkerDispatcher {
  new({NotebookDocument? document})
    : document = document ?? NotebookDocument() {
    _evaluator = NotebookEvaluator(env: this.document.env);
  }

  final NotebookDocument document;
  late final NotebookEvaluator _evaluator;
  final List<Map<String, Object?>> _undoStack = [];
  final List<Map<String, Object?>> _redoStack = [];

  static const int _maxHistory = 50;

  /// Dispatches a JSON request map `{id, type, ...}` and returns a response map
  /// `{id, ok, ...}`.
  Map<String, Object?> handle(Map<String, Object?> request) {
    final reqId = request['id'];
    final type = request['type']! as String;

    try {
      final payload = switch (type) {
        'evalCell' => _handleEvalCell(request),
        'updateControl' => _handleUpdateControl(request),
        'insertMarkdown' => _handleInsertMarkdown(request),
        'updateMarkdown' => _handleUpdateMarkdown(request),
        'moveCell' => _handleMoveCell(request),
        'deleteCell' => _handleDeleteCell(request),
        'convertCell' => _handleConvertCell(request),
        'recomputeStale' => _handleRecomputeStale(),
        'recomputeAll' => _handleRecomputeAll(),
        'importMarkdown' => _handleImportMarkdown(request),
        'exportMarkdown' => {'markdown': document.toMarkdown()},
        'loadSnapshot' => _handleLoadSnapshot(request),
        'getSnapshot' => _snapshotPayload(),
        'undo' => _handleUndo(),
        'redo' => _handleRedo(),
        'updateSettings' => _handleUpdateSettings(request),
        'clearSession' => _handleClearSession(),
        _ => throw FormatException('Unknown worker request type: $type'),
      };
      return {'id': reqId, 'ok': true, ...payload};
    } on Object catch (e) {
      return {'id': reqId, 'ok': false, 'error': '$e'};
    }
  }

  void _pushUndo() {
    _undoStack.add(document.toJson());
    if (_undoStack.length > _maxHistory) {
      _undoStack.removeAt(0);
    }
    _redoStack.clear();
  }

  Map<String, Object?> _snapshotPayload() => {
    'snapshot': document.toJson(),
    'canUndo': _undoStack.isNotEmpty,
    'canRedo': _redoStack.isNotEmpty,
  };

  Map<String, Object?> _handleEvalCell(Map<String, Object?> req) {
    _pushUndo();
    final source = req['source']! as String;
    final uid = req['uid'] as String?;
    final index = (req['index'] as num?)?.toInt();
    final forceApprox = req['forceApprox'] as bool? ?? false;

    MathCell cell;
    var removedSymbols = <String>{};
    var removedFunctions = <String>{};
    if (uid != null && document.cellByUid(uid) is MathCell) {
      cell = document.cellByUid(uid)! as MathCell;
      removedSymbols = Set<String>.of(cell.assignedSymbols);
      removedFunctions = Set<String>.of(cell.definedFunctions);
      cell.source = source;
    } else {
      cell = document.insertMathCell(source, index: index);
    }

    _evaluateMathCell(cell, forceApprox: forceApprox);

    removedSymbols = removedSymbols.difference(cell.assignedSymbols);
    removedFunctions = removedFunctions.difference(cell.definedFunctions);
    _removeOrphanedBindings(removedSymbols, removedFunctions);

    _propagateDependents(
      origin: cell,
      extraChangedSymbols: {...removedSymbols, ...removedFunctions},
    );
    return {'evaluatedUid': cell.uid, ..._snapshotPayload()};
  }

  Map<String, Object?> _handleUpdateControl(Map<String, Object?> req) {
    final recordUndo = req['recordUndo'] as bool? ?? false;
    if (recordUndo) {
      _pushUndo();
    }
    final uid = req['uid']! as String;
    final key = req['key']! as String;
    final value = req['value'];
    final cell = document.cellByUid(uid);
    if (cell is! MathCell) return _snapshotPayload();

    if (value == null) {
      cell.controlValues.remove(key);
    } else {
      cell.controlValues[key] = value;
    }

    _evaluateMathCell(cell);
    _propagateDependents(origin: cell);
    return _snapshotPayload();
  }

  void _evaluateMathCell(MathCell cell, {bool forceApprox = false}) {
    final res = _evaluator.evaluate(
      cell.source,
      lookupResult: document.lookupResult,
      forceApprox: forceApprox,
      currentMathId: cell.id,
      controlOverrides: cell.controlValues,
    );

    cell
      ..value = res.value
      ..assignedSymbols = res.assignedSymbols
      ..definedFunctions = res.definedFunctions
      ..preserveForm = res.preserveForm
      ..referencedResults = res.referencedResults
      ..referencedSymbols = res.referencedSymbols
      ..stale = false;

    _pruneControlOverrides(cell);
  }

  void _pruneControlOverrides(MathCell cell) {
    if (cell.controlValues.isEmpty) return;
    final activeKeys = switch (cell.value) {
      ControlValue(:final key) => {key},
      ControlGroupValue(:final controls) => {for (final c in controls) c.key},
      _ => const <String>{},
    };
    if (activeKeys.isEmpty) {
      cell.controlValues.clear();
    } else {
      cell.controlValues.removeWhere((k, _) => !activeKeys.contains(k));
    }
  }

  void _removeOrphanedBindings(
    Set<String> candidateSymbols,
    Set<String> candidateFunctions,
  ) {
    if (candidateSymbols.isEmpty && candidateFunctions.isEmpty) return;
    final definedSymbols = <String>{};
    final definedFunctions = <String>{};
    for (final c in document.cells) {
      if (c is MathCell) {
        definedSymbols.addAll(c.assignedSymbols);
        definedFunctions.addAll(c.definedFunctions);
      }
    }
    for (final s in candidateSymbols) {
      if (!definedSymbols.contains(s)) {
        document.env.variables.remove(s);
      }
    }
    for (final f in candidateFunctions) {
      if (!definedFunctions.contains(f)) {
        document.env.functions.remove(f);
      }
    }
  }

  /// Propagates updates across downstream [MathCell]s in loop-free topological
  /// order, flagging circular dependencies cleanly with [ErrorValue].
  void _propagateDependents({
    MathCell? origin,
    Set<String> extraChangedSymbols = const {},
  }) {
    final mathCells = <MathCell>[
      for (final c in document.cells)
        if (c is MathCell) c,
    ];
    if (mathCells.isEmpty) {
      _refreshMarkdownCells();
      return;
    }

    final idxByUid = <String, int>{
      for (var i = 0; i < mathCells.length; i++) mathCells[i].uid: i,
    };
    final byId = <int, MathCell>{for (final c in mathCells) c.id: c};

    MathCell? definingCell(String sym, int consumerIdx) {
      for (var i = consumerIdx - 1; i >= 0; i--) {
        final c = mathCells[i];
        if (c.assignedSymbols.contains(sym) ||
            c.definedFunctions.contains(sym)) {
          return c;
        }
      }
      for (var i = consumerIdx + 1; i < mathCells.length; i++) {
        final c = mathCells[i];
        if (c.assignedSymbols.contains(sym) ||
            c.definedFunctions.contains(sym)) {
          return c;
        }
      }
      return null;
    }

    final depsOf = <String, Set<String>>{
      for (final c in mathCells) c.uid: <String>{},
    };
    final consumersOf = <String, Set<String>>{
      for (final c in mathCells) c.uid: <String>{},
    };

    var originSelfCycle = false;
    for (var i = 0; i < mathCells.length; i++) {
      final v = mathCells[i];
      for (final resId in v.referencedResults) {
        final u = byId[resId];
        if (u == null) continue;
        if (u.uid == v.uid) {
          if (origin != null && v.uid == origin.uid) originSelfCycle = true;
          continue;
        }
        depsOf[v.uid]!.add(u.uid);
        consumersOf[u.uid]!.add(v.uid);
      }
      for (final sym in v.referencedSymbols) {
        final u = definingCell(sym, i);
        if (u == null) {
          if ((v.value is ControlValue || v.value is ControlGroupValue) &&
              (v.assignedSymbols.contains(sym) ||
                  v.definedFunctions.contains(sym))) {
            if (origin != null && v.uid == origin.uid) originSelfCycle = true;
          }
          continue;
        }
        depsOf[v.uid]!.add(u.uid);
        consumersOf[u.uid]!.add(v.uid);
      }
    }

    final reachable = <String>{};
    final bfs = <String>[];

    void enqueue(String uid) {
      if (reachable.add(uid)) bfs.add(uid);
    }

    if (originSelfCycle && origin != null) {
      enqueue(origin.uid);
    }
    if (origin != null) {
      for (final nextUid in consumersOf[origin.uid]!) {
        enqueue(nextUid);
      }
    }
    if (extraChangedSymbols.isNotEmpty) {
      for (final c in mathCells) {
        if (c.referencedSymbols.any(extraChangedSymbols.contains)) {
          enqueue(c.uid);
        }
      }
    }

    for (var head = 0; head < bfs.length; head++) {
      final cur = bfs[head];
      for (final nextUid in consumersOf[cur] ?? const <String>{}) {
        enqueue(nextUid);
      }
    }

    if (reachable.isEmpty) {
      _refreshMarkdownCells();
      return;
    }

    final inDegree = <String, int>{for (final uid in reachable) uid: 0};
    for (final uid in reachable) {
      for (final dep in depsOf[uid]!) {
        if (dep != uid && reachable.contains(dep)) {
          inDegree[uid] = inDegree[uid]! + 1;
        }
      }
    }

    final cellByUid = <String, MathCell>{for (final c in mathCells) c.uid: c};
    final ready = <String>[
      for (final entry in inDegree.entries)
        if (entry.value == 0) entry.key,
    ]..sort((a, b) => idxByUid[a]!.compareTo(idxByUid[b]!));

    final visited = <String>{};
    while (ready.isNotEmpty) {
      final uid = ready.removeAt(0);
      visited.add(uid);
      final cell = cellByUid[uid]!;
      if (cell.source.trim().isNotEmpty) {
        _evaluateMathCell(cell);
      } else {
        cell.stale = false;
      }
      for (final nextUid in consumersOf[uid]!) {
        if (!reachable.contains(nextUid)) continue;
        final nextDeg = inDegree[nextUid]! - 1;
        inDegree[nextUid] = nextDeg;
        if (nextDeg == 0) {
          ready
            ..add(nextUid)
            ..sort((a, b) => idxByUid[a]!.compareTo(idxByUid[b]!));
        }
      }
    }

    // Any remaining reachable cell could not be ordered topologically (cycle).
    for (final uid in reachable) {
      if (visited.contains(uid)) continue;
      final cell = cellByUid[uid]!;
      cell
        ..value = const ErrorValue('Circular dependency detected')
        ..stale = false;
      for (final sym in cell.assignedSymbols) {
        document.env.variables[sym] = cell.value!;
      }
    }

    _refreshMarkdownCells();
  }

  void _refreshMarkdownCells() {
    for (final c in document.cells) {
      if (c is MarkdownCell) {
        c
          ..refreshReferences()
          ..stale = false;
      }
    }
  }

  Map<String, Object?> _handleInsertMarkdown(Map<String, Object?> req) {
    _pushUndo();
    final source = req['source'] as String? ?? '';
    final index = (req['index'] as num?)?.toInt();
    final cell = document.insertMarkdownCell(source, index: index);
    return {'insertedUid': cell.uid, ..._snapshotPayload()};
  }

  Map<String, Object?> _handleUpdateMarkdown(Map<String, Object?> req) {
    _pushUndo();
    final uid = req['uid']! as String;
    final source = req['source']! as String;
    final cell = document.cellByUid(uid);
    if (cell is MarkdownCell) {
      cell
        ..source = source
        ..stale = false
        ..refreshReferences();
    }
    return _snapshotPayload();
  }

  Map<String, Object?> _handleMoveCell(Map<String, Object?> req) {
    _pushUndo();
    final uid = req['uid']! as String;
    final newIndex = (req['newIndex']! as num).toInt();
    document.moveCell(uid, newIndex);
    return _snapshotPayload();
  }

  Map<String, Object?> _handleDeleteCell(Map<String, Object?> req) {
    _pushUndo();
    final uid = req['uid']! as String;
    final removed = document.cellByUid(uid);
    final removedSymbols = removed is MathCell
        ? Set<String>.of(removed.assignedSymbols)
        : const <String>{};
    final removedFunctions = removed is MathCell
        ? Set<String>.of(removed.definedFunctions)
        : const <String>{};

    document.deleteCell(uid);
    _removeOrphanedBindings(removedSymbols, removedFunctions);

    if (removed is MathCell) {
      final affected = <String>{...removedSymbols, ...removedFunctions};
      // Also catch dependents of the deleted r[id] via tombstone removal?
      // Look up any remaining cells referencing removed.id.
      for (final c in document.cells) {
        if (c is MathCell && c.referencedResults.contains(removed.id)) {
          affected.addAll(c.assignedSymbols);
          affected.addAll(c.definedFunctions);
        }
      }
      _propagateDependents(extraChangedSymbols: affected);
    }
    return _snapshotPayload();
  }

  Map<String, Object?> _handleConvertCell(Map<String, Object?> req) {
    _pushUndo();
    final uid = req['uid']! as String;
    final existing = document.cellByUid(uid);
    final removedSymbols = existing is MathCell
        ? Set<String>.of(existing.assignedSymbols)
        : const <String>{};
    final removedFunctions = existing is MathCell
        ? Set<String>.of(existing.definedFunctions)
        : const <String>{};

    final converted = document.convertCellType(uid);
    if (converted is MathCell && converted.source.trim().isNotEmpty) {
      _evaluateMathCell(converted);
      _propagateDependents(origin: converted);
    } else if (existing is MathCell) {
      _removeOrphanedBindings(removedSymbols, removedFunctions);
      _propagateDependents(
        extraChangedSymbols: {...removedSymbols, ...removedFunctions},
      );
    }
    return {'convertedUid': converted?.uid, ..._snapshotPayload()};
  }

  Map<String, Object?> _handleRecomputeStale() {
    _pushUndo();
    for (final cell in document.cells) {
      if (cell is MathCell && cell.stale) {
        _evaluateMathCell(cell);
      } else if (cell is MarkdownCell && cell.stale) {
        cell.stale = false;
      }
    }
    _refreshMarkdownCells();
    return _snapshotPayload();
  }

  Map<String, Object?> _handleRecomputeAll() {
    _pushUndo();
    document.env.clear();
    for (final cell in document.cells) {
      if (cell is MathCell) {
        if (cell.source.trim().isEmpty) {
          cell
            ..value = const InfoValue('')
            ..stale = false;
        } else {
          _evaluateMathCell(cell);
        }
      } else if (cell is MarkdownCell) {
        cell
          ..refreshReferences()
          ..stale = false;
      }
    }
    return _snapshotPayload();
  }

  Map<String, Object?> _handleImportMarkdown(Map<String, Object?> req) {
    _pushUndo();
    final markdown = req['markdown']! as String;
    document.env.clear();
    document.loadFromMarkdown(markdown);
    for (final cell in document.cells) {
      if (cell is MathCell && cell.source.trim().isNotEmpty) {
        _evaluateMathCell(cell);
      }
    }
    _refreshMarkdownCells();
    return _snapshotPayload();
  }

  Map<String, Object?> _handleLoadSnapshot(Map<String, Object?> req) {
    final snapshot = req['snapshot']! as Map<String, Object?>;
    document.loadFromJson(snapshot);
    return _snapshotPayload();
  }

  Map<String, Object?> _handleUndo() {
    if (_undoStack.isEmpty) return _snapshotPayload();
    _redoStack.add(document.toJson());
    document.loadFromJson(_undoStack.removeLast());
    return _snapshotPayload();
  }

  Map<String, Object?> _handleRedo() {
    if (_redoStack.isEmpty) return _snapshotPayload();
    _undoStack.add(document.toJson());
    document.loadFromJson(_redoStack.removeLast());
    return _snapshotPayload();
  }

  Map<String, Object?> _handleUpdateSettings(Map<String, Object?> req) {
    _pushUndo();
    final raw = req['settings']! as Map<String, Object?>;
    document.env.settings = NotebookSettings.fromJson(raw);
    return _snapshotPayload();
  }

  Map<String, Object?> _handleClearSession() {
    _pushUndo();
    document.env.clear();
    return _snapshotPayload();
  }
}
