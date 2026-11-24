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
    if (uid != null && document.cellByUid(uid) is MathCell) {
      cell = document.cellByUid(uid)! as MathCell;
      cell.source = source;
    } else {
      cell = document.insertMathCell(source, index: index);
    }

    _evaluateMathCell(cell, forceApprox: forceApprox);
    return {'evaluatedUid': cell.uid, ..._snapshotPayload()};
  }

  void _evaluateMathCell(MathCell cell, {bool forceApprox = false}) {
    final prevValue = cell.value;
    final prevSymbol = cell.assignedSymbol ?? cell.definedFunction;

    final res = _evaluator.evaluate(
      cell.source,
      lookupResult: document.lookupResult,
      forceApprox: forceApprox,
      currentMathId: cell.id,
    );

    cell
      ..value = res.value
      ..assignedSymbol = res.assignedSymbol
      ..definedFunction = res.definedFunction
      ..preserveForm = res.preserveForm
      ..referencedResults = res.referencedResults
      ..referencedSymbols = res.referencedSymbols
      ..stale = false;

    final nextSymbol = cell.assignedSymbol ?? cell.definedFunction;
    if (prevValue != res.value || prevSymbol != nextSymbol) {
      document.markDependentsStale(
        changedResultId: cell.id,
        changedSymbol: nextSymbol ?? prevSymbol,
      );
    }
    // Also mark any markdown cell referencing this cell's id/symbol as fresh if
    // it was only waiting on this cell? Markdown cells are re-rendered from
    // snapshot directly; clear stale on markdown cells whose refs are all non-stale.
    _refreshMarkdownStaleness();
  }

  void _refreshMarkdownStaleness() {
    for (final c in document.cells) {
      if (c is MarkdownCell && c.stale) {
        final anyStale = c.referencedResults.any(
          (id) => document.mathCellById(id)?.stale ?? false,
        );
        if (!anyStale) c.stale = false;
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
    document.deleteCell(uid);
    return _snapshotPayload();
  }

  Map<String, Object?> _handleConvertCell(Map<String, Object?> req) {
    _pushUndo();
    final uid = req['uid']! as String;
    final converted = document.convertCellType(uid);
    if (converted is MathCell && converted.source.trim().isNotEmpty) {
      _evaluateMathCell(converted);
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
