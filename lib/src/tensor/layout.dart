import 'dart:typed_data';

/// Immutable multi-dimensional layout descriptor with strided coordinate mapping.
class Layout {
  factory({Iterable<int>? shape, Iterable<int>? strides, int offset = 0}) {
    final s = shape == null ? Int32List(0) : Int32List.fromList(shape.toList());
    for (final dim in s) {
      if (dim < 0) {
        throw ArgumentError('Shape dimensions must be non-negative: $s');
      }
    }
    final rank = s.length;
    var length = rank == 0 ? (shape == null ? 0 : 1) : 1;
    for (var i = 0; i < rank; i++) {
      length *= s[i];
    }
    Int32List str;
    if (strides != null) {
      str = Int32List.fromList(strides.toList());
      if (str.length != rank) {
        throw ArgumentError(
          'Strides length (${str.length}) must match rank ($rank)',
        );
      }
    } else {
      str = Int32List(rank);
      var currentStride = 1;
      for (var i = rank - 1; i >= 0; i--) {
        str[i] = currentStride;
        currentStride *= s[i];
      }
    }

    var isContiguous = true;
    if (rank > 0 && length > 0) {
      var expectedStride = 1;
      for (var i = rank - 1; i >= 0; i--) {
        if (s[i] > 1 && str[i] != expectedStride) {
          isContiguous = false;
          break;
        }
        expectedStride *= s[i];
      }
    }

    return Layout._(
      rank: rank,
      length: length,
      offset: offset,
      shape: s,
      strides: str,
      isContiguous: isContiguous,
    );
  }

  const new _({
    required this.rank,
    required this.length,
    required this.offset,
    required this.shape,
    required this.strides,
    required this.isContiguous,
  });

  static final Layout empty = Layout(shape: const [0]);

  final int rank;
  final int length;
  final int offset;
  final List<int> shape;
  final List<int> strides;
  final bool isContiguous;

  /// Converts an $N$-dimensional key into a flat buffer index.
  int toIndex(List<int> key) {
    if (key.length != rank) {
      throw ArgumentError('Key length (${key.length}) must match rank ($rank)');
    }
    var index = offset;
    for (var i = 0; i < rank; i++) {
      final k = key[i];
      final dim = shape[i];
      final normalizedK = k < 0 ? k + dim : k;
      if (normalizedK < 0 || normalizedK >= dim) {
        throw RangeError.value(
          k,
          'key[$i]',
          'Index out of bounds for axis $i of size $dim',
        );
      }
      index += normalizedK * strides[i];
    }
    return index;
  }

  /// Converts a flat index (0 to length-1) to an $N$-dimensional key.
  List<int> toKey(int linearIndex) {
    if (linearIndex < 0 || linearIndex >= length) {
      throw RangeError.range(linearIndex, 0, length - 1, 'linearIndex');
    }
    final key = List<int>.filled(rank, 0);
    var remaining = linearIndex;
    for (var i = 0; i < rank; i++) {
      var stride = 1;
      for (var j = i + 1; j < rank; j++) {
        stride *= shape[j];
      }
      key[i] = remaining ~/ stride;
      remaining %= stride;
    }
    return key;
  }

  /// Slices the first axis at [index].
  Layout operator [](int index) {
    if (rank == 0) throw StateError('Cannot slice 0-rank layout');
    final dim = shape[0];
    final normalized = index < 0 ? index + dim : index;
    if (normalized < 0 || normalized >= dim) {
      throw RangeError.range(index, 0, dim - 1, 'index');
    }
    return Layout(
      shape: shape.sublist(1),
      strides: strides.sublist(1),
      offset: offset + normalized * strides[0],
    );
  }

  /// Transposes the layout by permuting the axes.
  Layout transpose([List<int>? axes]) {
    final perm = axes ?? List<int>.generate(rank, (i) => rank - 1 - i);
    if (perm.length != rank) {
      throw ArgumentError(
        'Permutation length (${perm.length}) must match rank ($rank)',
      );
    }
    final newShape = List<int>.generate(rank, (i) => shape[perm[i]]);
    final newStrides = List<int>.generate(rank, (i) => strides[perm[i]]);
    return Layout(shape: newShape, strides: newStrides, offset: offset);
  }

  /// Reshapes this layout to a [newShape].
  Layout reshape(List<int> newShape) {
    var newLength = 1;
    var inferredIndex = -1;
    for (var i = 0; i < newShape.length; i++) {
      final dim = newShape[i];
      if (dim == -1) {
        if (inferredIndex != -1) {
          throw ArgumentError('Can only infer one dimension');
        }
        inferredIndex = i;
      } else if (dim < 0) {
        throw ArgumentError(
          'Shape dimensions must be non-negative or -1: $newShape',
        );
      } else {
        newLength *= dim;
      }
    }
    final effectiveShape = List<int>.from(newShape);
    if (inferredIndex != -1) {
      if (length % newLength != 0) {
        throw ArgumentError(
          'Cannot reshape tensor of length $length into $newShape',
        );
      }
      effectiveShape[inferredIndex] = length ~/ newLength;
      newLength = length;
    }
    if (newLength != length) {
      throw ArgumentError('Total elements must match: $length != $newLength');
    }
    if (!isContiguous) {
      throw StateError('Cannot reshape a non-contiguous layout without copy');
    }
    return Layout(shape: effectiveShape, offset: offset);
  }

  /// Flips layout along the specified [axis].
  Layout flip({int axis = 0}) {
    final normAxis = axis < 0 ? axis + rank : axis;
    if (normAxis < 0 || normAxis >= rank) {
      throw RangeError.value(axis, 'axis', 'Out of bounds [0, $rank)');
    }
    final newStrides = List<int>.from(strides);
    final dim = shape[normAxis];
    newStrides[normAxis] = -strides[normAxis];
    final newOffset = offset + (dim - 1) * strides[normAxis];
    return Layout(shape: shape, strides: newStrides, offset: newOffset);
  }

  /// Broadcasts this layout with [other] to a common shape.
  (Layout, Layout) broadcast(Layout other) {
    final maxRank = rank > other.rank ? rank : other.rank;
    final outShape = List<int>.filled(maxRank, 0);
    final thisStrides = List<int>.filled(maxRank, 0);
    final otherStrides = List<int>.filled(maxRank, 0);

    for (var i = 0; i < maxRank; i++) {
      final thisIdx = rank - 1 - i;
      final otherIdx = other.rank - 1 - i;
      final thisDim = thisIdx >= 0 ? shape[thisIdx] : 1;
      final otherDim = otherIdx >= 0 ? other.shape[otherIdx] : 1;

      if (thisDim != otherDim && thisDim != 1 && otherDim != 1) {
        throw ArgumentError(
          'Incompatible shapes for broadcasting: $shape and ${other.shape}',
        );
      }

      final outDim = thisDim > otherDim ? thisDim : otherDim;
      outShape[maxRank - 1 - i] = outDim;

      thisStrides[maxRank - 1 - i] = thisDim == 1
          ? 0
          : (thisIdx >= 0 ? strides[thisIdx] : 0);
      otherStrides[maxRank - 1 - i] = otherDim == 1
          ? 0
          : (otherIdx >= 0 ? other.strides[otherIdx] : 0);
    }

    final outThis = Layout(
      shape: outShape,
      strides: thisStrides,
      offset: offset,
    );
    final outOther = Layout(
      shape: outShape,
      strides: otherStrides,
      offset: other.offset,
    );
    return (outThis, outOther);
  }

  /// Slices a range along [axis].
  Layout getRange({required int axis, int? start, int? end, int step = 1}) {
    final normAxis = axis < 0 ? axis + rank : axis;
    if (normAxis < 0 || normAxis >= rank) {
      throw RangeError.value(axis, 'axis', 'Out of bounds [0, $rank)');
    }
    final dim = shape[normAxis];
    final s = start ?? 0;
    final e = end ?? dim;
    if (s < 0 || s > dim) throw RangeError.range(s, 0, dim, 'start');
    if (e < s || e > dim) throw RangeError.range(e, s, dim, 'end');
    if (step <= 0) throw ArgumentError.value(step, 'step', 'Must be positive');

    final newShape = List<int>.from(shape);
    final newStrides = List<int>.from(strides);
    final count = ((e - s) + step - 1) ~/ step;
    newShape[normAxis] = count;
    newStrides[normAxis] = strides[normAxis] * step;
    final newOffset = offset + s * strides[normAxis];

    return Layout(shape: newShape, strides: newStrides, offset: newOffset);
  }

  /// All index offsets in the underlying buffer.
  Iterable<int> get indices sync* {
    if (length == 0) return;
    if (rank == 0) {
      yield offset;
      return;
    }
    for (final key in keys) {
      yield toIndex(key);
    }
  }

  /// All multi-dimensional coordinate keys.
  Iterable<List<int>> get keys sync* {
    if (length == 0) return;
    if (rank == 0) {
      yield const [];
      return;
    }
    final current = List<int>.filled(rank, 0);
    while (true) {
      yield List<int>.from(current);
      var pos = rank - 1;
      while (pos >= 0) {
        current[pos]++;
        if (current[pos] < shape[pos]) {
          break;
        }
        current[pos] = 0;
        pos--;
      }
      if (pos < 0) break;
    }
  }

  @override
  String toString() =>
      'Layout(rank: $rank, length: $length, offset: $offset, shape: $shape, strides: $strides, isContiguous: $isContiguous)';
}
