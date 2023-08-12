import 'dart:typed_data';

import 'package:meta/meta.dart';
import 'package:more/collection.dart';
import 'package:more/printer.dart';

import '../stats/iterable.dart';
import '../type/type.dart';
import 'iterables/index.dart';
import 'iterables/key.dart';
import 'operations/element.dart';
import 'utils/errors.dart';
import 'utils/layout.dart' as utils;

/// Immutable object describing a multi-dimensional data layout in a flat list
/// of values.
@immutable
class Layout with ToStringPrinter {
  factory Layout({Iterable<int>? shape, Iterable<int>? strides, int? offset}) {
    final shape_ = utils.toIndices(shape ?? const <int>[]);
    final strides_ = strides == null
        ? utils.toStrides(shape: shape_)
        : utils.toIndices(strides);
    return Layout.internal(
      rank: shape_.length,
      length: shape_.product(),
      shape: shape_,
      strides: strides_,
      offset: offset ?? 0,
      isContiguous: shape_.isEmpty ||
          strides == null ||
          utils.isContiguous(shape: shape_, strides: strides_),
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
      shape: utils.toIndices([]),
      strides: utils.toIndices([]),
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
        assert(
            isContiguous == utils.isContiguous(shape: shape, strides: strides));

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
      final adjustedIndex = checkIndex(key[i], shape[i], 'key');
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

  /// Returns an updated layout with the first axis resolved to [index].
  Layout operator [](int index) => elementAt(index);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Layout &&
          offset == other.offset &&
          utils.indicesEquality.equals(shape, other.shape) &&
          utils.indicesEquality.equals(strides, other.strides);

  @override
  int get hashCode => Object.hash(offset, utils.indicesEquality.hash(shape),
      utils.indicesEquality.hash(strides));

  @override
  ObjectPrinter get toStringPrinter => super.toStringPrinter
    ..addValue(rank, name: 'rank')
    ..addValue(length, name: 'length')
    ..addValue(offset, name: 'offset')
    ..addValue(shape, name: 'shape')
    ..addValue(strides, name: 'strides')
    ..addValue(isContiguous, name: 'isContiguous');
}
