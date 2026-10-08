import 'dart:collection';

import '../../type/type.dart';
import '../layout.dart';

/// [Iterable] over the indices of a [Layout].
class IndexIterable extends IterableBase<int> {
  new(this.layout);

  final Layout layout;

  @override
  int get length => layout.length;

  @override
  Iterator<int> get iterator => IndexIterator(layout);
}

/// [Iterator] over the indices of a [Layout].
class IndexIterator implements Iterator<int> {
  new(Layout layout)
    : rank = layout.rank,
      shape = layout.shape,
      strides = layout.strides,
      indices = DataType.integer.newList(layout.rank, fillValue: 0),
      _hasMore = layout.length > 0,
      current = layout.rank > 0
          ? layout.offset - layout.strides.last
          : layout.offset {
    if (indices.isNotEmpty) indices.last = -1;
  }

  final int rank;
  final List<int> shape;
  final List<int> strides;
  final List<int> indices;
  bool _hasMore;

  @override
  int current;

  @override
  bool moveNext() {
    if (rank == 0) {
      if (!_hasMore) return false;
      _hasMore = false;
      return true;
    }
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
