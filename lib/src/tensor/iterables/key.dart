import 'dart:collection';

import '../../type/type.dart';
import '../layout.dart';

/// [Iterable] over the keys of a [Layout].
class KeyIterable extends IterableBase<List<int>> {
  new(this.layout);

  final Layout layout;

  @override
  int get length => layout.length;

  @override
  Iterator<List<int>> get iterator => KeyIterator(layout);
}

/// [Iterator] over the keys of a [Layout].
class KeyIterator implements Iterator<List<int>> {
  new(Layout layout)
    : rank = layout.rank,
      shape = layout.shape,
      _hasMore = layout.length > 0,
      current = DataType.integer.newList(layout.rank, fillValue: 0) {
    if (current.isNotEmpty) current.last = -1;
  }

  final int rank;
  final List<int> shape;
  bool _hasMore;

  @override
  List<int> current;

  @override
  bool moveNext() {
    if (rank == 0) {
      if (!_hasMore) return false;
      _hasMore = false;
      return true;
    }
    for (var i = rank - 1; i >= 0; i--) {
      current[i]++;
      if (current[i] < shape[i]) return true;
      current[i] = 0;
    }
    return false;
  }
}
