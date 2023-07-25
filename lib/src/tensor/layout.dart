import 'dart:typed_data';

import 'package:meta/meta.dart';
import 'package:more/collection.dart';
import 'package:more/printer.dart';

import '../stats/iterable.dart';
import '../type/type.dart';
import 'layout/iterable.dart';

/// Describes the data layout in a list of values.
class Layout with ToStringPrinter {
  factory Layout({Iterable<int>? shape, Iterable<int>? strides, int? offset}) {
    final shape_ = _toIndices(shape ?? const <int>[]);
    final strides_ =
        strides == null ? _toStrides(shape: shape_) : _toIndices(strides);
    return Layout.internal(
      rank: shape_.length,
      length: shape_.product(),
      shape: shape_,
      strides: strides_,
      offset: offset ?? 0,
      isContiguous:
          strides == null || _isContiguous(shape: shape_, strides: strides_),
    );
  }

  factory Layout.fromObject(Iterable<dynamic> object) {
    final shape = <int>[];
    for (Object? current = object;
        current is Iterable;
        current = current.first) {
      shape.add(current.length);
    }
    return Layout(shape: shape);
  }

  /// Internal constructor of [Layout] object.
  @internal
  Layout.internal({
    required this.rank,
    required this.length,
    required this.offset,
    required this.shape,
    required this.strides,
    required this.isContiguous,
  })  : assert(shape is TypedData, '`shape` should be TypedData'),
        assert(shape.length == rank, '`shape` should be of length $rank'),
        assert(shape.every((s) => s > 0), '`shape` should be positive'),
        assert(strides is TypedData, '`strides` should be TypedData'),
        assert(strides.length == rank, '`strides` should be of length $rank'),
        assert(strides.every((s) => s != 0), '`stride` should be non-zero'),
        assert(length == shape.product(), '`length` should match `shape`'),
        assert(isContiguous == _isContiguous(shape: shape, strides: strides));

  /// The number of dimensions.
  final int rank;

  /// The total number of elements.
  final int length;

  /// The absolute offset of the data.
  final int offset;

  /// The length of each dimension.
  final List<int> shape;

  /// The number of indices to jump to the next value in each dimension.
  final List<int> strides;

  /// True, if the values in this layout are in sequence.
  final bool isContiguous;

  /// An iterable over the indices of this layout.
  Iterable<int> get indices => rank == 0
      ? [offset]
      : isContiguous
          ? IntegerRange(offset, offset + length)
          : OffsetIterable(this);

  /// An iterable over the keys of this layout.
  Iterable<List<int>> get keys => indices.map((index) => toKey(index));

  /// Converts a key (index-list) to an index.
  int toIndex(List<int> key) {
    assert(key.length == rank, 'Expected key of length $rank, but got $key');
    var index = offset;
    for (var i = 0; i < rank; i++) {
      var adjusted = key[i];
      if (adjusted < 0) adjusted += shape[i];
      assert(0 <= adjusted && adjusted < shape[i],
          'Index ${key[i]} is out of range');
      index += adjusted * strides[i];
    }
    return index;
  }

  /// Converts an `offset` to a key, that is a list of indices.
  List<int> toKey(int index) {
    var value = index - offset;
    final key = DataType.index.newList(rank);
    for (var i = 0; i < rank; i++) {
      final div = value ~/ strides[i], rem = div % shape[i];
      value -= (key[i] = rem) * strides[i];
    }
    assert(value == 0, 'Invalid index $index');
    return key;
  }

  /// Returns an updated layout with the transposed axis.
  Layout transpose({List<int>? axes}) {
    axes ??= IntegerRange(rank).reversed;
    final shape_ = _toIndices(axes.map((each) => shape[each]));
    final strides_ = _toIndices(axes.map((each) => strides[each]));
    return Layout.internal(
      rank: rank,
      length: length,
      shape: shape_,
      strides: strides_,
      offset: offset,
      isContiguous: _isContiguous(shape: shape_, strides: strides_),
    );
  }

  /// Returns an updated layout with the first axis resolved to [index].
  Layout operator [](int index) => elementAt(index);

  /// Returns an updated layout with the given [axis] resolved to [index].
  Layout elementAt(int index, {int axis = 0}) {
    assert(0 < rank, 'Expected non-zero rank');
    assert(0 <= axis && axis < rank,
        '`axis` is out of range, expected $axis in 0..${rank - 1}');
    final adjustedIndex = index < 0 ? index + shape[axis] : index;
    assert(0 <= adjustedIndex && adjustedIndex < shape[axis],
        '`index` is out of range, expected $index in 0..${shape[axis] - 1}');
    return Layout.internal(
      rank: rank - 1,
      length: length ~/ shape[axis],
      offset: offset + adjustedIndex * strides[axis],
      shape: _toIndices([
        ...shape.take(axis),
        ...shape.skip(axis + 1),
      ]),
      strides: _toIndices([
        ...strides.take(axis),
        ...strides.skip(axis + 1),
      ]),
      isContiguous: isContiguous && axis == 0,
    );
  }

  /// Returns an updated layout with the given [axis] sliced to the range
  /// between [start] and [end] (exclusive).
  Layout getRange(int start, int end, {int step = 1, int axis = 0}) {
    assert(0 < rank, 'Expected non-zero rank');
    assert(0 <= axis && axis < rank,
        '`axis` is out of range, expected $axis in 0..${rank - 1}');
    final adjustedStart = start < 0 ? start + shape[axis] : start;
    assert(0 <= adjustedStart && adjustedStart <= shape[axis],
        '`start` is out of range, expected $start in 0..${shape[axis]}');
    final adjustedEnd = end < 0 ? end + shape[axis] : end;
    assert(adjustedStart <= adjustedEnd && adjustedEnd <= shape[axis],
        '`end` is out of range, expected $end in $adjustedStart..${shape[axis]}');
    final rangeLength = (adjustedEnd - adjustedStart) ~/ step;
    return Layout.internal(
      rank: rank,
      length: length ~/ shape[axis] * rangeLength,
      offset: offset + adjustedStart * strides[axis],
      shape: _toIndices([
        ...shape.take(axis),
        rangeLength,
        ...shape.skip(axis + 1),
      ]),
      strides: _toIndices([
        ...strides.take(axis),
        step * strides[axis],
        ...strides.skip(axis + 1),
      ]),
      isContiguous: isContiguous &&
          adjustedStart == 0 &&
          adjustedEnd == shape[0] &&
          step == 1,
    );
  }

  @override
  ObjectPrinter get toStringPrinter => super.toStringPrinter
    ..addValue(rank, name: 'rank')
    ..addValue(length, name: 'length')
    ..addValue(offset, name: 'offset')
    ..addValue(shape, name: 'shape')
    ..addValue(strides, name: 'strides');
}

List<int> _toIndices(Iterable<int> iterable) =>
    DataType.integer.copyList(iterable, readonly: true);

List<int> _toStrides({required List<int> shape}) {
  final result = DataType.integer.newList(shape.length, fillValue: 1);
  for (var i = result.length - 1; i > 0; i--) {
    result[i - 1] = result[i] * shape[i];
  }
  return _toIndices(result);
}

bool _isContiguous({required List<int> shape, required List<int> strides}) {
  for (var i = shape.length - 1, p = 1; i >= 0; i--) {
    if (shape[i] != 1) {
      if (strides[i] == p) {
        p *= shape[i];
      } else {
        return false;
      }
    }
  }
  return true;
}
