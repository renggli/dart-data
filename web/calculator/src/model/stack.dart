import 'package:data/symbolic.dart';

import 'serialization.dart';
import 'value.dart';

/// A single entry on the HP48-style RPN stack.
final class StackItem {
  const new({required this.resultId, required this.value});

  /// Shared session result identifier `r[resultId]` (or `0` for synthetic
  /// stack-depth values).
  final int resultId;

  /// Calculator value at this stack level.
  final CalcValue value;

  Map<String, Object?> toJson({int digits = 10}) => {
    'resultId': resultId,
    'value': CalcSerialization.toJson(value, digits: digits),
  };

  factory fromJson(Map<String, Object?> json) => StackItem(
    resultId: (json['resultId'] as num?)?.toInt() ?? 0,
    value: CalcSerialization.fromJson(json['value']! as Map<String, Object?>),
  );
}

/// HP48-style RPN stack machine with multi-level undo/redo and `LASTARG`
/// recall.
///
/// Stack levels follow HP48 convention:
/// - Level `1:` is the top of the stack (nearest the command line, last element
///   of [_items]).
/// - Level `2:` is the second item from the top, and so on up to [depth].
final class RpnStack {
  static const int _maxUndoLevels = 64;

  final List<StackItem> _items = [];
  final List<List<StackItem>> _undoStack = [];
  final List<List<StackItem>> _redoStack = [];
  List<StackItem> _lastArgs = const [];

  /// Number of items currently on the stack.
  int get depth => _items.length;

  /// Whether the stack is empty.
  bool get isEmpty => _items.isEmpty;

  /// Items ordered from bottom (oldest, level `depth:`) to top (newest,
  /// level `1:`).
  List<StackItem> get items => List.unmodifiable(_items);

  /// Arguments consumed by the most recent command (`LASTARG`).
  List<StackItem> get lastArgs => List.unmodifiable(_lastArgs);

  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  /// Captures an internal stack checkpoint for transactional execution.
  ({List<StackItem> items, List<StackItem> lastArgs, int undoDepth})
  checkpoint() => (
    items: List<StackItem>.of(_items),
    lastArgs: List<StackItem>.of(_lastArgs),
    undoDepth: _undoStack.length,
  );

  /// Restores stack state and undo ring to [cp].
  void restoreCheckpoint(
    ({List<StackItem> items, List<StackItem> lastArgs, int undoDepth}) cp,
  ) {
    _items
      ..clear()
      ..addAll(cp.items);
    _lastArgs = cp.lastArgs;
    while (_undoStack.length > cp.undoDepth) {
      _undoStack.removeLast();
    }
  }

  /// Returns the item at 1-based HP48 stack [level] (`1` = top of stack).
  StackItem level(int level) {
    if (level < 1 || level > _items.length) {
      throw StateError(
        'Stack underflow: level $level requested, but stack depth is ${_items.length}.',
      );
    }
    return _items[_items.length - level];
  }

  /// Saves a snapshot of the current stack onto the undo ring before a
  /// mutating operation.
  void snapshot() {
    _undoStack.add(List<StackItem>.of(_items));
    if (_undoStack.length > _maxUndoLevels) {
      _undoStack.removeAt(0);
    }
    _redoStack.clear();
  }

  /// Pushes [item] onto level `1:`.
  void push(StackItem item, {bool recordUndo = true}) {
    if (recordUndo) snapshot();
    _items.add(item);
  }

  /// Pops and returns level `1:`.
  StackItem pop({bool recordUndo = true}) {
    if (_items.isEmpty) {
      throw StateError('Too Few Arguments: stack is empty.');
    }
    if (recordUndo) snapshot();
    return _items.removeLast();
  }

  /// Pops [count] arguments from the top of the stack in HP48 order:
  /// `[level(count), ..., level(2), level(1)]` and records them in [lastArgs].
  List<StackItem> popArgs(int count, {bool recordUndo = true}) {
    if (_items.length < count) {
      throw StateError(
        'Too Few Arguments: need $count argument(s), stack has ${_items.length}.',
      );
    }
    if (recordUndo) snapshot();
    final start = _items.length - count;
    final popped = _items.sublist(start);
    _items.removeRange(start, _items.length);
    _lastArgs = popped;
    return popped;
  }

  /// `DUP`: Duplicates level `1:`.
  void dup() {
    if (_items.isEmpty) {
      throw StateError('Too Few Arguments: DUP requires 1 item on the stack.');
    }
    snapshot();
    _items.add(_items.last);
  }

  /// `DROP`: Removes level `1:`.
  StackItem drop() {
    if (_items.isEmpty) {
      throw StateError('Too Few Arguments: DROP requires 1 item on the stack.');
    }
    snapshot();
    final removed = _items.removeLast();
    _lastArgs = [removed];
    return removed;
  }

  /// `SWAP`: Exchanges level `1:` and level `2:`.
  void swap() {
    if (_items.length < 2) {
      throw StateError(
        'Too Few Arguments: SWAP requires 2 items on the stack.',
      );
    }
    snapshot();
    final a = _items.removeLast();
    final b = _items.removeLast();
    _items
      ..add(a)
      ..add(b);
  }

  /// `OVER`: Copies level `2:` to the top of the stack.
  void over() {
    if (_items.length < 2) {
      throw StateError(
        'Too Few Arguments: OVER requires 2 items on the stack.',
      );
    }
    snapshot();
    _items.add(_items[_items.length - 2]);
  }

  /// `ROT`: Rotates the top 3 stack levels (`3: a, 2: b, 1: c` -> `3: b, 2: c, 1: a`).
  void rot() {
    if (_items.length < 3) {
      throw StateError('Too Few Arguments: ROT requires 3 items on the stack.');
    }
    snapshot();
    final thirdIndex = _items.length - 3;
    final third = _items.removeAt(thirdIndex);
    _items.add(third);
  }

  /// `PICK`: Pops integer `n` from level `1:` (or uses explicit [n]) and copies
  /// level `n:` of the remaining stack to the top.
  void pick([int? n]) {
    if (n != null) {
      if (n < 1 || n > _items.length) {
        throw StateError(
          'PICK level $n out of range (depth ${_items.length}).',
        );
      }
      snapshot();
      _items.add(_items[_items.length - n]);
      return;
    }
    final top = pop(recordUndo: true);
    final idx = _extractPositiveInt(top.value, 'PICK');
    if (idx < 1 || idx > _items.length) {
      // Restore popped level before throwing
      _items.add(top);
      _undoStack.removeLast();
      throw StateError(
        'PICK level $idx out of range (depth ${_items.length}).',
      );
    }
    _lastArgs = [top];
    _items.add(_items[_items.length - idx]);
  }

  /// `ROLL`: Pops integer `n` from level `1:` (or uses explicit [n]) and moves
  /// level `n:` of the remaining stack to level `1:`.
  void roll([int? n]) {
    if (n != null) {
      if (n < 1 || n > _items.length) {
        throw StateError(
          'ROLL level $n out of range (depth ${_items.length}).',
        );
      }
      snapshot();
      final item = _items.removeAt(_items.length - n);
      _items.add(item);
      return;
    }
    final top = pop(recordUndo: true);
    final idx = _extractPositiveInt(top.value, 'ROLL');
    if (idx < 1 || idx > _items.length) {
      _items.add(top);
      _undoStack.removeLast();
      throw StateError(
        'ROLL level $idx out of range (depth ${_items.length}).',
      );
    }
    _lastArgs = [top];
    final item = _items.removeAt(_items.length - idx);
    _items.add(item);
  }

  /// `DEPTH`: Pushes the current stack depth as an integer onto level `1:`.
  void pushDepth({required int resultId}) {
    final currentDepth = _items.length;
    snapshot();
    _items.add(
      StackItem(
        resultId: resultId,
        value: ExprValue(IntegerNumber.of(currentDepth)),
      ),
    );
  }

  /// `CLEAR`: Empties the stack (undoable).
  void clear() {
    if (_items.isEmpty) return;
    snapshot();
    _lastArgs = List<StackItem>.of(_items);
    _items.clear();
  }

  /// `LASTARG`: Pushes the arguments consumed by the last command back onto
  /// the stack.
  void recallLastArgs() {
    if (_lastArgs.isEmpty) return;
    snapshot();
    _items.addAll(_lastArgs);
  }

  /// Removes a specific 1-based [level] during interactive stack selection.
  StackItem dropLevel(int level) {
    if (level < 1 || level > _items.length) {
      throw StateError('Stack level $level out of range.');
    }
    snapshot();
    return _items.removeAt(_items.length - level);
  }

  /// Replaces a specific 1-based [level] with [item].
  void replaceLevel(int level, StackItem item) {
    if (level < 1 || level > _items.length) {
      throw StateError('Stack level $level out of range.');
    }
    snapshot();
    _items[_items.length - level] = item;
  }

  /// `UNDO`: Restores the previous stack state.
  bool undo() {
    if (_undoStack.isEmpty) return false;
    _redoStack.add(List<StackItem>.of(_items));
    final prev = _undoStack.removeLast();
    _items
      ..clear()
      ..addAll(prev);
    return true;
  }

  /// `REDO`: Reapplies an undone stack state.
  bool redo() {
    if (_redoStack.isEmpty) return false;
    _undoStack.add(List<StackItem>.of(_items));
    final next = _redoStack.removeLast();
    _items
      ..clear()
      ..addAll(next);
    return true;
  }

  static int _extractPositiveInt(CalcValue value, String opName) {
    if (value case ExprValue(expr: IntegerNumber(asInt: final n?))
        when n >= 1) {
      return n;
    }
    throw ArgumentError('$opName expects a positive integer on level 1.');
  }

  List<Map<String, Object?>> toJson({int digits = 10}) => [
    for (final item in _items) item.toJson(digits: digits),
  ];

  void loadFromJson(List<Object?> json) {
    _items.clear();
    _undoStack.clear();
    _redoStack.clear();
    for (final raw in json) {
      _items.add(StackItem.fromJson(raw! as Map<String, Object?>));
    }
  }
}
