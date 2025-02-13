import 'dart:collection';

import '../../type/type.dart';
import '../layout.dart';

/// [Iterable] over the indices of a [Layout].
class IndexIterable extends IterableBase<int> {
  IndexIterable(this.layout);

  final Layout layout;

  @override
  int get length => layout.length;

  @override
  Iterator<int> get iterator => IndexIterator(layout);
}

/// [Iterator] over the indices of a [Layout].
class IndexIterator implements Iterator<int> {
  IndexIterator(Layout layout)
    : rank = layout.rank,
      shape = layout.shape,
      strides = layout.strides,
      indices = DataType.integer.newList(layout.rank, fillValue: 0),
      current = layout.offset - layout.strides.last {
    indices.last = -1;
  }

  final int rank;
  final List<int> shape;
  final List<int> strides;
  final List<int> indices;

  @override
  int current;

  @override
  bool moveNext() {
    for (var i = rank - 1; i >= 0; i--) {
      indices[i]++;
      current += strides[i];
      if (indices[i] < shape[i]) return true;
      indices[i] = 0;
      current -= shape[i] * strides[i];
    }
    return false;
  }
}
