import 'dart:collection';

import '../../type/type.dart';
import '../layout.dart';

/// Iterable over the keys of a [Layout].
class KeyIterable extends IterableBase<List<int>> {
  KeyIterable(this.layout);

  final Layout layout;

  @override
  int get length => layout.length;

  @override
  Iterator<List<int>> get iterator => KeyIterator(layout);
}

/// Iterator over the keys of a [Layout].
class KeyIterator implements Iterator<List<int>> {
  KeyIterator(Layout layout)
      : rank = layout.rank,
        shape = layout.shape,
        current = DataType.integer.newList(layout.rank, fillValue: 0) {
    current.last = -1;
  }

  final int rank;
  final List<int> shape;

  @override
  List<int> current;

  @override
  bool moveNext() {
    for (var i = rank - 1; i >= 0; i--) {
      current[i]++;
      if (current[i] < shape[i]) return true;
      current[i] = 0;
    }
    return false;
  }
}
