import 'serialization.dart';
import 'value.dart';

/// A numbered cell in the Scroll worksheet (`r[n]`).
final class WorksheetCell {
  new({
    required this.id,
    required this.input,
    required this.value,
    this.assignedSymbol,
    this.referencedResults = const {},
    this.referencedSymbols = const {},
    this.stale = false,
    this.pinned = false,
    this.collapsed = false,
    this.deleted = false,
  });

  /// 1-based monotonic result identifier (`r[id]`).
  final int id;

  /// Raw input statement string entered by the user.
  String input;

  /// Evaluated result value.
  CalcValue value;

  /// Variable or function name assigned by this cell (`a := ...`), if any.
  String? assignedSymbol;

  /// Set of `r[k]` result IDs directly referenced by this cell's input.
  Set<int> referencedResults;

  /// Set of variable/function names directly referenced by this cell's input.
  Set<String> referencedSymbols;

  /// Whether an upstream dependency (`r[k]` or variable) has been modified
  /// since this cell was last evaluated.
  bool stale;

  /// Whether this cell is pinned as a favorite.
  bool pinned;

  /// Whether this cell's output is collapsed in the UI.
  bool collapsed;

  /// Whether this cell has been deleted (leaving a tombstone so `r[id]` never
  /// renumbers and references fail explicitly).
  bool deleted;

  Map<String, Object?> toJson({int digits = 10}) => {
    'id': id,
    'input': input,
    'value': CalcSerialization.toJson(value, digits: digits),
    if (assignedSymbol != null) 'assignedSymbol': assignedSymbol,
    'referencedResults': referencedResults.toList(),
    'referencedSymbols': referencedSymbols.toList(),
    'stale': stale,
    'pinned': pinned,
    'collapsed': collapsed,
    'deleted': deleted,
  };

  factory fromJson(Map<String, Object?> json) => WorksheetCell(
    id: (json['id']! as num).toInt(),
    input: json['input']! as String,
    value: CalcSerialization.fromJson(json['value']! as Map<String, Object?>),
    assignedSymbol: json['assignedSymbol'] as String?,
    referencedResults: (json['referencedResults'] as List<Object?>? ?? const [])
        .map((e) => (e! as num).toInt())
        .toSet(),
    referencedSymbols: (json['referencedSymbols'] as List<Object?>? ?? const [])
        .cast<String>()
        .toSet(),
    stale: json['stale'] as bool? ?? false,
    pinned: json['pinned'] as bool? ?? false,
    collapsed: json['collapsed'] as bool? ?? false,
    deleted: json['deleted'] as bool? ?? false,
  );
}

/// Manages the numbered result table (`r[1]`, `r[2]`, ...), tombstones,
/// input history, and dependency graph invalidation across Scroll and RPN modes.
final class Session {
  final Map<int, WorksheetCell> _cells = {};
  final List<String> _history = [];
  int _nextId = 1;

  /// Next result number `r[n]` that will be allocated.
  int get nextId => _nextId;

  /// All active (non-deleted) worksheet cells in increasing `r[n]` order.
  List<WorksheetCell> get activeCells => [
    for (final cell in _cells.values)
      if (!cell.deleted) cell,
  ];

  /// All cells including tombstones.
  Map<int, WorksheetCell> get allCells => Map.unmodifiable(_cells);

  /// Chronological list of user inputs for `↑` / `↓` recall.
  List<String> get history => List.unmodifiable(_history);

  /// Appends a new evaluated cell and returns its allocated `r[n]` [WorksheetCell].
  WorksheetCell addResult({
    required String input,
    required CalcValue value,
    String? assignedSymbol,
    Set<int> referencedResults = const {},
    Set<String> referencedSymbols = const {},
    bool recordHistory = true,
  }) {
    final id = _nextId++;
    final cell = WorksheetCell(
      id: id,
      input: input,
      value: value,
      assignedSymbol: assignedSymbol,
      referencedResults: referencedResults,
      referencedSymbols: referencedSymbols,
    );
    _cells[id] = cell;
    if (recordHistory && input.trim().isNotEmpty) {
      if (_history.isEmpty || _history.last != input) {
        _history.add(input);
      }
    }
    if (assignedSymbol != null) {
      _markDependentsOfSymbolStale(assignedSymbol, excludeCellId: id);
    }
    return cell;
  }

  /// Updates an existing cell in-place and marks all transitively dependent
  /// cells as `stale = true`. Returns the ordered list of dependent cell IDs
  /// that became stale.
  List<int> updateCell(
    int id, {
    required String input,
    required CalcValue value,
    String? assignedSymbol,
    Set<int> referencedResults = const {},
    Set<String> referencedSymbols = const {},
  }) {
    final existing = _cells[id];
    if (existing == null || existing.deleted) {
      throw ArgumentError('Result r[$id] does not exist or was deleted.');
    }
    final oldSymbol = existing.assignedSymbol;
    existing
      ..input = input
      ..value = value
      ..assignedSymbol = assignedSymbol
      ..referencedResults = referencedResults
      ..referencedSymbols = referencedSymbols
      ..stale = false;

    return markDependentsStale(
      changedId: id,
      changedSymbols: {?oldSymbol, ?assignedSymbol},
    );
  }

  /// Resolves `r[index]` where positive `index` is an absolute result number
  /// (`r[1]`, `r[2]`, ...) and negative `index` (`r[-1]`, `r[-2]`, ...) counts
  /// backward from the most recent active non-error result.
  ///
  /// Throws [StateError] if the referenced result does not exist or was deleted.
  CalcValue resolveResult(int index, {int? beforeId}) {
    if (index == 0) {
      throw StateError('Result index r[0] is invalid (results start at r[1]).');
    }
    if (index > 0) {
      final cell = _cells[index];
      if (cell == null) {
        throw StateError('Result r[$index] does not exist yet.');
      }
      if (cell.deleted) {
        throw StateError('Result r[$index] was deleted.');
      }
      return cell.value;
    }
    // Negative index: r[-k] is k-th most recent active cell before [beforeId]
    final candidates = [
      for (final cell in _cells.values)
        if (!cell.deleted && (beforeId == null || cell.id < beforeId)) cell,
    ];
    final offset = candidates.length + index;
    if (offset < 0 || offset >= candidates.length) {
      throw StateError('Relative result r[$index] is out of range.');
    }
    return candidates[offset].value;
  }

  /// Resolves a relative index `r[-k]` to its canonical positive result ID `n`,
  /// or returns `index` if already positive.
  int resolveCanonicalId(int index, {int? beforeId}) {
    if (index > 0) return index;
    final candidates = [
      for (final cell in _cells.values)
        if (!cell.deleted && (beforeId == null || cell.id < beforeId)) cell,
    ];
    final offset = candidates.length + index;
    if (offset < 0 || offset >= candidates.length) {
      throw StateError('Relative result r[$index] is out of range.');
    }
    return candidates[offset].id;
  }

  /// Marks cell [id] as a deleted tombstone so `r[id]` never renumbers and
  /// marks any dependent cells stale.
  List<int> deleteCell(int id) {
    final cell = _cells[id];
    if (cell == null || cell.deleted) return const [];
    cell.deleted = true;
    return markDependentsStale(
      changedId: id,
      changedSymbols: {if (cell.assignedSymbol != null) cell.assignedSymbol!},
    );
  }

  /// Returns `true` if any active cell references `r[id]`.
  bool isResultReferenced(int id) => activeCells.any(
    (cell) => cell.id != id && cell.referencedResults.contains(id),
  );

  /// Removes an unreferenced transient cell (such as an RPN literal push that
  /// was immediately consumed by an operator or command) and rewinds `_nextId`
  /// if it was the latest allocated cell.
  void removeUnreferencedCell(int id) {
    final cell = _cells[id];
    if (cell == null || cell.deleted || cell.assignedSymbol != null) return;
    if (isResultReferenced(id)) return;
    _cells.remove(id);
    while (_nextId > 1 && !_cells.containsKey(_nextId - 1)) {
      _nextId--;
    }
  }

  /// Computes and marks all active cells transitively depending on [changedId]
  /// or [changedSymbols] as stale. Returns their IDs in topological (ascending
  /// `id`) order.
  List<int> markDependentsStale({
    int? changedId,
    Set<String> changedSymbols = const {},
  }) {
    final affectedIds = <int>{?changedId};
    final affectedSymbols = <String>{...changedSymbols};
    final staleList = <int>[];

    for (final cell in activeCells) {
      if (changedId != null && cell.id <= changedId) continue;
      final dependsOnResult = cell.referencedResults.any(affectedIds.contains);
      final dependsOnSymbol = cell.referencedSymbols.any(
        affectedSymbols.contains,
      );
      if (dependsOnResult || dependsOnSymbol) {
        cell.stale = true;
        staleList.add(cell.id);
        affectedIds.add(cell.id);
        if (cell.assignedSymbol != null) {
          affectedSymbols.add(cell.assignedSymbol!);
        }
      }
    }
    return staleList;
  }

  /// Returns all currently stale active cells in ascending ID order.
  List<WorksheetCell> get staleCells => [
    for (final cell in activeCells)
      if (cell.stale) cell,
  ];

  void _markDependentsOfSymbolStale(
    String symbol, {
    required int excludeCellId,
  }) {
    for (final cell in activeCells) {
      if (cell.id == excludeCellId) continue;
      if (cell.referencedSymbols.contains(symbol)) {
        cell.stale = true;
      }
    }
  }

  /// Clears all cells and resets numbering to `r[1]`.
  void clear() {
    _cells.clear();
    _nextId = 1;
  }

  Map<String, Object?> toJson({int digits = 10}) => {
    'nextId': _nextId,
    'history': _history,
    'cells': [for (final c in _cells.values) c.toJson(digits: digits)],
  };

  void loadFromJson(Map<String, Object?> json) {
    _cells.clear();
    _history.clear();
    _nextId = (json['nextId'] as num?)?.toInt() ?? 1;
    final hist = json['history'] as List<Object?>? ?? const [];
    _history.addAll(hist.cast<String>());
    final cellsJson = json['cells'] as List<Object?>? ?? const [];
    for (final raw in cellsJson) {
      final cell = WorksheetCell.fromJson(raw! as Map<String, Object?>);
      _cells[cell.id] = cell;
      if (cell.id >= _nextId) {
        _nextId = cell.id + 1;
      }
    }
  }
}
