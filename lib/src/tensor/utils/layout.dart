import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'package:more/collection.dart';
import 'package:more/printer.dart';

import '../../stats/iterable.dart';
import '../../type/type.dart';
import '../iterables/index.dart';
import '../iterables/key.dart';
import 'errors.dart';
import 'index.dart';

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
      isContiguous: shape_.isEmpty ||
          strides == null ||
          _isContiguous(shape: shape_, strides: strides_),
    );
  }

  factory Layout.fromObject(dynamic object) {
    if (object == null) {
      return empty;
    }
    final shape = <int>[];
    for (dynamic current = object;
        current is Iterable;
        current = current.first) {
      shape.add(current.length);
    }
    return Layout(shape: shape);
  }

  static final empty = Layout.internal(
      rank: 0,
      length: 0,
      offset: 0,
      shape: _toIndices([]),
      strides: _toIndices([]),
      isContiguous: true);

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
        assert(length == shape.product() || (length == 0 && rank == 0),
            '`length` should match `shape`'),
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
      ? length == 0
          ? const []
          : [offset]
      : isContiguous
          ? IntegerRange(offset, offset + length)
          : IndexIterable(this);

  /// An iterable over the keys of this layout.
  Iterable<List<int>> get keys => rank == 0
      ? length == 0
          ? const <List<int>>[]
          : const <List<int>>[[]]
      : KeyIterable(this);

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
    final key = DataType.integer.newList(rank);
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

  /// Returns a layout with a single-element axis at `axis` added.
  Layout expand({int axis = 0}) {
    RangeError.checkValueInInterval(axis, 0, rank, 'axis');
    final shape_ = [...shape.take(axis), 1, ...shape.skip(axis)];
    final strides_ = [
      ...strides.take(axis),
      axis < rank ? strides[axis] : 1,
      ...strides.skip(axis),
    ];
    return Layout.internal(
      rank: rank + 1,
      length: length,
      offset: offset,
      shape: _toIndices(shape_),
      strides: _toIndices(strides_),
      isContiguous: isContiguous,
    );
  }

  /// Returns a layout with a single-element axis at `axis` removed.
  Layout collapse({int axis = 0}) {
    RangeError.checkValueInInterval(axis, 0, rank - 1, 'axis');
    if (shape[axis] != 1) {
      throw ArgumentError.value(
          axis, 'axis', '$shape at $axis is greater than 1');
    }
    final shape_ = [...shape.take(axis), ...shape.skip(axis + 1)];
    final strides_ = [...strides.take(axis), ...strides.skip(axis + 1)];
    return Layout.internal(
      rank: rank - 1,
      length: length,
      offset: offset,
      shape: _toIndices(shape_),
      strides: _toIndices(strides_),
      isContiguous: isContiguous,
    );
  }

  /// Returns an updated layout with the first axis resolved to [index].
  Layout operator [](int index) => elementAt(index);

  /// Returns an updated layout with the given [axis] resolved to [index].
  Layout elementAt(int index, {int axis = 0}) {
    final axis_ = adjustIndex(axis, rank);
    RangeError.checkValueInInterval(axis_, 0, rank - 1, 'axis');
    final index_ = adjustIndex(index, shape[axis_]);
    RangeError.checkValueInInterval(index_, 0, shape[axis_], 'index');
    return Layout(
      shape: [...shape.take(axis_), ...shape.skip(axis_ + 1)],
      strides: [...strides.take(axis_), ...strides.skip(axis_ + 1)],
      offset: offset + index_ * strides[axis_],
    );
  }

  /// Returns an updated layout with the given [axis] sliced to the range
  /// between [start] and [end] (exclusive).
  Layout getRange(int start, int? end, {int step = 1, int axis = 0}) {
    final axis_ = adjustIndex(axis, rank);
    RangeError.checkValueInInterval(axis_, 0, rank - 1, 'axis');
    final start_ = adjustIndex(start, shape[axis_]);
    final end_ = adjustIndex(end ?? shape[axis_], shape[axis_]);
    RangeError.checkValidRange(start_, end_, shape[axis_], 'start', 'end');
    checkPositive(step, 'step');
    final rangeLength = (end_ - start_) ~/ step;
    return Layout(
      shape: [...shape.take(axis_), rangeLength, ...shape.skip(axis_ + 1)],
      strides: [
        ...strides.take(axis_),
        step * strides[axis_],
        ...strides.skip(axis_ + 1),
      ],
      offset: offset + start_ * strides[axis_],
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
    ..addValue(strides, name: 'strides')
    ..addValue(isContiguous, name: 'isContiguous');
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
