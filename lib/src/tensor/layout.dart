import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'package:more/collection.dart';
import 'package:more/printer.dart';

import '../stats/iterable.dart';
import '../type/type.dart';
import 'layout/iterable.dart';
import 'utils/index.dart';

/// Immutable object describing a multi-dimensional data layout in a flat list
/// of values.
@immutable
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
    RangeError.checkValueInInterval(key.length, rank, rank, 'key.length');
    var index = offset;
    for (var i = 0; i < rank; i++) {
      final adjustedIndex = adjustIndex(key[i], shape[i]);
      RangeError.checkValueInInterval(adjustedIndex, 0, shape[i], 'key');
      index += adjustedIndex * strides[i];
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
    RangeError.checkValueInInterval(axis, 0, rank - 1, 'axis');
    final adjustedIndex = adjustIndex(index, shape[axis]);
    RangeError.checkValueInInterval(adjustedIndex, 0, shape[axis], 'index');
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
    RangeError.checkValueInInterval(axis, 0, rank - 1, 'axis');
    final adjustedStart = adjustIndex(start, shape[axis]);
    final adjustedEnd = adjustIndex(end, shape[axis]);
    RangeError.checkValidRange(
        adjustedStart, adjustedEnd, shape[axis], 'start', 'end');
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
          adjustedEnd == shape[axis] &&
          step == 1,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Layout &&
          offset == other.offset &&
          _listEquality.equals(shape, other.shape) &&
          _listEquality.equals(strides, other.strides);

  @override
  int get hashCode => Object.hash(
      offset, _listEquality.hash(shape), _listEquality.hash(strides));

  @override
  ObjectPrinter get toStringPrinter => super.toStringPrinter
    ..addValue(rank, name: 'rank')
    ..addValue(length, name: 'length')
    ..addValue(offset, name: 'offset')
    ..addValue(shape, name: 'shape')
    ..addValue(strides, name: 'strides');
}

const _listEquality = ListEquality<int>();

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
