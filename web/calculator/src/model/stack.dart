import 'package:data/symbolic.dart';

import 'serialization.dart';
import 'value.dart';

/// A single entry on the HP48-style RPN stack.
final class StackItem {
  const new({
    required this.resultId,
    required this.value,
    this.isLiteralPush = false,
  });

  /// Shared session result identifier `r[resultId]` (or `0` for synthetic
  /// stack-depth values).
  final int resultId;

  /// Calculator value at this stack level.
  final CalcValue value;

  /// Whether this stack entry originated from a raw literal/symbol push in RPN
  /// mode (so its cell can be coalesced when popped by an RPN operator or
  /// command).
  final bool isLiteralPush;

  Map<String, Object?> toJson({int digits = 10}) => {
    'resultId': resultId,
    'value': CalcSerialization.toJson(value, digits: digits),
    if (isLiteralPush) 'isLiteralPush': true,
  };

  factory fromJson(Map<String, Object?> json) => StackItem(
    resultId: (json['resultId'] as num?)?.toInt() ?? 0,
    value: CalcSerialization.fromJson(json['value']! as Map<String, Object?>),
    isLiteralPush: json['isLiteralPush'] as bool? ?? false,
  );
}

/// HP48-style RPN stack machine.
///
/// Stack levels follow HP48 convention:
/// - Level `1:` is the top of the stack (nearest the command line, last element
///   of [_items]).
/// - Level `2:` is the second item from the top, and so on up to [depth].
final class RpnStack {
  final List<StackItem> _items = [];

  /// Number of items currently on the stack.
  int get depth => _items.length;

  /// Whether the stack is empty.
  bool get isEmpty => _items.isEmpty;

  /// Items ordered from bottom (oldest, level `depth:`) to top (newest,
  /// level `1:`).
  List<StackItem> get items => List.unmodifiable(_items);

  /// Captures an internal stack checkpoint for transactional execution.
  ({List<StackItem> items}) checkpoint() => (items: List<StackItem>.of(_items));

  /// Restores stack state to [cp].
  void restoreCheckpoint(({List<StackItem> items}) cp) {
    _items
      ..clear()
      ..addAll(cp.items);
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

  /// Pushes [item] onto level `1:`.
  void push(StackItem item) {
    _items.add(item);
  }

  /// Pops and returns level `1:`.
  StackItem pop() {
    if (_items.isEmpty) {
      throw StateError('Too Few Arguments: stack is empty.');
    }
    return _items.removeLast();
  }

  /// Pops [count] arguments from the top of the stack in HP48 order:
  /// `[level(count), ..., level(2), level(1)]`.
  List<StackItem> popArgs(int count) {
    if (_items.length < count) {
      throw StateError(
        'Too Few Arguments: need $count argument(s), stack has ${_items.length}.',
      );
    }
    final start = _items.length - count;
    final popped = _items.sublist(start);
    _items.removeRange(start, _items.length);
    return popped;
  }

  /// `DUP`: Duplicates level `1:`.
  void dup() {
    if (_items.isEmpty) {
      throw StateError('Too Few Arguments: DUP requires 1 item on the stack.');
    }
    _items.add(_items.last);
  }

  /// `DROP`: Removes level `1:`.
  StackItem drop() {
    if (_items.isEmpty) {
      throw StateError('Too Few Arguments: DROP requires 1 item on the stack.');
    }
    return _items.removeLast();
  }

  /// `SWAP`: Exchanges level `1:` and level `2:`.
  void swap() {
    if (_items.length < 2) {
      throw StateError(
        'Too Few Arguments: SWAP requires 2 items on the stack.',
      );
    }
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
    _items.add(_items[_items.length - 2]);
  }

  /// `ROT`: Rotates the top 3 stack levels (`3: a, 2: b, 1: c` -> `3: b, 2: c, 1: a`).
  void rot() {
    if (_items.length < 3) {
      throw StateError('Too Few Arguments: ROT requires 3 items on the stack.');
    }
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
      _items.add(_items[_items.length - n]);
      return;
    }
    final top = pop();
    final idx = _extractPositiveInt(top.value, 'PICK');
    if (idx < 1 || idx > _items.length) {
      _items.add(top);
      throw StateError(
        'PICK level $idx out of range (depth ${_items.length}).',
      );
    }
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
      final item = _items.removeAt(_items.length - n);
      _items.add(item);
      return;
    }
    final top = pop();
    final idx = _extractPositiveInt(top.value, 'ROLL');
    if (idx < 1 || idx > _items.length) {
      _items.add(top);
      throw StateError(
        'ROLL level $idx out of range (depth ${_items.length}).',
      );
    }
    final item = _items.removeAt(_items.length - idx);
    _items.add(item);
  }

  /// `DEPTH`: Pushes the current stack depth as an integer onto level `1:`.
  void pushDepth({required int resultId}) {
    final currentDepth = _items.length;
    _items.add(
      StackItem(
        resultId: resultId,
        value: ExprValue(IntegerNumber.of(currentDepth)),
      ),
    );
  }

  /// `CLEAR`: Empties the stack.
  void clear() {
    if (_items.isEmpty) return;
    _items.clear();
  }

  /// Removes a specific 1-based [level] during interactive stack selection.
  StackItem dropLevel(int level) {
    if (level < 1 || level > _items.length) {
      throw StateError('Stack level $level out of range.');
    }
    return _items.removeAt(_items.length - level);
  }

  /// Replaces a specific 1-based [level] with [item].
  void replaceLevel(int level, StackItem item) {
    if (level < 1 || level > _items.length) {
      throw StateError('Stack level $level out of range.');
    }
    _items[_items.length - level] = item;
  }

  /// Updates any stack items referencing [resultId] with [newValue].
  void updateResultValue(int resultId, CalcValue newValue) {
    for (var i = 0; i < _items.length; i++) {
      final cur = _items[i];
      if (cur.resultId == resultId) {
        _items[i] = StackItem(
          resultId: resultId,
          value: newValue,
          isLiteralPush: cur.isLiteralPush,
        );
      }
    }
  }

  /// Removes any stack items referencing [resultId] (e.g. when a cell is
  /// deleted in Scroll mode).
  void removeResultId(int resultId) {
    _items.removeWhere((item) => item.resultId == resultId);
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
    for (final raw in json) {
      _items.add(StackItem.fromJson(raw! as Map<String, Object?>));
    }
  }
}
