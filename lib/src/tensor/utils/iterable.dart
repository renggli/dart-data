import 'dart:collection';

import '../../type/type.dart';
import 'layout.dart';

/// Iterable over the
class TensorIterable extends IterableBase<int> {
  TensorIterable(this.layout);

  final Layout layout;

  @override
  int get length => layout.length;

  @override
  Iterator<int> get iterator => TensorIterator(layout);
}

class TensorIterator implements Iterator<int> {
  TensorIterator(Layout layout)
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
