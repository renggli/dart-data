library data.vector.vector;

import 'dart:collection' show ListMixin;

import 'package:data/src/vector/builder.dart';
import 'package:data/src/vector/format.dart';
import 'package:data/src/vector/view/cast_vector.dart';
import 'package:data/src/vector/view/index_vector.dart';
import 'package:data/src/vector/view/overlay_mask_vector.dart';
import 'package:data/src/vector/view/overlay_offset_vector.dart';
import 'package:data/src/vector/view/range_vector.dart';
import 'package:data/src/vector/view/reversed_vector.dart';
import 'package:data/src/vector/view/transformed_vector.dart';
import 'package:data/src/vector/view/unmodifiable_vector.dart';
import 'package:data/tensor.dart' show Tensor;
import 'package:data/type.dart' show DataType;
import 'package:more/printer.dart' show Printer;

/// Abstract vector type.
abstract class Vector<T> extends Tensor<T> {
  /// Default builder for new vectors.
  static Builder<Object> get builder =>
      Builder<Object>(Format.standard, DataType.object);

  /// Unnamed default constructor.
  Vector();

  /// Returns the shape of this vector.
  @override
  List<int> get shape => [count];

  /// Returns a copy of this vector.
  @override
  Vector<T> copy();

  /// The dimensionality of this vector.
  int get count;

  /// Returns the scalar at the provided [index].
  @override
  T operator [](int index) {
    RangeError.checkValidIndex(index, this, 'index', count);
    return getUnchecked(index);
  }

  /// Returns the scalar at the provided [index]. The behavior is undefined if
  /// [index] is outside of bounds.
  T getUnchecked(int index);

  /// Sets the scalar at the provided [index] to [value].
  void operator []=(int index, T value) {
    RangeError.checkValidIndex(index, this, 'index', count);
    setUnchecked(index, value);
  }

  /// Sets the scalar at the provided [index] to [value]. The behavior is
  /// undefined if [index] is outside of bounds.
  void setUnchecked(int index, T value);

  /// Returns a mutable view onto a vector range. Throws a [RangeError], if
  /// the index is out of bounds.
  Vector<T> range(int start, [int end]) {
    end = RangeError.checkValidRange(start, end, count, 'start', 'end');
    if (start == 0 && end == count) {
      return this;
    } else {
      return rangeUnchecked(start, end);
    }
  }

  /// Returns a mutable view onto a vector range. The behavior is undefined, if
  /// the range is out of bounds.
  Vector<T> rangeUnchecked(int start, int end) =>
      RangeVector<T>(this, start, end);

  /// Returns a mutable view onto indexes of a vector. Throws a [RangeError], if
  /// any of the indexes index is out of bounds.
  Vector<T> index(Iterable<int> indexes) {
    for (final index in indexes) {
      RangeError.checkValueInInterval(index, 0, count - 1, 'indexes');
    }
    return indexUnchecked(indexes);
  }

  /// Returns a mutable view onto a vector range. The behavior is undefined, if
  /// any of the indexes are out of bounds.
  Vector<T> indexUnchecked(Iterable<int> indexes) =>
      IndexVector<T>(this, indexes);

  /// Returns a mutable view where this vector is overlaid on top of a provided
  /// [base] vector. This happens either by using the given [offset], or using
  /// using a boolean [mask].
  Vector<T> overlay(
    Vector<T> base, {
    DataType<T> dataType,
    Vector<bool> mask,
    int offset,
  }) {
    dataType ??= this.dataType;
    if (mask == null && offset != null) {
      return OverlayOffsetVector(dataType, this, offset, base);
    } else if (mask != null && offset == null) {
      if (count != base.count || count != mask.count) {
        throw ArgumentError('Dimension of overlay ($count), mask '
            '(${mask.count}) and base (${base.count}) do not match.');
      }
      return OverlayMaskVector(dataType, this, mask, base);
    }
    throw ArgumentError('Either a mask or an offset required.');
  }

  /// Returns a read-only view on this [Vector] with all its elements lazily
  /// converted by calling the provided transformation [callback].
  Vector<S> map<S>(S Function(int index, T value) callback,
          [DataType<S> dataType]) =>
      transform<S>(callback, dataType: dataType);

  /// Returns a view on this [Vector] with all its elements lazily converted
  /// by calling the provided [read] transformation. An optionally provided
  /// [write] transformation enables writing to the returned vector.
  Vector<S> transform<S>(S Function(int index, T value) read,
          {T Function(int index, S value) write, DataType<S> dataType}) =>
      TransformedVector<T, S>(
        this,
        read,
        write ?? (i, v) => throw UnsupportedError('Vector is not mutable.'),
        dataType ?? DataType.fromType(S),
      );

  /// Returns a lazy [Vector] with the elements cast to `dataType`.
  Vector<S> cast<S>(DataType<S> dataType) => CastVector<T, S>(this, dataType);

  /// Returns a reversed view of the vector.
  Vector<T> get reversed => ReversedVector(this);

  /// Returns a unmodifiable view of the vector.
  Vector<T> get unmodifiable => UnmodifiableVector<T>(this);

  /// Returns a list iterable over the vector.
  List<T> get iterable => _VectorList<T>(this);

  /// Tests if [index] is within the bounds of this vector.
  bool isWithinBounds(int index) => 0 <= index && index < count;

  /// Returns a human readable representation of the vector.
  @override
  String format({
    Printer valuePrinter,
    Printer paddingPrinter,
    bool limit = true,
    int leadingItems = 3,
    int trailingItems = 3,
    String horizontalSeparator = ' ',
    String verticalSeparator = '\n',
    Printer ellipsesPrinter,
    String horizontalEllipses = '\u2026',
    String verticalEllipses = '\u22ee',
    String diagonalEllipses = '\u22f1',
  }) {
    final buffer = StringBuffer();
    valuePrinter ??= dataType.printer;
    paddingPrinter ??= Printer.standard();
    ellipsesPrinter ??= Printer.standard();
    for (var i = 0; i < count; i++) {
      if (i > 0) {
        buffer.write(horizontalSeparator);
      }
      if (limit && leadingItems <= i && i < count - trailingItems) {
        buffer.write(paddingPrinter(ellipsesPrinter(horizontalEllipses)));
        i = count - trailingItems - 1;
      } else {
        buffer.write(paddingPrinter(valuePrinter(getUnchecked(i))));
      }
    }
    return buffer.toString();
  }
}

class _VectorList<T> extends ListMixin<T> {
  final Vector<T> vector;

  _VectorList(this.vector);

  @override
  int get length => vector.count;

  @override
  set length(int newLength) =>
      throw UnsupportedError('Unable to change length of vector.');

  @override
  T operator [](int index) => vector[index];

  @override
  void operator []=(int index, T value) => vector[index] = value;
}
